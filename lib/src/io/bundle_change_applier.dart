import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../bundle.dart';
import '../bundle_change_overlay.dart';
import '../bundle_change_set.dart';
import '../document.dart';
import '../finding.dart';
import 'bundle_loader.dart';
import 'bundle_lock.dart';
import 'bundle_writer.dart';

part 'bundle_change_case_folding.dart';

/// Prepares and commits the single safe write path for OKF bundle mutations.
///
/// [prepare] builds the complete candidate, validates it with the fixed OKF
/// Spec validator, and returns an opaque capability. [commit] accepts only
/// that capability, rechecks the source snapshot, and transactionally writes
/// the exact bytes captured during preparation.
final class OkfBundleChangeApplier {
  /// Creates a write path. [clock] only dates generated log entries.
  const OkfBundleChangeApplier({this.clock = DateTime.now});

  /// Supplies the date generated log entries are recorded under.
  final DateTime Function() clock;

  /// Builds and validates a complete candidate without writing any file.
  Future<OkfBundlePreparation> prepare(
    String rootPath,
    OkfBundleChangeSet changes,
  ) =>
      _prepare(rootPath, changes);

  /// Commits exactly the bytes bound into [prepared].
  Future<OkfBundleCommitResult> commit(OkfPreparedChange prepared) =>
      OkfBundleLock.write(
        prepared._plan.rootPath,
        () => _commitLocked(prepared),
      );

  /// Prepares and commits [changes] while serializing the complete operation.
  ///
  /// Adapters that do not need the inspection seam can use this operation so
  /// concurrent callers never prepare from the same source state. Call
  /// [prepare] and [commit] separately when downstream policy must inspect the
  /// immutable candidate between them.
  Future<OkfBundleApplication> apply(
    String rootPath,
    OkfBundleChangeSet changes,
  ) =>
      OkfBundleLock.write(rootPath, () async {
        final preparation = await _prepare(rootPath, changes);
        return switch (preparation) {
          OkfPreparationReady(prepared: final prepared) => OkfBundleApplied(
              result: await _commitLocked(prepared),
            ),
          OkfPreparationRefused(validation: final validation) =>
            OkfBundleApplicationRefused(validation: validation),
        };
      });

  Future<OkfBundleCommitResult> _commitLocked(
    OkfPreparedChange prepared,
  ) async {
    if (prepared._committed) {
      throw StateError('A prepared change can be committed only once.');
    }
    prepared._committed = true;
    final plan = prepared._plan;
    final current = await _snapshot(plan.rootPath);
    if (!plan.source.sameContent(current)) {
      throw const OkfStalePreparedChangeException();
    }
    final written = await const OkfBundleWriteTransaction().writeAll(
      plan.rootPath,
      plan.changedFiles,
    );
    return OkfBundleCommitResult(changedPaths: written.changedPaths);
  }

  Future<OkfBundlePreparation> _prepare(
    String rootPath,
    OkfBundleChangeSet changes,
  ) async {
    final sourceBefore = await _snapshot(rootPath);
    final loaded = await const OkfBundleLoader().inspect(sourceBefore.rootPath);
    final overlay = OkfBundleChangeOverlay.of(
      loaded.bundle,
      changes,
      date: clock(),
    );
    final sourceAfter = await _snapshot(
      loaded.rootPath,
      retainedTextPaths: loaded.documents.keys.toSet(),
    );
    if (!sourceBefore.sameContent(sourceAfter)) {
      throw const OkfStalePreparedChangeException();
    }

    final changedFiles = Map<String, String>.unmodifiable(overlay.files);
    final candidate = _candidate(
      loaded: loaded,
      source: sourceAfter,
      changedFiles: changedFiles,
    );
    final validation = loaded.validateCandidate(
      candidate.toBundle(),
      replacedPaths: changedFiles.keys,
    );
    if (!validation.isConformant) {
      return OkfPreparationRefused(validation: validation);
    }
    await _validateCandidatePaths(
      candidate,
      rootPath: loaded.rootPath,
      source: sourceAfter,
      changedPaths: changedFiles.keys,
    );

    return OkfPreparationReady._(
      OkfPreparedChange._(
        candidate: candidate,
        validation: validation,
        plan: _PreparedCommitPlan(
          rootPath: loaded.rootPath,
          source: sourceAfter.withoutText(),
          changedFiles: changedFiles,
        ),
      ),
    );
  }
}

