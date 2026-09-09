import 'dart:convert';

import '../document.dart';
import '../finding.dart';
import 'rule.dart';

/// A parsed [OkfBundle] cannot contain the failures these definitions describe
/// —
/// unreadable UTF-8, malformed documents, or invalid paths never survive into
/// a bundle. Loading code therefore mints them directly instead of pretending
/// they are executable bundle rules.
final List<OkfSpecRuleDescriptor> loadFindingDescriptors =
    List<OkfSpecRuleDescriptor>.unmodifiable(<OkfSpecRuleDescriptor>[
      invalidDocumentFinding,
      invalidPathFinding,
      invalidUtf8Finding,
    ]);

/// `okf/invalid-document`: a Markdown document whose frontmatter or body
/// could not be parsed.
final OkfSpecRuleDescriptor invalidDocumentFinding = OkfSpecRuleDescriptor(
  id: OkfFindingId.okf('invalid-document'),
  prose: 'Markdown documents must parse, with well-formed YAML frontmatter.',
  defaultSeverity: OkfFindingSeverity.error,
  specReference: 'OKF 0.2',
);

/// `okf/invalid-path`: a bundle entry whose relative path is not portable.
final OkfSpecRuleDescriptor invalidPathFinding = OkfSpecRuleDescriptor(
  id: OkfFindingId.okf('invalid-path'),
  prose: 'Bundle entries must use valid relative POSIX paths.',
  defaultSeverity: OkfFindingSeverity.error,
  specReference: 'OKF 0.2',
);

/// `okf/invalid-utf8`: a Markdown file that is not valid UTF-8.
final OkfSpecRuleDescriptor invalidUtf8Finding = OkfSpecRuleDescriptor(
  id: OkfFindingId.okf('invalid-utf8'),
  prose: 'Markdown documents must contain valid UTF-8.',
  defaultSeverity: OkfFindingSeverity.error,
  specReference: 'OKF 0.2',
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
