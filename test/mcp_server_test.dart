import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  test('advertises the fixed read tool surface', () async {
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
      <String>{'list-concepts', 'lookup-concept', 'query-graph', 'validate'},
    );
    for (final tool in byName.values) {
      expect(tool['annotations'], <String, Object?>{
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

    final findings = ((await server.callTool('validate'))['structuredContent']!
        as Map<String, Object?>)['report']! as Map<String, Object?>;
    expect(
      (findings['findings']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((finding) => finding['id']),
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
      'name': 'create-concept',
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
    final unreadable = await server.callTool('validate');
    expect(unreadable['isError'], isTrue);

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
      expect(jsonEncode(result['structuredContent']),
          contains('invalid-document'));
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
