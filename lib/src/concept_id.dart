import 'package:path/path.dart' as p;

import 'bundle_path.dart';

/// The bundle-relative path of an OKF concept, without the `.md` suffix.
///
/// Concept IDs use POSIX separators on every platform. They may contain safe
/// Unicode; producers can use [isPortableAscii] when they need compatibility
/// with tooling that implements the narrower ASCII convention.
final class OkfConceptId implements Comparable<OkfConceptId> {
  /// Creates an ID from a bundle-relative path without a `.md` suffix.
  factory OkfConceptId(String value) {
    final validated = _validate(value, documentPath: false);
    return OkfConceptId._(validated);
  }

  const OkfConceptId._(this.value);

  /// Creates an ID from a bundle-relative concept document path.
  factory OkfConceptId.fromDocumentPath(String path) {
    final validatedPath = _validate(path, documentPath: true);
    if (!validatedPath.endsWith('.md')) {
      throw FormatException('Concept document paths must end in .md', path);
    }

    final basename = p.posix.basename(validatedPath);
    if (basename == 'index.md' || basename == 'log.md') {
      throw FormatException(
        'Reserved OKF documents do not have concept IDs',
        path,
      );
    }

    return OkfConceptId(validatedPath.substring(0, validatedPath.length - 3));
  }

  /// The validated bundle-relative ID, retained without normalization.
  final String value;

  /// Path segments making up this ID.
  List<String> get segments => List<String>.unmodifiable(value.split('/'));

  /// The final path segment.
  String get basename => p.posix.basename(value);

  /// The parent directory, or the empty string for a root concept.
  String get directory {
    final result = p.posix.dirname(value);
    return result == '.' ? '' : result;
  }

  /// Whether every segment follows the portable ASCII producer convention.
  bool get isPortableAscii => segments.every(_portableAsciiSegment.hasMatch);

  /// The concept's bundle-relative Markdown path.
  String get documentPath => '$value.md';

  @override
  int compareTo(OkfConceptId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OkfConceptId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  static final RegExp _portableAsciiSegment = RegExp(
    r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$',
  );

  static String _validate(String value, {required bool documentPath}) {
    validateBundlePath(value);
    if (!documentPath && value.endsWith('.md')) {
      throw FormatException(
        'A concept ID must not include the .md suffix',
        value,
      );
    }
    return value;
  }
}
