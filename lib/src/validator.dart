import 'bundle.dart';
import 'diagnostic.dart';
import 'document.dart';

/// The complete result of validating an in-memory OKF bundle.
///
/// Transitional: validation results migrate to the shared `OkfReport`
/// projection as rules register in the rule catalog.
final class OkfValidationReport {
  OkfValidationReport(Iterable<OkfDiagnostic> diagnostics)
      : diagnostics = List<OkfDiagnostic>.unmodifiable(diagnostics);

  /// Diagnostics in deterministic path/code/message order.
  final List<OkfDiagnostic> diagnostics;

  /// Whether the bundle has no conformance errors.
  bool get isValid => errorCount == 0;

  /// Whether at least one advisory warning was produced.
  bool get hasWarnings => warningCount != 0;

  /// Number of error diagnostics.
  int get errorCount => diagnostics
      .where(
        (diagnostic) => diagnostic.severity == OkfDiagnosticSeverity.error,
      )
      .length;

  /// Number of warning diagnostics.
  int get warningCount => diagnostics
      .where(
        (diagnostic) => diagnostic.severity == OkfDiagnosticSeverity.warning,
      )
      .length;

  /// Converts this report to a JSON-compatible object.
  Map<String, Object?> toJson() => <String, Object?>{
        'valid': isValid,
        'error_count': errorCount,
        'warning_count': warningCount,
        'diagnostics': diagnostics
            .map((diagnostic) => diagnostic.toJson())
            .toList(growable: false),
      };
}

/// Checks OKF v0.2 conformance and emits advisory shape diagnostics.
final class OkfValidator {
  /// Creates a validator.
  const OkfValidator();

  /// Validates [bundle] without mutating it.
  OkfValidationReport validate(OkfBundle bundle) {
    final diagnostics = <OkfDiagnostic>[];
    for (final entry in bundle.concepts.entries) {
      _validateConcept(
        entry.key.documentPath,
        entry.key.isPortableAscii,
        entry.value,
        diagnostics,
      );
    }
    for (final entry in bundle.indexFiles.entries) {
      _validateIndex(entry.key, entry.value, diagnostics);
    }
    for (final entry in bundle.logFiles.entries) {
      _validateLog(entry.key, entry.value, diagnostics);
    }

    diagnostics.sort(_compareDiagnostics);
    return OkfValidationReport(diagnostics);
  }

  void _validateConcept(
    String path,
    bool isPortableAscii,
    OkfDocument document,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (!document.hasFrontmatter) {
      diagnostics.add(
        _error(
          'missing_frontmatter',
          'Concept documents must begin with YAML frontmatter.',
          path,
        ),
      );
    }

    final frontmatter = document.frontmatter;
    final type = frontmatter['type'];
    if (!_isTruthy(type)) {
      diagnostics.add(
        _error(
          'missing_type',
          'Concept frontmatter must contain a non-empty type field.',
          path,
        ),
      );
    } else if (type is! String) {
      diagnostics.add(
        _warning(
          'type_not_string',
          'The type field should be a short string; it will be consumed '
              'best-effort.',
          path,
        ),
      );
    }

    if (!isPortableAscii) {
      diagnostics.add(
        _warning(
          'non_portable_concept_id',
          'This safe Unicode concept ID is valid but may not be accepted by '
              'ASCII-only producer tooling.',
          path,
        ),
      );
    }

    _validateTags(frontmatter['tags'], path, diagnostics);
    _validateSources(frontmatter['sources'], path, diagnostics);
    _validateUsageWindow(frontmatter['usage_window'], path, diagnostics);
    _validateGenerated(frontmatter['generated'], path, diagnostics);
    _validateVerified(frontmatter['verified'], path, diagnostics);
    _validateLifecycle(frontmatter, path, diagnostics);

    if (type == 'Attested Computation') {
      _validateAttestedComputation(frontmatter, path, diagnostics);
    }
  }

