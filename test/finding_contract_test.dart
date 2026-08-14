import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('finding IDs use one namespace and code segment', () {
    expect(
      OkfFindingId.parse('vendor/rule-code'),
      OkfFindingId.fromParts('vendor', 'rule-code'),
    );
    expect(OkfFindingId.okf('missing-type').value, 'okf/missing-type');

    for (final invalid in <String>[
      'missing-namespace',
      '/missing-namespace',
      'missing-code/',
      'too/many/segments',
      'white space/code',
    ]) {
      expect(
        () => OkfFindingId.parse(invalid),
        throwsFormatException,
        reason: invalid,
      );
    }
  });

  test('report projects findings and their suppression state', () {
    final finding = OkfFinding(
      id: OkfFindingId('vendor/review-needed'),
      severity: OkfFindingSeverity.advisory,
      message: 'Review this value.',
      location: OkfFindingLocation(path: 'concept.md', line: 4, column: 2),
    );
    final suppression = OkfFindingSuppression(
      id: OkfFindingId('vendor/review-needed'),
      note: 'Accepted for this bundle.',
    );

    final report = OkfReport(
      findings: <OkfFinding>[finding],
      suppressions: <OkfFindingSuppression>[suppression],
    );

    expect(report.suppressedCount, 1);
    expect(report.activeFindings, isEmpty);
    expect(
      report.toText(),
      'concept.md:4:2: advisory vendor/review-needed: Review this value. '
      '(suppressed: Accepted for this bundle.)',
    );
    expect(report.toJson(), <String, Object?>{
      'findings': <Object?>[
        <String, Object?>{
          'id': 'vendor/review-needed',
          'severity': 'advisory',
          'message': 'Review this value.',
          'location': <String, Object?>{
            'path': 'concept.md',
            'line': 4,
            'column': 2,
          },
          'suppressed': true,
          'suppression_note': 'Accepted for this bundle.',
        },
      ],
      'suppressed_count': 1,
    });
  });

  test('verdict owns the validation exit-code matrix', () {
    final error = OkfFinding(
      id: OkfFindingId('okf/invalid'),
      severity: OkfFindingSeverity.error,
      message: 'Invalid.',
    );
    final advisory = OkfFinding(
      id: OkfFindingId('okf/review'),
      severity: OkfFindingSeverity.advisory,
      message: 'Review.',
    );

    expect(OkfVerdict.of(OkfReport()).exitCode, 0);
    expect(OkfVerdict.of(OkfReport(findings: <OkfFinding>[error])).exitCode, 1);
    expect(
      OkfVerdict.of(OkfReport(findings: <OkfFinding>[advisory])).exitCode,
      0,
    );
    expect(
      OkfVerdict.of(
        OkfReport(findings: <OkfFinding>[advisory]),
        strict: true,
      ).exitCode,
      1,
    );
    expect(
      OkfVerdict.of(
        OkfReport(
          findings: <OkfFinding>[error],
          suppressions: <OkfFindingSuppression>[
            OkfFindingSuppression(id: OkfFindingId('okf/invalid')),
          ],
        ),
      ).exitCode,
      0,
    );
    expect(OkfExitCode.usage.value, 2);
  });

  test('verdict judges the same report instance it exposes', () {
    final report = OkfReport(
      findings: <OkfFinding>[
        OkfFinding(
          id: OkfFindingId.okf('review'),
          severity: OkfFindingSeverity.advisory,
          message: 'Review.',
        ),
      ],
    );
    final verdict = OkfVerdict.of(report, strict: true);

    expect(verdict.report, same(report));
    expect(verdict.strict, isTrue);
    expect(verdict.result, OkfExitCode.findings);
  });
}
