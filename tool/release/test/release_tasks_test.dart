import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'exposes the cli_pkg deployment tasks the release workflow runs',
    () async {
      final result = await Process.run(Platform.resolvedExecutable, <String>[
        'run',
        'grinder',
        '--help',
      ], workingDirectory: Directory.current.absolute.path);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stdout,
        allOf(
          contains('pkg-github-release'),
          contains('pkg-github-linux'),
          contains('pkg-github-macos'),
          contains('pkg-homebrew-update'),
        ),
      );
    },
  );
}
