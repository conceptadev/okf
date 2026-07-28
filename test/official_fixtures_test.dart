import 'package:okf/okf_io.dart';
import 'package:test/test.dart';

void main() {
  const expectedConcepts = <String, int>{
    'acme_retail': 9,
    'crypto_bitcoin': 9,
    'ga4': 9,
    'stackoverflow': 26,
  };

  group('official OKF fixtures', () {
    test('load all 53 concepts from the pinned upstream bundles', () async {
      var total = 0;
      for (final entry in expectedConcepts.entries) {
        final result = await const OkfBundleLoader().inspect(
          'test/fixtures/official/${entry.key}',
        );

        expect(result.issues, isEmpty, reason: entry.key);
        expect(
          result.bundle.concepts,
          hasLength(entry.value),
          reason: entry.key,
        );
        expect(
          result.assets,
          isNot(contains(endsWith('viz.html'))),
          reason: entry.key,
        );
        total += result.bundle.concepts.length;
      }

      expect(total, 53);
    });

    test('consume official bundles and expose known producer deviations',
        () async {
      for (final name in expectedConcepts.keys) {
        final bundle = await const OkfBundleLoader().load(
          'test/fixtures/official/$name',
        );
        final report = const OkfValidator().validate(bundle);

        if (name == 'acme_retail') {
          expect(report.errorCount, 1);
          expect(
            report.diagnostics.map((diagnostic) => diagnostic.code),
            contains('invalid_log_frontmatter'),
          );
          expect(
            bundle.assetPaths,
            contains('attesters/sql_equality.py'),
          );
        } else {
          expect(report.errorCount, 0, reason: name);
        }

        expect(
          () => OkfGraph.fromBundle(bundle),
          returnsNormally,
          reason: name,
        );
        expect(
          const OkfIndexGenerator().generate(bundle),
          contains('index.md'),
          reason: name,
        );
      }
    });

    test('treat scalar tags as advisory rather than conformance failures',
        () async {
      final bundle = await const OkfBundleLoader().load(
        'test/fixtures/official/stackoverflow',
      );
      final report = const OkfValidator().validate(bundle);

      expect(report.isValid, isTrue);
      expect(
        report.diagnostics
            .where((diagnostic) => diagnostic.code == 'invalid_tags'),
        isNotEmpty,
      );
    });

    test('round-trip every official concept semantically', () async {
      for (final name in expectedConcepts.keys) {
        final result = await const OkfBundleLoader().inspect(
          'test/fixtures/official/$name',
        );
        for (final entry in result.documents.entries) {
          final reparsed = OkfDocument.parse(
            entry.value.serialize(),
            sourcePath: entry.key,
          );

          expect(
            reparsed.frontmatter,
            entry.value.frontmatter,
            reason: '$name/${entry.key}',
          );
          expect(
            reparsed.body,
            entry.value.body,
            reason: '$name/${entry.key}',
          );
        }
      }
    });
  });
}
