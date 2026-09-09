/// Characters a plain Markdown link destination cannot carry.
///
/// The index entry writer rejects them, the index parser flags them, and
/// [encodeOkfLinkSegment] encodes them; graph resolution decodes through
/// [decodeOkfLinkSegment]. One definition keeps those seams in agreement.
final RegExp okfLinkDestinationUnsafe = RegExp(r'[()<>\s]');

/// Percent-encodes one path segment for a Markdown link target.
///
/// `Uri.encodeComponent` already leaves dots literal, so relative segments
/// such as `..` and file extensions stay readable. Parentheses are encoded
/// on top of it because it keeps them raw, while a raw `)` ends a Markdown
/// destination early ([okfLinkDestinationUnsafe]).
String encodeOkfLinkSegment(String value) =>
    Uri.encodeComponent(value).replaceAll('(', '%28').replaceAll(')', '%29');

/// Percent-encodes every segment of a POSIX path for a Markdown link target.
String encodeOkfLinkPath(String path) =>
    path.split('/').map(encodeOkfLinkSegment).join('/');

/// Percent-decodes one link path segment, or returns null when malformed.
///
/// Decoding is the identity for a segment with no `%`, so such a segment is
/// never handed to `Uri.decodeComponent` — which would reject raw non-ASCII
/// (an em dash in a real reference filename) as a broken escape. A decode
/// failure therefore always means a genuinely malformed percent sequence.
String? decodeOkfLinkSegment(String segment) {
  if (!segment.contains('%')) {
    return segment;
  }
  try {
    return Uri.decodeComponent(segment);
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}

/// Escapes a generated concept-link [value] as literal single-line text.
String escapeOkfConceptLinkLabel(String value) => value
    .trim()
    .replaceAll(_whitespaceRun, ' ')
    .replaceAllMapped(_markdownPunctuation, (match) => '\\${match.group(0)}');

final RegExp _whitespaceRun = RegExp(r'\s+');
final RegExp _markdownPunctuation = RegExp(
  r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''',
);
