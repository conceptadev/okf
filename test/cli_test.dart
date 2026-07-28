import 'dart:convert';
import 'dart:io';

import 'package:okf/src/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory sandbox;
  late Directory bundle;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('okf-cli-test-');
    bundle = await Directory(p.join(sandbox.path, 'bundle')).create();
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('shows help and version', () async {
    final help = await _run(<String>['--help'], sandbox.path);
    expect(help.exitCode, 0);
    expect(help.stdout, contains('Usage: okf <command>'));

    final commandHelp = await _run(
      <String>['validate', '--help'],
      sandbox.path,
    );
    expect(commandHelp.exitCode, 0);
    expect(commandHelp.stdout, contains('Usage: okf validate <bundle>'));

    final version = await _run(<String>['--version'], sandbox.path);
    expect(version.exitCode, 0);
    expect(version.stdout, 'okf 0.1.0');

    final pubspec =
        loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
    expect(okfPackageVersion, pubspec['version']);
  });

  test('usage and filesystem errors return exit code 2', () async {
    final missingCommand = await _run(const <String>[], sandbox.path);
    expect(missingCommand.exitCode, 2);
    expect(missingCommand.stderr, contains('A command is required'));

    final extraOperand = await _run(
      <String>['validate', 'one', 'two'],
      sandbox.path,
    );
    expect(extraOperand.exitCode, 2);
    expect(extraOperand.stderr, contains('exactly one'));

    final missingBundle = await _run(
      <String>['validate', 'missing'],
      sandbox.path,
    );
    expect(missingBundle.exitCode, 2);
    expect(missingBundle.stderr, contains('not a directory'));
  });

  test('validates bundles in text and JSON formats', () async {
    await _writeConcept(bundle, 'alpha.md');

    final text = await _run(
      <String>['validate', 'bundle'],
      sandbox.path,
    );
    expect(text.exitCode, 0);
    expect(text.stdout, 'OK: 1 concept(s) validated.');

    final json = await _run(
      <String>['validate', 'bundle', '--output=json'],
      sandbox.path,
    );
    final payload = jsonDecode(json.stdout) as Map<String, Object?>;
    expect(json.exitCode, 0);
    expect(payload['valid'], isTrue);
    expect(payload['error_count'], 0);
    expect(payload['warning_count'], 0);
    expect(payload['diagnostics'], isEmpty);
  });

  test('reports conformance and load failures with exit code 1', () async {
    await _writeConcept(bundle, 'missing_type.md', includeType: false);
    await File(p.join(bundle.path, 'broken.md')).writeAsString(
      '---\ntype: Reference\nbroken: [\n',
    );

    final result = await _run(
      <String>['validate', 'bundle', '--output=json'],
      sandbox.path,
    );
    final payload = jsonDecode(result.stdout) as Map<String, Object?>;
    final diagnostics = payload['diagnostics']! as List<Object?>;

    expect(result.exitCode, 1);
    expect(payload['valid'], isFalse);
    expect(payload['error_count'], 2);
    expect(
      diagnostics
          .cast<Map<String, Object?>>()
          .singleWhere((item) => item['code'] == 'invalid_document')['line'],
      isNotNull,
    );
    expect(
      diagnostics.cast<Map<String, Object?>>().map((item) => item['code']),
      containsAll(<String>['invalid_document', 'missing_type']),
    );
  });

  test('can promote warnings to a failing exit status', () async {
    await _writeConcept(bundle, 'café.md');

    final ordinary = await _run(
      <String>['validate', 'bundle'],
      sandbox.path,
    );
    expect(ordinary.exitCode, 0);
    expect(ordinary.stdout, contains('non_portable_concept_id'));

    final strict = await _run(
      <String>['validate', 'bundle', '--warnings-as-errors'],
      sandbox.path,
    );
    expect(strict.exitCode, 1);
  });

  test('format check is non-mutating and format is idempotent', () async {
    final file = File(p.join(bundle.path, 'alpha.md'));
    const original = '---\ntitle: Alpha\ntype: Reference\n---\n\n# Alpha';
    await file.writeAsString(original);

    final check = await _run(
      <String>['format', 'bundle', '--check'],
      sandbox.path,
    );
    expect(check.exitCode, 1);
    expect(check.stdout, contains('Would format alpha.md'));
    expect(await file.readAsString(), original);

    final formatted = await _run(
      <String>['format', 'bundle'],
      sandbox.path,
    );
    expect(formatted.exitCode, 0);
    expect(formatted.stdout, 'Formatted 1 file(s).');
    expect(await file.readAsString(), isNot(original));

    final secondCheck = await _run(
      <String>['format', 'bundle', '--check'],
      sandbox.path,
    );
    expect(secondCheck.exitCode, 0);
    expect(secondCheck.stdout, 'Already formatted.');
  });

  test('format refuses malformed input without partial writes', () async {
    final valid = File(p.join(bundle.path, 'valid.md'));
    const unformatted = '---\ntitle: Valid\ntype: Reference\n---\n\n# Valid';
    await valid.writeAsString(unformatted);
    await File(p.join(bundle.path, 'broken.md')).writeAsString(
      '---\ntype: Reference\nbroken: [\n',
    );

    final result = await _run(
      <String>['format', 'bundle'],
      sandbox.path,
    );

    expect(result.exitCode, 1);
    expect(result.stdout, contains('invalid_document'));
    expect(await valid.readAsString(), unformatted);
  });

  test('format rejects non-Markdown files', () async {
    await File(p.join(bundle.path, 'query.sql')).writeAsString('select 1');

    final result = await _run(
      <String>['format', 'bundle/query.sql'],
      sandbox.path,
    );

    expect(result.exitCode, 2);
    expect(result.stderr, contains('only .md files'));
  });

  test('generates and checks deterministic indexes', () async {
    await _writeConcept(bundle, 'alpha.md');

    final firstCheck = await _run(
      <String>['index', 'bundle', '--check'],
      sandbox.path,
    );
    expect(firstCheck.exitCode, 1);
    expect(firstCheck.stdout, contains('Index is stale: index.md'));
    expect(await File(p.join(bundle.path, 'index.md')).exists(), isFalse);

    final generated = await _run(
      <String>[
        'index',
        'bundle',
        '--declare-version=0.2',
      ],
      sandbox.path,
    );
    expect(generated.exitCode, 0);
    expect(generated.stdout, 'Generated 1 index file(s).');
    final index = await File(
      p.join(bundle.path, 'index.md'),
    ).readAsString();
    expect(index, contains('okf_version: "0.2"'));
    expect(index, contains('[Alpha](alpha.md)'));

    final current = await _run(
      <String>['index', 'bundle', '--check'],
      sandbox.path,
    );
    expect(current.exitCode, 0);
    expect(current.stdout, 'Indexes are current.');
  });

  test('renders JSON, DOT, and Mermaid graphs', () async {
    await _writeConcept(bundle, 'alpha.md');

    final json = await _run(
      <String>['graph', 'bundle', '--output=json'],
      sandbox.path,
    );
    expect(json.exitCode, 0);
    expect(jsonDecode(json.stdout), isA<Map<String, Object?>>());

    final dot = await _run(
      <String>['graph', 'bundle', '--output=dot'],
      sandbox.path,
    );
    expect(dot.exitCode, 0);
    expect(dot.stdout, contains('digraph'));

    final mermaid = await _run(
      <String>['graph', 'bundle', '--output=mermaid'],
      sandbox.path,
    );
    expect(mermaid.exitCode, 0);
    expect(mermaid.stdout, anyOf(contains('flowchart'), contains('graph')));
  });

  test('surfaces malformed indexes that will not be regenerated', () async {
    await _writeConcept(bundle, 'alpha.md');
    final orphan = await Directory(
      p.join(bundle.path, 'assets'),
    ).create();
    await File(p.join(orphan.path, 'index.md')).writeAsString(
      '---\nnot: [valid\n',
    );

    final result = await _run(
      <String>['index', 'bundle'],
      sandbox.path,
    );

    expect(result.exitCode, 1);
    expect(result.stdout, contains('invalid_reserved_document'));
  });

  test('escapes control characters in terminal diagnostics', () async {
    if (Platform.isWindows) {
      return;
    }
    await File(p.join(bundle.path, 'bad\u001b.md')).writeAsString(
      '---\ntype: Reference\n---\n',
    );

    final result = await _run(
      <String>['validate', 'bundle'],
      sandbox.path,
    );

    expect(result.exitCode, 1);
    expect(result.stdout, isNot(contains('\u001b')));
    expect(result.stdout, contains(r'\u{001b}'));
  });
}

Future<void> _writeConcept(
  Directory root,
  String relativePath, {
  bool includeType = true,
}) async {
  final file = File(
    p.joinAll(<String>[root.path, ...p.posix.split(relativePath)]),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(
    [
      '---',
      if (includeType) 'type: Reference',
      'title: Alpha',
      '---',
      '',
      '# Alpha',
      '',
    ].join('\n'),
  );
}

Future<_CliResult> _run(
  List<String> arguments,
  String workingDirectory,
) async {
  final output = <String>[];
  final errors = <String>[];
  final exitCode = await runOkfCli(
    arguments,
    workingDirectory: workingDirectory,
    out: output.add,
    err: errors.add,
  );
  return _CliResult(
    exitCode,
    output.join('\n'),
    errors.join('\n'),
  );
}

final class _CliResult {
  const _CliResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}
