import 'package:okf/okf_io.dart';

/// Writes one bundle file from a separate process.
///
/// Usage: `write_bundle_file.dart <root> <relative-path> <contents>`.
Future<void> main(List<String> arguments) => const OkfBundleWriter().writeAll(
      arguments[0],
      <String, String>{arguments[1]: arguments[2]},
    );
