import 'dart:collection';

import 'yaml_limits.dart';

/// Recursively snapshots [source] as supported, immutable YAML data.
///
/// Maps retain their iteration order and every non-string iterable is copied
/// to an unmodifiable list. Supported scalars are `null`, strings, numbers,
/// booleans, and dates. Map keys must be supported scalar values. Cyclic and
/// unsupported values, excessive nesting, and excessive collection sizes are
/// rejected with [ArgumentError].
Map<String, Object?> deepUnmodifiableJsonMap(Map<String, Object?> source) {
  final state = _SnapshotState();
  return state._copyStringMap(source);
}

final class _SnapshotState {
  final Set<Object> _active = HashSet<Object>.identity();
  var _nodes = 0;

  Map<String, Object?> _copyStringMap(
    Map<String, Object?> source, [
    int depth = 0,
  ]) {
    _checkDepth(depth);
    _enter(source);
    try {
      final copy = <String, Object?>{};
      for (final entry in source.entries) {
        copy[entry.key] = _copy(entry.value, depth + 1);
      }
      return Map<String, Object?>.unmodifiable(copy);
    } finally {
      _exit(source);
    }
  }

  Object? _copy(Object? value, int depth) {
    _countNode();
    _checkDepth(depth);
    if (_isSupportedScalar(value)) {
      return value;
    }
    if (value is Map<String, Object?>) {
      return _copyStringMap(value, depth);
    }
    if (value is Map<Object?, Object?>) {
      _enter(value);
      try {
        final copy = <Object?, Object?>{};
        for (final entry in value.entries) {
          if (!_isSupportedScalar(entry.key)) {
            throw ArgumentError(
              'YAML mapping keys must be scalar values; found '
              '${entry.key.runtimeType}.',
            );
          }
          copy[entry.key] = _copy(entry.value, depth + 1);
        }
        return Map<Object?, Object?>.unmodifiable(copy);
      } finally {
        _exit(value);
      }
    }
    if (value is Iterable) {
      _enter(value);
      try {
        return List<Object?>.unmodifiable(
          value.map((item) => _copy(item, depth + 1)),
        );
      } finally {
        _exit(value);
      }
    }
    throw ArgumentError('Unsupported YAML value of type ${value.runtimeType}.');
  }

  bool _isSupportedScalar(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is DateTime;

  void _checkDepth(int depth) {
    if (depth > maximumYamlDepth) {
      throw ArgumentError('YAML data exceeds the supported nesting depth.');
    }
  }

  void _countNode() {
    _nodes++;
    if (_nodes > maximumYamlNodes) {
      throw ArgumentError('YAML data exceeds the supported node limit.');
    }
  }

  void _enter(Object value) {
    if (!_active.add(value)) {
      throw ArgumentError('Cyclic YAML collections are not supported.');
    }
  }

  void _exit(Object value) => _active.remove(value);
}
