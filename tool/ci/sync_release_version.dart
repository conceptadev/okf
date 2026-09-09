import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final remaining = <String>[...arguments];
  final check = remaining.remove('--check');
  if (remaining.length > 1) {
    stderr.writeln(
      'usage: dart run tool/ci/sync_release_version.dart [--check] [root]',
    );
    exitCode = 2;
    return;
  }

  final root = Directory(remaining.isEmpty ? '.' : remaining.single);
  final packageJson =
      jsonDecode(File('${root.path}/package.json').readAsStringSync())
          as Map<String, Object?>;
  final version = packageJson['version'];
  if (version is! String || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    stderr.writeln('okf: package.json must contain a stable version');
    exitCode = 1;
    return;
  }

  var valid = true;
  valid &= _synchronize(
    root,
    'pubspec.yaml',
    RegExp(r'^version: [^\r\n]+$', multiLine: true),
    'version: $version',
    check,
  );
  valid &= _synchronize(
    root,
    'lib/src/version.dart',
    RegExp(
      r"^const okfPackageVersion = '[^']+';(?:\s*//.*)?$",
      multiLine: true,
    ),
    "const okfPackageVersion = '$version';",
    check,
  );
  valid &= _synchronize(
    root,
    'README.md',
    RegExp(r'conceptadev/okf@v\d+\.\d+\.\d+'),
    'conceptadev/okf@v$version',
    check,
  );

  final changelog = File('${root.path}/CHANGELOG.md').readAsStringSync();
  if (!RegExp(
    '^## ${RegExp.escape(version)}'
    r'(?:\s|$)',
    multiLine: true,
  ).hasMatch(changelog)) {
    stderr.writeln('okf: CHANGELOG.md has no $version entry');
    valid = false;
  }

  if (!valid) exitCode = 1;
}

bool _synchronize(
  Directory root,
  String relativePath,
  RegExp pattern,
  String replacement,
  bool check,
) {
  final file = File('${root.path}/$relativePath');
  final source = file.readAsStringSync();
  if (pattern.allMatches(source).length != 1) {
    stderr.writeln('okf: expected one version marker in $relativePath');
    return false;
  }

  final synchronized = source.replaceFirst(pattern, replacement);
  if (check && source != synchronized) {
    stderr.writeln('okf: $relativePath is not synchronized');
    return false;
  }
  if (!check && source != synchronized) file.writeAsStringSync(synchronized);
  return true;
}
