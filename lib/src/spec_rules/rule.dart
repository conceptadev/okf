import '../bundle.dart';
import '../document.dart';
import '../finding.dart';
import '../index_log.dart';

/// Creates findings using the fixed metadata of a Spec rule.
///
/// This extension is internal; the public descriptor stays read-only metadata.
extension SpecRuleFindings on OkfSpecRuleDescriptor {
  OkfFinding finding({required String message, OkfFindingLocation? location}) =>
      OkfFinding(
        id: id,
        severity: defaultSeverity,
        message: message,
        location: location,
      );
}

final class OkfSpecRule {
  OkfSpecRule({
    required String code,
    required String prose,
    required OkfFindingSeverity severity,
    required SpecRuleRun run,
    String specReference = 'OKF 0.2',
  }) : descriptor = OkfSpecRuleDescriptor(
         id: OkfFindingId.okf(code),
         prose: prose,
         defaultSeverity: severity,
         specReference: specReference,
       ),
       _run = run;

  final OkfSpecRuleDescriptor descriptor;
  final SpecRuleRun _run;

  Iterable<OkfFinding> run(SpecValidationContext context) =>
      _run(descriptor, context);
}

typedef SpecRuleRun =
    Iterable<OkfFinding> Function(
      OkfSpecRuleDescriptor descriptor,
      SpecValidationContext context,
    );

/// Locates a parse failure at [path], keeping the line and column when the
/// document parser supplied them.
OkfFindingLocation parseFailureLocation(String path, FormatException error) =>
    OkfFindingLocation(
      path: path,
      line: error is OkfDocumentException ? error.line : null,
      column: error is OkfDocumentException ? error.column : null,
    );

/// Whether [value] is a string with visible content.
bool isNonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

/// Parsed views shared by fixed OKF Spec rules during one validation pass.
final class SpecValidationContext {
  factory SpecValidationContext(OkfBundle bundle) {
    final invalidDocuments = <InvalidReservedDocument>[];
    return SpecValidationContext._(
      bundle: bundle,
      indexDocuments: _parseReservedDocuments(
        bundle.indexFiles,
        invalidDocuments,
        (path, document) => ParsedIndexDocument(
          path: path,
          document: document,
          content: OkfIndexDocument.parseBody(document.body),
        ),
      ),
      logDocuments: _parseReservedDocuments(
        bundle.logFiles,
        invalidDocuments,
        (path, document) => ParsedLogDocument(
          path: path,
          document: document,
          content: OkfLogDocument.parseBody(document.body),
        ),
      ),
      invalidDocuments: invalidDocuments,
    );
  }

  SpecValidationContext._({
    required this.bundle,
    required List<ParsedIndexDocument> indexDocuments,
    required List<ParsedLogDocument> logDocuments,
    required List<InvalidReservedDocument> invalidDocuments,
  }) : indexDocuments = List<ParsedIndexDocument>.unmodifiable(indexDocuments),
       logDocuments = List<ParsedLogDocument>.unmodifiable(logDocuments),
       invalidDocuments = List<InvalidReservedDocument>.unmodifiable(
         invalidDocuments,
       );

  final OkfBundle bundle;
  final List<ParsedIndexDocument> indexDocuments;
  final List<ParsedLogDocument> logDocuments;
  final List<InvalidReservedDocument> invalidDocuments;
}

sealed class ParsedReservedDocument {
  const ParsedReservedDocument({required this.path, required this.document});

  final String path;
  final OkfDocument document;
}

final class ParsedIndexDocument extends ParsedReservedDocument {
  const ParsedIndexDocument({
    required super.path,
    required super.document,
    required this.content,
  });

  final OkfIndexParseResult content;
}

final class ParsedLogDocument extends ParsedReservedDocument {
  const ParsedLogDocument({
    required super.path,
    required super.document,
    required this.content,
  });

  final OkfLogParseResult content;
}

final class InvalidReservedDocument {
  const InvalidReservedDocument({required this.path, required this.error});

  final String path;
  final FormatException error;
}

List<T> _parseReservedDocuments<T extends ParsedReservedDocument>(
  Map<String, String> files,
  List<InvalidReservedDocument> invalidDocuments,
  T Function(String path, OkfDocument document) convert,
) {
  final parsedDocuments = <T>[];
  for (final MapEntry(key: path, value: source) in files.entries) {
    try {
      parsedDocuments.add(
        convert(path, OkfDocument.parse(source, sourcePath: path)),
      );
    } on FormatException catch (error) {
      invalidDocuments.add(InvalidReservedDocument(path: path, error: error));
    }
  }
  return parsedDocuments;
}
