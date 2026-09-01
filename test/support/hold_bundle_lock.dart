import 'dart:io';

import 'package:okf/src/io/bundle_lock.dart';

/// Holds a bundle lock in a separate process until the test releases it.
///
/// Usage: `hold_bundle_lock.dart <root> <read|write> <ready> <release>`.
Future<void> main(List<String> arguments) async {
  final root = arguments[0];
  final readyPath = arguments[2];
  final releasePath = arguments[3];

  Future<void> hold() async {
    await File(readyPath).writeAsString('ready');
    while (!await File(releasePath).exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  await switch (arguments[1]) {
    'read' => OkfBundleLock.read(root, hold),
    'write' => OkfBundleLock.write(root, hold),
    final mode => throw ArgumentError.value(mode, 'mode'),
  };
}
