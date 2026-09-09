import 'dart:convert';

import '../document.dart';
import '../finding.dart';
import 'rule.dart';

/// A parsed [OkfBundle] cannot contain the failures these definitions describe
/// —
/// unreadable UTF-8, malformed documents, or invalid paths never survive into
/// a bundle. Loading code therefore mints them directly instead of pretending
/// they are executable bundle rules.
final List<OkfSpecFindingDefinition> loadFindingDefinitions =
    List<OkfSpecFindingDefinition>.unmodifiable(<OkfSpecFindingDefinition>[
      invalidDocumentFinding,
      invalidPathFinding,
      invalidUtf8Finding,
    ]);

/// `okf/invalid-document`: a Markdown document whose frontmatter or body
/// could not be parsed.
final OkfSpecFindingDefinition invalidDocumentFinding = specFindingDefinition(
  code: 'invalid-document',
  prose: 'Markdown documents must parse, with well-formed YAML frontmatter.',
  severity: OkfFindingSeverity.error,
);

/// `okf/invalid-path`: a bundle entry whose relative path is not portable.
final OkfSpecFindingDefinition invalidPathFinding = specFindingDefinition(
  code: 'invalid-path',
  prose: 'Bundle entries must use valid relative POSIX paths.',
  severity: OkfFindingSeverity.error,
);

/// `okf/invalid-utf8`: a Markdown file that is not valid UTF-8.
final OkfSpecFindingDefinition invalidUtf8Finding = specFindingDefinition(
  code: 'invalid-utf8',
  prose: 'Markdown documents must contain valid UTF-8.',
  severity: OkfFindingSeverity.error,
);

/// Decodes [bytes] as strict UTF-8.
///
/// On failure, appends the [invalidUtf8Finding] finding for [path] to
/// [findings] and returns null.
String? decodeMarkdown(
  List<int> bytes,
  String path,
  List<OkfFinding> findings,
) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException catch (error) {
    findings.add(
      invalidUtf8Finding.finding(
        message: error.message,
        location: OkfFindingLocation(path: path),
      ),
    );
    return null;
  }
}

/// Parses [source] as an OKF document.
///
/// On failure, appends the [invalidDocumentFinding] finding for [path] to
/// [findings] and returns null.
OkfDocument? parseMarkdown(
  String source,
  String path,
  List<OkfFinding> findings,
) {
  try {
    return OkfDocument.parse(source, sourcePath: path);
  } on FormatException catch (error) {
    findings.add(
      invalidDocumentFinding.finding(
        message: error.message,
        location: parseFailureLocation(path, error),
      ),
    );
    return null;
  }
}
