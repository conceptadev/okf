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
            'executor': <String, Object?>{'resource': '../references/run.md'},
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

  test('resolves raw non-ASCII targets against the bundle instead of '
      'crashing', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'overview.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Reference',
            'sources': <Object?>[
              <String, Object?>{
                'resource': 'references/Gap—Analysis-July29.pdf',
              },
              <String, Object?>{'resource': 'references/Missing—File.pdf'},
            ],
          },
        ),
      },
      assets: <String>['references/Gap—Analysis-July29.pdf'],
    );

    final graph = OkfGraph.fromBundle(bundle);

    final present = graph.edges.singleWhere(
      (edge) => edge.rawTarget == 'references/Gap—Analysis-July29.pdf',
    );
    expect(present.resolution, OkfGraphResolution.resolvedAsset);
    expect(present.resolvedPath, 'references/Gap—Analysis-July29.pdf');
    final absent = graph.edges.singleWhere(
      (edge) => edge.rawTarget == 'references/Missing—File.pdf',
    );
    expect(absent.resolution, OkfGraphResolution.unresolved);
  });

  test('classifies malformed percent escapes as invalid, not fatal', () {
    // Body-link hrefs arrive parser-normalized (a stray `%` becomes `%25`),
    // so raw malformed escapes only reach resolution through frontmatter
    // targets. A target containing `%` that fails to decode is a genuinely
    // broken escape — including a file literally named `100%`, by design.
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'overview.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Reference',
            'sources': <Object?>[
              <String, Object?>{'resource': 'refs/100%.md'},
              <String, Object?>{'resource': 'refs/a%zz.md'},
            ],
          },
          body: '[decodes](references/a%20b.txt)',
        ),
      },
      assets: <String>['references/a b.txt'],
    );

    final graph = OkfGraph.fromBundle(bundle);

    OkfGraphEdge edgeFor(String rawTarget) =>
        graph.edges.singleWhere((edge) => edge.rawTarget == rawTarget);
    expect(edgeFor('refs/100%.md').resolution, OkfGraphResolution.invalid);
    expect(edgeFor('refs/a%zz.md').resolution, OkfGraphResolution.invalid);
    final decoded = edgeFor('references/a%20b.txt');
    expect(decoded.resolution, OkfGraphResolution.resolvedAsset);
    expect(decoded.resolvedPath, 'references/a b.txt');
  });

  test('classifies prose source descriptors as descriptors even when they '
      'contain slashes', () {
    // Verbatim sources[].resource descriptors from the first real
    // migration's QA corpus.
    const descriptors = <String>[
      'Concepta/Raul follow-up packet, 23 June 2026 — Concepta '
          'current-understanding document, retained outside this bundle',
      'Direct inspection of both post-baseline packages on 3 August 2026 — '
          'file enumeration, extracted PDF/OOXML text, and a credential- and '
          'commercial-value scan; method record, not mirrored',
      'Waterstreet FMS / Anago CleanSuite sandbox at '
          '`https://sandbox.waterstreet.net/anago/secure.cfm`, crawled '
          'read-only during the same window',
    ];
    const paths = <String>[
      'references/query.sql',
      '../other/doc.md',
      '/abs/path.md',
      'notes.md',
      'references/C-Fee%20%281%29.xlsx',
    ];
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'overview.md': OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Reference',
          'sources': <Object?>[
            for (final target in <String>[...descriptors, ...paths])
              <String, Object?>{'resource': target},
          ],
        },
      ),
    });

    final graph = OkfGraph.fromBundle(bundle);

    OkfGraphResolution resolutionFor(String rawTarget) => graph.edges
        .singleWhere((edge) => edge.rawTarget == rawTarget)
        .resolution;
    for (final descriptor in descriptors) {
      expect(
        resolutionFor(descriptor),
        OkfGraphResolution.descriptor,
        reason: descriptor,
      );
    }
    for (final path in paths) {
      expect(
        resolutionFor(path),
        isNot(OkfGraphResolution.descriptor),
        reason: path,
      );
    }
  });

  test('checked-in JSON schema matches the graph wire contract', () async {
    final schema =
        jsonDecode(await File('schemas/graph-v1.schema.json').readAsString())
            as Map<String, Object?>;
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

  test('path prefixes match whole segments, never sibling directories', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'analytics/primary.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Metric'},
      ),
      'analytics-archive/decoy.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Metric'},
      ),
    });

    final graph = OkfGraph.fromBundle(
      bundle,
      query: OkfGraphQuery(pathPrefixes: const <String>['analytics']),
    );

    expect(graph.nodes.map((node) => node.id.value), <String>[
      'analytics/primary',
    ]);
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
        resolutions: const <OkfGraphResolution>[OkfGraphResolution.unresolved],
      ),
    );

    expect(graph.nodes.map((node) => node.id.value), <String>[
      'analytics/peer',
      'analytics/primary',
    ]);
    expect(graph.edges, hasLength(1));
    expect(graph.edges.single.rawTarget, 'missing.md');
    expect(graph.toDot(), contains('missing.md'));
    expect(graph.toMermaid(), contains('missing.md'));
  });

  test('owns the machine-readable query vocabulary', () {
    final properties =
        OkfGraphQuery.jsonSchema['properties']! as Map<String, Object?>;
    expect(properties.keys, <String>['types', 'path_prefixes', 'resolutions']);
    final resolutionItems =
        (properties['resolutions']! as Map<String, Object?>)['items']!
            as Map<String, Object?>;
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
    expect(query.toJson(), <String, Object?>{
      'types': <String>['Metric'],
      'path_prefixes': <String>['analytics/'],
      'resolutions': <String>['unresolved'],
    });
    expect(query.toJson().keys, properties.keys);
    expect(OkfGraphQuery.fromJson(query.toJson()).toJson(), query.toJson());
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

  test(
    'query parsing rejects malformed fields without changing Set semantics',
    () {
      for (final input in <Map<String, Object?>>[
        {'unknown': true},
        {'types': null},
        {'types': 'Metric'},
        {
          'types': <Object?>[42],
        },
        {
          'types': <Object?>[null],
        },
        {
          'types': <String>[''],
        },
        {
          'types': <String>['Metric', 'Metric'],
        },
        {
          'path_prefixes': <String>['area', 'area'],
        },
        {
          'resolutions': <String>['external', 'external'],
        },
        {
          'resolutions': <String>['unknown'],
        },
      ]) {
        expect(
          () => OkfGraphQuery.fromJson(input),
          throwsFormatException,
          reason: '$input',
        );
      }

      final types = <String>['Metric'];
      final query = OkfGraphQuery.fromJson({'types': types});
      types.add('Reference');
      expect(query.conceptTypes, <String>{'Metric'});
      expect(() => query.conceptTypes.add('Note'), throwsUnsupportedError);
      expect(query.toJson(), {
        'types': <String>['Metric'],
        'path_prefixes': <String>[],
        'resolutions': <String>[],
      });
      expect(
        OkfGraphQuery(conceptTypes: ['Metric', 'Metric']).conceptTypes,
        <String>{'Metric'},
      );
      expect(
        OkfGraphQuery.fromJson({
          'types': <String>[' '],
        }).conceptTypes,
        <String>{' '},
      );
    },
  );

  test(
    'invalid graph queries identify nested fields and retain their source',
    () {
      final input = <String, Object?>{
        'types': [42],
        'path_prefixes': [''],
        'unknown': true,
      };
      expect(
        () => OkfGraphQuery.fromJson(input),
        throwsA(
          isA<FormatException>()
              .having((error) => error.source, 'source', same(input))
              .having(
                (error) => error.message,
                'message',
                allOf([
                  startsWith('Invalid graph query:'),
                  contains('#/types/0:'),
                  contains('Expected string'),
                  contains('#/path_prefixes/0:'),
                  contains('Minimum 1'),
                  contains('#/unknown:'),
                  contains('not allowed'),
                  isNot(contains('One or more nested schemas')),
                ]),
              ),
        ),
      );
    },
  );

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
