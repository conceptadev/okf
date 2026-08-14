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
      catalog.entries.single.run(
        OkfBundle.fromDocuments(const <String, OkfDocument>{}),
        const <String, Object?>{'minimumLength': 4},
      ),
      isEmpty,
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
