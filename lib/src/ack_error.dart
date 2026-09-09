import 'package:ack/ack.dart';

/// Formats boundary failures with their field paths and nested reasons.
///
/// Codec failures retain the domain message without the exception's input
/// dump or stack trace. OKF conformance findings keep their own Report format.
String formatAckErrors(AckException exception) =>
    exception.errors.expand(_messages).join('\n');

Iterable<String> _messages(SchemaError error) sync* {
  if (error is SchemaNestedError) {
    for (final nested in error.errors) {
      yield* _messages(nested);
    }
  } else {
    final message = switch (error.cause) {
      FormatException(:final message) => message,
      _ => error.message,
    };
    yield '${error.path}: $message';
  }
}
