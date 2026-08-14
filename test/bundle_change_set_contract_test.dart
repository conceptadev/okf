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
        frontmatterChanges: const <String, Object?>{'title': 'Updated'},
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
  });

  test('prospective validation receives the base bundle and change set', () {
    final bundle = OkfBundle.fromDocuments(const <String, OkfDocument>{});
    final changes = OkfBundleChangeSet(const <OkfBundleChange>[]);
    OkfReport validate(
      OkfBundle candidate,
      OkfBundleChangeSet prospectiveChanges,
    ) {
      expect(candidate, same(bundle));
      expect(prospectiveChanges, same(changes));
      return OkfReport();
    }

    final OkfProspectiveBundleValidator prospectiveValidator = validate;

    expect(prospectiveValidator(bundle, changes).findings, isEmpty);
  });

  test('atomic apply result cannot represent partial application', () {
    final applied = OkfBundleApplied(
      report: OkfReport(),
      changedPaths: const <String>['concept.md', 'index.md', 'log.md'],
    );
    final refused = OkfBundleRefused(
      report: OkfReport(
        findings: <OkfFinding>[
          OkfFinding(
            id: OkfFindingId.okf('invalid-change'),
            severity: OkfFindingSeverity.error,
            message: 'The change is invalid.',
          ),
        ],
      ),
    );

    expect(applied.changedPaths, hasLength(3));
    expect(refused.report.activeFindings, hasLength(1));
  });
}
