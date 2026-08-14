/// A stable finding identifier in `<namespace>/<code>` form.
final class OkfFindingId {
  /// Creates and validates a namespaced identifier.
  factory OkfFindingId(String value) => OkfFindingId.parse(value);

  /// Creates and validates an identifier from separate grammar components.
  factory OkfFindingId.fromParts(String namespace, String code) =>
      OkfFindingId.parse('$namespace/$code');

  /// Creates an identifier in the namespace reserved for base OKF rules.
  factory OkfFindingId.okf(String code) => OkfFindingId.parse('okf/$code');

  /// Parses and validates a namespaced identifier.
  factory OkfFindingId.parse(String value) {
    final separator = value.indexOf('/');
    if (separator <= 0 ||
        separator != value.lastIndexOf('/') ||
        separator == value.length - 1 ||
        value.runes.any(_isWhitespaceOrControl)) {
      throw FormatException(
        'Finding IDs must use the <namespace>/<code> grammar',
        value,
      );
    }
    return OkfFindingId._(
      value.substring(0, separator),
      value.substring(separator + 1),
    );
  }

  const OkfFindingId._(this.namespace, this.code);

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

  /// The invocation or bundle source is invalid.
  usage(2);

  const OkfExitCode(this.value);

  /// The integer returned to a process adapter.
  final int value;
}

/// The judgment produced from findings, suppressions, and strictness.
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

bool _isWhitespaceOrControl(int rune) =>
    rune <= 0x20 || rune >= 0x7f && rune <= 0x9f;
