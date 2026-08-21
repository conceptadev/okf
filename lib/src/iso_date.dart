/// Parses a strict `YYYY-MM-DD` date, rejecting non-canonical spellings.
DateTime? parseIsoDate(String? value) {
  if (value == null) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null) {
    return null;
  }
  return formatIsoDate(parsed) == value ? parsed : null;
}

/// Emits a canonical `YYYY-MM-DD` date, as [parseIsoDate] accepts it.
String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
