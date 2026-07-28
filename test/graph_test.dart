import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('extracts, resolves, and retains every target class', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'overview.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Metric',
            'title': 'Overview',
            'resource': 'https://example.com/metric',
            'sources': <Object?>[
              <String, Object?>{'resource': 'all queries in project X'},
              <String, Object?>{'resource': 'tables/caf%C3%A9.md'},
            ],
          },
          body: '''
See [the café](tables/caf%C3%A9.md), [missing](missing.md),
[the query](references/query.sql), and [outside](../outside.md).
''',
        ),
        'tables/café.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'BigQuery Table',
            'verified': <String, Object?>{
              'by': 'human:reviewer',
              'at': '2026-07-27T12:00:00Z',
            },
          },
          body: 'Back to [overview](/overview.md).',
        ),
        'computations/revenue.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Attested Computation',
            'runtime': 'bigquery',
            'computation': '../references/revenue.sql',
            'executor': <String, Object?>{
              'resource': '../references/run.md',
            },
            'attester': <String, Object?>{
              'resource': '../references/attest.py',
            },
          },
        ),
        'references/run.md': OkfDocument(
          frontmatter: <String, Object?>{'type': 'Skill'},
        ),
      },
      assets: <String>[
        'references/query.sql',
        'references/revenue.sql',
        'references/attest.py',
      ],
    );

    final graph = OkfGraph.fromBundle(bundle);

    expect(graph.nodes, hasLength(4));
    expect(
      graph.nodes
          .singleWhere((node) => node.id.value == 'tables/café')
          .trustTier,
      'human-reviewed',
    );
    expect(
      graph.edges.map((edge) => edge.resolution),
      containsAll(<OkfGraphResolution>[
        OkfGraphResolution.resolvedConcept,
        OkfGraphResolution.resolvedAsset,
        OkfGraphResolution.external,
        OkfGraphResolution.descriptor,
        OkfGraphResolution.unresolved,
        OkfGraphResolution.invalid,
      ]),
    );

    final encodedEdge = graph.edges.singleWhere(
      (edge) =>
          edge.rawTarget == 'tables/caf%C3%A9.md' &&
          edge.origin == OkfGraphEdgeOrigin.sourceResource,
    );
    expect(encodedEdge.targetConcept?.value, 'tables/café');

    final json = graph.toJson();
    expect(json['nodes'], isA<List<Object?>>());
    expect(json['edges'], isA<List<Object?>>());
    expect(graph.toDot(), contains('missing.md'));
    expect(graph.toMermaid(), contains('missing.md'));
  });

  test('resolves relative and fragment-only links from nested concepts', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'a/one.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
        body: '[two](two.md) [self](#details)',
      ),
      'a/two.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
      ),
    });

    final graph = OkfGraph.fromBundle(bundle);

    expect(
      graph.edges
          .where(
            (edge) => edge.resolution == OkfGraphResolution.resolvedConcept,
          )
          .map((edge) => edge.targetConcept?.value),
      containsAll(<String?>['a/one', 'a/two']),
    );
  });

  test('does not turn generated footnote navigation into graph edges', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'claim.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
        body: '''
This claim has provenance.[^source]

[^source]: Source title
''',
      ),
    });

    expect(OkfGraph.fromBundle(bundle).edges, isEmpty);
  });

  test('escapes renderer-sensitive labels and control characters', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'unsafe.md': OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Reference',
          'title': '<script>\u001b',
        },
        body: '[target](missing<target>.md)',
      ),
    });

    final graph = OkfGraph.fromBundle(bundle);
    final mermaid = graph.toMermaid();
    final dot = graph.toDot();

    expect(mermaid, contains('&lt;script&gt;'));
    expect(mermaid, isNot(contains('\u001b')));
    expect(dot, isNot(contains('\u001b')));
  });
}