  void _validateTags(
    Object? value,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (value == null) {
      return;
    }
    if (value is! List<Object?> ||
        value.any((tag) => tag is! String || tag.trim().isEmpty)) {
      diagnostics.add(
        _warning(
          'invalid_tags',
          'tags should be a YAML list of non-empty strings.',
          path,
        ),
      );
    }
  }

  void _validateSources(
    Object? value,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (value == null) {
      return;
    }
    if (value is! List<Object?>) {
      diagnostics.add(
        _warning(
          'invalid_sources',
          'sources should be a list of mappings.',
          path,
        ),
      );
      return;
    }

    for (var index = 0; index < value.length; index++) {
      final source = value[index];
      if (source is! Map<Object?, Object?> ||
          !_isNonEmptyString(source['resource'])) {
        diagnostics.add(
          _warning(
            'invalid_source',
            'sources[$index] should be a mapping with a non-empty resource.',
            path,
          ),
        );
      }
    }
  }

  void _validateUsageWindow(
    Object? value,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (value == null) {
      return;
    }
    if (value is! Map<Object?, Object?> ||
        !_isIsoDate(value['from']) ||
        !_isIsoDate(value['to'])) {
      diagnostics.add(
        _warning(
          'invalid_usage_window',
          'usage_window should contain ISO date from and to values.',
          path,
        ),
      );
    }
  }

  void _validateGenerated(
    Object? value,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (value == null) {
      return;
    }
    if (value is! Map<Object?, Object?> ||
        !_isNonEmptyString(value['by']) ||
        (value['at'] != null && !_isIsoDateTime(value['at']))) {
      diagnostics.add(
        _warning(
          'invalid_generated',
          'generated should contain a non-empty by actor and an optional '
              'ISO 8601 at timestamp.',
          path,
        ),
      );
    }
  }

  void _validateVerified(
    Object? value,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (value == null) {
      return;
    }
    final events = value is List<Object?> ? value : <Object?>[value];
    if (events.isEmpty ||
        events.any(
          (event) =>
              event is! Map<Object?, Object?> ||
              !_isNonEmptyString(event['by']) ||
              !_isIsoDateTime(event['at']),
        )) {
      diagnostics.add(
        _warning(
          'invalid_verified',
          'verified should be a mapping or list of mappings containing by '
              'and an ISO 8601 at timestamp.',
          path,
        ),
      );
    }
  }

  void _validateLifecycle(
    Map<String, Object?> frontmatter,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    final status = frontmatter['status'];
    if (status != null &&
        (status is! String ||
            !const <String>{'draft', 'stable', 'deprecated'}.contains(
              status,
            ))) {
      diagnostics.add(
        _warning(
          'invalid_status',
          'status should be draft, stable, or deprecated.',
          path,
        ),
      );
    }

    final staleAfter = frontmatter['stale_after'];
    if (staleAfter != null && !_isIsoDate(staleAfter)) {
      diagnostics.add(
        _warning(
          'invalid_stale_after',
          'stale_after should be an ISO 8601 YYYY-MM-DD date.',
          path,
        ),
      );
    }
  }

  void _validateAttestedComputation(
    Map<String, Object?> frontmatter,
    String path,
    List<OkfDiagnostic> diagnostics,
  ) {
    if (!_isNonEmptyString(frontmatter['runtime'])) {
      diagnostics.add(
        _warning(
          'missing_computation_runtime',
          'Attested Computation concepts should declare a runtime.',
          path,
        ),
      );
    }

    final parameters = frontmatter['parameters'];
    if (parameters != null &&
        (parameters is! List<Object?> ||
            parameters.any(
              (parameter) =>
                  parameter is! Map<Object?, Object?> ||
                  !_isNonEmptyString(parameter['name']) ||
                  !_isNonEmptyString(parameter['type']) ||
                  (parameter['required'] != null &&
                      parameter['required'] is! bool),
            ))) {
      diagnostics.add(
        _warning(
          'invalid_computation_parameters',
          'parameters should contain mappings with name, type, and an '
              'optional boolean required field.',
          path,
        ),
      );
    }

    for (final key in const <String>['executor', 'attester']) {
      final value = frontmatter[key];
      if (value != null &&
          (value is! Map<Object?, Object?> ||
              !_isNonEmptyString(value['resource']))) {
        diagnostics.add(
          _warning(
            'invalid_$key',
            '$key should be a mapping with a non-empty resource.',
            path,
          ),
        );
      }
    }
  }

