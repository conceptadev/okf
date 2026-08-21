import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('generates indexes deepest-first and excludes reserved files', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'datasets/ga4.md': _document(
          'BigQuery Dataset',
          title: 'GA4',
          description: 'GA4 obfuscated ecommerce sample.',
        ),
        'tables/events.md': _document(
          'BigQuery Table',
          title: 'Events',
          description: 'Daily event rows.',
        ),
        'tables/users.md': _document('BigQuery Table', title: 'users'),
        'métricas/receita líquida.md': _document(
          'Metric',
          title: 'Receita líquida',
        ),
      },
      indexes: <String, String>{'index.md': '# Old\n* [Old](old.md)\n'},
      logs: <String, String>{
        'log.md': '# Log\n## 2026-07-27\n* Update\n',
      },
    );

    final generated = const OkfIndexGenerator().generate(bundle);

    expect(
      generated.keys,
      orderedEquals(<String>[
        'datasets/index.md',
        'métricas/index.md',
        'tables/index.md',
        'index.md',
      ]),
    );
    expect(generated['tables/index.md'], startsWith('# BigQuery Table\n'));
    expect(
      generated['tables/index.md']!.indexOf('[Events]'),
      lessThan(generated['tables/index.md']!.indexOf('[users]')),
    );
    expect(
        generated['métricas/index.md'], contains('receita%20l%C3%ADquida.md'));

    final root = generated['index.md']!;
    expect(root, isNot(contains('log.md')));
    expect(root, contains('(datasets/index.md) - GA4 obfuscated'));
    expect(root, contains('(tables/index.md) - Contains 2 entries:'));
  });

  test('preserves or explicitly declares the root OKF version', () {
    final document = _document('Reference', title: 'A');
    final preserved = OkfBundle.fromDocuments(
      <String, OkfDocument>{'a.md': document},
      indexes: <String, String>{
        'index.md': '''
---
okf_version: " 0.2 "
---
# Old
* [A](a.md)
''',
      },
    );

    final generated = const OkfIndexGenerator().generate(preserved);
    expect(generated['index.md'], startsWith('---\nokf_version: "0.2"'));

    final overridden = const OkfIndexGenerator().generate(
      preserved,
      declareVersion: '0.3',
    );
    expect(overridden['index.md'], startsWith('---\nokf_version: "0.3"'));
  });

  test('uses an injected deterministic directory description', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'group/a.md': _document('Reference', title: 'A'),
      'group/b.md': _document('Reference', title: 'B'),
    });
    final generator = OkfIndexGenerator(
      synthesizeDescription: (directory, entries) =>
          '$directory has ${entries.length} things',
    );

    final generated = generator.generate(bundle);

    expect(
      generated['index.md'],
      contains('(group/index.md) - group has 2 things'),
    );
  });

  test('falls back deterministically when a synthesizer fails', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'group/a.md': _document('Reference', title: 'A'),
      'group/b.md': _document('Reference', title: 'B'),
    });
    final generator = OkfIndexGenerator(
      synthesizeDescription: (_, __) => throw Exception('offline'),
    );

    expect(
      generator.generate(bundle)['index.md'],
      contains('(group/index.md) - Contains 2 entries: A, B.'),
    );
  });

  test('keeps existing asset-only indexed directories discoverable', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'overview.md': _document('Reference', title: 'Overview'),
      },
      indexes: <String, String>{
        'attesters/index.md':
            '# Attester\n\n* [check.py](check.py) - Checks receipts.\n',
      },
      assets: <String>['attesters/check.py'],
    );

    final generated = const OkfIndexGenerator().generate(bundle);

    expect(generated['index.md'], contains('[attesters](attesters/index.md)'));
    expect(generated, isNot(contains('attesters/index.md')));
  });
}

OkfDocument _document(
  String type, {
  String? title,
  String? description,
}) =>
    OkfDocument(
      frontmatter: <String, Object?>{
        'type': type,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      },
    );
