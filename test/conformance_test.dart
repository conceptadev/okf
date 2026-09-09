import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('accepts every tolerant-reader case from OKF 0.2 section 11', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'minimal.md': OkfDocument(
          frontmatter: <String, Object?>{'type': 'Vendor Type'},
          body: '[not written yet](missing.md)',
        ),
        'extended.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Reference',
            'vendor_extension': <String, Object?>{'retained': true},
            'verified': <String, Object?>{
              'by': 'human:reviewer',
              'at': '2026-08-19T00:00:00Z',
            },
          },
        ),
      },
      indexes: <String, String>{
        'index.md': '''
---
okf_version: "future"
---

# Concepts

- [Minimal](minimal.md)
''',
      },
    );

    final validation = const OkfSpecValidator().validate(bundle);

    expect(validation.isConformant, isTrue);
    expect(
      validation.report.findings.map((finding) => finding.id.value),
      everyElement(
        isNot(
          anyOf(
            'okf/missing-frontmatter',
            'okf/missing-type',
            'okf/invalid-reserved-document',
            'okf/invalid-index-structure',
          ),
        ),
      ),
    );
    expect(
      validation.report.findings.map((finding) => finding.id.value),
      contains('okf/unsupported-okf-version'),
    );
    expect(
      OkfGraph.fromBundle(bundle).edges.single.resolution,
      OkfGraphResolution.unresolved,
    );
    expect(
      bundle.concept(OkfConceptId('extended'))!.metadata.latestVerification?.by,
      'human:reviewer',
    );
  });

  test('accepts a conformant bundle without index files', () {
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'concept.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 'Reference'},
      ),
    });

    final validation = const OkfSpecValidator().validate(bundle);

    expect(validation.isConformant, isTrue);
    expect(validation.report.findings, isEmpty);
  });

  test('reports every section 11 hard requirement as an error', () {
    final invalid = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'no-frontmatter.md': OkfDocument(hasFrontmatter: false),
        'no-type.md': OkfDocument(),
      },
      logs: <String, String>{'log.md': '# Log\n\n## not-a-date\n'},
    );

    final validation = const OkfSpecValidator().validate(invalid);
    final findings = validation.report.findings;

    expect(validation.isConformant, isFalse);
    expect(
      findings.map((finding) => finding.id.value),
      orderedEquals(<String>[
        'okf/invalid-log-structure',
        'okf/missing-log-date',
        'okf/missing-frontmatter',
        'okf/missing-type',
        'okf/missing-type',
      ]),
    );
    expect(
      findings.map((finding) => finding.severity),
      everyElement(OkfFindingSeverity.error),
    );
  });
}
