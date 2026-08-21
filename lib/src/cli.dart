import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'control_characters.dart';
import 'diagnostic.dart';
import 'document.dart';
import 'graph.dart';
import 'index_generator.dart';
import 'io/bundle_loader.dart';
import 'io/bundle_writer.dart';
import 'validator.dart';

/// The package version reported by `okf --version`.
const okfPackageVersion = '0.2.0';

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
        return 0;
      }
      if (results.flag('help')) {
        _out(_rootUsage());
        return 0;
      }

      final command = results.command;
      if (command == null) {
        throw const _OkfUsageException('A command is required.');
      }
      if (command.flag('help')) {
        _out(_commandUsage(command.name ?? ''));
        return 0;
      }

      return switch (command.name) {
        'validate' => await _validate(command),
        'format' => await _format(command),
        'index' => await _index(command),
        'graph' => await _graph(command),
        _ => throw _OkfUsageException(
            'Unknown command: ${command.name ?? ''}',
          ),
      };
    } on ArgParserException catch (error) {
      _err('okf: ${_terminalSafe(error.message)}');
      _err('Run "okf --help" for usage.');
      return 2;
    } on _OkfUsageException catch (error) {
      _err('okf: ${_terminalSafe(error.message)}');
      _err('Run "okf --help" for usage.');
      return 2;
    } on FileSystemException catch (error) {
      _err('okf: ${_fileSystemMessage(error)}');
      return 2;
    } on ArgumentError catch (error) {
      _err('okf: ${_terminalSafe('${error.message ?? error}')}');
      return 2;
    } on Exception catch (error) {
      _err('okf: ${_terminalSafe('$error')}');
      return 2;
    }
  }

  Future<int> _validate(ArgResults command) async {
    final target = _singleOperand(command);
    final result = await _loader.inspect(_resolve(target));
    final diagnostics = <_CliDiagnostic>[
      ...result.issues.map(_CliDiagnostic.fromLoadIssue),
      ...OkfValidator()
          .validate(result.bundle)
          .diagnostics
          .map(_CliDiagnostic.fromDiagnostic),
    ]..sort(_compareDiagnostics);

    final warningsAsErrors = command.flag('warnings-as-errors');
    final errors = diagnostics.where((item) => item.severity == 'error').length;
    final warnings =
        diagnostics.where((item) => item.severity == 'warning').length;
    final valid = errors == 0 && (!warningsAsErrors || warnings == 0);

    if (command.option('output') == 'json') {
      _out(
        const JsonEncoder.withIndent('  ').convert(
          <String, Object?>{
            'valid': valid,
            'error_count': errors,
            'warning_count': warnings,
            'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
          },
        ),
      );
    } else {
      for (final diagnostic in diagnostics) {
        _out(diagnostic.toText());
      }
      if (diagnostics.isEmpty) {
        _out(
          'OK: ${result.bundle.concepts.length} concept(s) validated.',
        );
      }
    }
    return valid ? 0 : 1;
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
    final diagnostics = <_CliDiagnostic>[];
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
        diagnostics,
      );
    } else if (type == FileSystemEntityType.directory) {
      rootPath = targetPath;
      final loaded = await _loader.inspect(rootPath);
      diagnostics.addAll(
        loaded.issues.map(_CliDiagnostic.fromLoadIssue),
      );
      for (final entry in loaded.documents.entries) {
        desired[entry.key] = entry.value.serialize();
      }
      for (final entry in loaded.indexes.entries) {
        _addFormattedSource(
          entry.value,
          entry.key,
          desired,
          diagnostics,
        );
      }
      for (final entry in loaded.logs.entries) {
        _addFormattedSource(
          entry.value,
          entry.key,
          desired,
          diagnostics,
        );
      }
    } else {
      throw FileSystemException('Path does not exist', targetPath);
    }

    diagnostics.sort(_compareDiagnostics);
    if (diagnostics.isNotEmpty) {
      for (final diagnostic in diagnostics) {
        _out(diagnostic.toText());
      }
      return 1;
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
      return 1;
    }

    if (writeResult.hasChanges) {
      _out('Formatted ${writeResult.changedPaths.length} file(s).');
    } else {
      _out('Already formatted.');
    }
    return 0;
  }

  Future<int> _index(ArgResults command) async {
    final target = _resolve(_singleOperand(command));
    final loaded = await _loader.inspect(target);
    final generated = OkfIndexGenerator().generate(
      loaded.bundle,
      declareVersion: command.option('declare-version'),
    );
    final diagnostics = <_CliDiagnostic>[
      ...loaded.issues.map(_CliDiagnostic.fromLoadIssue),
      ...OkfValidator().validate(loaded.bundle).diagnostics.where(
        (item) {
          if (item.severity != OkfDiagnosticSeverity.error) {
            return false;
          }
          final basename = p.posix.basename(item.path ?? '');
          if (basename == 'log.md') {
            // Logs are excluded from index discovery and generation.
            return false;
          }
          return basename != 'index.md' || !generated.containsKey(item.path);
        },
      ).map(_CliDiagnostic.fromDiagnostic),
    ]..sort(_compareDiagnostics);
    if (diagnostics.isNotEmpty) {
      for (final diagnostic in diagnostics) {
        _out(diagnostic.toText());
      }
      return 1;
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
      return 1;
    }

    if (writeResult.hasChanges) {
      _out('Generated ${writeResult.changedPaths.length} index file(s).');
    } else {
      _out('Indexes are current.');
    }
    return 0;
  }

  Future<int> _graph(ArgResults command) async {
    final target = _resolve(_singleOperand(command));
    final loaded = await _loader.inspect(target);
    if (loaded.hasIssues) {
      final diagnostics = loaded.issues
          .map(_CliDiagnostic.fromLoadIssue)
          .toList()
        ..sort(_compareDiagnostics);
      for (final diagnostic in diagnostics) {
        _out(diagnostic.toText());
      }
      return 1;
    }

    final graph = OkfGraph.fromBundle(loaded.bundle);
    final output = switch (command.option('output')) {
      'json' => const JsonEncoder.withIndent('  ').convert(graph.toJson()),
      'dot' => graph.toDot(),
      'mermaid' => graph.toMermaid(),
      _ => throw StateError('Unsupported graph output format'),
    };
    _out(output.endsWith('\n')
        ? output.substring(0, output.length - 1)
        : output);
    return 0;
  }

  Future<void> _addFormattedFile(
    File file,
    String relativePath,
    Map<String, String> desired,
    List<_CliDiagnostic> diagnostics,
  ) async {
    try {
      final source = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: false,
      );
      _addFormattedSource(source, relativePath, desired, diagnostics);
    } on FormatException catch (error) {
      diagnostics.add(
        _CliDiagnostic(
          code: 'invalid_utf8',
          severity: 'error',
          message: error.message,
          path: relativePath,
        ),
      );
    }
  }

  void _addFormattedSource(
    String source,
    String relativePath,
    Map<String, String> desired,
    List<_CliDiagnostic> diagnostics,
  ) {
    try {
      desired[relativePath] = OkfDocument.parse(
        source,
        sourcePath: relativePath,
      ).serialize();
    } on OkfDocumentException catch (error) {
      diagnostics.add(
        _CliDiagnostic(
          code: 'invalid_document',
          severity: 'error',
          message: error.message,
          path: relativePath,
          line: error.line,
          column: error.column,
        ),
      );
    } on FormatException catch (error) {
      diagnostics.add(
        _CliDiagnostic(
          code: 'invalid_document',
          severity: 'error',
          message: error.message,
          path: relativePath,
        ),
      );
    }
  }

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
        'warnings-as-errors',
        negatable: false,
        help: 'Return failure when warnings are present.',
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
      ),
  );
  return parser;
}

