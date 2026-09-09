import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('repository actions are pinned to immutable commits', () {
    for (final path in <String>[
      'action.yml',
      '.github/workflows/ci.yml',
      '.github/workflows/release.yml',
      '.github/workflows/release-pr.yml',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains(RegExp(r'uses:\s+[^@\s]+@(?![0-9a-f]{40}(?:\s|$))'))),
        reason: '$path contains a movable action reference',
      );
    }
  });

  test('Changesets bot owns versions, changelog, tags, and dispatch', () {
    final source = File('.github/workflows/release-pr.yml').readAsStringSync();
    final workflow = loadYaml(source) as YamlMap;
    final permissions = workflow['permissions'] as YamlMap;
    final job = (workflow['jobs'] as YamlMap)['release'] as YamlMap;
    final steps = job['steps'] as YamlList;
    final action = steps.cast<YamlMap>().singleWhere(
          (step) =>
              step['uses']?.toString().startsWith('changesets/action@') ??
              false,
        );

    expect(permissions['actions'], 'write');
    expect(permissions['contents'], 'write');
    expect(permissions['pull-requests'], 'write');
    expect(
      action['uses'],
      'changesets/action@8488615a623b1b9c987934bb89eae8af6a946ac1',
    );
    final inputs = action['with'] as YamlMap;
    expect(inputs['github-token'], r'${{ secrets.GITHUB_TOKEN }}');
    expect(inputs['version-script'], 'npm run release:version');
    expect(inputs['publish-script'], 'npm run release:tag');
    expect(inputs['create-github-releases'], false);
    expect(inputs['push-git-tags'], true);
    expect(
      source,
      allOf(
        contains(r'gh workflow run ci.yml --ref "$branch"'),
        contains(r'gh workflow run release.yml --ref "$tag"'),
      ),
    );
    expect(source, isNot(contains('RELEASE_PLEASE_TOKEN')));
    expect(source, isNot(contains('id-token: write')));

    final config = jsonDecode(
      File('.changeset/config.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(config['baseBranch'], 'main');
    expect(
      config['privatePackages'],
      <String, Object?>{'version': true, 'tag': true},
    );

    final dartPackage =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final nodePackage = jsonDecode(
      File('package.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final packageLock = jsonDecode(
      File('package-lock.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final packageVersion = dartPackage['version'] as String;
    expect(nodePackage['name'], 'okf');
    expect(nodePackage['private'], true);
    expect(nodePackage['version'], packageVersion);
    expect(packageLock['version'], packageVersion);
    expect(
      File('lib/src/version.dart').readAsStringSync(),
      contains("'$packageVersion';"),
    );
    expect(
      File('README.md').readAsStringSync(),
      contains('okf@v$packageVersion'),
    );
    expect(File('.changeset/README.md').existsSync(), true);
    expect(File('release-please-config.json').existsSync(), false);
    expect(File('.release-please-manifest.json').existsSync(), false);
  });

  test('release version synchronizer updates every Dart-facing version',
      () async {
    final temporary = Directory.systemTemp.createTempSync('okf-version-');
    addTearDown(() => temporary.deleteSync(recursive: true));
    Directory('${temporary.path}/lib/src').createSync(recursive: true);
    File('${temporary.path}/package.json').writeAsStringSync(
      '{"name":"okf","version":"1.2.3"}',
    );
    File('${temporary.path}/pubspec.yaml').writeAsStringSync(
      'name: okf\nversion: 0.1.0\n',
    );
    File('${temporary.path}/lib/src/version.dart').writeAsStringSync(
      "const okfPackageVersion = '0.1.0'; // stale\n",
    );
    File('${temporary.path}/README.md').writeAsStringSync(
      'uses: conceptadev/okf@v0.1.0\n',
    );
    File('${temporary.path}/CHANGELOG.md').writeAsStringSync(
      '## 1.2.3\n\n- Release.\n',
    );

    final update = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/ci/sync_release_version.dart',
        temporary.path,
      ],
    );
    expect(update.exitCode, 0, reason: '${update.stderr}');
    expect(
      File('${temporary.path}/pubspec.yaml').readAsStringSync(),
      contains('version: 1.2.3'),
    );
    expect(
      File('${temporary.path}/lib/src/version.dart').readAsStringSync(),
      contains("const okfPackageVersion = '1.2.3';"),
    );
    expect(
      File('${temporary.path}/README.md').readAsStringSync(),
      contains('conceptadev/okf@v1.2.3'),
    );

    final check = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/ci/sync_release_version.dart',
        '--check',
        temporary.path,
      ],
    );
    expect(check.exitCode, 0, reason: '${check.stderr}');
  });

  test('cli_pkg release tooling isolates its effective SDK floor', () {
    final releasePubspecFile = File('tool/release/pubspec.yaml');
    expect(releasePubspecFile.existsSync(), isTrue);

    final packagePubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final releasePubspec =
        loadYaml(releasePubspecFile.readAsStringSync()) as YamlMap;
    final releaseEnvironment = releasePubspec['environment'] as YamlMap;
    final releaseDependencies = releasePubspec['dependencies'] as YamlMap;
    final releaseDevDependencies =
        releasePubspec['dev_dependencies'] as YamlMap;

    expect((packagePubspec['environment'] as YamlMap)['sdk'], '>=3.4.0 <4.0.0');
    expect(releasePubspec['name'], 'okf_release');
    expect(releasePubspec['publish_to'], 'none');
    expect(releaseEnvironment['sdk'], '>=3.11.0 <4.0.0');
    expect(releaseDependencies['cli_pkg'], '2.15.2');
    expect(releaseDependencies['grinder'], '0.10.0');
    expect(releaseDependencies, hasLength(2));
    expect(releaseDevDependencies['lints'], '^6.0.0');
    expect(releaseDevDependencies['test'], '^1.25.8');
    expect(
      (packagePubspec['dev_dependencies'] as YamlMap),
      isNot(contains('cli_pkg')),
    );
    final releaseLock =
        loadYaml(File('tool/release/pubspec.lock').readAsStringSync())
            as YamlMap;
    final releasePackages = releaseLock['packages'] as YamlMap;
    expect((releasePackages['cli_pkg'] as YamlMap)['version'], '2.15.2');
    expect((releaseLock['sdks'] as YamlMap)['dart'], '>=3.11.0 <4.0.0');
  });

  test('release workflows use project deployment adapters', () {
    final releaseSource =
        File('.github/workflows/release.yml').readAsStringSync();
    final releaseWorkflow = loadYaml(releaseSource) as YamlMap;
    final releaseJobs = releaseWorkflow['jobs'] as YamlMap;
    final verify = releaseJobs['verify'] as YamlMap;
    final pubPublish = releaseJobs['pub-publish'] as YamlMap;
    const releaseTool =
        'dart --packages=tool/release/.dart_tool/package_config.json '
        'tool/release/grind.dart';

    expect(
      releaseWorkflow.toString(),
      allOf(
        contains('$releaseTool okf-build-binary'),
        contains('$releaseTool okf-deploy-github'),
        contains('$releaseTool okf-deploy-pub'),
        contains('$releaseTool okf-deploy-homebrew'),
      ),
    );
    expect(
      verify.toString(),
      allOf(
        contains('dart format --output=none --set-exit-if-changed .'),
        contains('dart analyze --fatal-infos'),
        contains('dart run test'),
        contains('dart pub publish --dry-run'),
        contains('tool/release'),
      ),
    );
    expect(
      pubPublish.toString(),
      allOf(
        contains('dart-lang/setup-dart@'),
        contains('dart pub -C tool/release get --enforce-lockfile'),
        contains('okf-deploy-pub'),
      ),
    );
    expect(
      releaseSource,
      isNot(
        anyOf(
          contains('dart compile exe bin/okf.dart'),
          contains('bash tool/ci/publish-release.sh'),
          contains('bash tool/ci/publish-homebrew.sh'),
          contains('dart pub publish --force'),
          contains('PUB_CREDENTIALS'),
        ),
      ),
    );

    final releaseTaskSource =
        File('tool/release/grind.dart').readAsStringSync();
    expect(
      releaseTaskSource,
      allOf(
        contains('pkg.addStandaloneTasks()'),
        contains("'tool/ci/publish-release.sh'"),
        contains("'tool/ci/publish-homebrew.sh'"),
        contains("const <String>['pub', 'publish', '--force']"),
      ),
    );
    expect(
      releaseTaskSource,
      isNot(
        anyOf(
          contains('addGithubTasks'),
          contains('addPubTasks'),
          contains('PUB_CREDENTIALS'),
        ),
      ),
    );

    final ciWorkflow =
        loadYaml(File('.github/workflows/ci.yml').readAsStringSync())
            as YamlMap;
    expect(
      ciWorkflow.toString(),
      allOf(
        contains(
          'dart format --output=none --set-exit-if-changed '
          'bin example lib test tool/ci tool/generate_case_folding.dart',
        ),
        contains('dart pub -C tool/release get --enforce-lockfile'),
        contains('working-directory: tool/release'),
        contains('dart analyze --fatal-infos'),
        contains('dart run test'),
        contains('$releaseTool okf-build-binary'),
      ),
    );

    final dependabot =
        loadYaml(File('.github/dependabot.yml').readAsStringSync()) as YamlMap;
    expect(
      (dependabot['updates'] as YamlList).cast<YamlMap>().any(
            (update) =>
                update['package-ecosystem'] == 'pub' &&
                update['directory'] == '/tool/release',
          ),
      true,
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
      expect(binaries['needs'], <String>['platforms', 'verify']);
      expect(source, isNot(contains('@v4')));
      expect(source, isNot(contains('@v1')));
      expect(source, contains('persist-credentials: false'));
      expect(source, contains('release-matrix.sh'));
      expect(
        File('.pubignore').readAsLinesSync(),
        contains('test/ci_gate_test.dart'),
      );

      final dependabot =
          loadYaml(File('.github/dependabot.yml').readAsStringSync())
              as YamlMap;
      final actionUpdates =
          (dependabot['updates'] as YamlList).cast<YamlMap>().singleWhere(
                (update) => update['package-ecosystem'] == 'github-actions',
              );
      expect(actionUpdates['package-ecosystem'], 'github-actions');
      expect(actionUpdates['directory'], '/');
      expect((actionUpdates['schedule'] as YamlMap)['interval'], 'weekly');
      expect(
        (dependabot['updates'] as YamlList)
            .cast<YamlMap>()
            .any((update) => update['package-ecosystem'] == 'npm'),
        true,
      );
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

    test('homebrew job releases the tap from the published assets', () async {
      final source = File('.github/workflows/release.yml').readAsStringSync();
      final workflow = loadYaml(source) as YamlMap;
      final jobs = workflow['jobs'] as YamlMap;
      final homebrew = jobs['homebrew'] as YamlMap;
      final permissions = homebrew['permissions'] as YamlMap;

      expect(homebrew['needs'], 'publish');
      expect(permissions['contents'], 'read');
      expect(
        homebrew.toString(),
        allOf(
          contains('conceptadev/homebrew-tap'),
          // The script parameter and the repository secret are named
          // differently; a mismatch would hand the push an empty token.
          contains(r'HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_GH_TOKEN }}'),
          // Checksums must describe the bytes the release serves, so the
          // formula is built from a download rather than the build artifacts.
          contains('gh release download'),
        ),
      );

      final temporary = Directory.systemTemp.createTempSync('okf-homebrew-');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final distribution = Directory('${temporary.path}/dist')..createSync();
      for (final platform in _platforms()) {
        File('${distribution.path}/${platform.asset}')
            .writeAsStringSync(platform.asset);
      }

      final render = await Process.run(
        'bash',
        <String>['tool/ci/homebrew-formula.sh', 'v9.9.9', distribution.path],
        environment: <String, String>{'GH_REPO': 'conceptadev/okf'},
      );
      expect(render.exitCode, 0, reason: '${render.stderr}');
      final formula = render.stdout as String;

      expect(formula, contains('class Okf < Formula'));
      // brew audit rejects a version that duplicates the one it scans from
      // the download URL.
      expect(formula, isNot(contains('version "9.9.9"')));
      for (final platform in _platforms()) {
        final digest = sha256.convert(utf8.encode(platform.asset)).toString();
        expect(
          formula,
          contains(
            'url "https://github.com/conceptadev/okf/releases/download/'
            'v9.9.9/${platform.asset}"',
          ),
        );
        expect(formula, contains('sha256 "$digest"'));
      }

      // A platform the formula cannot express must fail the release instead of
      // silently shipping a tap that omits it.
      final unsupported = Directory('${temporary.path}/manifest')..createSync();
      File('${unsupported.path}/platforms.tsv').writeAsStringSync(
        'Plan9\tRISCV\tplan9-latest\tokf-plan9-riscv\n',
      );
      for (final script in <String>['homebrew-formula.sh', 'sha256.sh']) {
        File('tool/ci/$script').copySync('${unsupported.path}/$script');
      }
      File('${distribution.path}/okf-plan9-riscv').writeAsStringSync('asset');
      final rejected = await Process.run(
        'bash',
        <String>[
          '${unsupported.path}/homebrew-formula.sh',
          'v9.9.9',
          distribution.path,
        ],
        environment: <String, String>{'GH_REPO': 'conceptadev/okf'},
      );
      expect(rejected.exitCode, isNot(0));
      expect(rejected.stderr, contains('no Homebrew predicate'));
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