Future<void> _validateCandidatePaths(
  OkfPreparedCandidate candidate, {
  required String rootPath,
  required _BundleSnapshot source,
  required Iterable<String> changedPaths,
}) async {
  final pathsByPortableKey = <String, String>{};
  for (final path in <String>[
    ...candidate.concepts.keys,
    ...candidate.indexes.keys,
    ...candidate.logs.keys,
    ...candidate.assets,
  ]) {
    final key = _portablePathKey(path);
    final existing = pathsByPortableKey[key];
    if (existing != null && existing != path) {
      throw OkfBundleChangeException(
        'Bundle paths $existing and $path collide on a case-insensitive '
        'filesystem.',
      );
    }
    pathsByPortableKey[key] = path;
  }

  for (final entry in pathsByPortableKey.entries) {
    var ancestor = p.posix.dirname(entry.key);
    while (ancestor != '.') {
      final occupyingPath = pathsByPortableKey[ancestor];
      if (occupyingPath != null) {
        throw OkfBundleChangeException(
          'Bundle path $occupyingPath cannot be both a file and an ancestor '
          'of ${entry.value}.',
        );
      }
      ancestor = p.posix.dirname(ancestor);
    }
  }

  final sourcePathsByPortableKey = <String, String>{
    for (final path in source.fingerprints.keys)
      if (!path.startsWith(_linkFingerprintPrefix))
        _portablePathKey(path): path,
  };
  final root = Directory(rootPath);
  for (final path in changedPaths) {
    final sourcePath = sourcePathsByPortableKey[_portablePathKey(path)];
    if (sourcePath != null && sourcePath != path) {
      throw OkfBundleChangeException(
        'Bundle paths $sourcePath and $path collide on a case-insensitive '
        'filesystem.',
      );
    }

    var current = root.path;
    final segments = p.posix.split(path);
    for (var index = 0; index < segments.length; index++) {
      current = p.join(current, segments[index]);
      final type = await FileSystemEntity.type(current, followLinks: false);
      final isDestination = index == segments.length - 1;
      if (type == FileSystemEntityType.link) {
        throw OkfBundleChangeException(
          'Bundle path $path would write through a symbolic link.',
        );
      }
      if (!isDestination && type == FileSystemEntityType.file) {
        throw OkfBundleChangeException(
          'Bundle path $path has a file where a directory is required.',
        );
      }
      if (isDestination && type == FileSystemEntityType.directory) {
        throw OkfBundleChangeException(
          'Bundle path $path has a directory where a file is required.',
        );
      }
    }
  }
}

OkfPreparedCandidate _candidate({
  required OkfBundleLoadResult loaded,
  required _BundleSnapshot source,
  required Map<String, String> changedFiles,
}) {
  String preparedText(String path, String fallback) =>
      changedFiles[path] ?? source.text(path) ?? fallback;

  return OkfPreparedCandidate._(
    concepts: <String, String>{
      for (final entry in loaded.documents.entries)
        entry.key: preparedText(entry.key, entry.value.serialize()),
      for (final entry in changedFiles.entries)
        if (_isConceptPath(entry.key)) entry.key: entry.value,
    },
    indexes: <String, String>{
      for (final entry in loaded.indexes.entries)
        entry.key: preparedText(entry.key, entry.value),
      for (final entry in changedFiles.entries)
        if (p.posix.basename(entry.key) == 'index.md') entry.key: entry.value,
    },
    logs: <String, String>{
      for (final entry in loaded.logs.entries)
        entry.key: preparedText(entry.key, entry.value),
      for (final entry in changedFiles.entries)
        if (p.posix.basename(entry.key) == 'log.md') entry.key: entry.value,
    },
    assets: loaded.assets.toSet(),
  );
}

/// An immutable view of the complete candidate prepared for a bundle write.
///
/// Concept values are the exact serialized Markdown bytes represented by the
/// candidate. [toBundle] returns a detached in-memory copy for downstream
/// inspection; changing that copy cannot change a prepared write.
final class OkfPreparedCandidate {
  OkfPreparedCandidate._({
    required Map<String, String> concepts,
    required Map<String, String> indexes,
    required Map<String, String> logs,
    required Set<String> assets,
  })  : concepts = Map<String, String>.unmodifiable(concepts),
        indexes = Map<String, String>.unmodifiable(indexes),
        logs = Map<String, String>.unmodifiable(logs),
        assets = Set<String>.unmodifiable(assets);

  final Map<String, String> concepts;
  final Map<String, String> indexes;
  final Map<String, String> logs;
  final Set<String> assets;

  OkfBundle toBundle() => OkfBundle.fromDocuments(
        <String, OkfDocument>{
          for (final entry in concepts.entries)
            entry.key: OkfDocument.parse(entry.value, sourcePath: entry.key),
        },
        indexes: indexes,
        logs: logs,
        assets: assets,
      );
}

/// Opaque proof that an exact candidate passed OKF Spec validation.
final class OkfPreparedChange {
  OkfPreparedChange._({
    required this.candidate,
    required this.validation,
    required _PreparedCommitPlan plan,
  }) : _plan = plan;

  final OkfPreparedCandidate candidate;
  final OkfSpecValidation validation;

  final _PreparedCommitPlan _plan;
  bool _committed = false;
}

sealed class OkfBundlePreparation {
  const OkfBundlePreparation._();
}

