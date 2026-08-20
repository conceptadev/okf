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

  test('create changes snapshot source and inspected documents', () {
    final nested = <String, Object?>{'reviewed': false};
    final source = OkfDocument(
      frontmatter: <String, Object?>{'type': 'Reference', 'meta': nested},
      body: 'Original body.',
    );
    final change = OkfCreateConceptChange(
      id: OkfConceptId('new-concept'),
      document: source,
    );

    nested['reviewed'] = true;
    source.frontmatter['title'] = 'Mutated';
    final inspected = change.document;
    expect(inspected.frontmatter['title'], isNull);
    expect((inspected.frontmatter['meta'] as Map)['reviewed'], isFalse);
    expect(inspected.body, 'Original body.');

    inspected.frontmatter['title'] = 'Inspection mutation';
    expect(
      () => (inspected.frontmatter['meta'] as Map)['reviewed'] = true,
      throwsUnsupportedError,
    );
    final inspectedAgain = change.document;
    expect(inspectedAgain, isNot(same(inspected)));
    expect(inspectedAgain.frontmatter['title'], isNull);
    expect((inspectedAgain.frontmatter['meta'] as Map)['reviewed'], isFalse);
  });

  test('create changes snapshot documents without canonicalizing them', () {
    final verified = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final change = OkfCreateConceptChange(
      id: OkfConceptId('new-concept'),
      document: OkfDocument(
        frontmatter: <String, Object?>{'zeta': 1, 'type': 'Reference'},
        body: 'No trailing newline.',
      ),
    );

    // Serializing would reorder keys and add a trailing newline; describing
    // a change must not.
    expect(change.document.frontmatter.keys, <String>['zeta', 'type']);
    expect(change.document.body, 'No trailing newline.');

    // Serializing emits dates as quoted scalars, which read back as strings.
    final dated = OkfCreateConceptChange(
      id: OkfConceptId('dated'),
      document: OkfDocument(
        frontmatter: <String, Object?>{'verified': verified},
      ),
    );
    expect(dated.document.frontmatter['verified'], same(verified));

    // A body-only document whose body opens with a --- line stays body-only.
    const ambiguous = '---\nnot: frontmatter\n---\n\nreal body\n';
    final bodyOnly = OkfCreateConceptChange(
      id: OkfConceptId('body-only'),
      document: OkfDocument(body: ambiguous, hasFrontmatter: false),
    );
    expect(bodyOnly.document.hasFrontmatter, isFalse);
    expect(bodyOnly.document.frontmatter, isEmpty);
    expect(bodyOnly.document.body, ambiguous);
  });

  test('every change kind rejects unsupported YAML values alike', () {
    const unsupported = Duration(seconds: 1);
    expect(
      () => OkfCreateConceptChange(
        id: OkfConceptId('new-concept'),
        document: OkfDocument(
          frontmatter: <String, Object?>{'invalid': unsupported},
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => OkfUpdateConceptChange(
        id: OkfConceptId('existing'),
        frontmatterChanges: <String, Object?>{'invalid': unsupported},
      ),
      throwsArgumentError,
    );
  });

  test('update changes snapshot nested maps and every iterable', () {
    final nestedMap = <Object?, Object?>{'enabled': true};
    final nestedList = <Object?>['one'];
    final nestedSet = <Object?>{'alpha', 'beta'};
    final update = OkfUpdateConceptChange(
      id: OkfConceptId('existing'),
      frontmatterChanges: <String, Object?>{
        'map': nestedMap,
        'list': nestedList,
        'set': nestedSet,
      },
    );

    nestedMap['enabled'] = false;
    nestedList.add('two');
    nestedSet.add('gamma');
    expect(update.frontmatterChanges['map'], <Object?, Object?>{
      'enabled': true,
    });
    expect(update.frontmatterChanges['list'], <Object?>['one']);
    expect(update.frontmatterChanges['set'], <Object?>['alpha', 'beta']);
    expect(
      () => (update.frontmatterChanges['set'] as List<Object?>).add('gamma'),
      throwsUnsupportedError,
    );
  });

  test('update changes reject cyclic and unsupported YAML data', () {
    final cyclicList = <Object?>[];
    cyclicList.add(cyclicList);
    final cyclicMap = <String, Object?>{};
    cyclicMap['self'] = cyclicMap;

    for (final invalid in <Object?>[
      cyclicList,
      cyclicMap,
      const Duration(seconds: 1),
      <Object?, Object?>{<Object?>[]: 'non-scalar key'},
    ]) {
      expect(
        () => OkfUpdateConceptChange(
          id: OkfConceptId('existing'),
          frontmatterChanges: <String, Object?>{'invalid': invalid},
        ),
        throwsArgumentError,
      );
    }

    Object? deeplyNested = 'leaf';
    for (var depth = 0; depth < 201; depth++) {
      deeplyNested = <Object?>[deeplyNested];
    }
    expect(
      () => OkfUpdateConceptChange(
        id: OkfConceptId('existing'),
        frontmatterChanges: <String, Object?>{'invalid': deeplyNested},
      ),
      throwsArgumentError,
    );
  });

  test('link changes trim and require a relationship', () {
    final link = OkfLinkConceptsChange(
      source: OkfConceptId('source'),
      target: OkfConceptId('target'),
      relationship: '  depends-on\n',
    );

    expect(link.relationship, 'depends-on');
    for (final relationship in <String>['', ' ', '\n\t']) {
      expect(
        () => OkfLinkConceptsChange(
          source: OkfConceptId('source'),
          target: OkfConceptId('target'),
          relationship: relationship,
        ),
        throwsArgumentError,
      );
    }
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
