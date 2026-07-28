import 'package:path/path.dart' as p;

/// The bundle-relative path of an OKF concept, without the `.md` suffix.
///
/// Concept IDs use POSIX separators on every platform. They may contain safe
/// Unicode; producers can use [isPortableAscii] when they need compatibility
/// with tooling that implements the narrower ASCII convention.
final class OkfConceptId implements Comparable<OkfConceptId> {
  /// Creates an ID from a bundle-relative path without a `.md` suffix.
  factory OkfConceptId(String value) {
    final normalized = _validateAndNormalize(value);
    return OkfConceptId._(normalized);
  }

  const OkfConceptId._(this.value);

  /// Creates an ID from a bundle-relative concept document path.
  factory OkfConceptId.fromDocumentPath(String path) {
    final normalizedPath = _normalizeDocumentPath(path);
    if (!normalizedPath.endsWith('.md')) {
      throw FormatException('Concept document paths must end in .md', path);
    }

    final basename = p.posix.basename(normalizedPath);
    if (basename == 'index.md' || basename == 'log.md') {
      throw FormatException(
        'Reserved OKF documents do not have concept IDs',
        path,
      );
    }

    return OkfConceptId(
      normalizedPath.substring(0, normalizedPath.length - 3),
    );
  }

  /// The normalized bundle-relative ID.
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

  static String _normalizeDocumentPath(String value) {
    if (value.isEmpty) {
      throw FormatException('A concept document path cannot be empty', value);
    }
    if (value.startsWith('/') || p.posix.isAbsolute(value)) {
      throw FormatException(
        'A concept document path must be bundle-relative',
        value,
      );
    }
    if (value.contains(r'\')) {
      throw FormatException('Concept paths must use / separators', value);
    }

    final segments = value.split('/');
    _validateSegments(segments, value);
    return segments.join('/');
  }

  static String _validateAndNormalize(String value) {
    if (value.isEmpty) {
      throw FormatException('A concept ID cannot be empty', value);
    }
    if (value.startsWith('/') || p.posix.isAbsolute(value)) {
      throw FormatException('A concept ID must be bundle-relative', value);
    }
    if (value.contains(r'\')) {
      throw FormatException('Concept IDs must use / separators', value);
    }
    if (value.endsWith('.md')) {
      throw FormatException(
        'A concept ID must not include the .md suffix',
        value,
      );
    }

    final segments = value.split('/');
    _validateSegments(segments, value);
    return segments.join('/');
  }

  static void _validateSegments(List<String> segments, String source) {
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        throw FormatException(
          'Concept paths cannot contain empty, . or .. segments',
          source,
        );
      }
      if (segment.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
        throw FormatException(
          'Concept paths cannot contain control characters',
          source,
        );
      }
    }
  }
}
