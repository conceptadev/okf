import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  group('OkfConceptId', () {
    test('round-trips a safe Unicode document path', () {
      final id = OkfConceptId.fromDocumentPath('métricas/receita líquida.md');

      expect(id.value, 'métricas/receita líquida');
      expect(id.documentPath, 'métricas/receita líquida.md');
      expect(id.directory, 'métricas');
      expect(id.basename, 'receita líquida');
      expect(id.isPortableAscii, isFalse);
    });

    test('reports the portable producer convention', () {
      expect(OkfConceptId('tables/customer-orders').isPortableAscii, isTrue);
      expect(OkfConceptId('_meta/v2.1').isPortableAscii, isTrue);
      expect(OkfConceptId('has space').isPortableAscii, isFalse);
    });

    test('rejects suffixes, traversal, separators, and control characters', () {
      for (final value in <String>[
        '',
        '/rooted',
        'thing.md',
        'a//b',
        'a/./b',
        'a/../b',
        r'a\b',
        'a/\u0000b',
      ]) {
        expect(() => OkfConceptId(value), throwsFormatException, reason: value);
      }
    });

    test('keeps reserved filenames out of the concept namespace', () {
      expect(
        () => OkfConceptId.fromDocumentPath('nested/index.md'),
        throwsFormatException,
      );
      expect(
        () => OkfConceptId.fromDocumentPath('log.md'),
        throwsFormatException,
      );

      // Reserved names are exact and case-sensitive.
      expect(
        OkfConceptId.fromDocumentPath('Index.md').value,
        'Index',
      );
    });
  });

  test('OkfBundle exposes a deterministic inventory', () {
    final bundle = OkfBundle.fromDocuments(
      <String, OkfDocument>{
        'z.md': OkfDocument(frontmatter: <String, Object?>{'type': 'Z'}),
        'a/a.md': OkfDocument(frontmatter: <String, Object?>{'type': 'A'}),
      },
      indexes: <String, String>{'index.md': '# Root\n'},
      logs: <String, String>{'a/log.md': '# Log\n'},
      assets: <String>['references/query.sql'],
    );

    expect(
      bundle.allPaths,
      orderedEquals(<String>[
        'a/a.md',
        'a/log.md',
        'index.md',
        'references/query.sql',
        'z.md',
      ]),
    );
    expect(bundle.conceptAtPath('a/a.md')?.type, 'A');
    expect(bundle.containsPath('../outside'), isFalse);
  });
}
