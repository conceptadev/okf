/// A stable finding identifier in `<namespace>/<code>` form.
///
/// Both segments are lowercase kebab-case: one or more `[a-z0-9]` runs
/// joined by single hyphens. The grammar is frozen; it may only ever be
/// loosened, so downstream catalogs can rely on every ID they mint today
/// parsing tomorrow.
final class OkfFindingId {
  /// Creates and validates an identifier from separate grammar components.
  factory OkfFindingId.fromParts(String namespace, String code) =>
      OkfFindingId.parse('$namespace/$code');

  /// Creates an identifier in [baseNamespace].
  ///
  /// That namespace is reserved for the rules this package registers.
  /// Callers outside the package use this only to *refer* to a base finding
  /// — in a suppression, for example — never to register a rule under it.
  factory OkfFindingId.okf(String code) =>
      OkfFindingId.fromParts(baseNamespace, code);

  /// Parses and validates a namespaced identifier.
  factory OkfFindingId.parse(String value) {
    final match = _grammar.firstMatch(value);
    if (match == null) {
      throw FormatException(
        'Finding IDs must use the <namespace>/<code> grammar, each segment '
        'lowercase kebab-case',
        value,
      );
    }
    return OkfFindingId._(match[1]!, match[2]!);
  }

  const OkfFindingId._(this.namespace, this.code);

  /// The namespace in which this package mints its own finding IDs.
  static const String baseNamespace = 'okf';

  static final RegExp _grammar = RegExp(
    r'^([a-z0-9]+(?:-[a-z0-9]+)*)/([a-z0-9]+(?:-[a-z0-9]+)*)$',
  );

  /// The catalog namespace that owns this identifier.
  final String namespace;

  /// The stable code within [namespace].
  final String code;

  /// The complete namespaced identifier.
  String get value => '$namespace/$code';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfFindingId &&
          namespace == other.namespace &&
          code == other.code;

  @override
  int get hashCode => Object.hash(namespace, code);

  @override
  String toString() => value;
}

/// How a finding affects conformance.
enum OkfFindingSeverity {
  /// A conformance failure.
  error,

  /// Guidance that fails only when strict validation is requested.
  advisory,
}

/// A logical position within a bundle.
final class OkfFindingLocation {
  /// Creates a bundle-relative source location.
  ///
  /// [line] and [column] are one-based when present, and a column requires
  /// a line; violations are rejected in development builds.
  const OkfFindingLocation({
    required this.path,
    this.line,
    this.column,
  })  : assert(line == null || line > 0, 'line must be one-based'),
        assert(column == null || column > 0, 'column must be one-based'),
        assert(
          column == null || line != null,
          'a column requires a source line',
        );

  /// The logical, bundle-relative path.
  final String path;

  /// The one-based source line, when known.
  final int? line;

  /// The one-based source column, when known.
  final int? column;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfFindingLocation &&
          path == other.path &&
          line == other.line &&
          column == other.column;

  @override
  int get hashCode => Object.hash(path, line, column);
}

/// A single observation produced while loading or validating a bundle.
final class OkfFinding {
  /// Creates a finding.
  const OkfFinding({
    required this.id,
    required this.severity,
    required this.message,
    this.location,
  });

  /// The stable identity minted by the finding's registering catalog.
  final OkfFindingId id;

  /// How this finding affects conformance.
  final OkfFindingSeverity severity;

  /// A human-readable explanation.
  final String message;

  /// The associated bundle location, when one is available.
  final OkfFindingLocation? location;
}

/// Caller-supplied suppression data for one finding ID.
final class OkfFindingSuppression {
  /// Creates a suppression with an optional rationale.
  const OkfFindingSuppression({required this.id, this.note});

  /// The finding ID to suppress.
  final OkfFindingId id;

  /// The caller's optional rationale.
  final String? note;
}

/// Findings and their applied suppression state.
final class OkfReport {
  /// Creates the shared report projected by every validation adapter.
  OkfReport({
    Iterable<OkfFinding> findings = const <OkfFinding>[],
    Iterable<OkfFindingSuppression> suppressions =
        const <OkfFindingSuppression>[],
  })  : findings = List<OkfFinding>.unmodifiable(findings),
        suppressions = List<OkfFindingSuppression>.unmodifiable(suppressions) {
    for (final suppression in this.suppressions) {
      _suppressionsById.putIfAbsent(suppression.id, () => suppression);
    }
  }

