import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('validates only type and frontmatter as concept hard requirements', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'missing-frontmatter.md': OkfDocument(
        body: '# Body',
        hasFrontmatter: false,
      ),
      'missing-type.md': OkfDocument(),
      'empty-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': '   '},
      ),
      'numeric-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 7, 'unknown': true},
      ),
      'unknown-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Vendor Extension'},
      ),
    });

    final report = const OkfSpecValidator().validate(bundle).report;

    expect(
      report.findings
          .where((finding) => finding.severity == OkfFindingSeverity.error),
      hasLength(4),
    );
    expect(
      report.findings.where(
        (finding) => finding.severity == OkfFindingSeverity.advisory,
      ),
      hasLength(1),
    );
    expect(
      report.findings.map((finding) => finding.id.value),
      containsAll(<String>[
        'okf/missing-frontmatter',
        'okf/missing-type',
        'okf/type-not-string',
      ]),
    );
    expect(
      report.findings.where(
        (finding) => finding.id == OkfFindingId.okf('missing-type'),
      ),
      hasLength(3),
    );
  });

  test('accepts conformant reserved files', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'concept.md': OkfDocument(
          frontmatter: <String, Object?>{'type': 'Reference'},
        ),
      },
      indexes: <String, String>{
        'index.md': '''
---
okf_version: "0.2"
---

# References

- [Concept](concept.md) - A concept.
''',
      },
      logs: <String, String>{
        'log.md': '''
# Bundle Update Log

## 2026-07-27
- **Creation**: Added [Concept](concept.md).

## 2026-07-20
* **Initialization**: Created the bundle.
''',
      },
    );

    final report = const OkfSpecValidator().validate(bundle).report;

    expect(report.findings, isEmpty);
  });

  test('reports reserved structure violations and unknown versions', () {
    final bundle = OkfBundle.fromDocuments(
      const <String, OkfDocument>{},
      indexes: <String, String>{
        'index.md': '''
---
okf_version: "9.0"
---
# Empty
''',
        'nested/index.md': '''
---
okf_version: "0.2"
---
# Things
* [Thing](thing.md)
''',
      },
      logs: <String, String>{
        'log.md': '''
---
type: Log
title: Producer inconsistency
---
# Log
## 2026-02-30
Narrative instead of a list item.
''',
      },
    );

    final report = const OkfSpecValidator().validate(bundle).report;
    final codes = report.findings.map((finding) => finding.id.value).toList();

    expect(OkfVerdict.of(report).exitCode, 1);
    expect(codes, contains('okf/unsupported-okf-version'));
    expect(codes, contains('okf/invalid-index-frontmatter'));
    expect(codes, contains('okf/empty-index-section'));
    expect(codes, contains('okf/invalid-log-frontmatter'));
    expect(codes, contains('okf/invalid-log-date'));
    expect(codes, contains('okf/invalid-log-structure'));
  });

  test('optional family shape problems remain advisory', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      '計算.md': OkfDocument(
        frontmatter: <String, Object?>{
          'type': 'Attested Computation',
          'tags': 'finance',
          'sources': <Object?>[
            <String, Object?>{'title': 'Missing resource'},
          ],
          'generated': <String, Object?>{'at': 'yesterday'},
          'verified': <Object?>[],
          'status': 'archived',
          'stale_after': 'soon',
          'parameters': <Object?>[
            <String, Object?>{'name': 'year'},
          ],
          'executor': <String, Object?>{},
        },
      ),
    });

    final report = const OkfSpecValidator().validate(bundle).report;

    expect(OkfVerdict.of(report).exitCode, 0);
    expect(
      report.findings
          .where(
            (finding) => finding.severity == OkfFindingSeverity.advisory,
          )
          .length,
      greaterThanOrEqualTo(9),
    );
    expect(
      (report.toJson()['findings']! as List<Object?>).first,
      containsPair('id', startsWith('okf/')),
    );
  });
}
