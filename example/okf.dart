import 'dart:io';

import 'package:okf/okf_io.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run example/okf.dart <bundle>');
    exitCode = OkfExitCode.usage.value;
    return;
  }

  final result = await const OkfBundleLoader().inspect(arguments.single);
  final report = result.validate().report;
  final graph = OkfGraph.fromBundle(result.bundle);

  stdout.writeln(
    'Loaded ${result.bundle.concepts.length} concepts and '
    '${graph.edges.length} relationships.',
  );
  if (report.findings.isNotEmpty) {
    stdout.writeln(report.toText());
  }

  exitCode = OkfVerdict.of(report).exitCode;
}
