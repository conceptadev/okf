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
      'numeric-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 7, 'unknown': true},
      ),
      'unknown-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Vendor Extension'},
      ),
    });

    final report = const OkfValidator().validate(bundle);

    expect(report.errorCount, 3);
    expect(report.warningCount, 1);
    expect(
      report.diagnostics.map((diagnostic) => diagnostic.code),
      containsAll(<String>[
        'missing_frontmatter',
        'missing_type',
        'type_not_string',
      ]),
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

    final report = const OkfValidator().validate(bundle);

    expect(report.isValid, isTrue);
    expect(report.diagnostics, isEmpty);
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

    final report = const OkfValidator().validate(bundle);
    final codes =
        report.diagnostics.map((diagnostic) => diagnostic.code).toList();

    expect(report.isValid, isFalse);
    expect(codes, contains('unsupported_okf_version'));
    expect(codes, contains('invalid_index_frontmatter'));
    expect(codes, contains('empty_index_section'));
    expect(codes, contains('invalid_log_frontmatter'));
    expect(codes, contains('invalid_log_date'));
    expect(codes, contains('invalid_log_structure'));
  });

  test('optional family shape problems remain warnings', () {
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

    final report = const OkfValidator().validate(bundle);

    expect(report.isValid, isTrue);
    expect(report.warningCount, greaterThanOrEqualTo(9));
    expect(report.toJson()['valid'], isTrue);
  });
}