final class OkfPreparationRefused extends OkfBundlePreparation {
  const OkfPreparationRefused({required this.validation}) : super._();

  final OkfSpecValidation validation;
}

final class OkfPreparationReady extends OkfBundlePreparation {
  const OkfPreparationReady._(this.prepared) : super._();

  final OkfPreparedChange prepared;
}

final class OkfBundleCommitResult {
  OkfBundleCommitResult({required Iterable<String> changedPaths})
      : changedPaths = List<String>.unmodifiable(changedPaths);

  final List<String> changedPaths;
}

/// The result of serially preparing and applying one change set.
sealed class OkfBundleApplication {
  const OkfBundleApplication._();
}

/// A conformant candidate that was committed.
final class OkfBundleApplied extends OkfBundleApplication {
  /// Creates an applied result from the exact prepared commit.
  const OkfBundleApplied({required this.result}) : super._();

  /// The paths whose prepared bytes differed from the source bundle.
  final OkfBundleCommitResult result;
}

/// A candidate refused because it contains a Spec error.
final class OkfBundleApplicationRefused extends OkfBundleApplication {
  /// Creates a refusal carrying the closed Spec judgment.
  const OkfBundleApplicationRefused({required this.validation}) : super._();

  /// The non-conformant candidate's Spec judgment.
  final OkfSpecValidation validation;
}

final class OkfStalePreparedChangeException implements Exception {
  const OkfStalePreparedChangeException();

  @override
  String toString() =>
      'OkfStalePreparedChangeException: the source bundle changed after '
      'preparation';
}

final class _PreparedCommitPlan {
  _PreparedCommitPlan({
    required this.rootPath,
    required this.source,
    required Map<String, String> changedFiles,
  }) : changedFiles = Map<String, String>.unmodifiable(changedFiles);

  final String rootPath;
  final _BundleSnapshot source;
  final Map<String, String> changedFiles;
}

bool _isConceptPath(String path) =>
    path.endsWith('.md') &&
    p.posix.basename(path) != 'index.md' &&
    p.posix.basename(path) != 'log.md';

Future<_BundleSnapshot> _snapshot(
  String rootPath, {
  Set<String> retainedTextPaths = const <String>{},
}) async {
  final root = Directory(p.normalize(p.absolute(rootPath)));
  final rootType = await FileSystemEntity.type(root.path, followLinks: false);
  if (rootType == FileSystemEntityType.link) {
    throw FileSystemException(
      'Bundle root must not be a symbolic link',
      root.path,
    );
  }
  if (rootType != FileSystemEntityType.directory) {
    throw FileSystemException('Bundle root is not a directory', root.path);
  }

  final fingerprints = SplayTreeMap<String, String>();
  final retainedText = <String, List<int>>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final relative = p.posix.joinAll(
      p.split(p.relative(entity.path, from: root.path)),
    );
    if (p.posix.basename(relative) == okfBundleLockFileName) {
      continue;
    }
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      final file = File(entity.path);
      if (retainedTextPaths.contains(relative)) {
        final bytes = List<int>.unmodifiable(await file.readAsBytes());
        retainedText[relative] = bytes;
        fingerprints[relative] = sha256.convert(bytes).toString();
      } else {
        fingerprints[relative] =
            (await sha256.bind(file.openRead()).first).toString();
      }
    } else if (type == FileSystemEntityType.link) {
      fingerprints['$_linkFingerprintPrefix$relative'] = sha256
          .convert(utf8.encode(await Link(entity.path).target()))
          .toString();
    }
  }
  return _BundleSnapshot(
    rootPath: root.path,
    fingerprints: fingerprints,
    retainedText: retainedText,
  );
}

const String _linkFingerprintPrefix = '@link:';

String _portablePathKey(String path) => unorm.nfd(
      unorm.nfd(path).runes.map(_caseFoldRune).join(),
    );

String _caseFoldRune(int rune) =>
    _caseFoldMappings[rune] ?? String.fromCharCode(rune);

final class _BundleSnapshot {
  _BundleSnapshot({
    required this.rootPath,
    required Map<String, String> fingerprints,
    required Map<String, List<int>> retainedText,
  })  : fingerprints = Map<String, String>.unmodifiable(fingerprints),
        retainedText = Map<String, List<int>>.unmodifiable(retainedText);

  final String rootPath;
  final Map<String, String> fingerprints;
  final Map<String, List<int>> retainedText;

  String? text(String path) {
    final bytes = retainedText[path];
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: false);
  }

  _BundleSnapshot withoutText() => _BundleSnapshot(
        rootPath: rootPath,
        fingerprints: fingerprints,
        retainedText: const <String, List<int>>{},
      );

  bool sameContent(_BundleSnapshot other) {
    if (fingerprints.length != other.fingerprints.length) {
      return false;
    }
    for (final entry in fingerprints.entries) {
      if (other.fingerprints[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
