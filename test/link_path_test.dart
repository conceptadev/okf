import 'package:okf/okf.dart';
import 'package:okf/src/link_path.dart';
import 'package:test/test.dart';

/// Real reference filenames from the first migration's QA corpus.
const List<String> _realFilenames = <String>[
  'C-Fee_NetPayCalculator20200601 (1).xlsx',
  'C2-CleanSuite 2.0 — Pre-Development Requirements & Gap '
      'Analysis-July29.pdf',
  'Gap—Analysis-July29.pdf',
];

void main() {
  test('encoded segments carry no character the entry grammar rejects', () {
    expect(
      encodeOkfLinkSegment('C-Fee_NetPayCalculator20200601 (1).xlsx'),
      'C-Fee_NetPayCalculator20200601%20%281%29.xlsx',
    );
    for (final filename in _realFilenames) {
      expect(
        okfLinkDestinationUnsafe.hasMatch(encodeOkfLinkSegment(filename)),
        isFalse,
        reason: filename,
      );
    }
  });

  test('encoded paths keep separators and readable dots', () {
    expect(
      encodeOkfLinkPath('references/C-Fee (1).xlsx'),
      'references/C-Fee%20%281%29.xlsx',
    );
    expect(encodeOkfLinkPath('../tables/events.md'), '../tables/events.md');
  });

  test('decoding inverts encoding for real reference filenames', () {
    for (final filename in _realFilenames) {
      expect(
        decodeOkfLinkSegment(encodeOkfLinkSegment(filename)),
        filename,
        reason: filename,
      );
    }
    expect(decodeOkfLinkSegment('a%zz'), isNull);
    expect(decodeOkfLinkSegment('100%'), isNull);
  });

  test('encoder output round-trips through the index writer and parser', () {
    final document = OkfIndexDocument(
      entries: <OkfIndexEntry>[
        for (final filename in _realFilenames)
          OkfIndexEntry(
            type: 'Reference',
            title: filename,
            link: encodeOkfLinkPath(filename),
            description: 'Verbatim original.',
          ),
      ],
    );

    final parsed = OkfIndexDocument.parse(document.serialize());

    expect(parsed.issues, isEmpty);
    expect(
      parsed.entries.map((entry) => entry.link),
      _realFilenames.map(encodeOkfLinkPath),
    );
  });
}
