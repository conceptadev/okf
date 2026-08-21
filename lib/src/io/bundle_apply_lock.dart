import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Serializes complete apply operations for one normalized bundle path.
final class OkfBundleApplyLock {
  OkfBundleApplyLock._();

  static final Map<String, Future<void>> _tails = <String, Future<void>>{};
  static final Object _zoneKey = Object();

  /// Runs [action] after earlier actions for [rootPath] have completed.
  static Future<T> synchronized<T>(
    String rootPath,
    Future<T> Function() action,
  ) async {
    final key = await _normalizedKey(rootPath);
    if (Zone.current[_zoneKey] == key) {
      return action();
    }
    final previous = _tails[key] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _tails[key] = tail;

    await previous;
    RandomAccessFile? lock;
    var acquired = false;
    try {
      final lockFile = File(_lockPath(key));
      if (await FileSystemEntity.type(lockFile.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw FileSystemException(
          'Bundle apply lock must not be a symbolic link',
          lockFile.path,
        );
      }
      lock = await lockFile.open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      acquired = true;
      return await runZoned(
        action,
        zoneValues: <Object, Object>{_zoneKey: key},
      );
    } finally {
      try {
        if (acquired) {
          await lock!.unlock();
        }
      } finally {
        try {
          await lock?.close();
        } finally {
          release.complete();
          if (identical(_tails[key], tail)) {
            unawaited(_tails.remove(key));
          }
        }
      }
    }
  }
}

String _lockPath(String canonicalRoot) => p.join(
      p.dirname(canonicalRoot),
      '.${p.basename(canonicalRoot)}.okf-apply.lock',
    );

Future<String> _normalizedKey(String rootPath) async {
  final normalized = p.normalize(p.absolute(rootPath));
  var existingPath = normalized;
  final missingSegments = <String>[];
  while (await FileSystemEntity.type(existingPath) ==
      FileSystemEntityType.notFound) {
    final parent = p.dirname(existingPath);
    if (parent == existingPath) {
      break;
    }
    missingSegments.insert(0, p.basename(existingPath));
    existingPath = parent;
  }

  final resolved = await Directory(existingPath).resolveSymbolicLinks();
  final canonical = missingSegments.isEmpty
      ? resolved
      : p.joinAll(<String>[resolved, ...missingSegments]);
  return Platform.isWindows ? canonical.toLowerCase() : canonical;
}
