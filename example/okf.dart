import 'dart:io';

import 'package:okf/okf_io.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run example/okf.dart <bundle>');
    exitCode = 2;
    return;
  }

  final result = await const OkfBundleLoader().inspect(arguments.single);
  final report = const OkfValidator().validate(result.bundle);
  final graph = OkfGraph.fromBundle(result.bundle);

  stdout.writeln(
    'Loaded ${result.bundle.concepts.length} concepts and '
    '${graph.edges.length} relationships.',
  );
  for (final issue in result.issues) {
    stdout.writeln(issue);
  }
  for (final diagnostic in report.diagnostics) {
    stdout.writeln(diagnostic);
  }

  exitCode = result.hasIssues || !report.isValid ? 1 : 0;
}
