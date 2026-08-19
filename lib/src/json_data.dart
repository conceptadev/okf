/// Recursively copies [source] into an unmodifiable JSON-compatible map.
///
/// Every nested map and list is copied into an unmodifiable view, whatever
/// its static type — parsed YAML yields `Map<Object?, Object?>`, literals
/// yield `Map<String, Object?>`, and both are frozen. String-keyed maps stay
/// string-keyed. Scalar values are shared with [source] rather than copied.
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
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, value) =>
            MapEntry<Object?, Object?>(key, _deepUnmodifiable(value)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepUnmodifiable));
  }
  return value;
}
