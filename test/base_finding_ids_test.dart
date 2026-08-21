import 'package:okf/okf.dart';
import 'package:test/test.dart';

void main() {
  test('read-only descriptors pin every stable OKF finding ID', () {
    expect(
      okfSpecRuleDescriptors.map((descriptor) => descriptor.id.value),
      orderedEquals(<String>[
        'okf/invalid-document',
        'okf/invalid-path',
        'okf/invalid-utf8',
        'okf/missing-frontmatter',
        'okf/missing-type',
        'okf/type-not-string',
        'okf/non-portable-concept-id',
        'okf/invalid-tags',
        'okf/invalid-sources',
        'okf/invalid-source',
        'okf/invalid-usage-window',
        'okf/invalid-generated',
        'okf/invalid-verified',
        'okf/invalid-status',
        'okf/invalid-stale-after',
        'okf/missing-computation-runtime',
        'okf/invalid-computation-parameters',
        'okf/invalid-executor',
        'okf/invalid-attester',
        'okf/invalid-reserved-document',
        'okf/invalid-index-frontmatter',
        'okf/unsupported-okf-version',
        'okf/empty-index-section',
        'okf/index-entry-before-section',
        'okf/invalid-index-structure',
        'okf/missing-index-section',
        'okf/invalid-log-frontmatter',
        'okf/missing-log-title',
        'okf/empty-log-date',
        'okf/invalid-log-date',
        'okf/log-not-newest-first',
        'okf/log-entry-before-date',
        'okf/invalid-log-structure',
        'okf/missing-log-date',
      ]),
    );
    expect(
      okfSpecRuleDescriptors.every(
        (descriptor) =>
            descriptor.id.namespace == OkfFindingId.baseNamespace &&
            descriptor.prose.isNotEmpty &&
            descriptor.specReference.isNotEmpty,
      ),
      isTrue,
    );
    expect(() => okfSpecRuleDescriptors.clear(), throwsUnsupportedError);
  });

  test('closed validator produces one immutable Spec judgment', () {
    const validator = OkfSpecValidator();
    final bundle = OkfBundle.fromDocuments(<String, OkfDocument>{
      'missing-frontmatter.md': OkfDocument(
        body: '# Body',
        hasFrontmatter: false,
      ),
      'missing-type.md': OkfDocument(),
      'numeric-type.md': OkfDocument(
        frontmatter: <String, Object?>{'type': 7},
      ),
    });

    final first = validator.validate(bundle);
    final second = validator.validate(bundle);

    expect(first, isA<OkfSpecValidation>());
    expect(first.isConformant, isFalse);
    expect(first.report, isA<OkfReport>());
    expect(first.report.toJson(), second.report.toJson());
    expect(
      first.report.findings.map((finding) => finding.id.value),
      containsAll(<String>[
        'okf/missing-frontmatter',
        'okf/missing-type',
        'okf/type-not-string',
      ]),
    );
    expect(
      first.report.findings.every(
        (finding) => finding.id.namespace == OkfFindingId.baseNamespace,
      ),
      isTrue,
    );
  });
}
