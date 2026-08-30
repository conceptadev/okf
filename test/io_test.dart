import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:okf/okf_io.dart';
import 'package:okf/src/io/bundle_lock.dart' show OkfBundleLock;
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

    test('refuses a stale expected source in check and write modes', () async {
      final root = await Directory(p.join(sandbox.path, 'bundle')).create();
      await _write(root, 'concept.md', 'read\n');

      await expectLater(
        const OkfBundleWriter().writeAll(
          root.path,
          <String, String>{'concept.md': 'formatted\n'},
          checkOnly: true,
          expectedSources: const <String, String>{'concept.md': 'stale\n'},
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
          await File(p.join(root.path, 'concept.md')).readAsString(), 'read\n');

      await expectLater(
        const OkfBundleWriter().writeAll(
          root.path,
          <String, String>{'concept.md': 'formatted\n'},
          expectedSources: const <String, String>{'concept.md': 'stale\n'},
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
          await File(p.join(root.path, 'concept.md')).readAsString(), 'read\n');

      final result = await const OkfBundleWriter().writeAll(
        root.path,
        <String, String>{'concept.md': 'formatted\n'},
        expectedSources: const <String, String>{'concept.md': 'read\n'},
      );

      expect(result.changedPaths, <String>['concept.md']);
      expect(await File(p.join(root.path, 'concept.md')).readAsString(),
          'formatted\n');
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

  group('OkfBundleLock', () {
    late Directory root;
    late File lockFile;

    setUp(() async {
      root = await Directory(p.join(sandbox.path, 'bundle')).create();
      lockFile = File(p.join(root.path, okfBundleLockFileName));
    });

    test('a writer in another process blocks writes and reads', () async {
      final held = await _holdBundleLock(sandbox, root.path, 'write');

      var written = false;
      final write = const OkfBundleWriter().writeAll(
          root.path, <String, String>{
        'held.md': 'held\n'
      }).whenComplete(() => written = true);
      var inspected = false;
      final read = const OkfBundleLoader()
          .inspect(root.path)
          .whenComplete(() => inspected = true);
      final probe = await _probeBundleLock(sandbox, root.path, 'read');

      expect(await probe.acquiredWithinWindow, isFalse);
      expect(written, isFalse);
      expect(inspected, isFalse);
      expect(await File(p.join(root.path, 'held.md')).exists(), isFalse);

      await held.release();
      await write.timeout(const Duration(seconds: 10));
      await read.timeout(const Duration(seconds: 10));
      await probe.done.timeout(const Duration(seconds: 10));
      expect(await File(p.join(root.path, 'held.md')).readAsString(), 'held\n');
    });

    test('readers in separate processes share the lock', () async {
      // A reader can only take a shared claim on a lock file that exists.
      await const OkfBundleWriter()
          .writeAll(root.path, <String, String>{'seed.md': 'seed\n'});
      final held = await _holdBundleLock(sandbox, root.path, 'read');
      final probe = await _probeBundleLock(sandbox, root.path, 'read');

      expect(await probe.acquiredWithinWindow, isTrue);
      await probe.done.timeout(const Duration(seconds: 10));
      await held.release();
    });

    test('processes disagreeing about TMPDIR still exclude each other',
        () async {
      if (Platform.isWindows) {
        return;
      }
      final held = await _holdBundleLock(
        sandbox,
        root.path,
        'write',
        environment: <String, String>{
          'TMPDIR':
              (await Directory(p.join(sandbox.path, 'tmp-a')).create()).path,
        },
      );
      final probe = await _probeBundleLock(
        sandbox,
        root.path,
        'write',
        environment: <String, String>{
          'TMPDIR':
              (await Directory(p.join(sandbox.path, 'tmp-b')).create()).path,
        },
      );

      expect(await probe.acquiredWithinWindow, isFalse);
      await held.release();
      await probe.done.timeout(const Duration(seconds: 10));
    });

    test('a symbolically linked root shares one lock with its real path',
        () async {
      if (Platform.isWindows) {
        return;
      }
      final alias = p.join(sandbox.path, 'alias');
      await Link(alias).create(root.path);
      final held = await _holdBundleLock(sandbox, alias, 'write');
      final probe = await _probeBundleLock(sandbox, root.path, 'write');

      expect(await probe.acquiredWithinWindow, isFalse);
      await held.release();
      await probe.done.timeout(const Duration(seconds: 10));
      expect(await lockFile.exists(), isTrue);
    });

    test('inspection never creates the lock file', () async {
      await const OkfBundleLoader().inspect(root.path);

      expect(await lockFile.exists(), isFalse);
    });

    for (final firstAttemptFails in <bool>[false, true]) {
      final firstOutcome = firstAttemptFails ? 'failed' : 'completed';
      test(
          'retries a $firstOutcome read when the first writer creates the lock',
          () async {
        final state =
            await File(p.join(root.path, 'state.txt')).writeAsString('before');
        final firstRead = Completer<void>();
        final releaseRead = Completer<void>();
        var attempts = 0;

        final read = OkfBundleLock.read(root.path, () async {
          attempts++;
          final value = await state.readAsString();
          if (attempts == 1) {
            firstRead.complete();
            await releaseRead.future;
            if (firstAttemptFails) {
              throw StateError('read overlapped the first write');
            }
          }
          return value;
        });
        await firstRead.future;

        final writer = await _startLockHelper(
          'write_bundle_file.dart',
          <String>[root.path, 'state.txt', 'after'],
        );
        expect(
          await writer.exitCode.timeout(const Duration(seconds: 10)),
          0,
        );
        releaseRead.complete();

        expect(await read.timeout(const Duration(seconds: 10)), 'after');
        expect(attempts, 2);
      });
    }

    test('does not ignore an invalid existing lock file', () async {
      await Directory(lockFile.path).create();
      var actionRan = false;

      await expectLater(
        OkfBundleLock.read(root.path, () async => actionRan = true),
        throwsA(isA<FileSystemException>()),
      );
      expect(actionRan, isFalse);
    });

    test('does not ignore an unreadable existing lock file', () async {
      if (Platform.isWindows) {
        return;
      }
      await lockFile.create();
      final restricted = await Process.run('chmod', <String>[
        '0000',
        lockFile.path,
      ]);
      expect(restricted.exitCode, 0, reason: '${restricted.stderr}');
      var actionRan = false;

      try {
        await expectLater(
          OkfBundleLock.read(root.path, () async => actionRan = true),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        final restored = await Process.run('chmod', <String>[
          '0600',
          lockFile.path,
        ]);
        expect(restored.exitCode, 0, reason: '${restored.stderr}');
      }
      expect(actionRan, isFalse);
    });

    test('lock files are not part of the bundle inventory', () async {
      await const OkfBundleWriter().writeAll(
        root.path,
        <String, String>{'concept.md': '---\ntype: Reference\n---\n\n# C\n'},
      );
      final nestedRoot = p.join(root.path, 'nested');
      await const OkfBundleWriter().writeAll(
        nestedRoot,
        <String, String>{'concept.md': '---\ntype: Reference\n---\n\n# N\n'},
      );
      expect(await lockFile.exists(), isTrue);
      expect(
        await File(p.join(nestedRoot, okfBundleLockFileName)).exists(),
        isTrue,
      );

      final result = await const OkfBundleLoader().inspect(root.path);

      expect(result.assets, isEmpty);
      expect(result.paths, <String>['concept.md', 'nested/concept.md']);
      expect(result.report.findings, isEmpty);
    });

    test('a failing action releases the lock', () async {
      await expectLater(
        OkfBundleLock.write(
            root.path,
            () => Future<void>.error(
                  StateError('boom'),
                )),
        throwsStateError,
      );

      var reacquired = false;
      await OkfBundleLock.write(root.path, () async => reacquired = true);
      expect(reacquired, isTrue);
      final probe = await _probeBundleLock(sandbox, root.path, 'write');
      expect(await probe.acquiredWithinWindow, isTrue);
      await probe.done.timeout(const Duration(seconds: 10));
    });

    test('a shared claim cannot be upgraded to an exclusive one', () async {
      await expectLater(
        OkfBundleLock.read(
          root.path,
          () => OkfBundleLock.write(root.path, () async {}),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses a lock file that is a symbolic link', () async {
      if (Platform.isWindows) {
        return;
      }
      await Link(lockFile.path).create(p.join(sandbox.path, 'elsewhere.lock'));

      await expectLater(
        OkfBundleLock.write(root.path, () async {}),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

final class _HeldBundleLock {
  _HeldBundleLock(this._process, this._releasePath);

  final Process _process;
  final String _releasePath;

  Future<void> release() async {
    await File(_releasePath).writeAsString('release');
    await _process.exitCode.timeout(const Duration(seconds: 10));
  }
}

final class _BundleLockProbe {
  _BundleLockProbe(this.done, this._acquired);

  final Future<void> done;

  final File _acquired;

  Future<bool> get acquiredWithinWindow async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await _acquired.exists()) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return false;
  }
}

Future<_HeldBundleLock> _holdBundleLock(
  Directory sandbox,
  String rootPath,
  String mode, {
  Map<String, String>? environment,
}) async {
  final readyPath = p.join(sandbox.path, 'hold-$mode-ready');
  final releasePath = p.join(sandbox.path, 'hold-$mode-release');
  final process = await _startLockHelper(
    'hold_bundle_lock.dart',
    <String>[rootPath, mode, readyPath, releasePath],
    environment: environment,
  );
  await _waitForFile(File(readyPath));
  return _HeldBundleLock(process, releasePath);
}

Future<_BundleLockProbe> _probeBundleLock(
  Directory sandbox,
  String rootPath,
  String mode, {
  Map<String, String>? environment,
}) async {
  final startedPath = p.join(sandbox.path, 'probe-$mode-started');
  final acquiredPath = p.join(sandbox.path, 'probe-$mode-acquired');
  final process = await _startLockHelper(
    'acquire_bundle_lock.dart',
    <String>[rootPath, mode, startedPath, acquiredPath],
    environment: environment,
  );
  await _waitForFile(File(startedPath));
  return _BundleLockProbe(process.exitCode, File(acquiredPath));
}

Future<Process> _startLockHelper(
  String script,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    <String>['run', p.join('test', 'support', script), ...arguments],
    workingDirectory: Directory.current.path,
    environment: environment,
  );
  addTearDown(() async {
    process.kill();
    await process.exitCode;
  });
  return process;
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
