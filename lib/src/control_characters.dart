/// Escapes control characters using the CLI's stable `\u{xxxx}` convention.
String escapeControlCharacters(String value) {
  final output = StringBuffer();
  for (final rune in value.runes) {
    if (isControlCharacter(rune)) {
      output
        ..write(r'\u{')
        ..write(rune.toRadixString(16).padLeft(4, '0'))
        ..write('}');
    } else {
      output.writeCharCode(rune);
    }
  }
  return output.toString();
}

/// Whether [rune] is a C0, DEL, or C1 control character.
bool isControlCharacter(int rune) =>
    rune < 0x20 || rune >= 0x7f && rune <= 0x9f;
