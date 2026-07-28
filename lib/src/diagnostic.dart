/// The severity of an [OkfDiagnostic].
enum OkfDiagnosticSeverity {
  /// The input is not conformant or an operation could not be completed.
  error,

  /// The input is consumable, but departs from OKF guidance.
  warning,

  /// Additional information that does not indicate a problem.
  info;

  /// The stable lowercase representation used in JSON and CLI output.
  String get wireValue => name;
}

/// A machine-readable problem found while consuming an OKF bundle.
///
/// Lines and columns are one-based when present. [path] is a logical bundle
/// path, not necessarily an operating-system path.
final class OkfDiagnostic {
  /// Creates a diagnostic.
  const OkfDiagnostic(
    this.code,
    this.severity,
    this.message, {
    this.path,
    this.line,
    this.column,
  });

  /// A stable identifier suitable for filtering and automation.
  final String code;

  /// How strongly the diagnostic affects the operation.
  final OkfDiagnosticSeverity severity;

  /// A human-readable explanation.
  final String message;

  /// The logical document or bundle path associated with the diagnostic.
  final String? path;

  /// A one-based source line.
  final int? line;

  /// A one-based source column.
  final int? column;

  /// Alias that makes the bundle-relative meaning of [path] explicit.
  String? get logicalPath => path;

  /// Whether this diagnostic represents an error.
  bool get isError => severity == OkfDiagnosticSeverity.error;

  /// Converts this diagnostic to a stable JSON-compatible mapping.
  Map<String, Object> toJson() => <String, Object>{
        'code': code,
        'severity': severity.wireValue,
        'message': message,
        if (path != null) 'path': path!,
        if (line != null) 'line': line!,
        if (column != null) 'column': column!,
      };

  @override
  String toString() {
    final location = StringBuffer();
    if (path != null) {
      location.write(path);
    }
    if (line != null) {
      if (location.isNotEmpty) {
        location.write(':');
      }
      location.write(line);
      if (column != null) {
        location
          ..write(':')
          ..write(column);
      }
    }
    final prefix = location.isEmpty ? '' : '$location: ';
    return '$prefix${severity.wireValue} $code: $message';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfDiagnostic &&
          code == other.code &&
          severity == other.severity &&
          message == other.message &&
          path == other.path &&
          line == other.line &&
          column == other.column;

  @override
  int get hashCode => Object.hash(code, severity, message, path, line, column);
}
