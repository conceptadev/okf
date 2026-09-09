// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'document.dart';

// **************************************************************************
// AckModelGenerator
// **************************************************************************

final _okfLegacyCitationObject = Ack.object({
  'number': Ack.integer(),
  'title': Ack.string(),
  'target': Ack.string(),
  'raw': Ack.string(),
});

final _okfLegacyCitationWireSchema = Ack.preserveBoundary(
  _okfLegacyCitationObject,
);

final _okfLegacyCitationSchema = _okfLegacyCitationObject
    .codec<OkfLegacyCitation>(
      decode: _$OkfLegacyCitationFromRuntime,
      encode: _$OkfLegacyCitationToRuntime,
    );

abstract final class OkfLegacyCitationSchema {
  static AckSchema<Map<String, Object?>, OkfLegacyCitation> get schema =>
      _okfLegacyCitationSchema;

  static AckSchema<Map<String, Object?>, Map<String, Object?>> get wireSchema =>
      _okfLegacyCitationWireSchema;

  static OkfLegacyCitation parse(Object? value, {String? debugName}) =>
      _okfLegacyCitationSchema.parse(value, debugName: debugName)!;

  static SchemaResult<OkfLegacyCitation> safeParse(
    Object? value, {
    String? debugName,
  }) => _okfLegacyCitationSchema.safeParse(value, debugName: debugName);

  static OkfLegacyCitation fromJson(Map<String, dynamic> json) => parse(json);

  static Map<String, Object?> encode(
    OkfLegacyCitation value, {
    String? debugName,
  }) => _okfLegacyCitationSchema.encode(value, debugName: debugName)!;

  static SchemaResult<Map<String, Object?>> safeEncode(
    OkfLegacyCitation value, {
    String? debugName,
  }) => _okfLegacyCitationSchema.safeEncode(value, debugName: debugName);

  static Map<String, Object?> toJsonSchema() =>
      _okfLegacyCitationSchema.toJsonSchema();

  static AckSchemaModel toSchemaModel() =>
      AckSchemaModelExtension(_okfLegacyCitationSchema).toSchemaModel();
}

OkfLegacyCitation _$OkfLegacyCitationFromRuntime(Map<String, Object?> value) =>
    _$OkfLegacyCitationFromJson(Map<String, dynamic>.from(value));

Map<String, Object?> _$OkfLegacyCitationToRuntime(OkfLegacyCitation model) =>
    <String, Object?>{..._$OkfLegacyCitationToJson(model)};

mixin _$OkfLegacyCitationAck {
  OkfLegacyCitation copyWith({
    int? number,
    String? title,
    String? target,
    String? raw,
  }) {
    final self = this as OkfLegacyCitation;
    return OkfLegacyCitation(
      number: number ?? self.number,
      title: title ?? self.title,
      target: target ?? self.target,
      raw: raw ?? self.raw,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OkfLegacyCitation || runtimeType != other.runtimeType) {
      return false;
    }
    final self = this as OkfLegacyCitation;
    return deepEquals(self.number, other.number) &&
        deepEquals(self.title, other.title) &&
        deepEquals(self.target, other.target) &&
        deepEquals(self.raw, other.raw);
  }

  @override
  int get hashCode {
    final self = this as OkfLegacyCitation;
    return Object.hashAll([
      runtimeType,
      deepHashCode(self.number),
      deepHashCode(self.title),
      deepHashCode(self.target),
      deepHashCode(self.raw),
    ]);
  }

  @override
  String toString() {
    final self = this as OkfLegacyCitation;
    return 'OkfLegacyCitation(number: ${self.number}, title: ${self.title}, target: ${self.target}, raw: ${self.raw})';
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(
    OkfLegacyCitationSchema.encode(this as OkfLegacyCitation),
  );

  SchemaResult<Map<String, Object?>> safeToJson() =>
      OkfLegacyCitationSchema.safeEncode(this as OkfLegacyCitation);
}

int _ackOkfLegacyCitationFromRuntimeNumber(Object? value) => value as int;
Object? _ackOkfLegacyCitationToRuntimeNumber(int value) => value;
String _ackOkfLegacyCitationFromRuntimeTitle(Object? value) => value as String;
Object? _ackOkfLegacyCitationToRuntimeTitle(String value) => value;
String _ackOkfLegacyCitationFromRuntimeTarget(Object? value) => value as String;
Object? _ackOkfLegacyCitationToRuntimeTarget(String value) => value;
String _ackOkfLegacyCitationFromRuntimeRaw(Object? value) => value as String;
Object? _ackOkfLegacyCitationToRuntimeRaw(String value) => value;
