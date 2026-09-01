import 'dart:io';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';

void main(List<String> arguments) {
  // Dart defaults a null executable mapping to bin/<name>.dart. cli_pkg does
  // not, so preserve the root pubspec's intended entrypoint explicitly.
  pkg.executables.value = <String, String>{'okf': 'bin/okf.dart'};
  // Keep every published platform asset self-contained.
  pkg.useExe.value = (_) => true;
  pkg.addStandaloneTasks();
  grind(arguments);
}

@Task('Build and stage the current platform executable.')
@Depends('pkg-compile-native')
void okfBuildBinary() {
  final asset = File(_requiredEnvironment('ASSET'));
  asset.parent.createSync(recursive: true);
  File('build/okf.native').copySync(asset.path);

  if (!Platform.isWindows) {
    run('chmod', arguments: <String>['a+x', asset.path]);
  }
}

@Task('Publish an immutable GitHub release from staged assets.')
Future<void> okfDeployGithub() async {
  await runAsync(
    'bash',
    arguments: <String>[
      'tool/ci/publish-release.sh',
      _requiredEnvironment('TAG'),
      _requiredEnvironment('DISTRIBUTION'),
    ],
  );
}

@Task('Publish the package using the configured pub.dev credentials.')
Future<void> okfDeployPub() async {
  await runAsync(
    'dart',
    arguments: const <String>['pub', 'publish', '--force'],
  );
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    fail('$name must be set.');
  }
  return value;
}
