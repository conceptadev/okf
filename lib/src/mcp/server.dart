import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import '../bundle_change_set.dart';
import '../concept_id.dart';
import '../document.dart';
import '../finding.dart';
import '../graph.dart';
import '../io/bundle_change_applier.dart';
import '../io/bundle_loader.dart';
import '../version.dart';

/// The OKF tool surface served over the Model Context Protocol.
///
/// Every tool re-reads the bundle from disk, so an agent that edits files
/// between calls never observes a stale answer. The write verbs are adapters
/// over [OkfBundleChangeApplier]: they translate tool arguments into a change
/// description and return its result, so validation, index and log
/// maintenance, and atomicity have one owner.
final class OkfMcpServer {
  /// Creates a server that reads and writes the bundle at [rootPath].
  OkfMcpServer({
    required this.rootPath,
    OkfBundleLoader loader = const OkfBundleLoader(),
  })  : _loader = loader,
        _applier = const OkfBundleChangeApplier();

  /// The bundle root every tool reads.
  final String rootPath;

  final OkfBundleLoader _loader;

  /// Owns preparation and exact prepared commits for every write tool.
  final OkfBundleChangeApplier _applier;

  /// Serves the tool surface over stdio until the client disconnects.
  ///
  /// Standard output carries JSON-RPC alone, so every diagnostic goes to
  /// standard error. Reading the bundle before the transport starts tells a
  /// client that the root is unreadable at startup rather than through a tool
  /// error on every later call.
  Future<void> serve() async {
    final loaded = await _loader.inspect(rootPath);
    stderr.writeln(
      'okf mcp: serving ${loaded.bundle.concepts.length} concept(s) '
      'from ${loaded.rootPath}'
      '${loaded.hasFindings ? '; ${loaded.report.findings.length} unreadable file(s)' : ''}',
    );

    final server = _buildServer();
    final closed = Completer<void>();
    server.server.onclose = () {
      if (!closed.isCompleted) {
        closed.complete();
      }
    };
    await server.connect(StdioServerTransport());
    await closed.future;
  }

  McpServer _buildServer() {
    final server = McpServer(
      const Implementation(name: 'okf', version: okfPackageVersion),
      options: const McpServerOptions(
        capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
      ),
    );
    _registerReadTools(server);
    _registerWriteTools(server);
    return server;
  }

  void _registerReadTools(McpServer server) {
    server.registerTool(
      'list-concepts',
      description: 'List every concept in the bundle with its metadata.',
      inputSchema: JsonSchema.object(
        properties: const <String, JsonSchema>{},
        additionalProperties: false,
      ),
      annotations: _readOnlyAnnotations,
      callback: (arguments, extra) => _readComplete((loaded) => _payload(
            <String, Object?>{
              'concepts': <Map<String, Object?>>[
                for (final entry in loaded.bundle.concepts.entries)
                  _conceptSummary(entry.key, entry.value),
              ],
            },
          )),
    );

    server.registerTool(
      'lookup-concept',
      description: 'Read one concept in its canonical Markdown form.',
      inputSchema: JsonSchema.object(
        properties: <String, JsonSchema>{'id': _conceptIdSchema},
        required: const <String>['id'],
        additionalProperties: false,
      ),
      annotations: _readOnlyAnnotations,
      callback: (arguments, extra) => _readComplete((loaded) {
        final id = OkfConceptId(arguments['id']! as String);
        final document = loaded.bundle.concept(id);
        if (document == null) {
          throw FormatException('Unknown concept: ${id.value}');
        }
        return _payload(<String, Object?>{
          ..._conceptSummary(id, document),
          'markdown': document.serialize(),
        });
      }),
    );

    server.registerTool(
      'query-graph',
      description: 'Query the bundle relationship graph as versioned JSON.',
      inputSchema: JsonObject.fromJson(OkfGraphQuery.jsonSchema),
      annotations: _readOnlyAnnotations,
      callback: (arguments, extra) => _readComplete(
        (loaded) => _payload(
          OkfGraph.fromBundle(
            loaded.bundle,
            query: OkfGraphQuery.fromJson(arguments),
          ).toJson(),
        ),
      ),
    );

    server.registerTool(
      'validate',
      description: 'Validate the bundle and judge it as the CI gate does.',
      inputSchema: JsonSchema.object(
        properties: <String, JsonSchema>{
          'strict': JsonSchema.boolean(
            description: 'Fail on advisories, as `--warnings-as-errors` does.',
          ),
        },
        additionalProperties: false,
      ),
      annotations: _readOnlyAnnotations,
      callback: (arguments, extra) => _readInspection((loaded) {
        final verdict = OkfVerdict.of(
          loaded.validate().report,
          strict: arguments['strict'] as bool? ?? false,
        );
        return _payload(<String, Object?>{
          'report': verdict.report.toJson(),
          'strict': verdict.strict,
          'exit_code': verdict.exitCode,
        });
      }),
    );
  }

