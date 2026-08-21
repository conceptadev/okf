import 'dart:convert';
import 'dart:io';

import 'package:okf/okf_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late OkfBundleChangeApplier changes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('okf-change-set-test-');
    changes = OkfBundleChangeApplier(
      clock: () => DateTime.utc(2026, 8, 18),
    );
    await _seedBundle(root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('prepare is non-mutating and commit writes the prepared candidate',
      () async {
    final before = await _snapshot(root);
    final preparation = await changes.prepare(root.path, _createChurn());

    expect(preparation, isA<OkfPreparationReady>());
    expect(await _snapshot(root), before);
    final prepared = (preparation as OkfPreparationReady).prepared;
    expect(prepared.validation.isConformant, isTrue);
    expect(
      prepared.validation.report.toJson(),
      const OkfSpecValidator()
          .validate(prepared.candidate.toBundle())
          .report
          .toJson(),
    );

    final result = await changes.commit(prepared);
    expect(
      result.changedPaths,
      containsAll(<String>['metrics/churn.md', 'metrics/index.md', 'log.md']),
    );
    expect(
      await _read(root, 'metrics/churn.md'),
      prepared.candidate.concepts['metrics/churn.md'],
    );

    final loaded = await const OkfBundleLoader().inspect(root.path);
    expect(
      loaded.validate().report.toJson(),
      prepared.validation.report.toJson(),
      reason: 'ordinary validation and preparation share the Spec report',
    );
  });

  test('a Spec-invalid candidate is refused without changing a file', () async {
    final before = await _snapshot(root);
    final result = await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfCreateConceptChange(
          id: OkfConceptId('metrics/untyped'),
          document: OkfDocument(),
        ),
      ]),
    );

    expect(result, isA<OkfPreparationRefused>());
    final refusal = result as OkfPreparationRefused;
    expect(refusal.validation.isConformant, isFalse);
    expect(
      refusal.validation.report.findings.map((finding) => finding.id.value),
      contains('okf/missing-type'),
    );
    expect(await _snapshot(root), before);
  });

  test('replacing a malformed file removes its stale load finding', () async {
    await File(p.join(root.path, 'fixed.md')).writeAsBytes(<int>[0xff]);
    final result = await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfCreateConceptChange(
          id: OkfConceptId('fixed'),
          document: OkfDocument(
            frontmatter: <String, Object?>{'type': 'Reference'},
          ),
        ),
      ]),
    );

    final prepared = (result as OkfPreparationReady).prepared;
    expect(prepared.validation.isConformant, isTrue);
    await changes.commit(prepared);

    final loaded = await const OkfBundleLoader().inspect(root.path);
    expect(
        loaded.validate().report.toJson(), prepared.validation.report.toJson());
  });

  test('prepare rejects file and directory path collisions', () async {
    final result = changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        for (final id in <String>['node', 'node.md/child'])
          OkfCreateConceptChange(
            id: OkfConceptId(id),
            document: OkfDocument(
              frontmatter: <String, Object?>{'type': 'Reference'},
            ),
          ),
      ]),
    );

    await expectLater(result, throwsA(isA<OkfBundleChangeException>()));
  });

  test('prepare rejects case-folded path collisions', () async {
    await _write(root, 'A.md', '''
---
type: Reference
---
''');

    await expectLater(
      changes.prepare(
        root.path,
        OkfBundleChangeSet(<OkfBundleChange>[
          OkfCreateConceptChange(
            id: OkfConceptId('a'),
            document: OkfDocument(
              frontmatter: <String, Object?>{'type': 'Reference'},
            ),
          ),
        ]),
      ),
      throwsA(isA<OkfBundleChangeException>()),
    );
  });

  for (final aliases in <({String existing, String added, String name})>[
    (existing: '\u00e9', added: 'e\u0301', name: 'canonical normalization'),
    (existing: '\u03a3', added: '\u03c2', name: 'Greek case folding'),
    (existing: '\u00df', added: 'SS', name: 'expanding case folding'),
    (existing: '\u017f', added: 'S', name: 'historic case folding'),
  ]) {
    test('prepare rejects ${aliases.name} path collisions', () async {
      await _write(root, '${aliases.existing}.md', '''
---
type: Reference
---
''');

      await expectLater(
        changes.prepare(
          root.path,
          OkfBundleChangeSet(<OkfBundleChange>[
            OkfCreateConceptChange(
              id: OkfConceptId(aliases.added),
              document: OkfDocument(
                frontmatter: <String, Object?>{'type': 'Reference'},
              ),
            ),
          ]),
        ),
        throwsA(isA<OkfBundleChangeException>()),
      );
    });
  }

  test('an advisory-only Unicode candidate can commit', () async {
    final result = await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfCreateConceptChange(
          id: OkfConceptId('metrics/évolution'),
          document: OkfDocument(
            frontmatter: <String, Object?>{'type': 'Metric'},
          ),
        ),
      ]),
    );

    final prepared = (result as OkfPreparationReady).prepared;
    expect(
      prepared.validation.report.findings.map((finding) => finding.id.value),
      contains('okf/non-portable-concept-id'),
    );
    expect(prepared.validation.isConformant, isTrue);
    await changes.commit(prepared);
    expect(await File(p.join(root.path, 'metrics', 'évolution.md')).exists(),
        isTrue);
  });

  test('an unresolved link is a conformant prepared change', () async {
    final result = await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfLinkConceptsChange(
          source: OkfConceptId('metrics/revenue'),
          target: OkfConceptId('planned/future'),
          relationship: 'depends-on',
        ),
      ]),
    );

    final prepared = (result as OkfPreparationReady).prepared;
    expect(prepared.validation.isConformant, isTrue);
    expect(
      OkfGraph.fromBundle(prepared.candidate.toBundle())
          .edges
          .singleWhere((edge) => edge.rawTarget.contains('future'))
          .resolution,
      OkfGraphResolution.unresolved,
    );
    await changes.commit(prepared);
    expect(await _read(root, 'log.md'), contains('planned/future'));
  });

  test('inspection cannot mutate the candidate or committed bytes', () async {
    final preparation = await changes.prepare(root.path, _createChurn());
    final prepared = (preparation as OkfPreparationReady).prepared;
    final expected = prepared.candidate.concepts['metrics/churn.md']!;

    expect(
      () => prepared.candidate.concepts['metrics/churn.md'] = 'forged',
      throwsUnsupportedError,
    );
    final detached = prepared.candidate.toBundle();
    detached.concept(OkfConceptId('metrics/churn'))!.frontmatter['title'] =
        'Forged';

    await changes.commit(prepared);
    expect(await _read(root, 'metrics/churn.md'), expected);
    expect(await _read(root, 'metrics/churn.md'), isNot(contains('Forged')));
  });

  test('commit rejects stale source state and reuse', () async {
    final first = (await changes.prepare(root.path, _createChurn())
            as OkfPreparationReady)
        .prepared;
    await _write(root, 'metrics/revenue.md',
        '${await _read(root, 'metrics/revenue.md')}\n');

    await expectLater(
      changes.commit(first),
      throwsA(isA<OkfStalePreparedChangeException>()),
    );
    expect(
        await File(p.join(root.path, 'metrics', 'churn.md')).exists(), isFalse);

    final second = (await changes.prepare(root.path, _createChurn())
            as OkfPreparationReady)
        .prepared;
    await changes.commit(second);
    expect(() => changes.commit(second), throwsStateError);
  });

  test('prepare rejects an uncommittable source topology', () async {
    await File(p.join(root.path, 'log.md')).delete();
    await _write(root, 'log.md/occupied.txt', 'not a log\n');
    final before = await _snapshot(root);

    await expectLater(
      changes.prepare(root.path, _createChurn(id: 'a/churn')),
      throwsA(isA<OkfBundleChangeException>()),
    );
    expect(await _snapshot(root), before);
    expect(await Directory(p.join(root.path, 'a')).exists(), isFalse);
  });

  test('update preserves unmanaged field order and body content', () async {
    await _write(root, 'metrics/revenue.md', '''
---
type: Metric
title: Revenue
description: Monthly revenue.
owner: finance-team
review:
  cadence: quarterly
---

$_richBody''');
    final prepared = (await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfUpdateConceptChange(
          id: OkfConceptId('metrics/revenue'),
          frontmatterChanges: const <String, Object?>{
            'description': 'Recognized monthly revenue.',
            'status': 'stable',
          },
        ),
      ]),
    ) as OkfPreparationReady)
        .prepared;

    await changes.commit(prepared);
    final document = OkfDocument.parse(await _read(root, 'metrics/revenue.md'));
    expect(document.frontmatter['owner'], 'finance-team');
    expect(document.frontmatter['review'], <String, Object?>{
      'cadence': 'quarterly',
    });
    expect(
      document.frontmatter.keys.where(
        const <String>{'owner', 'review'}.contains,
      ),
      <String>['owner', 'review'],
    );
    expect(document.body, _richBody);
  });

  test('unrelated authored indexes remain byte-identical', () async {
    const authored = '# Reference\n\n* [Note](note.md) - Hand ordered.\n';
    await _write(root, 'other/note.md', '''
---
type: Reference
title: Note
---
''');
    await _write(root, 'other/index.md', authored);
    final prepared = (await changes.prepare(root.path, _createChurn())
            as OkfPreparationReady)
        .prepared;

    await changes.commit(prepared);

    expect(await _read(root, 'other/index.md'), authored);
    expect(prepared.candidate.indexes['other/index.md'], authored);
  });

  test('an idempotent change writes no file', () async {
    final first = (await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfDeprecateConceptChange(id: OkfConceptId('metrics/revenue')),
      ]),
    ) as OkfPreparationReady)
        .prepared;
    await changes.commit(first);
    final before = await _snapshot(root);

    final second = (await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfDeprecateConceptChange(id: OkfConceptId('metrics/revenue')),
      ]),
    ) as OkfPreparationReady)
        .prepared;
    final result = await changes.commit(second);

    expect(result.changedPaths, isEmpty);
    expect(await _snapshot(root), before);
  });

  test('an empty update is idempotent', () async {
    final before = await _snapshot(root);
    final prepared = (await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfUpdateConceptChange(id: OkfConceptId('metrics/revenue')),
      ]),
    ) as OkfPreparationReady)
        .prepared;

    final result = await changes.commit(prepared);

    expect(result.changedPaths, isEmpty);
    expect(await _snapshot(root), before);
  });

  test('non-index updates preserve an authored index in the same directory',
      () async {
    final authored = '${await _read(root, 'metrics/index.md')}\n';
    await _write(root, 'metrics/index.md', authored);
    final prepared = (await changes.prepare(
      root.path,
      OkfBundleChangeSet(<OkfBundleChange>[
        OkfUpdateConceptChange(
          id: OkfConceptId('metrics/revenue'),
          body: '# Revenue\n\nExpanded narrative.\n',
        ),
      ]),
    ) as OkfPreparationReady)
        .prepared;

    await changes.commit(prepared);

    expect(await _read(root, 'metrics/index.md'), authored);
    expect(prepared.candidate.indexes['metrics/index.md'], authored);
  });

  test('changes that describe no state remain tool errors', () async {
    await expectLater(
      changes.prepare(
        root.path,
        OkfBundleChangeSet(<OkfBundleChange>[
          OkfCreateConceptChange(
            id: OkfConceptId('metrics/revenue'),
            document: OkfDocument(
              frontmatter: <String, Object?>{'type': 'Metric'},
            ),
          ),
        ]),
      ),
      throwsA(isA<OkfBundleChangeException>()),
    );
  });

  test('apply serializes preparation and commit for concurrent callers',
      () async {
    final results = await Future.wait(<Future<OkfBundleApplication>>[
      changes.apply(root.path, _createChurn(id: 'metrics/churn')),
      changes.apply(root.path, _createChurn(id: 'metrics/margin')),
    ]);

    expect(results, everyElement(isA<OkfBundleApplied>()));
    final loaded = await const OkfBundleLoader().inspect(root.path);
    expect(
      loaded.bundle.concepts.keys.map((id) => id.value),
      containsAll(<String>['metrics/churn', 'metrics/margin']),
    );
    expect(
      OkfLogDocument.parse(loaded.logs['log.md']!).entries.map(
            (entry) => entry.description,
          ),
      containsAll(<String>[
        '[Churn](metrics/churn.md)',
        '[Churn](metrics/margin.md)',
      ]),
    );
  });
}

