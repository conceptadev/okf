import 'finding.dart';

/// Read-only metadata describing one fixed OKF Spec rule.
///
/// Descriptors contain no executable function and cannot alter validation.
final class OkfSpecRuleDescriptor {
  /// Creates immutable rule metadata.
  const OkfSpecRuleDescriptor({
    required this.id,
    required this.prose,
    required this.defaultSeverity,
    required this.specReference,
  });

  /// Stable `okf/<code>` finding ID.
  final OkfFindingId id;

  /// Human-readable statement of the condition checked.
  final String prose;

  /// Severity emitted when the condition is found.
  final OkfFindingSeverity defaultSeverity;

  /// Clause or tolerant-reader guidance in the pinned OKF revision.
  final String specReference;
}
