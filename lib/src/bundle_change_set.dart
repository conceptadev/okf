import 'bundle.dart';
import 'concept_id.dart';
import 'document.dart';
import 'finding.dart';
import 'json_data.dart';

/// A prospective mutation included in an [OkfBundleChangeSet].
sealed class OkfBundleChange {
  /// Shared by every change kind; the sealed hierarchy is closed here.
  const OkfBundleChange();
}

/// A request to create a concept from a complete document.
final class OkfCreateConceptChange extends OkfBundleChange {
  /// Creates a concept-change description, snapshotting [document].
  OkfCreateConceptChange({required this.id, required OkfDocument document})
      : _serializedDocument = document.serialize();

  /// The ID for the new concept.
  final OkfConceptId id;

  final String _serializedDocument;

  /// A detached copy of the prospective concept document.
  ///
  /// Each access returns a newly parsed document, so mutations made while
  /// inspecting one copy cannot change this description.
  OkfDocument get document =>
      OkfDocument.parse(_serializedDocument, sourcePath: id.documentPath);
}

/// A request to update the managed portions of an existing concept.
final class OkfUpdateConceptChange extends OkfBundleChange {
  /// Creates an update-change description.
  OkfUpdateConceptChange({
    required this.id,
    Map<String, Object?> frontmatterChanges = const <String, Object?>{},
    this.body,
  }) : frontmatterChanges = deepUnmodifiableJsonMap(frontmatterChanges);

  /// The concept to update.
  final OkfConceptId id;

  /// Frontmatter values to overlay while retaining unmanaged fields.
  ///
  /// Held as a deep, unmodifiable copy of the requested values.
  final Map<String, Object?> frontmatterChanges;

  /// Replacement Markdown body, or `null` to retain the existing body.
  final String? body;
}

/// A request to add a typed relationship between concepts.
final class OkfLinkConceptsChange extends OkfBundleChange {
  /// Creates a link-change description.
  ///
  /// Surrounding whitespace is removed from [relationship], whose resulting
  /// value must not be empty.
  factory OkfLinkConceptsChange({
    required OkfConceptId source,
    required OkfConceptId target,
    required String relationship,
  }) {
    final trimmedRelationship = relationship.trim();
    if (trimmedRelationship.isEmpty) {
      throw ArgumentError.value(
        relationship,
        'relationship',
        'must not be empty',
      );
    }
    return OkfLinkConceptsChange._(
      source: source,
      target: target,
      relationship: trimmedRelationship,
    );
  }

  const OkfLinkConceptsChange._({
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

/// An immutable view of the complete candidate prepared for a bundle write.
///
/// Concept values are the exact serialized Markdown bytes represented by the
/// candidate. [toBundle] returns a detached in-memory copy for downstream
/// inspection; changing that copy cannot change a prepared write.
final class OkfPreparedCandidate {
  OkfPreparedCandidate._({
    required Map<String, String> concepts,
    required Map<String, String> indexes,
    required Map<String, String> logs,
    required Set<String> assets,
  })  : concepts = Map<String, String>.unmodifiable(concepts),
        indexes = Map<String, String>.unmodifiable(indexes),
        logs = Map<String, String>.unmodifiable(logs),
        assets = Set<String>.unmodifiable(assets);

  /// Serialized concept documents keyed by bundle-relative path.
  final Map<String, String> concepts;

  /// Serialized index documents keyed by bundle-relative path.
  final Map<String, String> indexes;

  /// Serialized log documents keyed by bundle-relative path.
  final Map<String, String> logs;

  /// Asset paths present in the candidate.
  final Set<String> assets;

  /// Materializes a detached bundle for read-only downstream analysis.
  OkfBundle toBundle() => OkfBundle.fromDocuments(
        <String, OkfDocument>{
          for (final entry in concepts.entries)
            entry.key: OkfDocument.parse(entry.value, sourcePath: entry.key),
        },
        indexes: indexes,
        logs: logs,
        assets: assets,
      );
}

/// Opaque proof that an exact candidate passed OKF Spec validation.
///
/// Only the package's preparation implementation can construct this value.
final class OkfPreparedChange {
  const OkfPreparedChange._({
    required this.candidate,
    required this.validation,
  });

  /// The immutable candidate that was validated.
  final OkfPreparedCandidate candidate;

  /// The closed OKF Spec judgment for [candidate].
  final OkfSpecValidation validation;
}

/// The result of preparing an [OkfBundleChangeSet].
sealed class OkfBundlePreparation {
  const OkfBundlePreparation._();
}

/// A candidate refused because it is not OKF Spec-conformant.
final class OkfPreparationRefused extends OkfBundlePreparation {
  /// Creates a refusal carrying the candidate's OKF Spec judgment.
  const OkfPreparationRefused({required this.validation}) : super._();

  /// The non-conformant OKF Spec judgment.
  final OkfSpecValidation validation;
}

/// A candidate prepared for inspection and eventual commit.
final class OkfPreparationReady extends OkfBundlePreparation {
  const OkfPreparationReady._(this.prepared) : super._();

  /// The opaque prepared change.
  final OkfPreparedChange prepared;
}
