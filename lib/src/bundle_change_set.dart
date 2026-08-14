import 'dart:collection';

import 'bundle.dart';
import 'concept_id.dart';
import 'document.dart';
import 'finding.dart';

/// A prospective mutation included in an [OkfBundleChangeSet].
sealed class OkfBundleChange {
  const OkfBundleChange();
}

/// A request to create a concept from a complete document.
final class OkfCreateConceptChange extends OkfBundleChange {
  /// Creates a concept-change description.
  const OkfCreateConceptChange({required this.id, required this.document});

  /// The ID for the new concept.
  final OkfConceptId id;

  /// The prospective concept document.
  final OkfDocument document;
}

/// A request to update the managed portions of an existing concept.
final class OkfUpdateConceptChange extends OkfBundleChange {
  /// Creates an update-change description.
  OkfUpdateConceptChange({
    required this.id,
    Map<String, Object?> frontmatterChanges = const <String, Object?>{},
    this.body,
  }) : frontmatterChanges = UnmodifiableMapView<String, Object?>(
          Map<String, Object?>.of(frontmatterChanges),
        );

  /// The concept to update.
  final OkfConceptId id;

  /// Frontmatter values to overlay while retaining unmanaged fields.
  final Map<String, Object?> frontmatterChanges;

  /// Replacement Markdown body, or `null` to retain the existing body.
  final String? body;
}

/// A request to add a typed relationship between concepts.
final class OkfLinkConceptsChange extends OkfBundleChange {
  /// Creates a link-change description.
  const OkfLinkConceptsChange({
    required this.source,
    required this.target,
    required this.relationship,
  });

  /// The concept that owns the relationship.
  final OkfConceptId source;

  /// The concept referenced by the relationship.
  final OkfConceptId target;

  /// The producer-defined relationship type.
  final String relationship;
}

/// A request to deprecate an existing concept.
final class OkfDeprecateConceptChange extends OkfBundleChange {
  /// Creates a deprecation-change description.
  const OkfDeprecateConceptChange({required this.id, this.note});

  /// The concept to deprecate.
  final OkfConceptId id;

  /// Optional context recorded with the lifecycle change.
  final String? note;
}

/// An ordered group of changes validated and applied as one operation.
final class OkfBundleChangeSet {
  /// Creates a change set in application order.
  OkfBundleChangeSet(Iterable<OkfBundleChange> changes)
      : changes = List<OkfBundleChange>.unmodifiable(changes);

  /// The changes in application order.
  final List<OkfBundleChange> changes;
}

/// Validates a change set against its prospective overlaid bundle.
///
/// Implementations run the complete configured rule catalog against the
/// overlay and return the same report used for ordinary bundle validation.
typedef OkfProspectiveBundleValidator = OkfReport Function(
  OkfBundle baseBundle,
  OkfBundleChangeSet changes,
);

/// The all-or-nothing outcome of applying an [OkfBundleChangeSet].
sealed class OkfBundleApplyResult {
  const OkfBundleApplyResult({required this.report});

  /// The report produced by prospective validation.
  final OkfReport report;
}

/// A change set that was fully committed.
final class OkfBundleApplied extends OkfBundleApplyResult {
  /// Creates a successful atomic-apply result.
  OkfBundleApplied({
    required super.report,
    required Iterable<String> changedPaths,
  }) : changedPaths = List<String>.unmodifiable(changedPaths);

  /// Every bundle-relative path committed by the operation.
  final List<String> changedPaths;
}

/// A change set refused before any file was changed.
final class OkfBundleRefused extends OkfBundleApplyResult {
  /// Creates a refused atomic-apply result.
  const OkfBundleRefused({required super.report});
}
