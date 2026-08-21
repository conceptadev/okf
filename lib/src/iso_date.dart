/// Parses a strict `YYYY-MM-DD` date, rejecting non-canonical spellings.
DateTime? parseIsoDate(String? value) {
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