final class _CliDiagnostic {
  const _CliDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.path,
    this.line,
    this.column,
  });

  factory _CliDiagnostic.fromDiagnostic(OkfDiagnostic diagnostic) =>
      _CliDiagnostic(
        code: diagnostic.code,
        severity: diagnostic.severity.name,
        message: diagnostic.message,
        path: diagnostic.path,
        line: diagnostic.line,
        column: diagnostic.column,
      );

  factory _CliDiagnostic.fromLoadIssue(OkfBundleLoadIssue issue) =>
      _CliDiagnostic(
        code: issue.code,
        severity: 'error',
        message: issue.message,
        path: issue.path,
        line: issue.line,
        column: issue.column,
      );

  final String code;
  final String severity;
  final String message;
  final String? path;
  final int? line;
  final int? column;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'severity': severity,
        'message': message,
        if (path != null) 'path': path,
        if (line != null) 'line': line,
        if (column != null) 'column': column,
      };

  String toText() {
    final location = StringBuffer(_terminalSafe(path ?? '<bundle>'));
    if (line != null) {
      location.write(':$line');
      if (column != null) {
        location.write(':$column');
      }
    }
    return '$location: ${_terminalSafe(severity)} '
        '${_terminalSafe(code)}: ${_terminalSafe(message)}';
  }
}

final class _OkfUsageException implements Exception {
  const _OkfUsageException(this.message);

  final String message;
}

int _compareDiagnostics(_CliDiagnostic left, _CliDiagnostic right) {
  var comparison = (left.path ?? '').compareTo(right.path ?? '');
  if (comparison != 0) {
    return comparison;
  }
  comparison = (left.line ?? 0).compareTo(right.line ?? 0);
  if (comparison != 0) {
    return comparison;
  }
  comparison = (left.column ?? 0).compareTo(right.column ?? 0);
  if (comparison != 0) {
    return comparison;
  }
  return left.code.compareTo(right.code);
}

String _fileSystemMessage(FileSystemException error) {
  final path = error.path;
  final message =
      path == null || path.isEmpty ? error.message : '${error.message}: $path';
  return _terminalSafe(message);
}

String _terminalSafe(String value) => escapeControlCharacters(value);
