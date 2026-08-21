import '../document.dart';
import '../finding.dart';
import '../spec_rule.dart';
import 'context.dart';

final class OkfSpecFindingDefinition {
  const OkfSpecFindingDefinition(this.descriptor);

  final OkfSpecRuleDescriptor descriptor;

  OkfFinding finding({
    required String message,
    OkfFindingLocation? location,
  }) =>
      OkfFinding(
        id: descriptor.id,
        severity: descriptor.defaultSeverity,
        message: message,
        location: location,
      );
}

final class OkfSpecRule {
  const OkfSpecRule({required this.definition, required this.run});

  final OkfSpecFindingDefinition definition;
  final Iterable<OkfFinding> Function(SpecValidationContext context) run;

  OkfSpecRuleDescriptor get descriptor => definition.descriptor;
}

typedef SpecRuleRun = Iterable<OkfFinding> Function(
  OkfSpecFindingDefinition definition,
  SpecValidationContext context,
);

OkfSpecFindingDefinition specFindingDefinition({
  required String code,
  required String prose,
  required OkfFindingSeverity severity,
  String specReference = 'OKF 0.2',
}) =>
    OkfSpecFindingDefinition(
      OkfSpecRuleDescriptor(
        id: OkfFindingId.okf(code),
        prose: prose,
        defaultSeverity: severity,
        specReference: specReference,
      ),
    );

OkfSpecRule specRule({
  required String code,
  required String prose,
  required OkfFindingSeverity severity,
  required SpecRuleRun run,
  String specReference = 'OKF 0.2',
}) {
  final definition = specFindingDefinition(
    code: code,
    prose: prose,
    severity: severity,
    specReference: specReference,
  );
  return OkfSpecRule(
    definition: definition,
    run: (context) => run(definition, context),
  );
}

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

/// Parses a strict `YYYY-MM-DD` date, rejecting non-canonical spellings.
DateTime? parseIsoDate(String? value) {
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null) {
    return null;
  }
  final canonical = '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return canonical == value ? parsed : null;
}