  void _validateIndex(
    String path,
    String source,
    List<OkfDiagnostic> diagnostics,
  ) {
    final document = _parseReserved(path, source, diagnostics);
    if (document == null) {
      return;
    }

    final isRoot = path == 'index.md';
    if (document.hasFrontmatter) {
      final keys = document.frontmatter.keys.toSet();
      if (!isRoot ||
          keys.length != 1 ||
          !keys.contains('okf_version') ||
          !_isNonEmptyString(document.frontmatter['okf_version'])) {
        diagnostics.add(
          _error(
            'invalid_index_frontmatter',
            isRoot
                ? 'A root index frontmatter block may contain only a '
                    'non-empty okf_version.'
                : 'Only the bundle-root index may contain frontmatter.',
            path,
          ),
        );
      } else if (document.frontmatter['okf_version'] != '0.2') {
        diagnostics.add(
          _warning(
            'unsupported_okf_version',
            'Version ${document.frontmatter['okf_version']} is not understood; '
                'the bundle was consumed best-effort.',
            path,
          ),
        );
      }
    }

    final lines = document.body.split(RegExp(r'\r?\n'));
    var sawSection = false;
    var sectionHasEntry = false;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (_indexHeading.hasMatch(line)) {
        if (sawSection && !sectionHasEntry) {
          diagnostics.add(
            _error(
              'empty_index_section',
              'Every index section must contain at least one entry.',
              path,
            ),
          );
        }
        sawSection = true;
        sectionHasEntry = false;
      } else if (_indexEntry.hasMatch(line)) {
        if (!sawSection) {
          diagnostics.add(
            _error(
              'index_entry_before_section',
              'Index entries must follow a level-one section heading.',
              path,
            ),
          );
        }
        sectionHasEntry = true;
      } else {
        diagnostics.add(
          _error(
            'invalid_index_structure',
            'Index bodies may contain only level-one headings and linked '
                'list entries.',
            path,
          ),
        );
      }
    }
    if (!sawSection) {
      diagnostics.add(
        _error(
          'missing_index_section',
          'An index must contain at least one level-one section.',
          path,
        ),
      );
    } else if (!sectionHasEntry) {
      diagnostics.add(
        _error(
          'empty_index_section',
          'Every index section must contain at least one entry.',
          path,
        ),
      );
    }
  }

  void _validateLog(
    String path,
    String source,
    List<OkfDiagnostic> diagnostics,
  ) {
    final document = _parseReserved(path, source, diagnostics);
    if (document == null) {
      return;
    }
    if (document.hasFrontmatter) {
      diagnostics.add(
        _error(
          'invalid_log_frontmatter',
          'Log files must not contain YAML frontmatter.',
          path,
        ),
      );
    }

    final lines = document.body.split(RegExp(r'\r?\n'));
    var sawTitle = false;
    var sawDate = false;
    var entriesForDate = 0;
    DateTime? previousDate;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (!sawTitle) {
        if (!_logTitle.hasMatch(line)) {
          diagnostics.add(
            _error(
              'missing_log_title',
              'A log must begin with one level-one title.',
              path,
            ),
          );
        }
        sawTitle = true;
        continue;
      }

      final dateMatch = _logDate.firstMatch(line);
      if (dateMatch != null) {
        if (sawDate && entriesForDate == 0) {
          diagnostics.add(
            _error(
              'empty_log_date',
              'Every log date must contain at least one entry.',
              path,
            ),
          );
        }
        final date = _parseIsoDate(dateMatch.group(1));
        if (date == null) {
          diagnostics.add(
            _error(
              'invalid_log_date',
              'Log date headings must be valid ISO 8601 dates.',
              path,
            ),
          );
        } else if (previousDate != null && date.isAfter(previousDate)) {
          diagnostics.add(
            _error(
              'log_not_newest_first',
              'Log date groups must be ordered newest first.',
              path,
            ),
          );
        }
        previousDate = date ?? previousDate;
        sawDate = true;
        entriesForDate = 0;
      } else if (_logEntry.hasMatch(line)) {
        if (!sawDate) {
          diagnostics.add(
            _error(
              'log_entry_before_date',
              'Log entries must follow an ISO 8601 date heading.',
              path,
            ),
          );
        }
        entriesForDate++;
      } else {
        diagnostics.add(
          _error(
            'invalid_log_structure',
            'Log bodies may contain only a title, date headings, and list '
                'entries.',
            path,
          ),
        );
      }
    }

    if (!sawTitle) {
      diagnostics.add(
        _error(
          'missing_log_title',
          'A log must begin with one level-one title.',
          path,
        ),
      );
    }
    if (!sawDate) {
      diagnostics.add(
        _error(
          'missing_log_date',
          'A log must contain at least one ISO 8601 date heading.',
          path,
        ),
      );
    } else if (entriesForDate == 0) {
      diagnostics.add(
        _error(
          'empty_log_date',
          'Every log date must contain at least one entry.',
          path,
        ),
      );
    }
  }

  OkfDocument? _parseReserved(
    String path,
    String source,
    List<OkfDiagnostic> diagnostics,
  ) {
    try {
      return OkfDocument.parse(source, sourcePath: path);
    } on OkfDocumentException catch (error) {
      diagnostics.add(
        _error(
          'invalid_reserved_document',
          'Could not parse reserved document: ${error.message}',
          path,
          line: error.line,
          column: error.column,
        ),
      );
      return null;
    } on FormatException catch (error) {
      diagnostics.add(
        _error(
          'invalid_reserved_document',
          'Could not parse reserved document: ${error.message}',
          path,
        ),
      );
      return null;
    }
  }
}

