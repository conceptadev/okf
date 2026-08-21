import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:markdown/markdown.dart' as md;
import 'package:mcp_dart/mcp_dart.dart'
    show latestInitializationProtocolVersion;
import 'package:okf/okf.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Directory sandbox;
  late Directory bundle;
  final servers = <_McpHarness>[];

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('okf-mcp-test-');
    bundle = await Directory(p.join(sandbox.path, 'bundle')).create();
  });

  tearDown(() async {
    for (final server in servers) {
      await server.stop();
    }
    servers.clear();
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  Future<_McpHarness> serve() async {
    final harness = await _McpHarness.start(bundle.path);
    servers.add(harness);
    await harness.initialize();
    return harness;
  }

  test('advertises the fixed tool surface', () async {
    await writeConcept(bundle, 'alpha.md');
    final server = await serve();

    final tools =
        (await server.request('tools/list'))['tools']! as List<Object?>;
    final byName = <String, Map<String, Object?>>{
      for (final tool in tools.cast<Map<String, Object?>>())
        tool['name']! as String: tool,
    };

    expect(
      byName.keys.toSet(),
      <String>{
        'create-concept',
        'update-concept',
        'link-concepts',
        'deprecate-concept',
        'list-concepts',
        'lookup-concept',
        'query-graph',
        'validate',
      },
    );
    for (final tool in <String>[
      'list-concepts',
      'lookup-concept',
      'query-graph',
      'validate',
    ]) {
      expect(byName[tool]!['annotations'], <String, Object?>{
        'readOnlyHint': true,
        'destructiveHint': false,
        'idempotentHint': true,
        'openWorldHint': false,
      });
    }
    expect(
      byName['query-graph']!['inputSchema'],
      OkfGraphQuery.jsonSchema,
    );
    final effects = <String, ({bool destructive, bool idempotent})>{
      'create-concept': (destructive: false, idempotent: false),
      'update-concept': (destructive: true, idempotent: true),
      'link-concepts': (destructive: false, idempotent: true),
      'deprecate-concept': (destructive: true, idempotent: true),
    };
    for (final MapEntry(key: tool, value: effect) in effects.entries) {
      expect(byName[tool]!['annotations'], <String, Object?>{
        'readOnlyHint': false,
        'destructiveHint': effect.destructive,
        'idempotentHint': effect.idempotent,
        'openWorldHint': false,
      });
    }
    expect(await server.awaitDiagnostic(), contains('okf mcp: serving'));
  });

  test('validate returns the CLI Report and Verdict, strict included',
      () async {
    await writeConcept(bundle, 'alpha.md');
    await writeConcept(
      bundle,
      'beta.md',
      title: 'Beta',
      frontmatter: const <String>['status: retired'],
    );
    final server = await serve();

    for (final strict in <bool>[false, true]) {
      final cli = await runCli(
        <String>[
          'validate',
          'bundle',
          '--output=json',
          if (strict) '--warnings-as-errors',
        ],
        sandbox.path,
      );
      final tool = await server.callTool('validate', <String, Object?>{
        if (strict) 'strict': true,
      });

      expect(tool['isError'], isNot(true));
      final payload = tool['structuredContent']! as Map<String, Object?>;
      expect(payload['report'], jsonDecode(cli.stdout));
      expect(payload['exit_code'], cli.exitCode);
      expect(payload['strict'], strict);
    }

    expect(
      _findingIds(
        (await server.callTool('validate'))['structuredContent']!
            as Map<String, Object?>,
      ),
      <String>['okf/invalid-status'],
    );
  });

  test('query-graph answers the graph filter vocabulary with versioned JSON',
      () async {
    await writeConcept(
      bundle,
      'alpha.md',
      body: '# Alpha\n\n[beta](beta.md) and [out](https://example.com)',
    );
    await writeConcept(bundle, 'beta.md', type: 'Note', title: 'Beta');
    final server = await serve();

    final all = await server.graph(const <String, Object?>{});
    expect(all['schema_version'], '1');
    expect(_nodeIds(all), <String>['alpha', 'beta']);
    expect(_edgeKeys(all), <String>[
      'alpha -> beta.md (body/resolved-concept)',
      'alpha -> https://example.com (body/external)',
    ]);

    final references = await server.graph(const <String, Object?>{
      'types': <String>['Reference'],
    });
    expect(_nodeIds(references), <String>['alpha']);
    expect(_edgeKeys(references), <String>[
      'alpha -> https://example.com (body/external)',
    ]);

    final external = await server.graph(const <String, Object?>{
      'resolutions': <String>['external'],
    });
    expect(_nodeIds(external), <String>['alpha', 'beta']);
    expect(_edgeKeys(external), <String>[
      'alpha -> https://example.com (body/external)',
    ]);

    final underBeta = await server.graph(const <String, Object?>{
      'path_prefixes': <String>['beta'],
    });
    expect(_nodeIds(underBeta), <String>['beta']);
    expect(_edgeKeys(underBeta), isEmpty);
  });

  test('lists concepts and looks one up in canonical form', () async {
    await writeConcept(bundle, 'alpha.md');
    await writeConcept(
      bundle,
      'notes/beta.md',
      type: 'Note',
      title: 'Beta',
      frontmatter: const <String>['status: draft'],
    );
    final server = await serve();

    final listed =
        (await server.call('list-concepts'))['concepts']! as List<Object?>;
    expect(listed, <Map<String, Object?>>[
      <String, Object?>{
        'id': 'alpha',
        'path': 'alpha.md',
        'type': 'Reference',
        'title': 'Alpha',
        'status': 'stable',
        'trust_tier': 'unverified',
      },
      <String, Object?>{
        'id': 'notes/beta',
        'path': 'notes/beta.md',
        'type': 'Note',
        'title': 'Beta',
        'status': 'draft',
        'trust_tier': 'unverified',
      },
    ]);

    final looked = await server.call(
      'lookup-concept',
      const <String, Object?>{'id': 'notes/beta'},
    );
    expect(looked['id'], 'notes/beta');
    expect(looked['path'], 'notes/beta.md');
    expect(looked['status'], 'draft');
    expect(
      looked['markdown'],
      await File(p.join(bundle.path, 'notes', 'beta.md')).readAsString(),
    );
  });

  test('answers bad input with tool errors and keeps stdout JSON-RPC only',
      () async {
    await writeConcept(bundle, 'alpha.md');
    final server = await serve();

    final refusals = <Map<String, Object?>>[
      await server.callTool('query-graph', const <String, Object?>{
        'types': 'Reference',
      }),
      await server.callTool('query-graph', const <String, Object?>{
        'labels': <String>['unsupported'],
      }),
      await server.callTool('lookup-concept'),
      await server.callTool(
        'lookup-concept',
        const <String, Object?>{'id': 'alpha.md'},
      ),
      await server.callTool(
        'lookup-concept',
        const <String, Object?>{'id': 'missing'},
      ),
      await server.callTool('validate', const <String, Object?>{
        'strict': 'yes',
      }),
    ];
    for (final refusal in refusals) {
      expect(refusal['isError'], isTrue, reason: '${refusal['content']}');
      expect(refusal['content'], isNotEmpty);
    }

    final unknownTool = await server.send('tools/call', const <String, Object?>{
      'name': 'rename-concept',
      'arguments': <String, Object?>{},
    });
    expect(unknownTool['error'], isNotNull);

    await File(p.join(bundle.path, 'broken.md')).writeAsString(
      '---\ntype: Reference\nbroken: [\n',
    );
    final unreadableGraph = await server.callTool(
      'query-graph',
      const <String, Object?>{},
    );
    expect(unreadableGraph['isError'], isTrue);
    expect(
      jsonEncode(unreadableGraph['structuredContent']),
      contains('okf/invalid-document'),
    );

    final announced = server.stderrText.length;
    server.sendRaw('not json at all');

    await bundle.delete(recursive: true);
    for (final unreadable in <Map<String, Object?>>[
      await server.callTool('validate'),
      await server.callTool('create-concept', const <String, Object?>{
        'id': 'gamma',
        'type': 'Reference',
      }),
    ]) {
      expect(unreadable['isError'], isTrue);
    }

    await bundle.create();
    await writeConcept(bundle, 'alpha.md');
    expect(
      (await server.call('list-concepts'))['concepts'],
      hasLength(1),
    );

    expect(
      await server.awaitDiagnostic(after: announced),
      contains('not json at all'),
      reason: 'the malformed frame must be reported on stderr',
    );
    expect(server.stdoutLines, isNotEmpty);
    expect(server.stdoutLines, everyElement(predicate(_isJsonRpc, 'JSON-RPC')));
  });

  test('create-concept writes concept, index, and log in one operation',
      () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue',
    );
    final server = await serve();

    final result = await server.call('create-concept', <String, Object?>{
      'id': 'metrics/churn',
      'type': 'Metric',
      'title': 'Churn',
      'description': 'Monthly churn.',
      'tags': <String>['finance'],
      'body': '# Churn\n',
    });

    expect(
      result['changed_paths'],
      containsAll(<String>['metrics/churn.md', 'metrics/index.md', 'log.md']),
    );

    final concept =
        OkfDocument.parse(await readBundleFile(bundle, 'metrics/churn.md'));
    expect(concept.type, 'Metric');
    expect(concept.title, 'Churn');
    expect(concept.description, 'Monthly churn.');
    expect(concept.tags, <String>['finance']);
    expect(concept.body, '# Churn\n');

    expect(
      OkfIndexDocument.parse(await readBundleFile(bundle, 'metrics/index.md'))
          .entries,
      contains(
        const OkfIndexEntry(
          type: 'Metric',
          title: 'Churn',
          link: 'churn.md',
          description: 'Monthly churn.',
        ),
      ),
    );
    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    expect(log.entries.single.action, 'Created');
    expect(log.entries.single.description, '[Churn](metrics/churn.md)');

    final cli = await runCli(<String>['validate', 'bundle'], sandbox.path);
    expect(
      cli.exitCode,
      0,
      reason: 'the bundle the write path produced must pass the CLI gate',
    );
  });

  test('concurrent writes preserve every accepted change', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue',
    );
    final server = await serve();

    await Future.wait(<Future<Map<String, Object?>>>[
      server.call('create-concept', const <String, Object?>{
        'id': 'metrics/churn',
        'type': 'Metric',
        'title': 'Churn',
      }),
      server.call('create-concept', const <String, Object?>{
        'id': 'metrics/margin',
        'type': 'Metric',
        'title': 'Margin',
      }),
    ]);

    final index = OkfIndexDocument.parse(
      await readBundleFile(bundle, 'metrics/index.md'),
    );
    expect(
      index.entries.map((entry) => entry.title),
      containsAll(<String>['Churn', 'Margin', 'Revenue']),
    );
    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    expect(
      log.entries.map((entry) => entry.description),
      containsAll(<String>[
        '[Churn](metrics/churn.md)',
        '[Margin](metrics/margin.md)',
      ]),
    );
  });

  test('commits advisory-only changes and separates malformed input', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue',
    );
    final server = await serve();
    final advisory = await server.call('create-concept', <String, Object?>{
      'id': 'metrics/café',
      'type': 'Metric',
      'title': 'Café',
    });
    expect(advisory['changed_paths'], contains('metrics/café.md'));
    expect(
        await File(p.join(bundle.path, 'metrics', 'café.md')).exists(), isTrue);
    final validation = await server.call('validate');
    expect(
      _findingIds(validation),
      contains('okf/non-portable-concept-id'),
    );
    final before = await snapshotBundle(bundle);

    final rejected = <Map<String, Object?>>[
      await server.callTool('create-concept', const <String, Object?>{
        'id': 'metrics/churn',
      }),
      await server.callTool('create-concept', const <String, Object?>{
        'id': 'metrics/churn',
        'type': 'Metric',
        'tags': 'finance',
      }),
      await server.callTool('update-concept', const <String, Object?>{
        'id': 'metrics/revenue',
        'owner': 'finance-team',
      }),
      await server.callTool('update-concept', const <String, Object?>{
        'id': 'metrics/revenue',
      }),
      await server.callTool('create-concept', const <String, Object?>{
        'id': 'metrics/revenue',
        'type': 'Metric',
      }),
      await server.callTool('update-concept', const <String, Object?>{
        'id': 'metrics/missing',
        'title': 'Missing',
      }),
      await server.callTool('link-concepts', const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'metrics/revenue.md',
        'relationship': 'relates-to',
      }),
      await server.callTool('link-concepts', const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'metrics/revenue',
      }),
      await server.callTool('link-concepts', const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'metrics/revenue',
        'relationship': '  ',
      }),
      await server.callTool('link-concepts', const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'metrics/index',
        'relationship': 'relates-to',
      }),
      await server.callTool('link-concepts', const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'log',
        'relationship': 'relates-to',
      }),
      await server.callTool('deprecate-concept', const <String, Object?>{
        'id': 'metrics/missing',
      }),
      await server.callTool('deprecate-concept', const <String, Object?>{
        'id': 'metrics/revenue',
        'note': 7,
      }),
    ];
    for (final error in rejected) {
      expect(error['isError'], isTrue, reason: '${error['content']}');
      expect(
        error['structuredContent'],
        isNull,
        reason: 'input that describes no bundle state carries no Report',
      );
    }
    expect(await snapshotBundle(bundle), before);

    final idempotent = await server.call(
      'update-concept',
      const <String, Object?>{
        'id': 'metrics/revenue',
        'title': 'Revenue',
      },
    );
    expect(idempotent['changed_paths'], isEmpty);
    expect(await snapshotBundle(bundle), before);

    final reserved =
        await server.callTool('create-concept', const <String, Object?>{
      'id': 'metrics/index',
      'type': 'Metric',
      'title': 'Reserved',
    });
    expect(reserved['isError'], isTrue);
    expect(reserved['structuredContent'], isNull);
    expect(await snapshotBundle(bundle), before);

    await writeBundleFile(
      bundle,
      'log.md',
      '# Log\n\n* **Created**: [Revenue](metrics/revenue.md)\n',
    );
    final broken = await snapshotBundle(bundle);
    final refusedByLog =
        await server.callTool('create-concept', const <String, Object?>{
      'id': 'metrics/churn',
      'type': 'Metric',
      'title': 'Churn',
    });
    expect(
      _findingIds(refusedByLog['structuredContent']! as Map<String, Object?>),
      contains('okf/log-entry-before-date'),
      reason: 'a log the write path cannot re-emit refuses the whole change',
    );
    expect(await snapshotBundle(bundle), broken);

    expect(server.stdoutLines, everyElement(predicate(_isJsonRpc, 'JSON-RPC')));
  });

  test('update-concept preserves fields the tool does not manage', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue\n\nRecognized on delivery.',
      frontmatter: const <String>[
        'description: Monthly revenue.',
        'owner: finance-team',
        'review:',
        '  cadence: quarterly',
      ],
    );
    final server = await serve();

    final result = await server.call('update-concept', <String, Object?>{
      'id': 'metrics/revenue',
      'description': 'Recognized monthly revenue.',
    });
    expect(
      result['changed_paths'],
      containsAll(<String>['metrics/revenue.md', 'log.md']),
    );

    final document = OkfDocument.parse(
      await readBundleFile(bundle, 'metrics/revenue.md'),
    );
    expect(document.description, 'Recognized monthly revenue.');
    expect(document.type, 'Metric');
    expect(document.title, 'Revenue');
    expect(document.frontmatter['owner'], 'finance-team');
    expect(
      document.frontmatter['review'],
      <String, Object?>{'cadence': 'quarterly'},
    );
    expect(document.body, '# Revenue\n\nRecognized on delivery.\n');

    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    expect(log.entries.single.action, 'Updated');
  });

  test('link-concepts writes the source concept and the log in one operation',
      () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue',
    );
    await writeConcept(
      bundle,
      'metrics/churn.md',
      type: 'Metric',
      title: 'Churn',
      body: '# Churn',
    );
    final server = await serve();

    final result = await server.call('link-concepts', <String, Object?>{
      'source': 'metrics/revenue',
      'target': 'metrics/churn',
      'relationship': 'relates-to',
    });
    expect(
      result['changed_paths'],
      containsAll(<String>['metrics/revenue.md', 'log.md']),
    );

    final document = OkfDocument.parse(
      await readBundleFile(bundle, 'metrics/revenue.md'),
    );
    expect(document.frontmatter['sources'], <Object?>[
      <String, Object?>{'resource': 'churn.md', 'relationship': 'relates-to'},
    ]);
    expect(document.body, '# Revenue\n');

    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    expect(log.entries.single.action, 'Linked');
    expect(
      log.entries.single.description,
      '[Revenue](metrics/revenue.md) relates-to [Churn](metrics/churn.md)',
    );

    final cli = await runCli(<String>['validate', 'bundle'], sandbox.path);
    expect(
      cli.exitCode,
      0,
      reason: 'the bundle the write path produced must pass the CLI gate',
    );
  });

  test('link-concepts accepts an unresolved target', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
    );
    final server = await serve();

    final result = await server.call('link-concepts', <String, Object?>{
      'source': 'metrics/revenue',
      'target': 'planned/future-metric',
      'relationship': 'depends-on',
    });

    expect(
      result['changed_paths'],
      containsAll(<String>['metrics/revenue.md', 'log.md']),
    );
    final graph = await server.call('query-graph');
    expect(
      _edgeKeys(graph),
      contains(
        'metrics/revenue -> ../planned/future-metric.md '
        '(sources.resource/unresolved)',
      ),
    );
    expect(
      await readBundleFile(bundle, 'log.md'),
      contains('planned/future-metric'),
    );
  });

  test('link-concepts escapes an unresolved target in the log label', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
    );
    final server = await serve();

    const target = 'planned/x](mailto:attacker@example.com)[x';
    await server.call('link-concepts', const <String, Object?>{
      'source': 'metrics/revenue',
      'target': target,
      'relationship': 'depends-on',
    });

    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    final description = log.entries.single.description;
    expect(
      description,
      contains(
        r'planned\/x\]\(mailto\:attacker\@example\.com\)\[x',
      ),
    );
    expect(description, isNot(contains('](mailto:')));
    final rendered = md.markdownToHtml(
      description,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
    expect(RegExp('<a ').allMatches(rendered), hasLength(2));
    expect(rendered, isNot(contains('href="mailto:attacker@example.com"')));
    expect(rendered, contains(target));
  });

  test('deprecate-concept sets lifecycle status and writes the log entry',
      () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
      body: '# Revenue',
    );
    final server = await serve();

    final result = await server.call('deprecate-concept', <String, Object?>{
      'id': 'metrics/revenue',
      'note': 'Folded into churn.',
    });
    expect(
      result['changed_paths'],
      containsAll(<String>['metrics/revenue.md', 'log.md']),
    );

    expect(
      OkfDocument.parse(await readBundleFile(bundle, 'metrics/revenue.md'))
          .status,
      OkfLifecycleStatus.deprecated,
    );
    final log = OkfLogDocument.parse(await readBundleFile(bundle, 'log.md'));
    expect(log.entries.single.action, 'Deprecated');
    expect(
      log.entries.single.description,
      '[Revenue](metrics/revenue.md) \u2014 Folded into churn.',
    );

    final cli = await runCli(<String>['validate', 'bundle'], sandbox.path);
    expect(cli.exitCode, 0);
  });

  test('repeated link and deprecation calls write no files', () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      type: 'Metric',
      title: 'Revenue',
    );
    await writeConcept(
      bundle,
      'metrics/churn.md',
      type: 'Metric',
      title: 'Churn',
    );
    final server = await serve();
    const link = <String, Object?>{
      'source': 'metrics/revenue',
      'target': 'metrics/churn',
      'relationship': 'relates-to',
    };
    const deprecation = <String, Object?>{'id': 'metrics/churn'};
    await server.call('link-concepts', link);
    await server.call('deprecate-concept', deprecation);
    final before = await snapshotBundle(bundle);

    final repeatedLink = await server.call('link-concepts', link);
    final repeatedDeprecation =
        await server.call('deprecate-concept', deprecation);

    expect(repeatedLink['changed_paths'], isEmpty);
    expect(repeatedDeprecation['changed_paths'], isEmpty);
    expect(await snapshotBundle(bundle), before);
  });

  test('refuses a Spec-invalid link candidate without changing files',
      () async {
    await writeConcept(
      bundle,
      'metrics/revenue.md',
      includeType: false,
      title: 'Revenue',
      body: '# Revenue',
    );
    await writeConcept(
      bundle,
      'metrics/churn.md',
      type: 'Metric',
      title: 'Churn',
      body: '# Churn',
    );
    final server = await serve();
    final before = await snapshotBundle(bundle);

    final refusal = await server.callTool(
      'link-concepts',
      const <String, Object?>{
        'source': 'metrics/revenue',
        'target': 'metrics/churn',
        'relationship': 'relates-to',
      },
    );
    expect(refusal['isError'], isTrue);
    expect(
      _findingIds(refusal['structuredContent']! as Map<String, Object?>),
      contains('okf/missing-type'),
      reason: 'a refusal carries the finding IDs the CLI reports',
    );
    expect(await snapshotBundle(bundle), before);
    expect(server.stdoutLines, everyElement(predicate(_isJsonRpc, 'JSON-RPC')));
  });

  test('complete reads refuse a partial bundle while validate inspects it',
      () async {
    await writeConcept(bundle, 'alpha.md');
    await File(p.join(bundle.path, 'broken.md')).writeAsString(
      '---\ntype: Reference\nbroken: [\n',
    );
    final server = await serve();

    for (final result in <Map<String, Object?>>[
      await server.callTool('list-concepts'),
      await server.callTool(
        'lookup-concept',
        const <String, Object?>{'id': 'alpha'},
      ),
      await server.callTool('query-graph'),
    ]) {
      expect(result['isError'], isTrue);
      expect(
        jsonEncode(result['structuredContent']),
        contains('invalid-document'),
      );
    }

    final validation = await server.callTool('validate');
    expect(validation['isError'], isNot(true));
    expect(
      jsonEncode(validation['structuredContent']),
      contains('okf/invalid-document'),
    );
    expect(await server.awaitDiagnostic(), contains('1 unreadable file(s)'));
  });
}

