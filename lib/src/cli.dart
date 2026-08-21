import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'control_characters.dart';
import 'finding.dart';
import 'graph.dart';
import 'index_generator.dart';
import 'io/bundle_loader.dart';
import 'io/bundle_writer.dart';
import 'mcp/read_server.dart';
import 'spec_rules/load_findings.dart';
import 'validator.dart';
import 'version.dart';

/// A destination for one complete CLI output line.
typedef OkfCliOutput = void Function(String line);

/// Runs the OKF command-line interface and returns its process exit code.
///
/// Supplying [out] and [err] keeps the runner straightforward to embed and
/// test without changing the process-wide standard streams.
Future<int> runOkfCli(
  List<String> arguments, {
  String? workingDirectory,
  OkfCliOutput? out,
  OkfCliOutput? err,
}) =>
    OkfCli(
      workingDirectory: workingDirectory,
      out: out,
      err: err,
    ).run(arguments);

/// The embeddable implementation of the `okf` executable.
final class OkfCli {
  /// Creates an OKF CLI runner.
  OkfCli({
    String? workingDirectory,
    OkfCliOutput? out,
    OkfCliOutput? err,
    OkfBundleLoader loader = const OkfBundleLoader(),
    OkfBundleWriter writer = const OkfBundleWriter(),
  })  : workingDirectory = p.normalize(
          p.absolute(workingDirectory ?? Directory.current.path),
        ),
        _out = out ?? stdout.writeln,
        _err = err ?? stderr.writeln,
        _loader = loader,
        _writer = writer,
        _parser = _buildParser();

  /// The absolute directory used to resolve command operands.
  final String workingDirectory;

  final OkfCliOutput _out;
  final OkfCliOutput _err;
  final OkfBundleLoader _loader;
  final OkfBundleWriter _writer;
  final ArgParser _parser;

  /// Parses and executes [arguments].
  Future<int> run(List<String> arguments) async {
    try {
      final results = _parser.parse(arguments);
      if (results.flag('version')) {
        _out('okf $okfPackageVersion');
        return OkfExitCode.success.value;
      }
      if (results.flag('help')) {
        _out(_rootUsage());
        return OkfExitCode.success.value;
      }

      final command = results.command;
      if (command == null) {
        throw const _OkfUsageException('A command is required.');
      }
      if (command.flag('help')) {
        _out(_commandUsage(command.name ?? ''));
        return OkfExitCode.success.value;
      }

      return switch (command.name) {
        'validate' => await _validate(command),
        'format' => await _format(command),
        'index' => await _index(command),
        'graph' => await _graph(command),
        'mcp' => await _mcp(command),
        _ => throw _OkfUsageException(
            'Unknown command: ${command.name ?? ''}',
          ),
      };
    } on ArgParserException catch (error) {
      _err('okf: ${_terminalSafe(error.message)}');
      _err('Run "okf --help" for usage.');
      return OkfExitCode.usage.value;
    } on _OkfUsageException catch (error) {
      _err('okf: ${_terminalSafe(error.message)}');
      _err('Run "okf --help" for usage.');
      return OkfExitCode.usage.value;
    } on FileSystemException catch (error) {
      _err('okf: ${_fileSystemMessage(error)}');
      return OkfExitCode.usage.value;
    } on ArgumentError catch (error) {
      _err('okf: ${_terminalSafe('${error.message ?? error}')}');
      return OkfExitCode.usage.value;
    } on Exception catch (error) {
      _err('okf: ${_terminalSafe('$error')}');
      return OkfExitCode.usage.value;
    }
  }

  Future<int> _validate(ArgResults command) async {
    final target = _singleOperand(command);
    final result = await _loader.inspect(_resolve(target));
    final report = result.validate().report;
    final verdict = OkfVerdict.of(report, strict: command.flag('strict'));

    if (command.option('output') == 'json') {
      _out(
        const JsonEncoder.withIndent('  ').convert(report.toJson()),
      );
    } else {
      _emitReport(report);
      if (report.findings.isEmpty) {
        _out(
          'OK: ${result.bundle.concepts.length} concept(s) validated.',
        );
      }
    }
    return verdict.exitCode;
  }

  Future<int> _format(ArgResults command) async {
    final targetOperand = _singleOperand(command);
    final targetPath = _resolve(targetOperand);
    final type = await FileSystemEntity.type(
      targetPath,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Refusing to format a symbolic link',
        targetPath,
      );
    }

