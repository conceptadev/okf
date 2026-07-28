import 'dart:async';
import 'dart:io';

import 'package:okf/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runOkfCli(arguments);
}
