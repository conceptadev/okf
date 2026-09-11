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

/// Parses an ISO 8601 date and time, such as `2026-06-25T09:00:00Z`.
///
/// Accepts the extended and basic formats with optional fractional seconds and
/// an optional UTC offset. Unlike [DateTime.tryParse], out-of-range fields are
/// rejected rather than rolled over: `2026-02-30T10:00:00Z` is invalid, not
/// `2026-03-02T10:00:00Z`.
DateTime? parseIsoDateTime(String? value) {
  if (value == null) {
    return null;
  }
  final match =
      _extendedDateTime.firstMatch(value) ?? _basicDateTime.firstMatch(value);
  if (match == null) {
    return null;
  }
  int field(int group) => int.parse(match.group(group) ?? '0');
  final year = field(1);
  final month = field(2);
  final day = field(3);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      field(4) > 23 ||
      field(5) > 59 ||
      field(6) > 59 ||
      field(7) > 23 ||
      field(8) > 59) {
    return null;
  }
  return DateTime.tryParse(value);
}

// Groups: year, month, day, hour, minute, second, offset hours, offset minutes.
final _extendedDateTime = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?'
  r'(?:Z|[+-](\d{2})(?::?(\d{2}))?)?$',
);
final _basicDateTime = RegExp(
  r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(?:(\d{2})(?:\.\d+)?)?'
  r'(?:Z|[+-](\d{2})(\d{2})?)?$',
);
