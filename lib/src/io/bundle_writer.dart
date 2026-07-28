import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../document.dart';

/// The outcome of writing or checking a set of bundle files.
final class OkfWriteResult {
  OkfWriteResult(Iterable<String> changedPaths)
      : changedPaths = List<String>.unmodifiable(changedPaths);

  /// Paths whose desired content differed from the filesystem.
  final List<String> changedPaths;

  /// Whether at least one file differed.
  bool get hasChanges => changedPaths.isNotEmpty;
}

/// Writes files beneath an explicit OKF bundle root.
///
/// Each file uses a temporary sibling followed by the strongest replacement
/// operation available on the platform. A multi-file call is not
/// transactional, and replacement does not promise to preserve filesystem
/// metadata such as modes, ACLs, or extended attributes. Existing symbolic
/// links in the destination path are rejected. These checks assume the bundle
/// is not being concurrently replaced by an adversarial process.
final class OkfBundleWriter {
  /// Creates a bundle writer.
  const OkfBundleWriter();

  /// Serializes and writes [document] beneath [rootPath].
  Future<OkfWriteResult> writeDocument(
    String rootPath,
    String relativePath,
    OkfDocument document, {
    bool checkOnly = false,
  }) =>
      writeAll(
        rootPath,
        <String, String>{relativePath: document.serialize()},
        checkOnly: checkOnly,
      );

  /// Writes all [files], keyed by bundle-relative path.
  ///
  /// When [checkOnly] is true the filesystem is not changed; the returned
  /// paths identify files that would be written.
  Future<OkfWriteResult> writeAll(
    String rootPath,
    Map<String, String> files, {
    bool checkOnly = false,
  }) async {
    final root = await _validatedRoot(
      rootPath,
      createIfMissing: !checkOnly,
    );
    final normalizedFiles = SplayTreeMap<String, String>();
    for (final entry in files.entries) {
      final relativePath = _normalizeRelativePath(entry.key);
      if (normalizedFiles.containsKey(relativePath)) {
        throw ArgumentError.value(
          entry.key,
          'files',
          'Multiple paths normalize to $relativePath',
        );
      }
      normalizedFiles[relativePath] = entry.value;
    }

    final changed = <String>[];
    for (final entry in normalizedFiles.entries) {
      final destination = File(
        p.joinAll(<String>[root.path, ...p.posix.split(entry.key)]),
      );
      await _rejectLinks(root, entry.key);

      final desiredBytes = utf8.encode(entry.value);
      final currentBytes =
          await destination.exists() ? await destination.readAsBytes() : null;
      if (_bytesEqual(currentBytes, desiredBytes)) {
        continue;
      }

      changed.add(entry.key);
      if (!checkOnly) {
        await destination.parent.create(recursive: true);
        await _rejectLinks(root, entry.key);
        await _atomicWrite(destination, desiredBytes);
      }
    }

    return OkfWriteResult(changed);
  }

  Future<Directory> _validatedRoot(
    String rootPath, {
    required bool createIfMissing,
  }) async {
    if (rootPath.trim().isEmpty) {
      throw const FileSystemException('Bundle root must not be empty');
    }

    final root = Directory(p.normalize(p.absolute(rootPath)));
    final type = await FileSystemEntity.type(
      root.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Bundle root must not be a symbolic link',
        root.path,
      );
    }
    if (type == FileSystemEntityType.notFound) {
      if (createIfMissing) {
        await root.create(recursive: true);
      }
    } else if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Bundle root is not a directory',
        root.path,
      );
    }
    return root;
  }

  Future<void> _rejectLinks(Directory root, String relativePath) async {
    var currentPath = root.path;
    for (final segment in p.posix.split(relativePath)) {
      currentPath = p.join(currentPath, segment);
      final type = await FileSystemEntity.type(
        currentPath,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Refusing to write through a symbolic link',
          currentPath,
        );
      }
    }
  }

  Future<void> _atomicWrite(File destination, List<int> bytes) async {
    final random = Random.secure();
    File? temporary;
    for (var attempt = 0; attempt < 16; attempt++) {
      final suffix =
          '${pid.toRadixString(16)}-${random.nextInt(1 << 32).toRadixString(16)}';
      final candidate = File(
        p.join(
          destination.parent.path,
          '.${p.basename(destination.path)}.okf-$suffix.tmp',
        ),
      );
      try {
        await candidate.create(exclusive: true);
        temporary = candidate;
        break;
      } on FileSystemException {
        // A colliding temporary name is harmless; try another one.
      }
    }
    if (temporary == null) {
      throw FileSystemException(
        'Could not allocate a temporary file',
        destination.path,
      );
    }

    try {
      final sink = temporary.openWrite(mode: FileMode.writeOnly);
      sink.add(bytes);
      await sink.flush();
      await sink.close();
      await _replace(temporary, destination);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<void> _replace(File temporary, File destination) async {
    try {
      await temporary.rename(destination.path);
      return;
    } on FileSystemException {
      if (!await destination.exists()) {
        rethrow;
      }
    }

    final backup = File(
      '${destination.path}.okf-${pid.toRadixString(16)}.bak',
    );
    if (await backup.exists()) {
      throw FileSystemException(
        'Could not allocate a replacement backup',
        backup.path,
      );
    }

    await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
      await backup.delete();
    } on FileSystemException {
      if (!await destination.exists() && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    } finally {
      if (await backup.exists() && await destination.exists()) {
        await backup.delete();
      }
    }
  }
}

String _normalizeRelativePath(String value) {
  if (value.isEmpty ||
      p.posix.isAbsolute(value) ||
      p.windows.isAbsolute(value) ||
      value.contains(r'\')) {
    throw ArgumentError.value(
      value,
      'relativePath',
      'Path must be a non-empty relative POSIX path',
    );
  }

  final segments = value.split('/');
  if (segments.isEmpty ||
      segments.any(
        (segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.runes.any((rune) => rune < 0x20 || rune == 0x7f),
      )) {
    throw ArgumentError.value(
      value,
      'relativePath',
      'Path cannot contain empty, dot, traversal, or control segments',
    );
  }
  return segments.join('/');
}

bool _bytesEqual(List<int>? left, List<int> right) {
  if (left == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
