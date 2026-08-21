import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:okf/okf_io.dart';
import 'package:okf/src/io/bundle_writer.dart' show OkfBundleWriteTransaction;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('okf-io-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  group('OkfBundleLoader', () {
    test('loads a sorted inventory without following links', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      await _write(
        root,
        'zeta.md',
        '---\ntype: Reference\ntitle: Zeta\n---\n\n# Zeta\n',
      );
      await _write(
        root,
        'nested/alpha.md',
        '---\ntype: Metric\ntitle: Alpha\n---\n\n# Alpha\n',
      );
      await _write(root, 'index.md', '# Index\n');
      await _write(root, 'nested/log.md', '# Log\n\n## 2026-01-01\n');
      await _write(root, 'assets/query.sql', 'select 1;\n');

      if (!Platform.isWindows) {
        final outside = await File(
          p.join(sandbox.path, 'outside.md'),
        ).writeAsString('---\ntype: Reference\n---\n');
        await Link(
          p.join(root.path, 'linked.md'),
        ).create(outside.path);
      }

      final result = await const OkfBundleLoader().inspect(root.path);

      expect(
        result.documents.keys,
        orderedEquals(<String>['nested/alpha.md', 'zeta.md']),
      );
      expect(result.indexes.keys, orderedEquals(<String>['index.md']));
      expect(
        result.logs.keys,
        orderedEquals(<String>['nested/log.md']),
      );
      expect(
        result.assets,
        orderedEquals(<String>['assets/query.sql']),
      );
      expect(
        result.paths,
        orderedEquals(<String>[
          'assets/query.sql',
          'index.md',
          'nested/alpha.md',
          'nested/log.md',
          'zeta.md',
        ]),
      );
      expect(result.bundle.concepts.length, 2);
      expect(result.bundle.assetPaths, contains('assets/query.sql'));
      expect(result.hasFindings, isFalse);
    });

    test('reports every malformed concept and returns a partial bundle',
        () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      await _write(
        root,
        'valid.md',
        '---\ntype: Reference\n---\n\nValid\n',
      );
      await _write(
        root,
        'broken.md',
        '---\ntype: Reference\nunterminated: [\n',
      );
      final invalidUtf8 = File(p.join(root.path, 'invalid.md'));
      await invalidUtf8.writeAsBytes(<int>[0xff], flush: true);

      final result = await const OkfBundleLoader().inspect(root.path);

      expect(result.bundle.concepts.length, 1);
      expect(
        result.report.findings.map((finding) => finding.location?.path),
        orderedEquals(<String>['broken.md', 'invalid.md']),
      );
      expect(
        result.report.findings.map((finding) => finding.id.value),
        orderedEquals(<String>[
          'okf/invalid-document',
          'okf/invalid-utf8',
        ]),
      );
      expect(result.report.findings.first.location?.line, isNotNull);
      expect(result.report.findings.first.location?.column, isNotNull);
      expect(
        result.paths,
        containsAll(<String>['broken.md', 'invalid.md', 'valid.md']),
      );
      await expectLater(
        const OkfBundleLoader().load(root.path),
        throwsA(
          isA<OkfBundleLoadException>().having(
            (error) => error.result.report.findings.length,
            'finding count',
            2,
          ),
        ),
      );
    });

    test('validate merges load findings with fixed Spec findings', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      await _write(root, 'valid.md', '---\ntype: Reference\n---\n\nValid\n');
      await _write(root, 'broken.md', '---\ntype: Reference\nbad: [\n');
      await _write(root, 'untyped.md', '---\ntitle: Untyped\n---\n');

      final result = await const OkfBundleLoader().inspect(root.path);
      final validation = result.validate();
      final report = validation.report;

      expect(
        report.findings.map((finding) => '${finding.id}'),
        orderedEquals(<String>[
          'okf/invalid-document',
          'okf/missing-type',
        ]),
      );
      expect(report.findings.last.location?.path, 'untyped.md');
      expect(validation.isConformant, isFalse);
      expect(OkfVerdict.of(report).exitCode, 1);
    });

    test('reports bundle paths containing C1 control characters', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      const invalidPath = 'invalid\u0085asset.txt';
      await _write(root, invalidPath, 'invalid path\n');

      final result = await const OkfBundleLoader().inspect(root.path);

      expect(result.bundle.allPaths, isEmpty);
      expect(result.report.findings, hasLength(1));
      expect(result.report.findings.single.id.value, 'okf/invalid-path');
      expect(result.report.findings.single.location?.path, invalidPath);
    });

    test('rejects a symbolic-link root', () async {
      if (Platform.isWindows) {
        return;
      }
      final root = await Directory(
        p.join(sandbox.path, 'real'),
      ).create();
      final link = await Link(
        p.join(sandbox.path, 'linked'),
      ).create(root.path);

      await expectLater(
        const OkfBundleLoader().inspect(link.path),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('OkfBundleWriter', () {
    test('recursively creates a missing bundle root', () async {
      final root = p.join(sandbox.path, 'missing', 'bundle');

      final result = await const OkfBundleWriter().writeAll(
        root,
        <String, String>{'a.md': 'a\n'},
      );

      expect(result.changedPaths, <String>['a.md']);
      expect(await File(p.join(root, 'a.md')).readAsString(), 'a\n');
    });

    test('writes deterministically and supports non-mutating checks', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      const writer = OkfBundleWriter();

      final first = await writer.writeAll(
        root.path,
        <String, String>{
          'zeta.md': 'zeta\n',
          'nested/alpha.md': 'alpha\n',
        },
      );
      expect(
        first.changedPaths,
        orderedEquals(<String>['nested/alpha.md', 'zeta.md']),
      );
      expect(
        await File(p.join(root.path, 'nested/alpha.md')).readAsString(),
        'alpha\n',
      );

      final unchanged = await writer.writeAll(
        root.path,
        <String, String>{'zeta.md': 'zeta\n'},
        checkOnly: true,
      );
      expect(unchanged.hasChanges, isFalse);

      final check = await writer.writeAll(
        root.path,
        <String, String>{'zeta.md': 'changed\n'},
        checkOnly: true,
      );
      expect(check.changedPaths, orderedEquals(<String>['zeta.md']));
      expect(
        await File(p.join(root.path, 'zeta.md')).readAsString(),
        'zeta\n',
      );

      await writer.writeAll(
        root.path,
        <String, String>{'zeta.md': 'changed\n'},
      );
      expect(
        await File(p.join(root.path, 'zeta.md')).readAsString(),
        'changed\n',
      );
      expect(
        await root
            .list(recursive: true, followLinks: false)
            .where(
              (entity) => p.basename(entity.path).contains('.okf-'),
            )
            .isEmpty,
        isTrue,
      );
    });

    test('writes serialized documents', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      final document = OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Reference',
          'title': 'Example',
        },
        body: '# Example\n',
      );

      final result = await const OkfBundleWriter().writeDocument(
        root.path,
        'example.md',
        document,
      );

      expect(result.changedPaths, orderedEquals(<String>['example.md']));
      expect(
        await File(p.join(root.path, 'example.md')).readAsString(),
        document.serialize(),
      );
    });

    test('transactional writes restore the exact original bytes', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      final original = File(p.join(root.path, 'a.md'));
      await original.writeAsBytes(<int>[0xff], flush: true);
      await Directory(p.join(root.path, 'z.md')).create();

      await expectLater(
        const OkfBundleWriteTransaction().writeAll(
          root.path,
          <String, String>{
            'a.md': 'changed\n',
            'z.md': 'cannot replace a directory\n',
          },
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await original.readAsBytes(), <int>[0xff]);
    });

    test('writes wait for the bundle lock held by another process', () async {
      if (Platform.isWindows) {
        return;
      }
      final root = await Directory(p.join(sandbox.path, 'bundle')).create();
      final lockPath = p.join(sandbox.path, '.bundle.okf-apply.lock');
      final readyPath = p.join(sandbox.path, 'lock-ready');
      final releasePath = p.join(sandbox.path, 'lock-release');
      final helper = await Process.start(
        Platform.resolvedExecutable,
        <String>[
          'run',
          p.join('test', 'support', 'hold_file_lock.dart'),
          lockPath,
          readyPath,
          releasePath,
        ],
        workingDirectory: Directory.current.path,
      );
      addTearDown(() async {
        helper.kill();
        await helper.exitCode;
      });
      await _waitForFile(File(readyPath));

      var completed = false;
      final write = const OkfBundleWriter().writeAll(
          root.path, <String, String>{
        'held.md': 'held\n'
      }).whenComplete(() => completed = true);
      var readCompleted = false;
      final read = const OkfBundleLoader()
          .inspect(root.path)
          .whenComplete(() => readCompleted = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(completed, isFalse);
      expect(readCompleted, isFalse);
      expect(await File(p.join(root.path, 'held.md')).exists(), isFalse);

      await File(releasePath).writeAsString('release');
      await write.timeout(const Duration(seconds: 5));
      await read.timeout(const Duration(seconds: 5));
      expect(await File(p.join(root.path, 'held.md')).readAsString(), 'held\n');
    });

    test('rejects absolute and escaping paths', () async {
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      const writer = OkfBundleWriter();

      await expectLater(
        writer.writeAll(
          root.path,
          <String, String>{'../escape.md': 'no'},
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        writer.writeAll(
          root.path,
          <String, String>{p.join(sandbox.path, 'absolute.md'): 'no'},
        ),
        throwsA(isA<ArgumentError>()),
      );
      for (final path in <String>[
        'nested/../normalized-away.md',
        'nested/./dot.md',
        r'nested\backslash.md',
        'nested/\u001bescape.md',
        'nested/\u0085escape.md',
      ]) {
        await expectLater(
          writer.writeAll(root.path, <String, String>{path: 'no'}),
          throwsA(isA<ArgumentError>()),
          reason: path,
        );
      }
      expect(
        await File(p.join(sandbox.path, 'escape.md')).exists(),
        isFalse,
      );
    });

    test('check-only does not create a missing bundle root', () async {
      final root = Directory(p.join(sandbox.path, 'missing'));

      final result = await const OkfBundleWriter().writeAll(
        root.path,
        <String, String>{'concept.md': 'would change\n'},
        checkOnly: true,
      );

      expect(result.changedPaths, <String>['concept.md']);
      expect(await root.exists(), isFalse);
    });

    test('refuses to write through a symbolic link', () async {
      if (Platform.isWindows) {
        return;
      }
      final root = await Directory(
        p.join(sandbox.path, 'bundle'),
      ).create();
      final outside = await Directory(
        p.join(sandbox.path, 'outside'),
      ).create();
      await Link(p.join(root.path, 'linked')).create(outside.path);

      await expectLater(
        const OkfBundleWriter().writeAll(
          root.path,
          <String, String>{'linked/escape.md': 'no'},
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(p.join(outside.path, 'escape.md')).exists(),
        isFalse,
      );
    });
  });
}

Future<void> _write(
  Directory root,
  String relativePath,
  String contents,
) async {
  final file = File(
    p.joinAll(<String>[root.path, ...p.posix.split(relativePath)]),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(contents, encoding: utf8, flush: true);
}

Future<void> _waitForFile(File file) async {
  for (var attempt = 0; attempt < 500; attempt++) {
    if (await file.exists()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('Timed out waiting for ${file.path}');
}
