import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('synthetic bundle validates, indexes, graphs, and round-trips', () {
    final documents = <String, OkfDocument>{
      'metrics/revenue.md': OkfDocument.parse('''
---
type: Metric
title: "Revenue: net"
tags: [finance, reporting]
sources:
  - id: policy
    resource: https://example.com/revenue-policy
generated: {by: "pipeline:daily", at: "2026-07-28T09:00:00Z"}
verified: {by: "human:reviewer", at: "2026-07-28T10:00:00Z"}
extension:
  confidence: 0.95
---

# Net revenue

Calculated from [orders](../tables/orders.md) and checked by
[the attester](../attesters/check.dart).
'''),
      'tables/orders.md': OkfDocument.parse('''
---
type: BigQuery Table
title: Orders
resource: bigquery://sample.sales.orders
---

# Orders
'''),
      'computations/revenue-ytd.md': OkfDocument.parse('''
---
type: Attested Computation
title: Revenue YTD
runtime: bigquery
computation: ../queries/revenue.sql
parameters:
  start_date: {type: date, required: true}
executor:
  resource: ../queries/revenue.sql
attester:
  resource: ../attesters/check.dart
---

# Revenue YTD
'''),
      'legacy/handbook.md': OkfDocument.parse('''
---
type: Reference
title: Finance handbook
timestamp: "2026-07-01"
---

# Finance handbook

# Citations

- https://example.com/finance
'''),
    };
    final bundle = OkfBundle.fromDocuments(
      documents,
      indexes: const <String, String>{
        'attesters/index.md':
            '# Attesters\n\n* [check.dart](check.dart) - Verifies output.\n',
      },
      assets: const <String>[
        'attesters/check.dart',
        'queries/revenue.sql',
      ],
    );

    final report = const OkfValidator().validate(bundle);
    final graph = OkfGraph.fromBundle(bundle);
    final generatedIndexes = const OkfIndexGenerator().generate(bundle);

    expect(report.isValid, isTrue);
    expect(
      graph.edges.map((edge) => edge.resolution),
      containsAll(<OkfGraphResolution>[
        OkfGraphResolution.resolvedConcept,
        OkfGraphResolution.resolvedAsset,
        OkfGraphResolution.external,
      ]),
    );
    expect(generatedIndexes, contains('index.md'));
    expect(
      generatedIndexes['index.md'],
      contains('[attesters](attesters/index.md)'),
    );

    for (final entry in documents.entries) {
      final reparsed = OkfDocument.parse(
        entry.value.serialize(),
        sourcePath: entry.key,
      );
      expect(reparsed.frontmatter, entry.value.frontmatter, reason: entry.key);
      expect(reparsed.body, entry.value.body, reason: entry.key);
    }
  });

  test('producer shape deviations remain advisory', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'metric.md': OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Metric',
          'tags': 'finance',
        },
      ),
    });

    final report = const OkfValidator().validate(bundle);

    expect(report.isValid, isTrue);
    expect(
      report.diagnostics.map((diagnostic) => diagnostic.code),
      contains('invalid_tags'),
    );
  });
}
