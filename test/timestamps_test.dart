import 'package:okf/okf.dart';
import 'package:okf/src/timestamps.dart';
import 'package:test/test.dart';

void main() {
  const frontmatter = <String, Object?>{
    'type': 'Reference',
    'generated': <String, Object?>{'by': 'agent/v1', 'at': '2026-06-20'},
    'verified': <Object?>[
      <String, Object?>{'by': 'human:reviewer', 'at': '2026-06-25T09:00:00Z'},
      <String, Object?>{'by': 'process:nightly', 'at': '2026-06-26T09:00:00'},
    ],
    'stale_after': '2026-09-23',
    'usage_window': <String, Object?>{
      'from': '2026-06-01',
      'to': '2026-06-30T00:00:00Z',
    },
    'sources': <Object?>[
      <String, Object?>{
        'resource': 'https://example.com/policy',
        'last_modified': '2026-05-30',
        'usage_window': <String, Object?>{
          'from': '2026-07-01',
          'to': '2026-07-07',
        },
      },
    ],
  };

  List<OkfFinding> offsetFindings(Map<String, Object?> frontmatter) =>
      const OkfSpecValidator()
          .validate(
            OkfBundle.fromDocuments(<String, OkfDocument>{
              'concept.md': OkfDocument(frontmatter: frontmatter),
            }),
          )
          .report
          .findings
          .where(
            (finding) => finding.id.value == 'okf/timestamp-without-offset',
          )
          .toList();

  test('visits every timestamp location', () {
    final paths = <String>[];
    visitOkfTimestamps(frontmatter, (path, value) => paths.add(path));
    expect(paths, <String>[
      'generated.at',
      'verified[0].at',
      'verified[1].at',
      'stale_after',
      'usage_window.from',
      'usage_window.to',
      'sources[0].last_modified',
      'sources[0].usage_window.from',
      'sources[0].usage_window.to',
    ]);
  });

  test('reports date-only and offset-less timestamps as advisories', () {
    final findings = offsetFindings(frontmatter);
    // Reports order findings by message, not by frontmatter position.
    expect(
      findings.map((finding) => finding.message),
      unorderedMatches(<Matcher>[
        startsWith('generated.at is the date 2026-06-20'),
        startsWith('verified[1].at is 2026-06-26T09:00:00, which has no UTC'),
        startsWith('stale_after is the date 2026-09-23'),
        startsWith('usage_window.from is the date 2026-06-01'),
        startsWith('sources[0].last_modified is the date 2026-05-30'),
        startsWith('sources[0].usage_window.from is the date 2026-07-01'),
        startsWith('sources[0].usage_window.to is the date 2026-07-07'),
      ]),
    );
    expect(
      findings.every(
        (finding) => finding.severity == OkfFindingSeverity.advisory,
      ),
      isTrue,
    );
  });

  test('a bundle carrying date-only timestamps stays conformant', () {
    final validation = const OkfSpecValidator().validate(
      OkfBundle.fromDocuments(<String, OkfDocument>{
        'concept.md': OkfDocument(frontmatter: frontmatter),
      }),
    );

    expect(offsetFindings(frontmatter), isNotEmpty);
    expect(validation.isConformant, isTrue);
  });

  test('date-only values read as midnight UTC only where a date was valid', () {
    final metadata = OkfMetadata.fromFrontmatter(frontmatter);

    // stale_after, usage_window and last_modified accepted a date before this
    // revision, so a date-only value keeps reading as midnight UTC.
    expect(metadata.staleAfter, DateTime.utc(2026, 9, 23));
    expect(metadata.usageWindow?.from, DateTime.utc(2026, 6, 1));
    expect(metadata.sources.single.lastModified, DateTime.utc(2026, 5, 30));
    // generated.at and verified[].at have always required a time, so a
    // date-only value carries no instant and no verification.
    expect(metadata.generated?.atDateTime, isNull);
    expect(metadata.verified.first.atDateTime, isNotNull);
  });

  test('migrates date-only timestamps and leaves the rest', () {
    final migration = migrateDateOnlyTimestamps(frontmatter);

    expect(migration.changes, <String>[
      'generated.at 2026-06-20 -> 2026-06-20T00:00:00Z',
      'stale_after 2026-09-23 -> 2026-09-23T00:00:00Z',
      'usage_window.from 2026-06-01 -> 2026-06-01T00:00:00Z',
      'sources[0].last_modified 2026-05-30 -> 2026-05-30T00:00:00Z',
      'sources[0].usage_window.from 2026-07-01 -> 2026-07-01T00:00:00Z',
      'sources[0].usage_window.to 2026-07-07 -> 2026-07-07T00:00:00Z',
    ]);
    expect(frontmatter['stale_after'], '2026-09-23');
    expect(
      offsetFindings(migration.frontmatter).map((finding) => finding.message),
      <Matcher>[startsWith('verified[1].at is 2026-06-26T09:00:00')],
    );
    expect(migrateDateOnlyTimestamps(migration.frontmatter).changes, isEmpty);
  });

  test('returns the same mapping when nothing changes', () {
    const current = <String, Object?>{
      'type': 'Reference',
      'stale_after': '2026-09-23T00:00:00Z',
    };
    expect(
      identical(migrateDateOnlyTimestamps(current).frontmatter, current),
      isTrue,
    );
  });
}
