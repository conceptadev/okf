import '../finding.dart';
import '../index_log.dart';
import 'context.dart';
import 'rule.dart';

/// Fixed Spec rules over reserved `index.md` and `log.md` documents, in
/// validation order.
final List<OkfSpecRule> reservedRules = List<OkfSpecRule>.unmodifiable(
  <OkfSpecRule>[
    specRule(
      code: 'invalid-reserved-document',
      prose: 'Reserved index and log documents must be parseable.',
      severity: OkfFindingSeverity.error,
      run: (definition, context) => <OkfFinding>[
        for (final invalid in context.invalidDocuments)
          definition.finding(
            message: 'Could not parse reserved document: '
                '${invalid.error.message}',
            location: parseFailureLocation(invalid.path, invalid.error),
          ),
      ],
    ),
    _indexRule(
      'invalid-index-frontmatter',
      'Index frontmatter must follow the root index contract.',
      OkfFindingSeverity.error,
      (source) => <String>[
        if (source.document.hasFrontmatter &&
            !_isRootVersionFrontmatter(source))
          source.path == _rootIndexPath
              ? 'A root index frontmatter block may contain only a '
                  'non-empty okf_version.'
              : 'Only the bundle-root index may contain frontmatter.',
      ],
    ),
    _indexRule(
      'unsupported-okf-version',
      'Root indexes should declare a supported OKF version.',
      OkfFindingSeverity.advisory,
      (source) => <String>[
        if (_isRootVersionFrontmatter(source) &&
            source.document.frontmatter['okf_version'] != '0.2')
          'Version ${source.document.frontmatter['okf_version']} is not '
              'understood; '
              'the bundle was consumed best-effort.',
      ],
    ),
    _indexRule(
      'empty-index-section',
      'Every index section must contain at least one entry.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfIndexIssue.emptySection,
        'Every index section must contain at least one entry.',
      ),
    ),
    _indexRule(
      'index-entry-before-section',
      'Index entries must follow a level-one section heading.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfIndexIssue.entryBeforeSection,
        'Index entries must follow a level-one section heading.',
      ),
    ),
    _indexRule(
      'invalid-index-structure',
      'Index bodies may contain only headings and linked list entries.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfIndexIssue.unrecognizedLine,
        'Index bodies may contain only level-one headings and linked '
        'list entries.',
      ),
    ),
    _indexRule(
      'missing-index-section',
      'Indexes must contain at least one level-one section.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfIndexIssue.missingSection,
        'An index must contain at least one level-one section.',
      ),
    ),
    _indexRule(
      'non-portable-index-link',
      'Index link destinations should be readable by CommonMark parsers.',
      OkfFindingSeverity.advisory,
      (source) => _issueMessages(
        source.content.issues,
        OkfIndexIssue.nonPortableLink,
        'Index link destinations should percent-encode whitespace, '
        'parentheses, and angle brackets, or use the angle-bracket form.',
      ),
    ),
    _logRule(
      'invalid-log-frontmatter',
      'Log files must not contain YAML frontmatter.',
      OkfFindingSeverity.error,
      (source) => <String>[
        if (source.document.hasFrontmatter)
          'Log files must not contain YAML frontmatter.',
      ],
    ),
    _logRule(
      'missing-log-title',
      'Logs must begin with one level-one title.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.missingTitle,
        'A log must begin with one level-one title.',
      ),
    ),
    _logRule(
      'empty-log-date',
      'Every log date must contain at least one entry.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.emptyDate,
        'Every log date must contain at least one entry.',
      ),
    ),
    _logRule(
      'invalid-log-date',
      'Log date headings must contain valid ISO 8601 dates.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.invalidDate,
        'Log date headings must be valid ISO 8601 dates.',
      ),
    ),
    _logRule(
      'log-not-newest-first',
      'Log date groups must be ordered newest first.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.notNewestFirst,
        'Log date groups must be ordered newest first.',
      ),
    ),
    _logRule(
      'log-entry-before-date',
      'Log entries must follow an ISO 8601 date heading.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.entryBeforeDate,
        'Log entries must follow an ISO 8601 date heading.',
      ),
    ),
    _logRule(
      'invalid-log-structure',
      'Log bodies may contain only titles, dates, and list entries.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.unrecognizedLine,
        'Log bodies may contain only a title, date headings, and list entries.',
      ),
    ),
    _logRule(
      'missing-log-date',
      'Logs must contain at least one ISO 8601 date heading.',
      OkfFindingSeverity.error,
      (source) => _issueMessages(
        source.content.issues,
        OkfLogIssue.missingDate,
        'A log must contain at least one ISO 8601 date heading.',
      ),
    ),
  ],
);

/// The messages one rule reports for a single parsed reserved document.
typedef _ReservedCheck<T extends ParsedReservedDocument> = Iterable<String>
    Function(T source);

/// A Spec rule that checks every parseable `index.md` independently.
OkfSpecRule _indexRule(
  String code,
  String prose,
  OkfFindingSeverity severity,
  _ReservedCheck<ParsedIndexDocument> check,
) =>
    specRule(
      code: code,
      prose: prose,
      severity: severity,
      run: (definition, context) =>
          _checkEach(definition, context.indexDocuments, check),
    );

/// A Spec rule that checks every parseable `log.md` independently.
OkfSpecRule _logRule(
  String code,
  String prose,
  OkfFindingSeverity severity,
  _ReservedCheck<ParsedLogDocument> check,
) =>
    specRule(
      code: code,
      prose: prose,
      severity: severity,
      run: (definition, context) =>
          _checkEach(definition, context.logDocuments, check),
    );

/// Runs [check] over every document in [files] that parses; unparseable
/// documents are reported by `okf/invalid-reserved-document` alone.
Iterable<OkfFinding> _checkEach<T extends ParsedReservedDocument>(
  OkfSpecFindingDefinition definition,
  List<T> documents,
  _ReservedCheck<T> check,
) =>
    <OkfFinding>[
      for (final document in documents)
        for (final message in check(document))
          definition.finding(
            message: message,
            location: OkfFindingLocation(path: document.path),
          ),
    ];

const String _rootIndexPath = 'index.md';

/// Whether the document is the bundle-root index carrying exactly one
/// non-empty `okf_version` in its frontmatter.
bool _isRootVersionFrontmatter(ParsedIndexDocument source) =>
    source.path == _rootIndexPath &&
    source.document.hasFrontmatter &&
    source.document.frontmatter.length == 1 &&
    isNonEmptyString(source.document.frontmatter['okf_version']);

Iterable<String> _issueMessages<T extends Enum>(
  List<T> issues,
  T expected,
  String message,
) =>
    issues.where((issue) => issue == expected).map((_) => message);
