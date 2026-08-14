import 'bundle.dart';
import 'finding.dart';
import 'json_data.dart';

/// Parameter values supplied to a registered rule.
typedef OkfRuleParameters = Map<String, Object?>;

/// Executes one rule against a loaded bundle.
typedef OkfRuleRun = Iterable<OkfFinding> Function(
  OkfBundle bundle,
  OkfRuleParameters parameters,
);

/// The complete registration record for one validation rule.
final class OkfRuleCatalogEntry {
  /// Creates a rule entry that can be registered in a catalog.
  OkfRuleCatalogEntry({
    required this.id,
    required this.prose,
    required this.owner,
    required this.defaultSeverity,
    required Map<String, Object?> parameterSchema,
    required this.run,
  }) : parameterSchema = deepUnmodifiableJsonMap(parameterSchema) {
    if (prose.trim().isEmpty) {
      throw ArgumentError.value(prose, 'prose', 'Rule prose must not be empty');
    }
    if (owner.trim().isEmpty) {
      throw ArgumentError.value(owner, 'owner', 'Rule owner must not be empty');
    }
  }

  /// The stable namespaced ID minted by this registration.
  final OkfFindingId id;

  /// Human-readable documentation for the rule.
  final String prose;

  /// The catalog owner responsible for the rule.
  final String owner;

  /// The severity used when the rule does not override it.
  final OkfFindingSeverity defaultSeverity;

  /// The JSON-compatible schema for accepted [run] parameters.
  ///
  /// Held as a deep, unmodifiable copy of the registered schema.
  final Map<String, Object?> parameterSchema;

  /// The rule execution function.
  final OkfRuleRun run;
}

/// An open registry of base and downstream rule catalog entries.
final class OkfRuleCatalog {
  /// Creates a catalog and registers [entries] in iteration order.
  OkfRuleCatalog([
    Iterable<OkfRuleCatalogEntry> entries = const <OkfRuleCatalogEntry>[],
  ]) {
    for (final entry in entries) {
      register(entry);
    }
  }

  final Map<OkfFindingId, OkfRuleCatalogEntry> _entries =
      <OkfFindingId, OkfRuleCatalogEntry>{};

  /// Registered entries in registration order.
  List<OkfRuleCatalogEntry> get entries =>
      List<OkfRuleCatalogEntry>.unmodifiable(_entries.values);

  /// Registers an entry from any valid namespace.
  ///
  /// A catalog cannot contain two rules with the same stable ID.
  void register(OkfRuleCatalogEntry entry) {
    if (_entries.containsKey(entry.id)) {
      throw StateError('Rule ${entry.id} is already registered');
    }
    _entries[entry.id] = entry;
  }
}
