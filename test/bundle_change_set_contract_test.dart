import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('change set describes every supported bundle mutation', () {
    final changes = OkfBundleChangeSet(<OkfBundleChange>[
      OkfCreateConceptChange(
        id: OkfConceptId('new-concept'),
        document: OkfDocument(
          frontmatter: <String, Object?>{'type': 'Reference'},
        ),
      ),
      OkfUpdateConceptChange(
        id: OkfConceptId('existing'),
        frontmatterChanges: const <String, Object?>{
          'title': 'Updated',
          'meta': <String, Object?>{'reviewed': false},
        },
      ),
      OkfLinkConceptsChange(
        source: OkfConceptId('existing'),
        target: OkfConceptId('new-concept'),
        relationship: 'depends-on',
      ),
      OkfDeprecateConceptChange(
        id: OkfConceptId('old-concept'),
        note: 'Replaced by new-concept.',
      ),
    ]);

    expect(changes.changes[0], isA<OkfCreateConceptChange>());
    expect(changes.changes[1], isA<OkfUpdateConceptChange>());
    expect(changes.changes[2], isA<OkfLinkConceptsChange>());
    expect(changes.changes[3], isA<OkfDeprecateConceptChange>());
    final update = changes.changes[1] as OkfUpdateConceptChange;
    expect(
      () => update.frontmatterChanges['new'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => (update.frontmatterChanges['meta']
          as Map<String, Object?>)['reviewed'] = true,
      throwsUnsupportedError,
    );
  });

  test('update changes freeze parsed frontmatter, not only literals', () {
    final parsed = OkfDocument.parse('''
---
type: Reference
meta: {reviewed: false}
tags: [a, b]
---
''');
    final update = OkfUpdateConceptChange(
      id: OkfConceptId('existing'),
      frontmatterChanges: parsed.frontmatter,
    );

    expect(
      () => (update.frontmatterChanges['meta'] as Map)['reviewed'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => (update.frontmatterChanges['tags'] as List).add('c'),
      throwsUnsupportedError,
    );
    expect(update.frontmatterChanges['meta'], <Object?, Object?>{
      'reviewed': false,
    });
    // The caller's parsed map remains untouched.
    (parsed.frontmatter['meta'] as Map)['reviewed'] = true;
    expect((update.frontmatterChanges['meta'] as Map)['reviewed'], isFalse);
  });

  test('preparation refusal carries the closed Spec judgment', () {
    final validation = OkfSpecValidation(
      OkfReport(
        findings: <OkfFinding>[
          OkfFinding(
            id: OkfFindingId.okf('invalid-change'),
            severity: OkfFindingSeverity.error,
            message: 'The change is invalid.',
          ),
        ],
      ),
    );
    final OkfBundlePreparation result = OkfPreparationRefused(
      validation: validation,
    );

    expect(result, isA<OkfPreparationRefused>());
    expect(
      (result as OkfPreparationRefused).validation,
      same(validation),
    );
    expect(validation.isConformant, isFalse);
  });
}
