import 'dart:convert';
import 'dart:io';

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
    expect(json['schema_version'], okfGraphJsonSchemaVersion);
    expect(json['nodes'], isA<List<Object?>>());
    expect(json['edges'], isA<List<Object?>>());
    expect(graph.toDot(), contains('missing.md'));
    expect(graph.toMermaid(), contains('missing.md'));
  });

  test('checked-in JSON schema matches the graph wire contract', () async {
    final schema = jsonDecode(
      await File('schemas/graph-v1.schema.json').readAsString(),
    ) as Map<String, Object?>;
    final properties = schema['properties']! as Map<String, Object?>;
    final definitions = schema[r'$defs']! as Map<String, Object?>;
    final nodeSchema = definitions['node']! as Map<String, Object?>;
    final nodeProperties = nodeSchema['properties']! as Map<String, Object?>;
    final edgeSchema = definitions['edge']! as Map<String, Object?>;
    final edgeProperties = edgeSchema['properties']! as Map<String, Object?>;

    expect(
      (properties['schema_version']! as Map<String, Object?>)['const'],
      okfGraphJsonSchemaVersion,
    );
    final graphJson = OkfGraph.fromBundle(
      OkfBundle.fromDocuments(<String, OkfDocument>{}),
    ).toJson();
    expect(schema['required'], graphJson.keys);
    expect(properties.keys.toSet(), graphJson.keys.toSet());

    final id = OkfConceptId('source');
    final requiredNode = OkfGraphNode(
      id: id,
      type: 'Metric',
      title: 'Source',
      status: 'active',
      trustTier: 'unverified',
      staleAfter: null,
    );
    final completeNode = OkfGraphNode(
      id: id,
      type: 'Metric',
      title: 'Source',
      status: 'active',
      trustTier: 'unverified',
      staleAfter: '2026-09-01',
    );
    expect(nodeSchema['required'], requiredNode.toJson().keys);
    expect(nodeProperties.keys.toSet(), completeNode.toJson().keys.toSet());

    final requiredEdge = OkfGraphEdge(
      source: id,
      rawTarget: 'target.md',
      origin: OkfGraphEdgeOrigin.bodyLink,
      resolution: OkfGraphResolution.unresolved,
    );
    final completeEdge = OkfGraphEdge(
      source: id,
      rawTarget: 'target.md',
      origin: OkfGraphEdgeOrigin.bodyLink,
      resolution: OkfGraphResolution.resolvedConcept,
      resolvedPath: 'target.md',
      targetConcept: OkfConceptId('target'),
    );
    expect(edgeSchema['required'], requiredEdge.toJson().keys);
    expect(edgeProperties.keys.toSet(), completeEdge.toJson().keys.toSet());
    expect(
      (edgeProperties['origin']! as Map<String, Object?>)['enum'],
      OkfGraphEdgeOrigin.values.map((origin) => origin.wireValue),
    );
    expect(
      (edgeProperties['resolution']! as Map<String, Object?>)['enum'],
      OkfGraphResolution.values.map((resolution) => resolution.wireValue),
    );
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

  test('filters a graph through the exported query vocabulary', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'analytics/primary.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Metric'},
        body: '''
[peer](peer.md) [reference](reference.md) [missing](missing.md)
''',
      ),
      'analytics/peer.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Metric'},
      ),
      'analytics/reference.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
      ),
      'other/metric.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Metric'},
      ),
    });

    final graph = OkfGraph.fromBundle(
      bundle,
      query: OkfGraphQuery(
        conceptTypes: const <String>['Metric'],
        pathPrefixes: const <String>['analytics/'],
        resolutions: const <OkfGraphResolution>[
          OkfGraphResolution.unresolved,
        ],
      ),
    );

    expect(
      graph.nodes.map((node) => node.id.value),
      <String>['analytics/peer', 'analytics/primary'],
    );
    expect(graph.edges, hasLength(1));
    expect(graph.edges.single.rawTarget, 'missing.md');
    expect(graph.toDot(), contains('missing.md'));
    expect(graph.toMermaid(), contains('missing.md'));
  });

  test('owns the machine-readable query vocabulary', () {
    final properties =
        OkfGraphQuery.jsonSchema['properties']! as Map<String, Object?>;
    expect(
      properties.keys,
      <String>['types', 'path_prefixes', 'resolutions'],
    );
    final resolutionItems = (properties['resolutions']!
        as Map<String, Object?>)['items']! as Map<String, Object?>;
    expect(
      resolutionItems['enum'],
      OkfGraphResolution.values.map((resolution) => resolution.wireValue),
    );

    final query = OkfGraphQuery.fromJson(<String, Object?>{
      'types': <String>['Metric'],
      'path_prefixes': <String>['analytics/'],
      'resolutions': <String>['unresolved'],
    });

    expect(query.conceptTypes, <String>{'Metric'});
    expect(query.pathPrefixes, <String>{'analytics/'});
    expect(query.resolutions, <OkfGraphResolution>{
      OkfGraphResolution.unresolved,
    });
    expect(
      query.toJson(),
      <String, Object?>{
        'types': <String>['Metric'],
        'path_prefixes': <String>['analytics/'],
        'resolutions': <String>['unresolved'],
      },
    );
    expect(query.toJson().keys, properties.keys);
    expect(
      OkfGraphQuery.fromJson(query.toJson()).toJson(),
      query.toJson(),
    );
    expect(
      () => OkfGraphQuery.fromJson(<String, Object?>{
        'resolutions': <String>['unknown'],
      }),
      throwsFormatException,
    );
    expect(
      () => OkfGraphQuery.fromJson(<String, Object?>{'types': null}),
      throwsFormatException,
    );
    expect(
      () => OkfGraphQuery(pathPrefixes: const <String>['']),
      throwsArgumentError,
    );
  });

  test('an empty query preserves every default projection', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'source.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
        body: '[target](target.md)',
      ),
      'target.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
      ),
    });

    final unfiltered = OkfGraph.fromBundle(bundle);
    final emptyQuery = OkfGraph.fromBundle(bundle, query: OkfGraphQuery());

    expect(emptyQuery.toJson(), unfiltered.toJson());
    expect(emptyQuery.toDot(), unfiltered.toDot());
    expect(emptyQuery.toMermaid(), unfiltered.toMermaid());
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
