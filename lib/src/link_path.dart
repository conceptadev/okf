/// Percent-encodes one path segment for a Markdown link target.
///
/// Dots stay literal so relative segments such as `..` and file extensions
/// remain readable in generated indexes, logs, and concept links.
String encodeOkfLinkSegment(String value) =>
    Uri.encodeComponent(value).replaceAll('%2E', '.');

/// Percent-encodes every segment of a POSIX path for a Markdown link target.
String encodeOkfLinkPath(String path) =>
    path.split('/').map(encodeOkfLinkSegment).join('/');

/// Escapes a generated concept-link [value] as literal single-line text.
String escapeOkfConceptLinkLabel(String value) =>
    value.trim().replaceAll(_whitespaceRun, ' ').replaceAllMapped(
          _markdownPunctuation,
          (match) => '\\${match.group(0)}',
        );

final RegExp _whitespaceRun = RegExp(r'\s+');
final RegExp _markdownPunctuation = RegExp(
  r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''',
);
