/// One entry in an OKF `index.md` document.
final class OkfIndexEntry {
  /// Creates an index entry.
  const OkfIndexEntry({
    required this.type,
    required this.title,
    required this.link,
    required this.description,
  });

  /// The section heading in which the entry appears.
  final String type;

  /// The display label for the entry.
  final String title;

  /// A URL relative to the containing index.
  final String link;

  /// A short summary, empty when none is available.
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfIndexEntry &&
          type == other.type &&
          title == other.title &&
          link == other.link &&
          description == other.description;

  @override
  int get hashCode => Object.hash(type, title, link, description);
}

/// One dated entry in an OKF `log.md` document.
final class OkfLogEntry {
  /// Creates a log entry.
  const OkfLogEntry({
    required this.date,
    required this.action,
    required this.description,
  });

  /// The entry date in `YYYY-MM-DD` form.
  final String date;

  /// The producer-defined action label.
  final String action;

  /// The Markdown description following the action label.
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkfLogEntry &&
          date == other.date &&
          action == other.action &&
          description == other.description;

  @override
  int get hashCode => Object.hash(date, action, description);
}
