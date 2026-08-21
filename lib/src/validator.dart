import 'base_rules/base_rule.dart';
import 'base_rules/concept_rules.dart';
import 'base_rules/load_rules.dart';
import 'base_rules/reserved_rules.dart';
import 'base_rules/validation_context.dart';
import 'bundle.dart';
import 'finding.dart';
import 'spec_rule.dart';

final _bundleRules = <OkfSpecRule>[
  ...conceptRuleEntries,
  ...reservedRuleEntries,
];

/// Read-only metadata for the complete fixed OKF Spec finding set.
final List<OkfSpecRuleDescriptor> okfSpecRuleDescriptors =
    List<OkfSpecRuleDescriptor>.unmodifiable(<OkfSpecRuleDescriptor>[
  ...loadFindingDefinitions.map((definition) => definition.descriptor),
  ..._bundleRules.map((rule) => rule.descriptor),
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
          for (final rule in _bundleRules) ...rule.run(context),
        ],
      ),
    );
  }
}
