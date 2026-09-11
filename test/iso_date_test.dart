import 'package:okf/okf.dart';
import 'package:okf/src/iso_date.dart';
import 'package:test/test.dart';

void main() {
  group('parseIsoDateTime', () {
    test('accepts ISO 8601 date-times', () {
      for (final value in [
        '2026-09-11T17:46:35Z',
        '2026-09-11T17:46:35.123Z',
        '2026-09-11T17:46:35+02:00',
        '2026-09-11T17:46:35+0200',
        '2026-09-11T17:46',
        '20260911T174635Z',
        '2024-02-29T00:00:00Z',
      ]) {
        expect(parseIsoDateTime(value), isNotNull, reason: value);
      }
      expect(
        parseIsoDateTime('2026-09-11T17:46:35+02:00'),
        DateTime.utc(2026, 9, 11, 15, 46, 35),
      );
    });

    test('rejects out-of-range fields instead of rolling them over', () {
      for (final value in [
        '2026-13-40T17:46:35Z',
        '2026-09-11T25:61:61Z',
        '2026-02-30T10:00:00Z',
        '2025-02-29T00:00:00Z',
        '2026-09-11T24:00:00Z',
        '2026-09-11T17:46:35+24:00',
        '2026-09-11',
        '2026-09-11 17:46:35Z',
        'Tomorrow',
      ]) {
        expect(parseIsoDateTime(value), isNull, reason: value);
      }
    });
  });

  test('impossible generation and verification times are advisories', () {
    OkfSpecValidation validate(String at) => const OkfSpecValidator().validate(
      OkfBundle.fromDocuments(<String, OkfDocument>{
        'concept.md': OkfDocument(
          frontmatter: <String, Object?>{
            'type': 'Reference',
            'generated': <String, Object?>{'by': 'agent/v1', 'at': at},
            'verified': <String, Object?>{'by': 'human:reviewer', 'at': at},
          },
        ),
      }, indexes: const <String, String>{}),
    );
    List<String> ids(OkfSpecValidation validation) =>
        validation.report.findings.map((finding) => finding.id.value).toList();

    expect(
      ids(validate('2026-09-11T17:46:35Z')),
      isNot(
        anyOf(
          contains('okf/invalid-generated'),
          contains('okf/invalid-verified'),
        ),
      ),
    );
    final impossible = validate('2026-02-30T10:00:00Z');
    expect(
      ids(impossible),
      containsAll(<String>['okf/invalid-generated', 'okf/invalid-verified']),
    );
    expect(impossible.isConformant, isTrue);
  });

  test('an impossible verification time is not usable', () {
    expect(
      OkfVerification.tryParse(<String, Object?>{
        'by': 'human:reviewer',
        'at': '2026-02-30T10:00:00Z',
      })!.isUsable,
      isFalse,
    );
  });
}