    late final String rootPath;
    final desired = <String, String>{};
    final findings = <OkfFinding>[];
    if (type == FileSystemEntityType.file) {
      if (!targetPath.endsWith('.md')) {
        throw const _OkfUsageException(
          'format accepts only .md files or bundle directories.',
        );
      }
      rootPath = p.dirname(targetPath);
      final relativePath = p.basename(targetPath);
      await _addFormattedFile(
        File(targetPath),
        relativePath,
        desired,
        findings,
      );
    } else if (type == FileSystemEntityType.directory) {
      rootPath = targetPath;
      final loaded = await _loader.inspect(rootPath);
      findings.addAll(loaded.report.findings);
      for (final entry in loaded.documents.entries) {
        desired[entry.key] = entry.value.serialize();
      }
      for (final entry in loaded.indexes.entries) {
        _addFormattedSource(
          entry.value,
          entry.key,
          desired,
          findings,
        );
      }
      for (final entry in loaded.logs.entries) {
        _addFormattedSource(
          entry.value,
          entry.key,
          desired,
          findings,
        );
      }
    } else {
      throw FileSystemException('Path does not exist', targetPath);
    }

    final report = OkfReport(findings: findings);
    if (report.findings.isNotEmpty) {
      _emitReport(report);
      return OkfVerdict.of(report).exitCode;
    }

    final checkOnly = command.flag('check');
    final writeResult = await _writer.writeAll(
      rootPath,
      desired,
      checkOnly: checkOnly,
    );
    if (checkOnly && writeResult.hasChanges) {
      for (final path in writeResult.changedPaths) {
        _out('Would format $path');
      }
      // A check-mode exit is an adapter decision (ADR-0007).
      return OkfExitCode.findings.value;
    }

