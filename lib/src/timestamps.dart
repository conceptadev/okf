import 'iso_date.dart';

/// Returns the value to store at a timestamp [path], given its current value.
typedef OkfTimestampRewrite = Object? Function(String path, Object? value);

/// Applies [rewrite] to every OKF timestamp value in [frontmatter].
///
/// Visits `generated.at`, `verified` event `at` values, `stale_after`,
/// `usage_window` boundaries, and each source's `last_modified` and
/// `usage_window`. Containers are copied only along changed paths, so
/// [frontmatter] itself is returned when nothing changes.
Map<String, Object?> rewriteOkfTimestamps(
  Map<String, Object?> frontmatter,
  OkfTimestampRewrite rewrite,
) {
  Object? window(Object? value, String path) => _update(
    _update(value, 'from', (from) => rewrite('$path.from', from)),
    'to',
    (to) => rewrite('$path.to', to),
  );

  var result = frontmatter;
  result = _updateRoot(
    result,
    'generated',
    (generated) =>
        _update(generated, 'at', (at) => rewrite('generated.at', at)),
  );
  result = _updateRoot(result, 'verified', (verified) {
    if (verified is Map) {
      return _update(verified, 'at', (at) => rewrite('verified.at', at));
    }
    return _updateEach(
      verified,
      (index, event) =>
          _update(event, 'at', (at) => rewrite('verified[$index].at', at)),
    );
  });
  result = _updateRoot(
    result,
    'stale_after',
    (value) => rewrite('stale_after', value),
  );
  result = _updateRoot(
    result,
    'usage_window',
    (value) => window(value, 'usage_window'),
  );
  return _updateRoot(
    result,
    'sources',
    (sources) => _updateEach(sources, (index, source) {
      final updated = _update(
        source,
        'last_modified',
        (value) => rewrite('sources[$index].last_modified', value),
      );
      return _update(
        updated,
        'usage_window',
        (value) => window(value, 'sources[$index].usage_window'),
      );
    }),
  );
}

/// Calls [visit] with the path and value of every OKF timestamp.
void visitOkfTimestamps(
  Map<String, Object?> frontmatter,
  void Function(String path, Object? value) visit,
) => rewriteOkfTimestamps(frontmatter, (path, value) {
  visit(path, value);
  return value;
});

/// Rewrites `YYYY-MM-DD` timestamps as midnight UTC datetimes.
///
/// OKF revision 62432a0 made every timestamp an ISO 8601 datetime with an
/// explicit UTC offset. A date-only value read as midnight UTC keeps its
/// meaning, so it is the one form that can be migrated without guessing.
/// Datetimes without an offset are ambiguous and are left unchanged.
({Map<String, Object?> frontmatter, List<String> changes})
migrateDateOnlyTimestamps(Map<String, Object?> frontmatter) {
  final changes = <String>[];
  final migrated = rewriteOkfTimestamps(frontmatter, (path, value) {
    if (value is! String || parseIsoDate(value) == null) {
      return value;
    }
    final replacement = '${value}T00:00:00Z';
    changes.add('$path $value -> $replacement');
    return replacement;
  });
  return (frontmatter: migrated, changes: changes);
}

Map<String, Object?> _updateRoot(
  Map<String, Object?> map,
  String key,
  Object? Function(Object? value) update,
) => _update(map, key, update)! as Map<String, Object?>;

Object? _update(Object? map, String key, Object? Function(Object? value) f) {
  if (map is! Map || !map.containsKey(key)) {
    return map;
  }
  final current = map[key];
  final replacement = f(current);
  if (identical(replacement, current)) {
    return map;
  }
  if (map is Map<String, Object?>) {
    return Map<String, Object?>.of(map)..[key] = replacement;
  }
  return Map<Object?, Object?>.of(map)..[key] = replacement;
}

Object? _updateEach(Object? list, Object? Function(int, Object?) f) {
  if (list is! List) {
    return list;
  }
  var changed = false;
  final replacement = <Object?>[];
  for (var index = 0; index < list.length; index++) {
    final item = f(index, list[index]);
    changed = changed || !identical(item, list[index]);
    replacement.add(item);
  }
  return changed ? replacement : list;
}