  /// Every finding, including suppressed findings, in producer order.
  final List<OkfFinding> findings;

  /// Suppression data supplied by the caller.
  final List<OkfFindingSuppression> suppressions;

  final Map<OkfFindingId, OkfFindingSuppression> _suppressionsById =
      <OkfFindingId, OkfFindingSuppression>{};

  /// Findings that still participate in the verdict.
  List<OkfFinding> get activeFindings => List<OkfFinding>.unmodifiable(
        findings.where(
          (finding) => !_suppressionsById.containsKey(finding.id),
        ),
      );

  /// The number of findings matched by a suppression.
  int get suppressedCount => findings
      .where((finding) => _suppressionsById.containsKey(finding.id))
      .length;

  /// Projects this report as deterministic, line-oriented text.
  String toText() => findings.map(_findingToText).join('\n');

  /// Projects this report as a JSON-compatible object.
  Map<String, Object?> toJson() => <String, Object?>{
        'findings': findings.map(_findingToJson).toList(growable: false),
        'suppressed_count': suppressedCount,
      };

  String _findingToText(OkfFinding finding) {
    final location = finding.location;
    final prefix = StringBuffer();
    if (location != null) {
      prefix.write(location.path);
      if (location.line != null) {
        prefix.write(':${location.line}');
        if (location.column != null) {
          prefix.write(':${location.column}');
        }
      }
      prefix.write(': ');
    }
    final suppression = _suppressionsById[finding.id];
    final suppressionText = suppression == null
        ? ''
        : suppression.note == null
            ? ' (suppressed)'
            : ' (suppressed: ${suppression.note})';
    return '$prefix${finding.severity.name} ${finding.id}: '
        '${finding.message}$suppressionText';
  }

  Map<String, Object?> _findingToJson(OkfFinding finding) {
    final location = finding.location;
    final suppression = _suppressionsById[finding.id];
    return <String, Object?>{
      'id': finding.id.value,
      'severity': finding.severity.name,
      'message': finding.message,
      if (location != null)
        'location': <String, Object?>{
          'path': location.path,
          if (location.line != null) 'line': location.line,
          if (location.column != null) 'column': location.column,
        },
      'suppressed': suppression != null,
      if (suppression?.note != null) 'suppression_note': suppression!.note,
    };
  }
}

/// Process outcomes owned by the finding contract.
enum OkfExitCode {
  /// No active findings fail the requested validation mode.
  success(0),

  /// An error, or an advisory in strict mode, remains active.
  findings(1),

  /// The invocation failed before a report existed.
  ///
  /// Adapters return this for an unparseable invocation or an unreadable
  /// bundle source. Malformed content inside a loadable bundle merges into
  /// the [OkfReport] as findings and exits through [findings] instead.
  usage(2);

  const OkfExitCode(this.value);

  /// The integer returned to a process adapter.
  final int value;
}

/// The judgment produced from findings, suppressions, and strictness.
///
/// A verdict judges loaded content only, so [result] is always
/// [OkfExitCode.success] or [OkfExitCode.findings]; [OkfExitCode.usage] is
/// decided by an adapter before a report exists.
final class OkfVerdict {
  OkfVerdict._({
    required this.report,
    required this.strict,
    required this.result,
  });

  /// Judges [report] under the complete validation exit-code matrix.
  factory OkfVerdict.of(OkfReport report, {bool strict = false}) {
    final fails = report.activeFindings.any(
      (finding) =>
          finding.severity == OkfFindingSeverity.error ||
          strict && finding.severity == OkfFindingSeverity.advisory,
    );
    return OkfVerdict._(
      report: report,
      strict: strict,
      result: fails ? OkfExitCode.findings : OkfExitCode.success,
    );
  }

  /// The report whose active findings were judged.
  final OkfReport report;

  /// Whether advisories participate in failure.
  final bool strict;

  /// The semantic process outcome.
  final OkfExitCode result;

  /// The integer returned by command and automation adapters.
  int get exitCode => result.value;
}
