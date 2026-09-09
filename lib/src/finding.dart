import 'control_characters.dart';

/// A stable finding identifier in `<namespace>/<code>` form.
///
/// Both segments are lowercase kebab-case: one or more `[a-z0-9]` runs
/// joined by single hyphens. The grammar is frozen; it may only ever be
/// loosened, so consumers can rely on every ID they store today parsing
/// tomorrow.
final class OkfFindingId {
  /// Creates and validates an identifier from separate grammar components.
  factory OkfFindingId.fromParts(String namespace, String code) =>
      OkfFindingId.parse('$namespace/$code');

  /// Creates an identifier in [baseNamespace].
  ///
  /// This package uses only this namespace for its own findings.
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

  /// The namespace that owns this identifier.
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
  advisory;

  /// The stable lowercase representation used in JSON and text output.
  String get wireValue => name;
}

/// A reported source position associated with a bundle.
final class OkfFindingLocation {
  /// Creates a source location.
  ///
  /// [path] is retained verbatim so a finding can identify a malformed bundle
  /// entry. It is diagnostic data, not a path that is safe for file-system
  /// access. Text projections escape its control characters.
  ///
  /// [line] and [column] are one-based when present, and a column requires
  /// a line.
  factory OkfFindingLocation({required String path, int? line, int? column}) {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'must not be empty');
    }
    if (line != null && line <= 0) {
      throw ArgumentError.value(line, 'line', 'must be one-based');
    }
    if (column != null && column <= 0) {
      throw ArgumentError.value(column, 'column', 'must be one-based');
    }
    if (column != null && line == null) {
      throw ArgumentError.value(column, 'column', 'requires a source line');
    }
    return OkfFindingLocation._(path: path, line: line, column: column);
  }

  const OkfFindingLocation._({
    required this.path,
    required this.line,
    required this.column,
  });

  /// The reported source path, which may identify a malformed bundle entry.
  final String path;

  /// The one-based source line, when known.
  final int? line;

  /// The one-based source column, when known.
  final int? column;

  /// Projects this location as a JSON-compatible object.
  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    if (line != null) 'line': line,
    if (column != null) 'column': column,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfFindingLocation &&
          path == other.path &&
          line == other.line &&
          column == other.column;

  @override
  int get hashCode => Object.hash(path, line, column);

  /// Renders `path`, `path:line`, or `path:line:column`.
  @override
  String toString() {
    final text = StringBuffer(escapeControlCharacters(path));
    if (line != null) {
      text.write(':$line');
      if (column != null) {
        text.write(':$column');
      }
    }
    return text.toString();
  }
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

  /// The stable identity of the condition that produced this finding.
  final OkfFindingId id;

  /// How this finding affects conformance.
  final OkfFindingSeverity severity;

  /// A human-readable explanation. JSON projections retain it verbatim;
  /// line-oriented text projections escape control characters.
  final String message;

  /// The associated bundle location, when one is available.
  final OkfFindingLocation? location;

  /// Projects this finding as a JSON-compatible object.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.value,
    'severity': severity.wireValue,
    'message': message,
    if (location != null) 'location': location!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfFinding &&
          id == other.id &&
          severity == other.severity &&
          message == other.message &&
          location == other.location;

  @override
  int get hashCode => Object.hash(id, severity, message, location);

  /// Renders the one-line text form: `[location: ]severity id: message`.
  @override
  String toString() {
    final prefix = location == null ? '' : '$location: ';
    return '$prefix${severity.wireValue} $id: '
        '${escapeControlCharacters(message)}';
  }
}

/// The immutable findings produced while loading and validating a bundle.
///
/// A report holds its findings in one canonical order ([compareFindings])
/// regardless of which producers contributed them, so every adapter that
/// projects the same findings emits the same sequence. Merging reports is
/// constructing one from their concatenated findings.
final class OkfReport {
  /// Creates the shared report projected by every validation adapter.
  ///
  /// [findings] are rearranged into the canonical order.
  OkfReport({Iterable<OkfFinding> findings = const <OkfFinding>[]})
    : findings = List<OkfFinding>.unmodifiable(
        findings.toList()..sort(compareFindings),
      );

  /// Every finding in canonical order.
  final List<OkfFinding> findings;

  /// The canonical ordering of report findings: path, line, column, ID,
  /// severity, message. Findings without a location sort first.
  static int compareFindings(OkfFinding left, OkfFinding right) {
    var comparison = (left.location?.path ?? '').compareTo(
      right.location?.path ?? '',
    );
    if (comparison != 0) {
      return comparison;
    }
    comparison = (left.location?.line ?? 0).compareTo(
      right.location?.line ?? 0,
    );
    if (comparison != 0) {
      return comparison;
    }
    comparison = (left.location?.column ?? 0).compareTo(
      right.location?.column ?? 0,
    );
    if (comparison != 0) {
      return comparison;
    }
    comparison = left.id.value.compareTo(right.id.value);
    if (comparison != 0) {
      return comparison;
    }
    comparison = left.severity.index.compareTo(right.severity.index);
    return comparison != 0 ? comparison : left.message.compareTo(right.message);
  }

  /// Projects this report as deterministic, line-oriented text.
  String toText() => toTextLines().join('\n');

  /// The text projection one finding per line, for adapters that write
  /// lines individually.
  Iterable<String> toTextLines() => findings.map((finding) => '$finding');

  /// Projects this report as a JSON-compatible object.
  Map<String, Object?> toJson() => <String, Object?>{
    'findings': findings
        .map((finding) => finding.toJson())
        .toList(growable: false),
  };
}

/// The closed OKF Spec judgment for one complete candidate bundle.
///
/// Unlike an adapter verdict, Spec conformance is never affected by
/// strictness or caller policy: only an OKF Spec error can make it false.
final class OkfSpecValidation {
  /// Judges [report] using the fixed OKF Spec conformance rule.
  OkfSpecValidation(this.report)
    : isConformant = !report.findings.any(
        (finding) => finding.severity == OkfFindingSeverity.error,
      );

  /// The immutable OKF Spec report.
  final OkfReport report;

  /// Whether [report] contains no OKF Spec errors.
  final bool isConformant;
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

/// An adapter's local exit judgment over an OKF Spec report.
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

  /// Judges [report] under the adapter validation exit-code matrix.
  factory OkfVerdict.of(OkfReport report, {bool strict = false}) {
    final fails = report.findings.any(
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

  /// The report whose findings were judged.
  final OkfReport report;

  /// Whether advisories participate in failure.
  final bool strict;

  /// The semantic process outcome.
  final OkfExitCode result;

  /// The integer returned by command and automation adapters.
  int get exitCode => result.value;
}
