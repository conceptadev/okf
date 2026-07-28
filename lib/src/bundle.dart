import 'dart:collection';

import 'package:path/path.dart' as p;

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
          'Duplicate normalized concept path',
        );
      }
      concepts[id] = entry.value;
    }

    final normalizedIndexes = _normalizeReservedFiles(indexes, 'index.md');
    final normalizedLogs = _normalizeReservedFiles(logs, 'log.md');
    final normalizedAssets = SplayTreeSet<String>();
    for (final path in assets) {
      final normalized = _normalizeBundlePath(path);
      if (_isReservedMarkdownPath(normalized) || normalized.endsWith('.md')) {
        throw ArgumentError.value(
          path,
          'assets',
          'Markdown files must be supplied as documents, indexes, or logs',
        );
      }
      normalizedAssets.add(normalized);
    }

    final occupied = <String>{};
    for (final id in concepts.keys) {
      occupied.add(id.documentPath);
    }
    for (final path in <String>[
      ...normalizedIndexes.keys,
      ...normalizedLogs.keys,
      ...normalizedAssets,
    ]) {
      if (!occupied.add(path)) {
        throw ArgumentError.value(path, 'path', 'Duplicate bundle path');
      }
    }

    return OkfBundle._(
      concepts: SplayTreeMap<OkfConceptId, OkfDocument>.of(concepts),
      indexFiles: normalizedIndexes,
      logFiles: normalizedLogs,
      assetPaths: normalizedAssets,
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
      return allPaths.contains(_normalizeBundlePath(path));
    } on FormatException {
      return false;
    }
  }

  static SplayTreeMap<String, String> _normalizeReservedFiles(
    Map<String, String> files,
    String expectedName,
  ) {
    final result = SplayTreeMap<String, String>();
    for (final entry in files.entries) {
      final normalized = _normalizeBundlePath(entry.key);
      if (p.posix.basename(normalized) != expectedName) {
        throw ArgumentError.value(
          entry.key,
          expectedName == 'index.md' ? 'indexes' : 'logs',
          'Expected a path ending in $expectedName',
        );
      }
      if (result.containsKey(normalized)) {
        throw ArgumentError.value(
          entry.key,
          'files',
          'Duplicate normalized reserved path',
        );
      }
      result[normalized] = entry.value;
    }
    return result;
  }

  static bool _isReservedMarkdownPath(String path) {
    final basename = p.posix.basename(path);
    return basename == 'index.md' || basename == 'log.md';
  }

  static String _normalizeBundlePath(String value) {
    if (value.isEmpty || value.startsWith('/') || value.contains(r'\')) {
      throw FormatException(
        'Bundle paths must be non-empty, relative POSIX paths',
        value,
      );
    }
    final segments = value.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw FormatException(
        'Bundle paths cannot contain empty, . or .. segments',
        value,
      );
    }
    if (segments.any(
      (segment) => segment.runes.any((rune) => rune < 0x20 || rune == 0x7f),
    )) {
      throw FormatException(
        'Bundle paths cannot contain control characters',
        value,
      );
    }
    return segments.join('/');
  }
}
