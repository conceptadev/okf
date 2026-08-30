import 'dart:io';

import 'package:okf/src/io/bundle_lock.dart';

/// Acquires and immediately releases a bundle lock in a separate process.
///
/// Usage: `acquire_bundle_lock.dart <root> <read|write> <started> <acquired>`.
Future<void> main(List<String> arguments) async {
  final root = arguments[0];
  final startedPath = arguments[2];
  final acquiredPath = arguments[3];

  Future<void> acquired() => File(acquiredPath).writeAsString('acquired');

  await File(startedPath).writeAsString('started');
  await switch (arguments[1]) {
    'read' => OkfBundleLock.read(root, acquired),
    'write' => OkfBundleLock.write(root, acquired),
    final mode => throw ArgumentError.value(mode, 'mode'),
  };
}
