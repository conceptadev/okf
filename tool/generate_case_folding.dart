import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _source = 'https://www.unicode.org/Public/17.0.0/ucd/CaseFolding.txt';
const _sourceSha256 =
    'ff8d8fefbf123574205085d6714c36149eb946d717a0c585c27f0f4ef58c4183';

Future<void> main() async {
  final request = await HttpClient().getUrl(Uri.parse(_source));
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException(
      'Failed to download $_source: HTTP ${response.statusCode}',
    );
  }

  final mappings = <int, List<int>>{};
  final contents = await utf8.decoder.bind(response).join();
  final digest = sha256.convert(utf8.encode(contents)).toString();
  if (digest != _sourceSha256) {
    throw StateError('CaseFolding.txt digest mismatch: $digest');
  }
  for (final line in const LineSplitter().convert(contents)) {
    final fields = line.split('#').first.trim().split(';');
    if (fields.length < 3) {
      continue;
    }
    final status = fields[1].trim();
    if (status != 'C' && status != 'F') {
      continue;
    }
    mappings[int.parse(fields[0].trim(), radix: 16)] = fields[2]
        .trim()
        .split(' ')
        .map((value) => int.parse(value, radix: 16))
        .toList(growable: false);
  }

  final output = StringBuffer()
    ..writeln('// Generated from Unicode 17.0.0 CaseFolding.txt.')
    ..writeln('// See THIRD_PARTY_NOTICES for the Unicode License v3.')
    ..writeln('// Run: dart run tool/generate_case_folding.dart')
    ..writeln()
    ..writeln("part of 'bundle_change_applier.dart';")
    ..writeln()
    ..writeln('const Map<int, String> _caseFoldMappings = <int, String>{');
  for (final entry in mappings.entries) {
    final key = entry.key.toRadixString(16).toUpperCase().padLeft(4, '0');
    final value = entry.value
        .map((rune) => '\\u{${rune.toRadixString(16).toUpperCase()}}')
        .join();
    output.writeln("  0x$key: '$value',");
  }
  output.writeln('};');

  await File('lib/src/io/bundle_change_case_folding.dart')
      .writeAsString(output.toString());
}