  void _registerWriteTools(McpServer server) {
    _registerWrite(
      server,
      'create-concept',
      'Create a concept, maintaining the index and log with it.',
      properties: _conceptWriteProperties,
      requiredProperties: const <String>['id', 'type'],
      destructive: false,
      idempotent: false,
      describe: (arguments) => OkfCreateConceptChange(
        id: OkfConceptId(arguments['id']! as String),
        document: OkfDocument(
          frontmatter: _managedFrontmatter(arguments),
          body: arguments['body'] as String? ?? '',
        ),
      ),
    );

    _registerWrite(
      server,
      'update-concept',
      'Update the managed fields of an existing concept.',
      properties: _conceptWriteProperties,
      requiredProperties: const <String>['id'],
      destructive: true,
      idempotent: true,
      describe: (arguments) {
        final frontmatter = _managedFrontmatter(arguments);
        final body = arguments['body'] as String?;
        if (frontmatter.isEmpty && body == null) {
          throw OkfBundleChangeException(
            'Update for ${arguments['id']} does not change a managed field.',
          );
        }
        return OkfUpdateConceptChange(
          id: OkfConceptId(arguments['id']! as String),
          frontmatterChanges: frontmatter,
          body: body,
        );
      },
    );

    _registerWrite(
      server,
      'link-concepts',
      'Relate two concepts, recording the link on the source.',
      properties: <String, JsonSchema>{
        'source': _conceptIdSchema,
        'target': _conceptIdSchema,
        'relationship': JsonSchema.string(
          minLength: 1,
          pattern: r'\S',
          description: 'Producer-defined relationship type.',
        ),
      },
      requiredProperties: const <String>[
        'source',
        'target',
        'relationship',
      ],
      destructive: false,
      idempotent: true,
      describe: (arguments) => OkfLinkConceptsChange(
        source: OkfConceptId(arguments['source']! as String),
        target: OkfConceptId(arguments['target']! as String),
        relationship: arguments['relationship']! as String,
      ),
    );

    _registerWrite(
      server,
      'deprecate-concept',
      'Retire a concept, recording why in the log.',
      properties: <String, JsonSchema>{
        'id': _conceptIdSchema,
        'note': JsonSchema.string(
          description: 'Context recorded with the lifecycle change.',
        ),
      },
      requiredProperties: const <String>['id'],
      destructive: true,
      idempotent: true,
      describe: (arguments) => OkfDeprecateConceptChange(
        id: OkfConceptId(arguments['id']! as String),
        note: arguments['note'] as String?,
      ),
    );
  }

  /// Registers one write verb from its parameters and [describe], the
  /// translation from those parameters into a change description.
  ///
  /// Declaring every write verb through here keeps what they share from
  /// drifting apart: a closed schema is what decides the malformed-input
  /// tier, so it is not a per-verb choice.
  void _registerWrite(
    McpServer server,
    String name,
    String description, {
    required Map<String, JsonSchema> properties,
    required List<String> requiredProperties,
    required bool destructive,
    required bool idempotent,
    required OkfBundleChange Function(Map<String, Object?> arguments) describe,
  }) =>
      server.registerTool(
        name,
        description: description,
        inputSchema: JsonSchema.object(
          properties: properties,
          required: requiredProperties,
          additionalProperties: false,
        ),
        annotations: ToolAnnotations(
          readOnlyHint: false,
          destructiveHint: destructive,
          idempotentHint: idempotent,
          openWorldHint: false,
        ),
        callback: (arguments, extra) => _write(() => describe(arguments)),
      );

  Future<CallToolResult> _readComplete(
    CallToolResult Function(OkfBundleLoadResult) answer,
  ) =>
      _readInspection((loaded) {
        if (loaded.hasFindings) {
          return _error(
            'The bundle has files that could not be read.',
            report: loaded.report,
          );
        }
        return answer(loaded);
      });

  Future<CallToolResult> _readInspection(
    CallToolResult Function(OkfBundleLoadResult) answer,
  ) =>
      _guard(() async => answer(await _loader.inspect(rootPath)));

