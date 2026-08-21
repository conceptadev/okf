import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('index and log entry data share one public model seam', () {
    const indexEntry = OkfIndexEntry(
      type: 'Reference',
      title: 'Example',
      link: 'example.md',
      description: 'An example concept.',
    );
    const logEntry = OkfLogEntry(
      date: '2026-08-14',
      action: 'Creation',
      description: 'Added [Example](example.md).',
    );

    expect(indexEntry.link, 'example.md');
    expect(logEntry.date, '2026-08-14');
    expect(logEntry.action, 'Creation');
    expect(logEntry.description, contains('[Example]'));
  });

  test('index and log entries are values', () {
    const indexEntry = OkfIndexEntry(
      type: 'Reference',
      title: 'Example',
      link: 'example.md',
      description: '',
    );
    const logEntry = OkfLogEntry(
      date: '2026-08-14',
      action: 'Creation',
      description: 'Added [Example](example.md).',
    );

    expect(
      indexEntry,
      const OkfIndexEntry(
        type: 'Reference',
        title: 'Example',
        link: 'example.md',
        description: '',
      ),
    );
    expect(
      indexEntry.hashCode,
      const OkfIndexEntry(
        type: 'Reference',
        title: 'Example',
        link: 'example.md',
        description: '',
      ).hashCode,
    );
    expect(
      indexEntry,
      isNot(
        const OkfIndexEntry(
          type: 'Reference',
          title: 'Example',
          link: 'other.md',
          description: '',
        ),
      ),
    );
    expect(
      logEntry,
      const OkfLogEntry(
        date: '2026-08-14',
        action: 'Creation',
        description: 'Added [Example](example.md).',
      ),
    );
    expect(
      logEntry,
      isNot(
        const OkfLogEntry(
          date: '2026-08-15',
          action: 'Creation',
          description: 'Added [Example](example.md).',
        ),
      ),
    );
  });
}
