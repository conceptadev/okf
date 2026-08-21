import 'package:path/path.dart' as p;

import 'control_characters.dart';

/// Validates [value] as a logical, bundle-relative POSIX path.
///
/// The original value is returned unchanged. Bundle paths are a wire-format
/// contract, so invalid syntax is rejected rather than normalized.
String validateBundlePath(String value) {
  if (value.isEmpty || p.posix.isAbsolute(value)) {
    throw FormatException(
      'Bundle paths must be non-empty, relative POSIX paths',
      value,
    );
  }
  if (value.contains(r'\')) {
    throw FormatException('Bundle paths must use / separators', value);
  }

  final segments = value.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw FormatException(
      'Bundle paths cannot contain empty, . or .. segments',
      value,
    );
  }
  if (segments.any((segment) => segment.runes.any(isControlCharacter))) {
    throw FormatException(
      'Bundle paths cannot contain control characters',
      value,
    );
  }
  return value;
}