  /// Prepares and commits the change returned by [describe].
  ///
  /// A Spec-invalid candidate comes back as a refusal carrying the report —
  /// the finding IDs `okf validate` prints for the same state — and the bundle
  /// is left exactly as it was.
  ///
  /// [describe] runs inside the guard below, so a rejected argument stays on
  /// the tool-error path.
  Future<CallToolResult> _write(OkfBundleChange Function() describe) =>
      _guard(() async {
        final application = await _applier.apply(
          rootPath,
          OkfBundleChangeSet(<OkfBundleChange>[describe()]),
        );
        return switch (application) {
          OkfBundleApplied(result: final result) => _payload(
              <String, Object?>{'changed_paths': result.changedPaths},
            ),
          OkfBundleApplicationRefused(validation: final validation) => _error(
              'The change was refused; the bundle is unchanged.',
              report: validation.report,
            ),
        };
      });

  /// Runs one tool call, turning every failure below the protocol into a tool
  /// error so a bad request never ends the session.
  ///
  /// This is the malformed-input tier that the static input schemas do not
  /// already cover: an unreadable root, a rejected concept ID, or a change
  /// that describes no bundle state at all. None of them carries a report,
  /// which is what separates them from a refusal.
  Future<CallToolResult> _guard(
    Future<CallToolResult> Function() answer,
  ) async {
    try {
      return await answer();
    } on OkfBundleChangeException catch (error) {
      return _error(error.message);
    } on FormatException catch (error) {
      return _error(error.message);
    } on Exception catch (error) {
      return _error('$error');
    }
  }
}

const ToolAnnotations _readOnlyAnnotations = ToolAnnotations(
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
);

/// The argument every tool that names a single concept takes, declared once so
/// the read and write verbs cannot describe the same ID differently.
final JsonSchema _conceptIdSchema = JsonSchema.string(
  minLength: 1,
  description: 'Bundle-relative concept ID, without the .md suffix.',
);

/// The parameters the create and update verbs take.
///
/// Beyond the `id` that addresses the concept, these are the fields those
/// verbs manage; everything else a document carries belongs to whoever
/// wrote it.
final Map<String, JsonSchema> _conceptWriteProperties = <String, JsonSchema>{
  'id': _conceptIdSchema,
  'type': JsonSchema.string(
    minLength: 1,
    description: 'OKF concept type, such as Reference, Metric, or Note.',
  ),
  'title': JsonSchema.string(minLength: 1, description: 'Display name.'),
  'description': JsonSchema.string(description: 'One-line summary.'),
  'tags': JsonSchema.array(
    items: JsonSchema.string(minLength: 1),
    description: 'Cross-cutting category tags.',
    uniqueItems: true,
  ),
  'body': JsonSchema.string(
    description: 'Markdown body below the frontmatter.',
  ),
};

/// The managed frontmatter fields [arguments] carries.
///
/// An absent field is left out rather than nulled, so an update never clears
/// what the caller did not mention.
Map<String, Object?> _managedFrontmatter(Map<String, Object?> arguments) =>
    <String, Object?>{
      if (arguments['type'] case final String type) 'type': type,
      if (arguments['title'] case final String title) 'title': title,
      if (arguments['description'] case final String description)
        'description': description,
      if (arguments['tags'] case final List<Object?> tags)
        'tags': tags.cast<String>(),
    };

Map<String, Object?> _conceptSummary(OkfConceptId id, OkfDocument document) {
  final type = document.type;
  final title = document.title;
  return <String, Object?>{
    'id': id.value,
    'path': id.documentPath,
    if (type != null) 'type': type,
    if (title != null) 'title': title,
    'status': document.status.wireValue,
    'trust_tier': document.trustTier.wireValue,
  };
}

/// Returns [payload] both structured and serialized, because a client that
/// predates structured tool results reads the text block instead.
CallToolResult _payload(Map<String, Object?> payload) =>
    CallToolResult.fromStructuredContent(payload);

/// Refuses a call, carrying [report] so the caller learns why in one round
/// trip instead of having to ask the validate tool.
CallToolResult _error(String message, {OkfReport? report}) {
  final payload =
      report == null ? null : <String, Object?>{'report': report.toJson()};
  return CallToolResult(
    isError: true,
    content: <Content>[
      TextContent(text: message),
      if (payload != null) TextContent(text: jsonEncode(payload)),
    ],
    structuredContent: payload,
  );
}
