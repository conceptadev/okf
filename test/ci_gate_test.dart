import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('repository actions are pinned to immutable commits', () {
    for (final path in <String>[
      'action.yml',
      '.github/workflows/ci.yml',
      '.github/workflows/release.yml',
      '.github/workflows/release-please.yml',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains(RegExp(r'uses:\s+[^@\s]+@(?![0-9a-f]{40}(?:\s|$))'))),
        reason: '$path contains a movable action reference',
      );
    }
  });

  test('release bot owns versions, changelog, tags, and release events', () {
    final source =
        File('.github/workflows/release-please.yml').readAsStringSync();
    final workflow = loadYaml(source) as YamlMap;
    final permissions = workflow['permissions'] as YamlMap;
    final job = (workflow['jobs'] as YamlMap)['release-please'] as YamlMap;
    final steps = job['steps'] as YamlList;
    final action = steps[1] as YamlMap;

    expect(permissions, <String, Object?>{'contents': 'read'});
    expect(
      action['uses'],
      'googleapis/release-please-action@'
      '45996ed1f6d02564a971a2fa1b5860e934307cf7',
    );
    expect(
      (action['with'] as YamlMap)['token'],
      r'${{ secrets.RELEASE_PLEASE_TOKEN }}',
    );
    expect(source, contains('Require the release bot token'));
    expect(source, isNot(contains('gh workflow run')));

    final config = jsonDecode(
      File('release-please-config.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(config['release-type'], 'dart');
    expect(config['include-component-in-tag'], false);
    expect(config['include-v-in-tag'], true);
    expect(config['bump-minor-pre-major'], true);
    expect(config['draft'], true);
    expect(config['force-tag-creation'], true);
    expect(
      config.toString(),
      allOf(contains('lib/src/version.dart'), contains('README.md')),
    );
    final package =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final packageVersion = package['version'] as String;
    final manifest = jsonDecode(
      File('.release-please-manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(manifest['.'], packageVersion);
    expect(
      File('lib/src/version.dart').readAsStringSync(),
      contains("'$packageVersion'; // x-release-please-version"),
    );
    expect(
      File('README.md').readAsStringSync(),
      allOf(
        contains('okf@v$packageVersion'),
        contains('x-release-please-start-version'),
        contains('x-release-please-end'),
      ),
    );
  });

  test('composite action checks out and validates with zero configuration', () {
    final source = File('action.yml').readAsStringSync();
    final action = loadYaml(source) as YamlMap;
    final inputs = action['inputs'] as YamlMap;
    final steps = (action['runs'] as YamlMap)['steps'] as YamlList;

    final checkout = steps[1] as YamlMap;
    expect(
      checkout['uses'],
      'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
    );
    expect(checkout['if'], "steps.workspace.outputs.checkout == 'true'");
    expect((checkout['with'] as YamlMap)['clean'], false);
    expect((checkout['with'] as YamlMap)['persist-credentials'], false);
    expect((inputs['bundle'] as YamlMap)['default'], '.');
    expect((inputs['strict'] as YamlMap)['default'], 'false');
    expect(source, contains(r'inputs.engine-version || github.action_ref'));
    expect(source, contains('tool/ci/install-engine.sh'));
    expect(source, contains('tool/ci/validate-engine.sh'));
    expect(
      RegExp(r'tool/ci/validate-engine\.sh').allMatches(source),
      hasLength(1),
    );
    expect(
      File('README.md').readAsStringSync(),
      isNot(contains('uses: actions/checkout@v4')),
    );
  });

  group('supported runner behavior', () {
    test('checkout is requested only for an empty workspace', () async {
      final temporary = Directory.systemTemp.createTempSync('okf-workspace-');
      addTearDown(() => temporary.deleteSync(recursive: true));

      final empty = await _checkoutDecision(temporary.path);
      expect(empty.exitCode, 0, reason: '${empty.stderr}');
      expect((empty.stdout as String).trim(), 'true');

      File('${temporary.path}/unrelated.txt').writeAsStringSync('unrelated');
      final unsafe = await _checkoutDecision(temporary.path);
      expect(unsafe.exitCode, 1);

      File('${temporary.path}/unrelated.txt').deleteSync();
      expect(
        (await Process.run('git', <String>['init'],
                workingDirectory: temporary.path))
            .exitCode,
        0,
      );
      await Process.run(
        'git',
        <String>[
          '-c',
          'user.name=OKF Test',
          '-c',
          'user.email=okf@example.invalid',
          'commit',
          '--allow-empty',
          '-m',
          'fixture',
        ],
        workingDirectory: temporary.path,
      );
      File('${temporary.path}/generated.md').writeAsStringSync('generated');
      final prepared = await _checkoutDecision(temporary.path);
      expect(prepared.exitCode, 0, reason: '${prepared.stderr}');
      expect((prepared.stdout as String).trim(), 'false');
    });

    test('downloaded engine receives exactly one validation invocation',
        () async {
      final temporary = Directory.systemTemp.createTempSync('okf-ci-gate-');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final fakeBin = Directory('${temporary.path}/bin')..createSync();
      final curlLog = File('${temporary.path}/curl.log');
      final engineLog = File('${temporary.path}/engine.log');
      final ghLog = File('${temporary.path}/gh.log');
      final curl = File('${fakeBin.path}/curl')
        ..writeAsStringSync('''#!/usr/bin/env bash
set -euo pipefail
while (( \$# )); do
  case "\$1" in
    --output) output="\$2"; shift 2 ;;
    https://*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
cat > "\$output" <<'ENGINE'
#!/usr/bin/env bash
printf '%s\\n' "\$@" > "\$FAKE_ENGINE_LOG"
exit "\${FAKE_ENGINE_EXIT:-0}"
ENGINE
printf '%s\\n' "\$url" > "\$FAKE_CURL_LOG"
''');
      final gh = File('${fakeBin.path}/gh')
        ..writeAsStringSync('''#!/usr/bin/env bash
printf '%s\\n' "\$*" > "\$FAKE_GH_LOG"
''');
      await Process.run('chmod', <String>['+x', curl.path, gh.path]);
      final environment = <String, String>{
        'PATH': '${fakeBin.path}:${Platform.environment['PATH']}',
        'FAKE_CURL_LOG': curlLog.path,
        'FAKE_ENGINE_LOG': engineLog.path,
        'FAKE_GH_LOG': ghLog.path,
      };
      final engine = File('${temporary.path}/okf');

      final install = await Process.run(
        'bash',
        <String>[
          'tool/ci/install-engine.sh',
          'v0.2.0',
          'Linux',
          'X64',
          engine.path,
        ],
        environment: environment,
      );
      expect(install.exitCode, 0, reason: '${install.stderr}');
      expect(
        curlLog.readAsStringSync().trim(),
        endsWith('/v0.2.0/okf-linux-x64'),
      );
      expect(
        ghLog.readAsStringSync().trim(),
        'release verify-asset v0.2.0 ${engine.path} '
        '--repo conceptadev/okf',
      );

      final validation = await Process.run(
        'bash',
        <String>[
          'tool/ci/validate-engine.sh',
          engine.path,
          'bundle with spaces',
          'true',
        ],
        environment: environment,
      );
      expect(validation.exitCode, 0, reason: '${validation.stderr}');
      expect(
        engineLog.readAsLinesSync(),
        <String>['validate', 'bundle with spaces', '--strict'],
      );

      final invalidVersion = await Process.run(
        'bash',
        <String>[
          'tool/ci/install-engine.sh',
          '../mutable',
          'Linux',
          'X64',
          engine.path,
        ],
        environment: environment,
      );
      expect(invalidVersion.exitCode, 2);
    });

    test('validation script omits strict and propagates verdicts', () async {
      final temporary = Directory.systemTemp.createTempSync('okf-ci-verdict-');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final engineLog = File('${temporary.path}/engine.log');
      final engine = File('${temporary.path}/okf')
        ..writeAsStringSync('''#!/usr/bin/env bash
printf '%s\\n' "\$@" > "\$FAKE_ENGINE_LOG"
exit "\${FAKE_ENGINE_EXIT:-0}"
''');
      await Process.run('chmod', <String>['+x', engine.path]);

      final result = await Process.run(
        'bash',
        <String>['tool/ci/validate-engine.sh', engine.path, '.', 'false'],
        environment: <String, String>{
          'FAKE_ENGINE_LOG': engineLog.path,
          'FAKE_ENGINE_EXIT': '1',
        },
      );
      expect(result.exitCode, 1);
      expect(engineLog.readAsLinesSync(), <String>['validate', '.']);

      final invalid = await Process.run(
        'bash',
        <String>['tool/ci/validate-engine.sh', engine.path, '.', 'sometimes'],
      );
      expect(invalid.exitCode, 2);
    });

    test('one platform manifest drives release and action assets', () async {
      final platforms = _platforms();
      final matrixResult = await Process.run(
        'bash',
        <String>['tool/ci/release-matrix.sh'],
      );
      expect(matrixResult.exitCode, 0, reason: '${matrixResult.stderr}');
      final matrix =
          jsonDecode(matrixResult.stdout as String) as Map<String, Object?>;
      expect(
        matrix['include'],
        platforms
            .map(
              (platform) => <String, String>{
                'os': platform.workflowRunner,
                'asset': platform.asset,
              },
            )
            .toList(),
      );

      for (final platform in platforms) {
        final lookup = await Process.run(
          'bash',
          <String>[
            'tool/ci/platform-asset.sh',
            platform.runnerOs,
            platform.runnerArch,
          ],
        );
        expect(lookup.exitCode, 0, reason: '${lookup.stderr}');
        expect((lookup.stdout as String).trim(), platform.asset);
      }
    });

    test('release workflow publishes every manifest asset', () async {
      final source = File('.github/workflows/release.yml').readAsStringSync();
      final workflow = loadYaml(source) as YamlMap;
      final jobs = workflow['jobs'] as YamlMap;
      final permissions = workflow['permissions'] as YamlMap;
      final verify = jobs['verify'] as YamlMap;
      final binaries = jobs['binaries'] as YamlMap;
      final publishJob = jobs['publish'] as YamlMap;
      final publishPermissions = publishJob['permissions'] as YamlMap;
      final pubPublishJob = jobs['pub-publish'] as YamlMap;
      final pubPublishPermissions = pubPublishJob['permissions'] as YamlMap;
      expect(jobs, contains('ref'));
      expect(permissions['contents'], 'read');
      expect(publishPermissions['actions'], 'read');
      expect(publishPermissions['contents'], 'write');
      expect(pubPublishJob['needs'], 'publish');
      expect(pubPublishPermissions['contents'], 'read');
      expect(pubPublishPermissions['id-token'], 'write');
      expect(
        pubPublishJob.toString(),
        allOf(
          contains('dart-lang/setup-dart@'),
          contains('dart pub publish --force'),
        ),
      );
      expect(binaries['needs'], <String>['platforms', 'verify']);
      expect(
        verify.toString(),
        allOf(
          contains('dart format --output=none --set-exit-if-changed .'),
          contains('dart analyze --fatal-infos'),
          contains('dart test'),
          contains('dart pub publish --dry-run'),
        ),
      );
      expect(source, isNot(contains('@v4')));
      expect(source, isNot(contains('@v1')));
      expect(source, contains('persist-credentials: false'));
      expect(source, contains('release-matrix.sh'));
      expect(source, contains('publish-release.sh'));
      expect(
        File('.pubignore').readAsLinesSync(),
        contains('test/ci_gate_test.dart'),
      );

      final dependabot =
          loadYaml(File('.github/dependabot.yml').readAsStringSync())
              as YamlMap;
      final actionUpdates =
          (dependabot['updates'] as YamlList).single as YamlMap;
      expect(actionUpdates['package-ecosystem'], 'github-actions');
      expect(actionUpdates['directory'], '/');
      expect((actionUpdates['schedule'] as YamlMap)['interval'], 'weekly');

      final temporary = Directory.systemTemp.createTempSync('okf-release-');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final distribution = Directory('${temporary.path}/dist')..createSync();
      for (final platform in _platforms()) {
        File('${distribution.path}/${platform.asset}')
            .writeAsStringSync('asset');
      }
      final fakeBin = Directory('${temporary.path}/bin')..createSync();
      final ghLog = File('${temporary.path}/gh.log');
      final gh = File('${fakeBin.path}/gh')
        ..writeAsStringSync('''#!/usr/bin/env bash
printf '%s\\n' "\$*" >> "\$FAKE_GH_LOG"
[[ "\$1" == api ]] && { printf 'true\\n'; exit 0; }
[[ "\$1 \$2" == 'release view' ]] && exit 1
exit 0
''');
      await Process.run('chmod', <String>['+x', gh.path]);

      final publish = await Process.run(
        'bash',
        <String>['tool/ci/publish-release.sh', 'v0.2.0', distribution.path],
        environment: <String, String>{
          'PATH': '${fakeBin.path}:${Platform.environment['PATH']}',
          'FAKE_GH_LOG': ghLog.path,
          'GH_REPO': 'conceptadev/okf',
        },
      );
      expect(publish.exitCode, 0, reason: '${publish.stderr}');
      final calls = ghLog.readAsStringSync();
      expect(
        calls,
        contains(
          'api repos/conceptadev/okf/releases/tags/v0.2.0 '
          '--jq .immutable',
        ),
      );
      expect(calls, contains('release create v0.2.0'));
      expect(calls, contains('release edit v0.2.0 --draft=false'));
      for (final platform in _platforms()) {
        expect(calls, contains(platform.asset));
      }
    });

    test('CI shell scripts parse as Bash', () async {
      final scripts = Directory('tool/ci')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sh'))
          .map((file) => file.path)
          .toList();
      final result = await Process.run('bash', <String>['-n', ...scripts]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });
  }, skip: Platform.isWindows ? 'the action has no Windows binary' : false);
}

Future<ProcessResult> _checkoutDecision(String workspace) => Process.run(
      'bash',
      <String>['tool/ci/needs-checkout.sh', workspace],
    );

List<
    ({
      String runnerOs,
      String runnerArch,
      String workflowRunner,
      String asset,
    })> _platforms() => File('tool/ci/platforms.tsv')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) {
      final fields = line.split('\t');
      return (
        runnerOs: fields[0],
        runnerArch: fields[1],
        workflowRunner: fields[2],
        asset: fields[3],
      );
    }).toList();
