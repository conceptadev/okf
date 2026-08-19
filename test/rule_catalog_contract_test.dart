import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('external namespaces register complete rule entries', () {
    final rule = OkfRuleCatalogEntry(
      id: OkfFindingId.parse('vendor/review-title'),
      prose: 'Titles need a downstream review.',
      owner: 'vendor-quality',
      defaultSeverity: OkfFindingSeverity.advisory,
      parameterSchema: const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'minimumLength': <String, Object?>{'type': 'integer'},
        },
      },
      run: (bundle, parameters) => const <OkfFinding>[],
    );
    final catalog = OkfRuleCatalog()..register(rule);

    expect(catalog.entries, <OkfRuleCatalogEntry>[rule]);
    expect(catalog.entries.single.id.value, 'vendor/review-title');
    expect(catalog.entries.single.prose, isNotEmpty);
    expect(catalog.entries.single.owner, 'vendor-quality');
    expect(
      catalog.entries.single.parameterSchema['type'],
      'object',
    );
    expect(
      () => (catalog.entries.single.parameterSchema['properties']
          as Map<String, Object?>)['minimumLength'] = true,
      throwsUnsupportedError,
    );
    expect(
      catalog.entries.single.run(
        OkfBundle.fromDocuments(const <String, OkfDocument>{}),
        const <String, Object?>{'minimumLength': 4},
      ),
      isEmpty,
    );
  });

  test('a namespaced rule reports through the same Report and Verdict', () {
    late final OkfRuleCatalogEntry rule;
    rule = OkfRuleCatalogEntry(
      id: OkfFindingId.parse('vendor/short-id'),
      prose: 'Concept IDs must be long enough for vendor tooling.',
      owner: 'vendor-quality',
      defaultSeverity: OkfFindingSeverity.advisory,
      parameterSchema: const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'minimumLength': <String, Object?>{'type': 'integer'},
        },
      },
      run: (bundle, parameters) => <OkfFinding>[
        for (final id in bundle.concepts.keys)
          if ((parameters['minimumLength'] as int? ?? 0) > id.value.length)
            rule.finding(
              message: 'Concept ID is too short.',
              location: OkfFindingLocation(path: id.documentPath),
            ),
      ],
    );
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'ab.md': OkfDocument(frontmatter: const <String, Object?>{'type': 'T'}),
      'long-enough.md':
          OkfDocument(frontmatter: const <String, Object?>{'type': 'T'}),
    });

    final report = OkfReport(
      findings: rule.run(bundle, const <String, Object?>{'minimumLength': 4}),
    );

    expect(report.findings, <OkfFinding>[
      OkfFinding(
        id: OkfFindingId.parse('vendor/short-id'),
        severity: OkfFindingSeverity.advisory,
        message: 'Concept ID is too short.',
        location: const OkfFindingLocation(path: 'ab.md'),
      ),
    ]);
    expect(
      report.toText(),
      'ab.md: advisory vendor/short-id: Concept ID is too short.',
    );
    expect(OkfVerdict.of(report).exitCode, 0);
    expect(OkfVerdict.of(report, strict: true).exitCode, 1);
    expect(
      OkfVerdict.of(
        OkfReport(
          findings: report.findings,
          suppressions: <OkfFindingSuppression>[
            OkfFindingSuppression(id: OkfFindingId.parse('vendor/short-id')),
          ],
        ),
        strict: true,
      ).exitCode,
      0,
    );
    expect(
      rule.finding(message: 'Escalated.', severity: OkfFindingSeverity.error),
      OkfFinding(
        id: rule.id,
        severity: OkfFindingSeverity.error,
        message: 'Escalated.',
      ),
    );
  });

  test('catalog rejects incomplete metadata and duplicate IDs', () {
    OkfRuleCatalogEntry entry(
            {String prose = 'Rule prose', String owner = 'base'}) =>
        OkfRuleCatalogEntry(
          id: OkfFindingId.okf('sample'),
          prose: prose,
          owner: owner,
          defaultSeverity: OkfFindingSeverity.error,
          parameterSchema: const <String, Object?>{},
          run: (bundle, parameters) => const <OkfFinding>[],
        );

    expect(() => entry(prose: ' '), throwsArgumentError);
    expect(() => entry(owner: ''), throwsArgumentError);

    final catalog = OkfRuleCatalog()..register(entry());
    expect(() => catalog.register(entry()), throwsStateError);
  });
}
