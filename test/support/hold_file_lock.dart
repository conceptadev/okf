import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final lock = await File(arguments[0]).open(mode: FileMode.append);
  await lock.lock(FileLock.blockingExclusive);
  await File(arguments[1]).writeAsString('ready');
  while (!await File(arguments[2]).exists()) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await lock.unlock();
  await lock.close();
}
