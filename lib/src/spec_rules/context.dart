import '../bundle.dart';
import '../document.dart';

/// Parsed views shared by fixed OKF Spec rules during one validation pass.
final class SpecValidationContext {
  factory SpecValidationContext(OkfBundle bundle) {
    final invalidDocuments = <InvalidReservedDocument>[];
    return SpecValidationContext._(
      bundle: bundle,
      indexDocuments: _parseReservedDocuments(
        bundle.indexFiles,
        invalidDocuments,
      ),
      logDocuments: _parseReservedDocuments(
        bundle.logFiles,
        invalidDocuments,
      ),
      invalidDocuments: invalidDocuments,
    );
  }

  SpecValidationContext._({
    required this.bundle,
    required List<ParsedReservedDocument> indexDocuments,
    required List<ParsedReservedDocument> logDocuments,
    required List<InvalidReservedDocument> invalidDocuments,
  })  : indexDocuments = List<ParsedReservedDocument>.unmodifiable(
          indexDocuments,
        ),
        logDocuments = List<ParsedReservedDocument>.unmodifiable(logDocuments),
        invalidDocuments = List<InvalidReservedDocument>.unmodifiable(
          invalidDocuments,
        );

  final OkfBundle bundle;
  final List<ParsedReservedDocument> indexDocuments;
  final List<ParsedReservedDocument> logDocuments;
  final List<InvalidReservedDocument> invalidDocuments;
}

final class ParsedReservedDocument {
  ParsedReservedDocument({required this.path, required this.document})
      : bodyLines = List<String>.unmodifiable(
          document.body
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        );

  final String path;
  final OkfDocument document;
  final List<String> bodyLines;

  Iterable<String> get logBody => bodyLines.skip(1);
}

final class InvalidReservedDocument {
  const InvalidReservedDocument({required this.path, required this.error});

  final String path;
  final FormatException error;
}

List<ParsedReservedDocument> _parseReservedDocuments(
  Map<String, String> files,
  List<InvalidReservedDocument> invalidDocuments,
) {
  final parsedDocuments = <ParsedReservedDocument>[];
  for (final MapEntry(key: path, value: source) in files.entries) {
    try {
      parsedDocuments.add(
        ParsedReservedDocument(
          path: path,
          document: OkfDocument.parse(source, sourcePath: path),
        ),
      );
    } on FormatException catch (error) {
      invalidDocuments.add(InvalidReservedDocument(path: path, error: error));
    }
  }
  return parsedDocuments;
}
