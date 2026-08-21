import '../finding.dart';
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
      (source) {
        var sawSection = false;
        var sectionHasEntry = false;
        final messages = <String>[];
        for (final line in source.bodyLines) {
          if (_heading.hasMatch(line)) {
            if (sawSection && !sectionHasEntry) {
              messages.add(_emptyIndexSection);
            }
            sawSection = true;
            sectionHasEntry = false;
          } else if (_indexEntry.hasMatch(line)) {
            sectionHasEntry = true;
          }
        }
        if (sawSection && !sectionHasEntry) {
          messages.add(_emptyIndexSection);
        }
        return messages;
      },
    ),
    _indexRule(
      'index-entry-before-section',
      'Index entries must follow a level-one section heading.',
      OkfFindingSeverity.error,
      (source) => <String>[
        for (final line in source.bodyLines.takeWhile(
          (line) => !_heading.hasMatch(line),
        ))
          if (_indexEntry.hasMatch(line))
            'Index entries must follow a level-one section heading.',
      ],
    ),
    _indexRule(
      'invalid-index-structure',
      'Index bodies may contain only headings and linked list entries.',
      OkfFindingSeverity.error,
      (source) => <String>[
        for (final line in source.bodyLines)
          if (!_heading.hasMatch(line) && !_indexEntry.hasMatch(line))
            'Index bodies may contain only level-one headings and linked '
                'list entries.',
      ],
    ),
    _indexRule(
      'missing-index-section',
      'Indexes must contain at least one level-one section.',
      OkfFindingSeverity.error,
      (source) => <String>[
        if (!source.bodyLines.any(_heading.hasMatch))
          'An index must contain at least one level-one section.',
      ],
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
      (source) {
        final lines = source.bodyLines;
        return <String>[
          if (lines.isEmpty || !_heading.hasMatch(lines.first))
            'A log must begin with one level-one title.',
        ];
      },
    ),
    _logRule(
      'empty-log-date',
      'Every log date must contain at least one entry.',
      OkfFindingSeverity.error,
      (source) {
        var sawDate = false;
        var entriesForDate = 0;
        final messages = <String>[];
        for (final line in source.logBody) {
          if (_logDate.hasMatch(line)) {
            if (sawDate && entriesForDate == 0) {
              messages.add(_emptyLogDate);
            }
            sawDate = true;
            entriesForDate = 0;
          } else if (_logEntry.hasMatch(line)) {
            entriesForDate++;
          }
        }
        if (sawDate && entriesForDate == 0) {
          messages.add(_emptyLogDate);
        }
        return messages;
      },
    ),
    _logRule(
      'invalid-log-date',
      'Log date headings must contain valid ISO 8601 dates.',
      OkfFindingSeverity.error,
      (source) => <String>[
        for (final line in source.logBody)
          if (_logDate.hasMatch(line) && _dateOf(line) == null)
            'Log date headings must be valid ISO 8601 dates.',
      ],
    ),
    _logRule(
      'log-not-newest-first',
      'Log date groups must be ordered newest first.',
      OkfFindingSeverity.error,
      (source) {
        DateTime? previousDate;
        final messages = <String>[];
        for (final line in source.logBody) {
          final date = _dateOf(line);
          if (date == null) {
            continue;
          }
          if (previousDate != null && date.isAfter(previousDate)) {
            messages.add('Log date groups must be ordered newest first.');
          }
          previousDate = date;
        }
        return messages;
      },
    ),
    _logRule(
      'log-entry-before-date',
      'Log entries must follow an ISO 8601 date heading.',
      OkfFindingSeverity.error,
      (source) => <String>[
        for (final line in source.logBody.takeWhile(
          (line) => !_logDate.hasMatch(line),
        ))
          if (_logEntry.hasMatch(line))
            'Log entries must follow an ISO 8601 date heading.',
      ],
    ),
    _logRule(
      'invalid-log-structure',
      'Log bodies may contain only titles, dates, and list entries.',
      OkfFindingSeverity.error,
      (source) => <String>[
        for (final line in source.logBody)
          if (!_logDate.hasMatch(line) && !_logEntry.hasMatch(line))
            'Log bodies may contain only a title, date headings, and list '
                'entries.',
      ],
    ),
    _logRule(
      'missing-log-date',
      'Logs must contain at least one ISO 8601 date heading.',
      OkfFindingSeverity.error,
      (source) => <String>[
        if (!source.logBody.any(_logDate.hasMatch))
          'A log must contain at least one ISO 8601 date heading.',
      ],
    ),
  ],
);

/// The messages one rule reports for a single parsed reserved document.
typedef _ReservedCheck = Iterable<String> Function(
  ParsedReservedDocument source,
);

/// A Spec rule that checks every parseable `index.md` independently.
OkfSpecRule _indexRule(
  String code,
  String prose,
  OkfFindingSeverity severity,
  _ReservedCheck check,
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
  _ReservedCheck check,
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
Iterable<OkfFinding> _checkEach(
  OkfSpecFindingDefinition definition,
  List<ParsedReservedDocument> documents,
  _ReservedCheck check,
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
const String _emptyIndexSection =
    'Every index section must contain at least one entry.';
const String _emptyLogDate = 'Every log date must contain at least one entry.';

/// Whether the document is the bundle-root index carrying exactly one
/// non-empty `okf_version` in its frontmatter.
bool _isRootVersionFrontmatter(ParsedReservedDocument source) =>
    source.path == _rootIndexPath &&
    source.document.hasFrontmatter &&
    source.document.frontmatter.length == 1 &&
    isNonEmptyString(source.document.frontmatter['okf_version']);

DateTime? _dateOf(String line) =>
    parseIsoDate(_logDate.firstMatch(line)?.group(1));

final RegExp _heading = RegExp(r'^# [^#].*$');
final RegExp _indexEntry = RegExp(
  r'^[*-] \[(?:\\.|[^\]])+\]\([^)]+\)(?:\s+-\s+.+)?$',
);
final RegExp _logDate = RegExp(r'^## (\d{4}-\d{2}-\d{2})$');
final RegExp _logEntry = RegExp(r'^[*-] .+$');
