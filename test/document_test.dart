import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  group('OkfDocument.parse', () {
    test('reads ordered YAML frontmatter and Markdown body', () {
      const source = '''
---
type: BigQuery Table
title: Customer Orders
tags: [sales, orders]
custom:
  enabled: true
  weights: [1, 2]
---

# Customer Orders

One row per order.
''';

      final document = OkfDocument.parse(source);

      expect(document.hasFrontmatter, isTrue);
      expect(
        document.frontmatter.keys,
        orderedEquals(<String>['type', 'title', 'tags', 'custom']),
      );
      expect(document.type, 'BigQuery Table');
      expect(document.tags, <String>['sales', 'orders']);
      expect(document.frontmatter['custom'], <Object?, Object?>{
        'enabled': true,
        'weights': <Object?>[1, 2],
      });
      expect(document.body, startsWith('# Customer Orders'));
      expect(document.body, endsWith('\n'));
    });

    test('treats a body-only file as syntactically consumable', () {
      const source = '# Hello\r\n\r\nNo frontmatter here.';

      final document = OkfDocument.parse(source);

      expect(document.hasFrontmatter, isFalse);
      expect(document.frontmatter, isEmpty);
      expect(document.body, '# Hello\n\nNo frontmatter here.');
      expect(document.serialize(), '# Hello\n\nNo frontmatter here.\n');
    });

    test('accepts whitespace around delimiter lines', () {
      final document = OkfDocument.parse(
        '  ---  \r\ntype: Reference\r\n  ---\r\n\r\nBody\r\n',
      );

      expect(document.type, 'Reference');
      expect(document.body, 'Body\n');
    });

    test('rejects unterminated frontmatter with source context', () {
      expect(
        () => OkfDocument.parse(
          '---\ntype: Reference\n',
          sourcePath: 'concepts/example.md',
        ),
        throwsA(
          isA<OkfDocumentException>()
              .having(
                (error) => error.message,
                'message',
                contains('Unterminated'),
              )
              .having(
                (error) => error.sourcePath,
                'sourcePath',
                'concepts/example.md',
              ),
        ),
      );
    });

    test('rejects malformed YAML and reports a source position', () {
      try {
        OkfDocument.parse(
          '---\ntype: [unterminated\n---\n',
          sourcePath: 'bad.md',
        );
        fail('Expected malformed YAML to throw.');
      } on OkfDocumentException catch (error) {
        expect(error, isA<FormatException>());
        expect(error.message, contains('Invalid YAML'));
        expect(error.sourcePath, 'bad.md');
        expect(error.line, isNotNull);
        expect(error.column, isNotNull);
      }
    });

    test('rejects a non-mapping frontmatter value', () {
      expect(
        () => OkfDocument.parse('---\n- one\n- two\n---\n'),
        throwsA(
          isA<OkfDocumentException>().having(
            (error) => error.message,
            'message',
            contains('YAML mapping'),
          ),
        ),
      );
    });
  });

  group('OkfDocument serialization', () {
    test('uses preferred keys then preserves extension insertion order', () {
      final document = OkfDocument(
        frontmatter: <String, Object?>{
          'z_extension': 'last-ish',
          'sources': <Object?>[],
          'title': 'Orders',
          'type': 'BigQuery Table',
          'runtime': 'bigquery',
          'a_extension': <String, Object?>{'answer': 42},
        },
        body: '# Orders',
      );

      final serialized = document.serialize();

      expect(
        serialized,
        startsWith(
          '---\n'
          'type: BigQuery Table\n'
          'title: Orders\n'
          'sources: []\n'
          'runtime: bigquery\n'
          'z_extension: last-ish\n'
          'a_extension:\n'
          '  answer: 42\n'
          '---\n\n',
        ),
      );
      expect(serialized, endsWith('# Orders\n'));

      final reparsed = OkfDocument.parse(serialized);
      expect(reparsed.frontmatter, document.frontmatter);
      expect(reparsed.body, '# Orders\n');
    });

    test('quotes ambiguous strings without changing semantic values', () {
      final document = OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Reference',
          'looks_boolean': 'true',
          'looks_null': 'null',
          'date': '2026-07-27',
          'unicode': 'Conhecimento útil',
          'multiline': 'first\nsecond',
          'colon_space': 'BigQuery Table: votes',
          'trailing_colon': 'Label:',
        },
      );

      final serialized = document.serialize();
      final reparsed = OkfDocument.parse(serialized);

      expect(reparsed.frontmatter, document.frontmatter);
      expect(serialized, contains('looks_boolean: "true"'));
      expect(serialized, contains('date: "2026-07-27"'));
      expect(serialized, contains('unicode: "Conhecimento útil"'));
      expect(serialized, contains('colon_space: "BigQuery Table: votes"'));
      expect(serialized, contains('trailing_colon: "Label:"'));
    });

    test('rejects unsupported values and cyclic Dart collections', () {
      final cyclic = <Object?>[];
      cyclic.add(cyclic);

      expect(
        () => OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Reference',
            'unsupported': const Duration(seconds: 1),
          },
        ).serialize(),
        throwsA(isA<OkfYamlEncodeException>()),
      );
      expect(
        () => OkfDocument(
          frontmatter: <String, Object?>{'type': 'Reference', 'cyclic': cyclic},
        ).serialize(),
        throwsA(isA<OkfYamlEncodeException>()),
      );
    });

    test('round-trips nested source and verification structures', () {
      const source = '''
---
type: Metric
verified: {by: "human:ana", at: "2026-07-20T12:00:00Z"}
sources:
  - id: policy
    resource: https://example.com/policy
    custom_signal:
      confidence: 0.8
unknown_top: [one, {two: 2}]
---

Body.
''';
      final first = OkfDocument.parse(source);
      final second = OkfDocument.parse(first.serialize());

      expect(second.frontmatter, first.frontmatter);
      expect(second.body, first.body);
      expect(second.trustTier, OkfTrustTier.humanReviewed);
    });

    test('serializes an explicitly empty frontmatter block', () {
      final document = OkfDocument();

      expect(document.serialize(), '---\n---\n\n');
      final reparsed = OkfDocument.parse(document.serialize());
      expect(reparsed.hasFrontmatter, isTrue);
      expect(reparsed.frontmatter, isEmpty);
      expect(reparsed.body, isEmpty);
    });

    test('copyWith preserves unknown values', () {
      final original = OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Reference',
          'vendor': <String, Object?>{'flag': true},
        },
        body: 'Old',
      );

      final updated = original.copyWith(body: 'New');

      expect(updated.frontmatter['vendor'], <String, Object?>{'flag': true});
      expect(updated.body, 'New');
      expect(original.body, 'Old');
    });
  });

  group('legacy citations', () {
    test('extracts numbered links only from top-level Citations sections', () {
      final document = OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
        body: '''
# Context

[9] [Not a citation](https://example.com/no)

# Citations

[1] [Policy](https://example.com/policy)
[2] [Runbook](../references/runbook.md)

# Other

[3] [Outside](https://example.com/outside)
''',
      );

      expect(document.legacyCitations, <OkfLegacyCitation>[
        const OkfLegacyCitation(
          number: 1,
          title: 'Policy',
          target: 'https://example.com/policy',
          raw: '[1] [Policy](https://example.com/policy)',
        ),
        const OkfLegacyCitation(
          number: 2,
          title: 'Runbook',
          target: '../references/runbook.md',
          raw: '[2] [Runbook](../references/runbook.md)',
        ),
      ]);
      expect(document.hasLegacyCitations, isTrue);
      expect(document.citations, document.legacyCitations);
    });

    test('extracts the bullet-list form shown by the v0.1 specification', () {
      final document = OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
        body: '''
# Citations

- https://wiki.example/fpa-handbook
* [Revenue policy](https://wiki.example/revenue_(policy))
''',
      );

      expect(
        document.legacyCitations.map((citation) => citation.target).toList(),
        <String>[
          'https://wiki.example/fpa-handbook',
          'https://wiki.example/revenue_(policy)',
        ],
      );
    });
  });

  test('rejects cyclic YAML aliases without overflowing the stack', () {
    expect(
      () => OkfDocument.parse('''
---
type: Reference
cycle: &cycle [*cycle]
---
'''),
      throwsA(
        isA<OkfDocumentException>().having(
          (error) => error.message,
          'message',
          anyOf(
            contains('Cyclic YAML aliases'),
            contains('Self-referential collections'),
          ),
        ),
      ),
    );
  });
}
