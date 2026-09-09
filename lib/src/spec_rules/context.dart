import '../bundle.dart';
import '../document.dart';
import '../index_log.dart';

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