List<String> _findingIds(Map<String, Object?> payload) => <String>[
      for (final finding in ((payload['report']!
              as Map<String, Object?>)['findings']! as List<Object?>)
          .cast<Map<String, Object?>>())
        finding['id']! as String,
    ];

bool _isJsonRpc(Object? line) {
  final Object? decoded;
  try {
    decoded = jsonDecode(line! as String);
  } on FormatException {
    return false;
  }
  return decoded is Map<String, Object?> && decoded['jsonrpc'] == '2.0';
}

List<String> _nodeIds(Map<String, Object?> graph) => <String>[
      for (final node
          in (graph['nodes']! as List<Object?>).cast<Map<String, Object?>>())
        node['id']! as String,
    ];

List<String> _edgeKeys(Map<String, Object?> graph) => <String>[
      for (final edge
          in (graph['edges']! as List<Object?>).cast<Map<String, Object?>>())
        '${edge['source']} -> ${edge['raw_target']} '
            '(${edge['origin']}/${edge['resolution']})',
    ];

/// A JSON-RPC client that drives `okf mcp` as a real subprocess.
final class _McpHarness {
  _McpHarness._(this._process);

  static Future<_McpHarness> start(String bundlePath) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      <String>['run', 'bin/okf.dart', 'mcp', bundlePath],
    );
    return _McpHarness._(process).._listen();
  }

  final Process _process;
  final List<String> stdoutLines = <String>[];
  final StringBuffer stderrText = StringBuffer();
  final Map<int, Completer<Map<String, Object?>>> _pending =
      <int, Completer<Map<String, Object?>>>{};
  int _nextId = 0;
  Completer<void>? _diagnostic;
  int _diagnosticAfter = 0;

  void _listen() {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_receive);
    _process.stderr.transform(utf8.decoder).listen(_receiveDiagnostic);
  }

  void _receive(String line) {
    stdoutLines.add(line);
    if (!_isJsonRpc(line)) {
      return;
    }
    final message = jsonDecode(line) as Map<String, Object?>;
    final id = message['id'];
    if (id is int) {
      _pending.remove(id)?.complete(message);
    }
  }

  /// Sends [line] verbatim, so the test can drive malformed frames.
  void sendRaw(String line) => _process.stdin.write('$line\n');

  /// Waits until standard error holds more than [after] characters.
  Future<String> awaitDiagnostic({int after = 0}) async {
    if (stderrText.length <= after) {
      _diagnosticAfter = after;
      _diagnostic = Completer<void>();
      await _diagnostic!.future.timeout(const Duration(seconds: 30));
    }
    return stderrText.toString();
  }

  void _receiveDiagnostic(String chunk) {
    stderrText.write(chunk);
    final waiter = _diagnostic;
    if (waiter != null &&
        !waiter.isCompleted &&
        stderrText.length > _diagnosticAfter) {
      waiter.complete();
    }
  }

  Future<void> initialize() async {
    await request('initialize', <String, Object?>{
      'protocolVersion': latestInitializationProtocolVersion,
      'capabilities': <String, Object?>{},
      'clientInfo': <String, Object?>{'name': 'okf-test', 'version': '1.0.0'},
    });
    _send(<String, Object?>{
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
  }

  Future<Map<String, Object?>> graph(Map<String, Object?> query) =>
      call('query-graph', query);

  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    final result = await callTool(name, arguments);
    expect(result['isError'], isNot(true), reason: '${result['content']}');
    return result['structuredContent']! as Map<String, Object?>;
  }

  Future<Map<String, Object?>> callTool(
    String name, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) =>
      request('tools/call', <String, Object?>{
        'name': name,
        'arguments': arguments,
      });

  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final message = await send(method, params);
    final error = message['error'];
    if (error != null) {
      fail('$method failed: ${jsonEncode(error)}');
    }
    return message['result']! as Map<String, Object?>;
  }

  Future<Map<String, Object?>> send(
    String method, [
    Map<String, Object?>? params,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _send(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    });
    return completer.future.timeout(const Duration(seconds: 60));
  }

  void _send(Map<String, Object?> message) {
    _process.stdin.write('${jsonEncode(message)}\n');
  }

  Future<void> stop() async {
    await _process.stdin.close();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill();
      await _process.exitCode;
      rethrow;
    }
  }
}
