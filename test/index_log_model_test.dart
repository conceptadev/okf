import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('index entries survive an emit and parse round trip', () {
    final document = OkfIndexDocument(
      okfVersion: '0.2',
      entries: const <OkfIndexEntry>[
        OkfIndexEntry(
          type: 'BigQuery Table',
          title: 'Events',
          link: 'events.md',
          description: 'Daily event rows.',
        ),
        OkfIndexEntry(
          type: 'BigQuery Table',
          title: 'Users [beta]',
          link: 'users.md',
          description: '',
        ),
        OkfIndexEntry(
          type: r'Metric \ #Tagged',
          title: 'Receita líquida',
          link: 'receita%20l%C3%ADquida.md',
          description: 'Net revenue - after returns.',
        ),
      ],
    );

    final parsed = OkfIndexDocument.parse(document.serialize());

    expect(parsed.entries, document.entries);
    expect(parsed.okfVersion, '0.2');
    expect(parsed.issues, isEmpty);
    expect(parsed.toDocument().serialize(), document.serialize());
  });

  test('log entries survive an emit and parse round trip', () {
    final document = OkfLogDocument(
      title: 'Bundle Update Log',
      entries: const <OkfLogEntry>[
        OkfLogEntry(
          date: '2026-08-14',
          action: 'Creation',
          description: 'Added [Events](events.md).',
        ),
        OkfLogEntry(
          date: '2026-08-14',
          action: 'Link',
          description: 'Linked [Events](events.md) to [GA4](ga4.md).',
        ),
        OkfLogEntry(
          date: '2026-07-27',
          action: '',
          description: 'Created the bundle.',
        ),
      ],
    );

    final parsed = OkfLogDocument.parse(document.serialize());

    expect(parsed.entries, document.entries);
    expect(parsed.title, 'Bundle Update Log');
    expect(parsed.issues, isEmpty);
    expect(parsed.toDocument().serialize(), document.serialize());
  });

  test('emitted logs group dates newest first', () {
    final serialized = OkfLogDocument(
      title: 'Log',
      entries: const <OkfLogEntry>[
        OkfLogEntry(date: '2026-07-27', action: '', description: 'Older.'),
        OkfLogEntry(date: '2026-08-14', action: 'Creation', description: 'A.'),
      ],
    ).serialize();

    expect(
      serialized,
      '# Log\n\n## 2026-08-14\n\n* **Creation**: A.\n\n'
      '## 2026-07-27\n\n* Older.\n',
    );
  });

  test('generated indexes parse back through the model', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'tables/events.md': OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'BigQuery Table',
          'title': 'Events',
          'description': 'Daily event rows.',
        },
      ),
    });

    final generated = const OkfIndexGenerator().generate(bundle);
    final parsed = OkfIndexDocument.parse(generated['tables/index.md']!);

    expect(parsed.issues, isEmpty);
    expect(
      parsed.entries,
      const <OkfIndexEntry>[
        OkfIndexEntry(
          type: 'BigQuery Table',
          title: 'Events',
          link: 'events.md',
          description: 'Daily event rows.',
        ),
      ],
    );
  });

  test('index parsing reports structural problems in document order', () {
    final parsed = OkfIndexDocument.parse(
      '* [Orphan](orphan.md)\n\n# Empty\n\n# Things\n\nNarrative line.\n'
      '* [Thing](thing.md)\n',
    );

    expect(
      parsed.issues,
      const <OkfIndexIssue>[
        OkfIndexIssue.entryBeforeSection,
        OkfIndexIssue.emptySection,
        OkfIndexIssue.unrecognizedLine,
      ],
    );
    expect(parsed.entries.map((entry) => entry.type), <String>['Things']);
  });

  test('an index without sections reports a missing section', () {
    expect(
      OkfIndexDocument.parse('').issues,
      const <OkfIndexIssue>[OkfIndexIssue.missingSection],
    );
  });

  test('log parsing reports structural problems in document order', () {
    final parsed = OkfLogDocument.parse(
      '# Log\n\n* Orphan entry.\n\n## 2026-02-30\n\n## 2026-07-27\n\n'
      '* Older.\n\n## 2026-08-14\n\nNarrative line.\n\n* Newer.\n',
    );

    expect(
      parsed.issues,
      const <OkfLogIssue>[
        OkfLogIssue.entryBeforeDate,
        OkfLogIssue.invalidDate,
        OkfLogIssue.emptyDate,
        OkfLogIssue.notNewestFirst,
        OkfLogIssue.unrecognizedLine,
      ],
    );
    expect(
      parsed.entries.map((entry) => entry.date),
      <String>['2026-07-27', '2026-08-14'],
    );
  });

  test('emitted documents satisfy the rules that read them', () {
    final index = OkfIndexDocument(
      okfVersion: '0.2',
      entries: const <OkfIndexEntry>[
        OkfIndexEntry(
          type: 'Reference',
          title: 'Concept',
          link: 'concept.md',
          description: 'A concept.',
        ),
      ],
    ).serialize();
    final log = OkfLogDocument(
      title: 'Bundle Update Log',
      entries: const <OkfLogEntry>[
        OkfLogEntry(
          date: '2026-07-27',
          action: 'Initialization',
          description: 'Created the bundle.',
        ),
        OkfLogEntry(
          date: '2026-08-14',
          action: 'Creation',
          description: 'Added [Concept](concept.md).',
        ),
      ],
    ).serialize();

    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'concept.md': OkfDocument(
          frontmatter: <String, Object?>{'type': 'Reference'},
        ),
      },
      indexes: <String, String>{'index.md': index},
      logs: <String, String>{'log.md': log},
    );

    expect(const OkfSpecValidator().validate(bundle).report.findings, isEmpty);
  });

  test('a log without a title or dates reports both', () {
    expect(
      OkfLogDocument.parse('').issues,
      const <OkfLogIssue>[OkfLogIssue.missingTitle, OkfLogIssue.missingDate],
    );
  });

  test('writable documents reject states their rules reject', () {
    expect(
      () => OkfIndexDocument(entries: const <OkfIndexEntry>[]),
      throwsArgumentError,
    );
    expect(
      () => OkfIndexDocument(
        entries: const <OkfIndexEntry>[
          OkfIndexEntry(
            type: 'Reference',
            title: '',
            link: 'concept.md',
            description: '',
          ),
        ],
      ),
      throwsArgumentError,
    );
    for (final link in <String>['line\nbreak.md', 'line\rbreak.md']) {
      expect(
        () => OkfIndexDocument(
          entries: <OkfIndexEntry>[
            OkfIndexEntry(
              type: 'Reference',
              title: 'Concept',
              link: link,
              description: '',
            ),
          ],
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => OkfLogDocument(title: 'Log', entries: const <OkfLogEntry>[]),
      throwsArgumentError,
    );
    expect(
      () => OkfLogDocument(
        title: 'Log',
        entries: const <OkfLogEntry>[
          OkfLogEntry(date: '2026-02-30', action: '', description: 'Invalid.'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => OkfLogDocument(
        title: 'Log',
        entries: const <OkfLogEntry>[
          OkfLogEntry(
            date: '2026-08-14',
            action: '',
            description: '**Creation**: Ambiguous.',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('parsed malformed dates remain available to reporting rules', () {
    final parsed = OkfLogDocument.parse(
      '# Log\n\n## 2026-02-30\n\n* Still represented.\n',
    );

    expect(parsed.issues, contains(OkfLogIssue.invalidDate));
    expect(
      parsed.entries,
      const <OkfLogEntry>[
        OkfLogEntry(
          date: '2026-02-30',
          action: '',
          description: 'Still represented.',
        ),
      ],
    );
    expect(parsed.toDocument, throwsStateError);
  });

  test('parsed frontmatter cannot be silently discarded on re-emission', () {
    final index = OkfIndexDocument.parse('''
---
okf_version: "0.2"
extension: retained
---
# Reference
* [Concept](concept.md)
''');
    final log = OkfLogDocument.parse('''
---
extension: retained
---
# Log
## 2026-08-14
* Created.
''');

    expect(index.toDocument, throwsStateError);
    expect(log.toDocument, throwsStateError);
  });

  test('writable indexes canonicalize text without reordering entries', () {
    final document = OkfIndexDocument(
      okfVersion: ' 0.3 ',
      entries: const <OkfIndexEntry>[
        OkfIndexEntry(
          type: ' A ',
          title: ' First\nentry ',
          link: 'first.md',
          description: ' First   description. ',
        ),
        OkfIndexEntry(
          type: 'B',
          title: 'Second',
          link: 'second.md',
          description: '',
        ),
        OkfIndexEntry(
          type: 'A',
          title: 'Third',
          link: 'third.md',
          description: '',
        ),
      ],
    );

    final parsed = OkfIndexDocument.parse(document.serialize());

    expect(
      document.entries.map((entry) => entry.type),
      <String>['A', 'B', 'A'],
    );
    expect(document.entries.first.title, 'First entry');
    expect(document.entries.first.description, 'First description.');
    expect(parsed.entries, document.entries);
    expect(parsed.okfVersion, ' 0.3 ');
    expect(parsed.issues, isEmpty);
  });

  test('writable logs canonicalize text and store dates newest first', () {
    final document = OkfLogDocument(
      title: ' # Audit\nLog ',
      entries: const <OkfLogEntry>[
        OkfLogEntry(
          date: '2026-07-27',
          action: '',
          description: ' Older   entry. ',
        ),
        OkfLogEntry(
          date: '2026-08-14',
          action: ' Creation ',
          description: ' Newer\nentry. ',
        ),
      ],
    );

    final parsed = OkfLogDocument.parse(document.serialize());

    expect(document.title, '# Audit Log');
    expect(
      document.entries,
      const <OkfLogEntry>[
        OkfLogEntry(
          date: '2026-08-14',
          action: 'Creation',
          description: 'Newer entry.',
        ),
        OkfLogEntry(
          date: '2026-07-27',
          action: '',
          description: 'Older entry.',
        ),
      ],
    );
    expect(parsed.title, document.title);
    expect(parsed.entries, document.entries);
    expect(parsed.issues, isEmpty);
  });
}
