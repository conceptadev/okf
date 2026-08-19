import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('finding IDs use one namespace and code segment', () {
    expect(
      OkfFindingId.parse('vendor/rule-code'),
      OkfFindingId.fromParts('vendor', 'rule-code'),
    );
    expect(OkfFindingId.okf('missing-type').value, 'okf/missing-type');
    expect(OkfFindingId.okf('x').namespace, OkfFindingId.baseNamespace);
    expect(OkfFindingId.parse('v2/rule-0').code, 'rule-0');

    for (final invalid in <String>[
      'missing-namespace',
      '/missing-namespace',
      'missing-code/',
      'too/many/segments',
      'white space/code',
      'Vendor/rule',
      'vendor/Rule_Code',
      'vendor/rule.code',
      'vendor/-leading-hyphen',
      'vendor/double--hyphen',
      'trailing-/code',
      'vendor/non-ascii-é',
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
      id: OkfFindingId.parse('vendor/review-needed'),
      severity: OkfFindingSeverity.advisory,
      message: 'Review this value.',
      location: OkfFindingLocation(path: 'concept.md', line: 4, column: 2),
    );
    final suppression = OkfFindingSuppression(
      id: OkfFindingId.parse('vendor/review-needed'),
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

  test('findings, locations, and suppressions are values', () {
    OkfFinding finding({String path = 'a.md', int? line, int? column}) =>
        OkfFinding(
          id: OkfFindingId.okf('sample'),
          severity: OkfFindingSeverity.error,
          message: 'Sample.',
          location: OkfFindingLocation(path: path, line: line, column: column),
        );

    expect(finding(line: 3, column: 1), finding(line: 3, column: 1));
    expect(finding(line: 3, column: 1).hashCode,
        finding(line: 3, column: 1).hashCode);
    expect(finding(line: 3), isNot(finding(line: 4)));
    expect(finding(path: 'b.md'), isNot(finding()));
    expect(
      OkfFindingSuppression(id: OkfFindingId.okf('sample'), note: 'n'),
      OkfFindingSuppression(id: OkfFindingId.okf('sample'), note: 'n'),
    );
    expect(
      OkfFindingSuppression(id: OkfFindingId.okf('sample')),
      isNot(OkfFindingSuppression(id: OkfFindingId.okf('sample'), note: 'n')),
    );

    expect('${finding()}', 'a.md: error okf/sample: Sample.');
    expect('${finding(line: 3)}', 'a.md:3: error okf/sample: Sample.');
    expect('${finding(line: 3, column: 1)}',
        'a.md:3:1: error okf/sample: Sample.');
    expect(
      '${OkfFinding(
        id: OkfFindingId.okf('sample'),
        severity: OkfFindingSeverity.advisory,
        message: 'Sample.',
      )}',
      'advisory okf/sample: Sample.',
    );
    expect(finding(line: 3).toJson(), <String, Object?>{
      'id': 'okf/sample',
      'severity': 'error',
      'message': 'Sample.',
      'location': <String, Object?>{'path': 'a.md', 'line': 3},
    });
    expect(OkfFindingSeverity.advisory.wireValue, 'advisory');
  });

  test('reports hold findings in one canonical order', () {
    OkfFinding finding(
      String id,
      String message, {
      String? path,
      int? line,
      int? column,
      OkfFindingSeverity severity = OkfFindingSeverity.error,
    }) =>
        OkfFinding(
          id: OkfFindingId.parse(id),
          severity: severity,
          message: message,
          location: path == null
              ? null
              : OkfFindingLocation(path: path, line: line, column: column),
        );
    final findings = <OkfFinding>[
      finding('okf/b-rule', 'Late file.', path: 'b.md'),
      finding('okf/no-location', 'No location.'),
      finding('okf/z-rule', 'Early line.', path: 'a.md', line: 2),
      finding('okf/a-rule', 'Later line.', path: 'a.md', line: 9),
      finding('okf/a-rule', 'Same spot, later ID.', path: 'a.md', line: 2),
      finding(
        'okf/a-rule',
        'Same spot, advisory.',
        path: 'a.md',
        line: 2,
        severity: OkfFindingSeverity.advisory,
      ),
    ];

    final report = OkfReport(findings: findings);
    expect(
      report.findings.map((item) => item.message),
      orderedEquals(<String>[
        'No location.',
        'Same spot, later ID.',
        'Same spot, advisory.',
        'Early line.',
        'Later line.',
        'Late file.',
      ]),
    );
    // Producer order does not leak into either projection.
    final reversed = OkfReport(findings: findings.reversed);
    expect(reversed.findings, report.findings);
    expect(reversed.toText(), report.toText());
    expect(reversed.toJson(), report.toJson());
    expect(() => report.findings.clear(), throwsUnsupportedError);
    expect(() => report.activeFindings.clear(), throwsUnsupportedError);
  });

  test('verdict owns the validation exit-code matrix', () {
    final error = OkfFinding(
      id: OkfFindingId.okf('invalid'),
      severity: OkfFindingSeverity.error,
      message: 'Invalid.',
    );
    final advisory = OkfFinding(
      id: OkfFindingId.okf('review'),
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
            OkfFindingSuppression(id: OkfFindingId.okf('invalid')),
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