    if (writeResult.hasChanges) {
      _out('Formatted ${writeResult.changedPaths.length} file(s).');
    } else {
      _out('Already formatted.');
    }
    return OkfExitCode.success.value;
  }

  Future<int> _index(ArgResults command) async {
    final target = _resolve(_singleOperand(command));
    final loaded = await _loader.inspect(target);
    final generated = OkfIndexGenerator().generate(
      loaded.bundle,
      declareVersion: command.option('declare-version'),
    );
    // Load failures always block; validation only blocks on errors outside
    // the files index generation owns (generated indexes) or ignores (logs).
    final report = OkfReport(findings: <OkfFinding>[
      ...loaded.report.findings,
      ...const OkfSpecValidator()
          .validate(loaded.bundle)
          .report
          .findings
          .where((finding) => _blocksIndexGeneration(finding, generated)),
    ]);
    if (report.findings.isNotEmpty) {
      _emitReport(report);
      return OkfVerdict.of(report).exitCode;
    }

    final checkOnly = command.flag('check');
    final writeResult = await _writer.writeAll(
      loaded.rootPath,
      generated,
      checkOnly: checkOnly,
    );
    if (checkOnly && writeResult.hasChanges) {
      for (final path in writeResult.changedPaths) {
        _out('Index is stale: $path');
      }
      // A check-mode exit is an adapter decision (ADR-0007).
      return OkfExitCode.findings.value;
    }

    if (writeResult.hasChanges) {
      _out('Generated ${writeResult.changedPaths.length} index file(s).');
    } else {
      _out('Indexes are current.');
    }
    return OkfExitCode.success.value;
  }

  Future<int> _graph(ArgResults command) async {
    final target = _resolve(_singleOperand(command));
    final loaded = await _loader.inspect(target);
    if (loaded.hasFindings) {
      _emitReport(loaded.report);
      return OkfVerdict.of(loaded.report).exitCode;
    }

    final resolutions =
        command.multiOption('resolution').map(OkfGraphResolution.fromWireValue);
    final graph = OkfGraph.fromBundle(
      loaded.bundle,
      query: OkfGraphQuery(
        conceptTypes: command.multiOption('type'),
        pathPrefixes: command.multiOption('path-prefix'),
        resolutions: resolutions,
      ),
    );
    final output = switch (command.option('output')) {
      'json' => const JsonEncoder.withIndent('  ').convert(graph.toJson()),
      'dot' => graph.toDot(),
      'mermaid' => graph.toMermaid(),
      _ => throw StateError('Unsupported graph output format'),
    };
    _out(output.endsWith('\n')
        ? output.substring(0, output.length - 1)
        : output);
    return OkfExitCode.success.value;
  }

  Future<int> _mcp(ArgResults command) async {
    await OkfMcpServer(
      rootPath: _resolve(_singleOperand(command)),
    ).serve();
    return OkfExitCode.success.value;
  }

  Future<void> _addFormattedFile(
    File file,
    String relativePath,
    Map<String, String> desired,
    List<OkfFinding> findings,
  ) async {
    final source = decodeMarkdown(
      await file.readAsBytes(),
      relativePath,
      findings,
    );
    if (source != null) {
      _addFormattedSource(source, relativePath, desired, findings);
    }
  }

  void _addFormattedSource(
    String source,
    String relativePath,
    Map<String, String> desired,
    List<OkfFinding> findings,
  ) {
    final document = parseMarkdown(source, relativePath, findings);
    if (document != null) {
      desired[relativePath] = document.serialize();
    }
  }

  void _emitReport(OkfReport report) => report.toTextLines().forEach(_out);

  String _singleOperand(ArgResults command) {
    if (command.rest.length != 1) {
      throw _OkfUsageException(
        '${command.name} expects exactly one file or bundle path.',
      );
    }
    return command.rest.single;
  }

  String _resolve(String operand) => p.normalize(
        p.isAbsolute(operand) ? operand : p.join(workingDirectory, operand),
      );

  String _rootUsage() => '''
Open Knowledge Format toolkit

Usage: okf <command> [arguments]

Commands:
  validate   Validate an OKF bundle
  format     Canonically format Markdown documents
  index      Generate deterministic bundle indexes
  graph      Render the bundle relationship graph
  mcp        Serve the read tool surface over MCP stdio

Global options:
${_parser.usage}

Run "okf <command> --help" for command-specific usage.''';

  String _commandUsage(String name) {
    final parser = _parser.commands[name];
    if (parser == null) {
      return _rootUsage();
    }
    final operand = name == 'format' ? '<file-or-bundle>' : '<bundle>';
    return 'Usage: okf $name $operand [options]\n\n${parser.usage}';
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Show the package version.',
    );

  parser.addCommand(
    'validate',
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show command help.',
      )
      ..addOption(
        'output',
        allowed: const <String>['text', 'json'],
        defaultsTo: 'text',
        help: 'Diagnostic output format.',
      )
      ..addFlag(
        'strict',
        negatable: false,
        aliases: <String>['warnings-as-errors'],
        help: 'Fail on advisory findings as well as errors.',
      ),
  );
  parser.addCommand(
    'format',
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show command help.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'Report files that would change without writing them.',
      ),
  );
  parser.addCommand(
    'index',
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show command help.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'Report stale indexes without writing them.',
      )
      ..addOption(
        'declare-version',
        allowed: const <String>['0.2'],
        help: 'Declare okf_version in the generated root index.',
      ),
  );
  parser.addCommand(
    'graph',
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show command help.',
      )
      ..addOption(
        'output',
        allowed: const <String>['json', 'dot', 'mermaid'],
        defaultsTo: 'json',
        help: 'Graph output format.',
      )
      ..addMultiOption(
        'type',
        valueHelp: 'TYPE',
        splitCommas: false,
        help: 'Include concepts with these types.',
      )
      ..addMultiOption(
        'path-prefix',
        valueHelp: 'PREFIX',
        splitCommas: false,
        help: 'Include concepts under these bundle path prefixes.',
      )
      ..addMultiOption(
        'resolution',
        valueHelp: 'STATE',
        allowed: OkfGraphResolution.values.map(
          (resolution) => resolution.wireValue,
        ),
        help: 'Include edges with these resolution states.',
      ),
  );
  parser.addCommand(
    'mcp',
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show command help.',
      ),
  );
  return parser;
}

bool _blocksIndexGeneration(
  OkfFinding finding,
  Map<String, String> generated,
) {
  if (finding.severity != OkfFindingSeverity.error) {
    return false;
  }
  final path = finding.location?.path ?? '';
  return switch (p.posix.basename(path)) {
    'log.md' => false,
    'index.md' => !generated.containsKey(path),
    _ => true,
  };
}

final class _OkfUsageException implements Exception {
  const _OkfUsageException(this.message);

  final String message;
}

String _fileSystemMessage(FileSystemException error) {
  final path = error.path;
  final message =
      path == null || path.isEmpty ? error.message : '${error.message}: $path';
  return _terminalSafe(message);
}

String _terminalSafe(String value) => escapeControlCharacters(value);
