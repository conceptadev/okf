import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import '../concept_id.dart';
import '../document.dart';
import '../finding.dart';
import '../graph.dart';
import '../io/bundle_loader.dart';
import '../version.dart';

/// The read-only OKF tool surface served over the Model Context Protocol.
///
/// Every tool re-reads the bundle from disk, so an agent that edits files
/// between calls never observes a stale answer.
final class OkfMcpServer {
  /// Creates a server that answers questions about the bundle at [rootPath].
  OkfMcpServer({
    required this.rootPath,
    OkfBundleLoader loader = const OkfBundleLoader(),
  }) : _loader = loader;

  /// The bundle root every tool reads.
  final String rootPath;

  final OkfBundleLoader _loader;

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
        properties: <String, JsonSchema>{
          'id': JsonSchema.string(
            minLength: 1,
            description: 'Bundle-relative concept ID, without the .md suffix.',
          ),
        },
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

    return server;
  }

  /// Answers one tool call from a freshly loaded bundle.
  ///
  /// Every failure below the protocol — an unreadable root, a rejected
  /// argument, a missing concept — becomes a tool error, so a bad request
  /// never ends the session.
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
  ) async {
    try {
      return answer(await _loader.inspect(rootPath));
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
