import 'dart:collection';

import 'package:path/path.dart' as p;

import 'bundle_path.dart';
import 'concept_id.dart';
import 'document.dart';

/// A platform-independent, in-memory OKF knowledge bundle.
final class OkfBundle {
  OkfBundle._({
    required Map<OkfConceptId, OkfDocument> concepts,
    required Map<String, String> indexFiles,
    required Map<String, String> logFiles,
    required Set<String> assetPaths,
  })  : concepts = UnmodifiableMapView(concepts),
        indexFiles = UnmodifiableMapView(indexFiles),
        logFiles = UnmodifiableMapView(logFiles),
        assetPaths = UnmodifiableSetView(assetPaths);

  /// Builds a bundle from POSIX, bundle-relative document paths.
  ///
  /// [documents] contains concept documents only. Reserved files are supplied
  /// as their original text through [indexes] and [logs].
  factory OkfBundle.fromDocuments(
    Map<String, OkfDocument> documents, {
    Map<String, String> indexes = const <String, String>{},
    Map<String, String> logs = const <String, String>{},
    Iterable<String> assets = const <String>[],
  }) {
    final concepts = <OkfConceptId, OkfDocument>{};
    final sortedDocuments = documents.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in sortedDocuments) {
      final id = OkfConceptId.fromDocumentPath(entry.key);
      if (concepts.containsKey(id)) {
        throw ArgumentError.value(
          entry.key,
          'documents',
          'Duplicate concept path',
        );
      }
      concepts[id] = entry.value;
    }

    final validatedIndexes = _validateReservedFiles(indexes, 'index.md');
    final validatedLogs = _validateReservedFiles(logs, 'log.md');
    final validatedAssets = SplayTreeSet<String>();
    for (final path in assets) {
      final validated = validateBundlePath(path);
      // `index.md` and `log.md` are covered by the suffix: every reserved
      // name ends in `.md`.
      if (validated.endsWith('.md')) {
        throw ArgumentError.value(
          path,
          'assets',
          'Markdown files must be supplied as documents, indexes, or logs',
        );
      }
      validatedAssets.add(validated);
    }

    final occupied = <String>{};
    for (final id in concepts.keys) {
      occupied.add(id.documentPath);
    }
    for (final path in <String>[
      ...validatedIndexes.keys,
      ...validatedLogs.keys,
      ...validatedAssets,
    ]) {
      if (!occupied.add(path)) {
        throw ArgumentError.value(path, 'path', 'Duplicate bundle path');
      }
    }

    return OkfBundle._(
      concepts: SplayTreeMap<OkfConceptId, OkfDocument>.of(concepts),
      indexFiles: validatedIndexes,
      logFiles: validatedLogs,
      assetPaths: validatedAssets,
    );
  }

  /// Concept documents keyed by their logical ID.
  final Map<OkfConceptId, OkfDocument> concepts;

  /// Raw reserved index documents keyed by bundle-relative path.
  final Map<String, String> indexFiles;

  /// Raw reserved log documents keyed by bundle-relative path.
  final Map<String, String> logFiles;

  /// Non-Markdown files known to be present in the bundle.
  final Set<String> assetPaths;

  /// Every known bundle-relative file path, in deterministic order.
  late final Set<String> allPaths = UnmodifiableSetView<String>(
    SplayTreeSet<String>.of(<String>{
      for (final id in concepts.keys) id.documentPath,
      ...indexFiles.keys,
      ...logFiles.keys,
      ...assetPaths,
    }),
  );

  /// Finds a concept by ID.
  OkfDocument? concept(OkfConceptId id) => concepts[id];

  /// Finds a concept by its bundle-relative Markdown path.
  OkfDocument? conceptAtPath(String path) {
    try {
      return concepts[OkfConceptId.fromDocumentPath(path)];
    } on FormatException {
      return null;
    }
  }

  /// Whether a bundle-relative file path is present in the inventory.
  bool containsPath(String path) {
    try {
      return allPaths.contains(validateBundlePath(path));
    } on FormatException {
      return false;
    }
  }

  static SplayTreeMap<String, String> _validateReservedFiles(
    Map<String, String> files,
    String expectedName,
  ) {
    final result = SplayTreeMap<String, String>();
    for (final entry in files.entries) {
      final validated = validateBundlePath(entry.key);
      if (p.posix.basename(validated) != expectedName) {
        throw ArgumentError.value(
          entry.key,
          expectedName == 'index.md' ? 'indexes' : 'logs',
          'Expected a path ending in $expectedName',
        );
      }
      if (result.containsKey(validated)) {
        throw ArgumentError.value(
          entry.key,
          'files',
          'Duplicate reserved path',
        );
      }
      result[validated] = entry.value;
    }
    return result;
  }
}
