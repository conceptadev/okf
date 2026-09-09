import 'bundle.dart';
import 'finding.dart';
import 'spec_rules/concept_rules.dart';
import 'spec_rules/load_findings.dart';
import 'spec_rules/reserved_rules.dart';
import 'spec_rules/rule.dart';

final List<OkfSpecRule> _validationRules = List<OkfSpecRule>.unmodifiable(
  <OkfSpecRule>[...conceptRules, ...reservedRules],
);

/// Read-only metadata for the complete fixed OKF Spec finding set.
final List<OkfSpecRuleDescriptor> okfSpecRuleDescriptors =
    List<OkfSpecRuleDescriptor>.unmodifiable(<OkfSpecRuleDescriptor>[
      ...loadFindingDescriptors,
      ..._validationRules.map((rule) => rule.descriptor),
    ]);

/// Checks the pinned OKF v0.2 requirements with a fixed internal rule set.
final class OkfSpecValidator {
  /// Creates the closed validator. It accepts no caller configuration.
  const OkfSpecValidator();

  /// Validates [bundle] without mutating it.
  OkfSpecValidation validate(OkfBundle bundle) {
    final context = SpecValidationContext(bundle);
    return OkfSpecValidation(
      OkfReport(
        findings: <OkfFinding>[
          for (final rule in _validationRules) ...rule.run(context),
        ],
      ),
    );
  }
}
