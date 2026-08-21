import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bundle.dart';
import '../bundle_path.dart';
import '../document.dart';
import '../finding.dart';
import '../spec_rules/load_findings.dart';
import '../validator.dart';

/// The result of inspecting an OKF bundle directory.
///
/// [bundle] contains every entry that could be read successfully. Path,
/// UTF-8, and document parse failures are retained in [report], so one
/// invocation can report every malformed file; [validate] merges them with
/// the validator's findings into the complete Report.
final class OkfBundleLoadResult {
  OkfBundleLoadResult({
    required this.rootPath,
    required this.bundle,
    required Map<String, OkfDocument> documents,
    required Map<String, String> indexes,
    required Map<String, String> logs,
    required Iterable<String> assets,
    required this.report,
  })  : documents = UnmodifiableMapView<String, OkfDocument>(Map.of(documents)),
        indexes = UnmodifiableMapView<String, String>(Map.of(indexes)),
        logs = UnmodifiableMapView<String, String>(Map.of(logs)),
        assets = List<String>.unmodifiable(assets);

  /// The normalized, absolute bundle root.
  final String rootPath;

  /// The successfully loaded portion of the bundle.
  final OkfBundle bundle;

  /// Concept documents keyed by sorted POSIX-style relative path.
  final Map<String, OkfDocument> documents;

  /// Reserved `index.md` files keyed by relative path.
  final Map<String, String> indexes;

  /// Reserved `log.md` files keyed by relative path.
  final Map<String, String> logs;

  /// Non-Markdown files found under the bundle root.
  final List<String> assets;

  /// Load-time findings only — files that could not be read as part of
  /// the bundle — in canonical Report order.
  ///
  /// This is not the bundle's complete Report; see [validate].
  final OkfReport report;

  /// Every regular file path in the inventory, in deterministic order.
  List<String> get paths {
    final result = <String>{
      ...documents.keys,
      ...indexes.keys,
      ...logs.keys,
      ...assets,
      ...report.findings.map((finding) => finding.location?.path).nonNulls,
    }.toList()
      ..sort();
    return List<String>.unmodifiable(result);
  }

  /// Whether any file failed to load, so [bundle] is partial.
  bool get hasFindings => report.findings.isNotEmpty;

  /// Validates the loaded bundle and merges load findings into one Report.
  ///
  /// This is the complete Report for the bundle — the projection every
  /// adapter surfaces — in the canonical Report order.
  OkfSpecValidation validate() {
    final validation = const OkfSpecValidator().validate(bundle);
    return OkfSpecValidation(
      OkfReport(
        findings: <OkfFinding>[
          ...report.findings,
          ...validation.report.findings,
        ],
      ),
    );
  }
}

/// Thrown by [OkfBundleLoader.load] when inspection finds malformed files.
final class OkfBundleLoadException implements Exception {
  const OkfBundleLoadException(this.result);

  /// The partial bundle and all discovered failures.
  final OkfBundleLoadResult result;

  @override
  String toString() =>
      'Could not load OKF bundle: ${result.report.findings.length} '
      'file(s) failed';
}

/// Loads OKF bundles from an explicitly supplied filesystem root.
///
/// Traversal is deterministic and never follows symbolic links. The root
/// itself must be a real directory rather than a link. These checks assume the
/// bundle is not being concurrently replaced by an adversarial process.
final class OkfBundleLoader {
  /// Creates a bundle loader.
  const OkfBundleLoader();

  /// Loads a complete bundle.
  ///
  /// Throws [OkfBundleLoadException] after scanning the entire tree when one
  /// or more Markdown concepts could not be decoded or parsed. Use [inspect]
  /// to consume the successfully loaded portion alongside those findings.
  Future<OkfBundle> load(String rootPath) async {
    final result = await inspect(rootPath);
    if (result.hasFindings) {
      throw OkfBundleLoadException(result);
    }
    return result.bundle;
  }

  /// Inventories and parses the bundle rooted at [rootPath].
  Future<OkfBundleLoadResult> inspect(String rootPath) async {
    final root = await _validatedRoot(rootPath);
    final entities = <_BundleEntry>[];

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.file) {
        continue;
      }

      final relativePath = _relativePath(root.path, entity.path);
      entities.add(_BundleEntry(relativePath, File(entity.path)));
    }
    entities.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );

    final documents = <String, OkfDocument>{};
    final indexes = <String, String>{};
    final logs = <String, String>{};
    final assets = <String>[];
    final findings = <OkfFinding>[];

    for (final entry in entities) {
      try {
        validateBundlePath(entry.relativePath);
      } on FormatException catch (error) {
        findings.add(
          invalidPathFinding.finding(
            message: error.message,
            location: OkfFindingLocation(path: entry.relativePath),
          ),
        );
        continue;
      }

      if (!entry.relativePath.endsWith('.md')) {
        assets.add(entry.relativePath);
        continue;
      }

      final source = decodeMarkdown(
        await entry.file.readAsBytes(),
        entry.relativePath,
        findings,
      );
      if (source == null) {
        continue;
      }

      final basename = p.posix.basename(entry.relativePath);
      if (basename == 'index.md') {
        indexes[entry.relativePath] = source;
        continue;
      }
      if (basename == 'log.md') {
        logs[entry.relativePath] = source;
        continue;
      }

      final document = parseMarkdown(source, entry.relativePath, findings);
      if (document != null) {
        documents[entry.relativePath] = document;
      }
    }

    final bundle = OkfBundle.fromDocuments(
      documents,
      indexes: indexes,
      logs: logs,
      assets: assets,
    );
    return OkfBundleLoadResult(
      rootPath: root.path,
      bundle: bundle,
      documents: documents,
      indexes: indexes,
      logs: logs,
      assets: assets,
      report: OkfReport(findings: findings),
    );
  }

  Future<Directory> _validatedRoot(String rootPath) async {
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
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Bundle root is not a directory',
        root.path,
      );
    }
    return root;
  }
}

final class _BundleEntry {
  const _BundleEntry(this.relativePath, this.file);

  final String relativePath;
  final File file;
}

String _relativePath(String rootPath, String entityPath) {
  final relative = p.relative(entityPath, from: rootPath);
  final segments = p.split(relative);
  if (relative == '.' ||
      p.isAbsolute(relative) ||
      segments.isEmpty ||
      segments.any((segment) => segment == '..')) {
    throw FileSystemException(
      'Bundle entry escapes the bundle root',
      entityPath,
    );
  }
  return p.posix.joinAll(segments);
}