final RegExp _indexHeading = RegExp(r'^# [^#].*$');
final RegExp _indexEntry = RegExp(
  r'^[*-] \[(?:\\.|[^\]])+\]\([^)]+\)(?:\s+-\s+.+)?$',
);
final RegExp _logTitle = RegExp(r'^# [^#].*$');
final RegExp _logDate = RegExp(r'^## (\d{4}-\d{2}-\d{2})$');
final RegExp _logEntry = RegExp(r'^[*-] .+$');

bool _isTruthy(Object? value) {
  if (value == null || value == false) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is Iterable<Object?>) {
    return value.isNotEmpty;
  }
  if (value is Map<Object?, Object?>) {
    return value.isNotEmpty;
  }
  return true;
}

bool _isNonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

bool _isIsoDate(Object? value) {
  if (value is DateTime) {
    return true;
  }
  return value is String &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      _parseIsoDate(value) != null;
}

DateTime? _parseIsoDate(String? value) {
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null) {
    return null;
  }
  final canonical = '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return canonical == value ? parsed : null;
}

bool _isIsoDateTime(Object? value) {
  if (value is DateTime) {
    return true;
  }
  return value is String &&
      value.contains('T') &&
      DateTime.tryParse(value) != null;
}

OkfDiagnostic _error(
  String code,
  String message,
  String path, {
  int? line,
  int? column,
}) =>
    OkfDiagnostic(
      code,
      OkfDiagnosticSeverity.error,
      message,
      path: path,
      line: line,
      column: column,
    );

OkfDiagnostic _warning(String code, String message, String path) =>
    OkfDiagnostic(
      code,
      OkfDiagnosticSeverity.warning,
      message,
      path: path,
    );

int _compareDiagnostics(OkfDiagnostic left, OkfDiagnostic right) {
  final pathComparison = (left.path ?? '').compareTo(right.path ?? '');
  if (pathComparison != 0) {
    return pathComparison;
  }
  final severityComparison = left.severity.index.compareTo(
    right.severity.index,
  );
  if (severityComparison != 0) {
    return severityComparison;
  }
  final codeComparison = left.code.compareTo(right.code);
  return codeComparison != 0
      ? codeComparison
      : left.message.compareTo(right.message);
}
