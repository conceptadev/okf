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

  test('report projects findings deterministically', () {
    final finding = OkfFinding(
      id: OkfFindingId.parse('vendor/review-needed'),
      severity: OkfFindingSeverity.advisory,
      message: 'Review this value.',
      location: OkfFindingLocation(path: 'concept.md', line: 4, column: 2),
    );
    final report = OkfReport(findings: <OkfFinding>[finding]);

    expect(
      report.toText(),
      'concept.md:4:2: advisory vendor/review-needed: Review this value.',
    );
    expect(report.toTextLines(), <String>[report.toText()]);
    expect(OkfReport().toTextLines(), isEmpty);
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
        },
      ],
    });
  });

  test('findings and locations are values', () {
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

  test('finding locations enforce their canonical shape at runtime', () {
    expect(() => OkfFindingLocation(path: ''), throwsArgumentError);
    expect(
      () => OkfFindingLocation(path: 'concept.md', line: 0),
      throwsArgumentError,
    );
    expect(
      () => OkfFindingLocation(path: 'concept.md', line: -1),
      throwsArgumentError,
    );
    expect(
      () => OkfFindingLocation(path: 'concept.md', column: 1),
      throwsArgumentError,
    );
    expect(
      () => OkfFindingLocation(path: 'concept.md', line: 1, column: 0),
      throwsArgumentError,
    );
    expect(
      () => OkfFindingLocation(path: 'concept.md', line: 1, column: -1),
      throwsArgumentError,
    );

    const malformedPath = '../invalid\\path\n.md';
    final location = OkfFindingLocation(path: malformedPath);
    expect(location.path, malformedPath);
    expect('$location', r'../invalid\path\u{000a}.md');
  });

  test('finding text escapes controls while JSON retains raw values', () {
    const path = 'invalid\npath.md';
    const message = 'First line\nSecond\tline\u0085done';
    final finding = OkfFinding(
      id: OkfFindingId.okf('multiline'),
      severity: OkfFindingSeverity.error,
      message: message,
      location: OkfFindingLocation(path: path),
    );
    final report = OkfReport(findings: <OkfFinding>[finding]);

    expect(
      report.toText(),
      r'invalid\u{000a}path.md: error okf/multiline: First line\u{000a}Second'
      r'\u{0009}line\u{0085}done',
    );
    expect(report.toText().split('\n'), hasLength(1));
    expect(
      (report.toJson()['findings']! as List<Object?>).single,
      allOf(
        containsPair('message', message),
        containsPair('location', <String, Object?>{'path': path}),
      ),
    );
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
      // Differs from the previous finding only by message, so the last
      // comparison tier is the only thing that can order the pair.
      finding('okf/a-rule', 'Same spot, earlier text.', path: 'a.md', line: 2),
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
        'Same spot, earlier text.',
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
  });

  test('Spec conformance depends only on OKF Spec errors', () {
    final advisory = OkfFinding(
      id: OkfFindingId.okf('review'),
      severity: OkfFindingSeverity.advisory,
      message: 'Review.',
    );
    final error = OkfFinding(
      id: OkfFindingId.okf('invalid'),
      severity: OkfFindingSeverity.error,
      message: 'Invalid.',
    );

    final advisoryOnly = OkfSpecValidation(
      OkfReport(findings: <OkfFinding>[advisory]),
    );
    final invalid = OkfSpecValidation(
      OkfReport(findings: <OkfFinding>[advisory, error]),
    );

    expect(advisoryOnly.isConformant, isTrue);
    expect(invalid.isConformant, isFalse);
    expect(advisoryOnly.report.findings, <OkfFinding>[advisory]);
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