const String _richBody = '''
# Revenue

Recognized revenue, see [churn](churn.md).
''';

OkfBundleChangeSet _createChurn({String id = 'metrics/churn'}) =>
    OkfBundleChangeSet(<OkfBundleChange>[
      OkfCreateConceptChange(
        id: OkfConceptId(id),
        document: OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Metric',
            'title': 'Churn',
            'description': 'Monthly churn.',
          },
          body: '# Churn\n',
        ),
      ),
    ]);

Future<void> _seedBundle(Directory root) async {
  await _write(root, 'metrics/revenue.md', '''
---
type: Metric
title: Revenue
description: Monthly revenue.
---

# Revenue
''');
  await _write(root, 'index.md', '''
---
okf_version: "0.2"
---

# Subdirectories

* [metrics](metrics/index.md) - Monthly revenue.
''');
  await _write(root, 'metrics/index.md', '''
# Metric

* [Revenue](revenue.md) - Monthly revenue.
''');
  await _write(root, 'log.md', '''
# Log

## 2026-08-01

* **Created**: [Revenue](metrics/revenue.md)
''');
}

Future<String> _read(Directory root, String relativePath) =>
    File(p.joinAll(<String>[root.path, ...p.posix.split(relativePath)]))
        .readAsString();

Future<Map<String, String>> _snapshot(Directory root) async {
  final files = <String, String>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      files[p.relative(entity.path, from: root.path)] =
          base64Encode(await entity.readAsBytes());
    }
  }
  return files;
}

Future<void> _write(Directory root, String relativePath, String content) async {
  final file =
      File(p.joinAll(<String>[root.path, ...p.posix.split(relativePath)]));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
