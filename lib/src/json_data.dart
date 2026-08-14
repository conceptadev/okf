/// Recursively copies [source] into an unmodifiable JSON-compatible map.
///
/// Nested maps and lists are copied and made unmodifiable as well; every
/// other value is shared as-is.
Map<String, Object?> deepUnmodifiableJsonMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(
      source.map(
        (key, value) =>
            MapEntry<String, Object?>(key, _deepUnmodifiable(value)),
      ),
    );

Object? _deepUnmodifiable(Object? value) {
  if (value is Map<String, Object?>) {
    return deepUnmodifiableJsonMap(value);
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_deepUnmodifiable));
  }
  return value;
}
