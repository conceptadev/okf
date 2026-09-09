// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'index_log.dart';

// **************************************************************************
// AckModelGenerator
// **************************************************************************

final _okfIndexEntryObject = Ack.object({
  'type': Ack.string(),
  'title': Ack.string(),
  'link': Ack.string(),
  'description': Ack.string(),
});

final _okfIndexEntryWireSchema = Ack.preserveBoundary(_okfIndexEntryObject);

final _okfIndexEntrySchema = _okfIndexEntryObject.codec<OkfIndexEntry>(
  decode: _$OkfIndexEntryFromRuntime,
  encode: _$OkfIndexEntryToRuntime,
);

abstract final class OkfIndexEntrySchema {
  static AckSchema<Map<String, Object?>, OkfIndexEntry> get schema =>
      _okfIndexEntrySchema;

  static AckSchema<Map<String, Object?>, Map<String, Object?>> get wireSchema =>
      _okfIndexEntryWireSchema;

  static OkfIndexEntry parse(Object? value, {String? debugName}) =>
      _okfIndexEntrySchema.parse(value, debugName: debugName)!;

  static SchemaResult<OkfIndexEntry> safeParse(
    Object? value, {
    String? debugName,
  }) => _okfIndexEntrySchema.safeParse(value, debugName: debugName);

  static OkfIndexEntry fromJson(Map<String, dynamic> json) => parse(json);

  static Map<String, Object?> encode(
    OkfIndexEntry value, {
    String? debugName,
  }) => _okfIndexEntrySchema.encode(value, debugName: debugName)!;

  static SchemaResult<Map<String, Object?>> safeEncode(
    OkfIndexEntry value, {
    String? debugName,
  }) => _okfIndexEntrySchema.safeEncode(value, debugName: debugName);

  static Map<String, Object?> toJsonSchema() =>
      _okfIndexEntrySchema.toJsonSchema();

  static AckSchemaModel toSchemaModel() =>
      AckSchemaModelExtension(_okfIndexEntrySchema).toSchemaModel();
}

OkfIndexEntry _$OkfIndexEntryFromRuntime(Map<String, Object?> value) =>
    _$OkfIndexEntryFromJson(Map<String, dynamic>.from(value));

Map<String, Object?> _$OkfIndexEntryToRuntime(OkfIndexEntry model) =>
    <String, Object?>{..._$OkfIndexEntryToJson(model)};

mixin _$OkfIndexEntryAck {
  OkfIndexEntry copyWith({
    String? type,
    String? title,
    String? link,
    String? description,
  }) {
    final self = this as OkfIndexEntry;
    return OkfIndexEntry(
      type: type ?? self.type,
      title: title ?? self.title,
      link: link ?? self.link,
      description: description ?? self.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OkfIndexEntry || runtimeType != other.runtimeType) {
      return false;
    }
    final self = this as OkfIndexEntry;
    return deepEquals(self.type, other.type) &&
        deepEquals(self.title, other.title) &&
        deepEquals(self.link, other.link) &&
        deepEquals(self.description, other.description);
  }

  @override
  int get hashCode {
    final self = this as OkfIndexEntry;
    return Object.hashAll([
      runtimeType,
      deepHashCode(self.type),
      deepHashCode(self.title),
      deepHashCode(self.link),
      deepHashCode(self.description),
    ]);
  }

  @override
  String toString() {
    final self = this as OkfIndexEntry;
    return 'OkfIndexEntry(type: ${self.type}, title: ${self.title}, link: ${self.link}, description: ${self.description})';
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(
    OkfIndexEntrySchema.encode(this as OkfIndexEntry),
  );

  SchemaResult<Map<String, Object?>> safeToJson() =>
      OkfIndexEntrySchema.safeEncode(this as OkfIndexEntry);
}

String _ackOkfIndexEntryFromRuntimeType(Object? value) => value as String;
Object? _ackOkfIndexEntryToRuntimeType(String value) => value;
String _ackOkfIndexEntryFromRuntimeTitle(Object? value) => value as String;
Object? _ackOkfIndexEntryToRuntimeTitle(String value) => value;
String _ackOkfIndexEntryFromRuntimeLink(Object? value) => value as String;
Object? _ackOkfIndexEntryToRuntimeLink(String value) => value;
String _ackOkfIndexEntryFromRuntimeDescription(Object? value) =>
    value as String;
Object? _ackOkfIndexEntryToRuntimeDescription(String value) => value;

final _okfLogEntryObject = Ack.object({
  'date': Ack.string(),
  'action': Ack.string(),
  'description': Ack.string(),
});

final _okfLogEntryWireSchema = Ack.preserveBoundary(_okfLogEntryObject);

final _okfLogEntrySchema = _okfLogEntryObject.codec<OkfLogEntry>(
  decode: _$OkfLogEntryFromRuntime,
  encode: _$OkfLogEntryToRuntime,
);

abstract final class OkfLogEntrySchema {
  static AckSchema<Map<String, Object?>, OkfLogEntry> get schema =>
      _okfLogEntrySchema;

  static AckSchema<Map<String, Object?>, Map<String, Object?>> get wireSchema =>
      _okfLogEntryWireSchema;

  static OkfLogEntry parse(Object? value, {String? debugName}) =>
      _okfLogEntrySchema.parse(value, debugName: debugName)!;

  static SchemaResult<OkfLogEntry> safeParse(
    Object? value, {
    String? debugName,
  }) => _okfLogEntrySchema.safeParse(value, debugName: debugName);

  static OkfLogEntry fromJson(Map<String, dynamic> json) => parse(json);

  static Map<String, Object?> encode(OkfLogEntry value, {String? debugName}) =>
      _okfLogEntrySchema.encode(value, debugName: debugName)!;

  static SchemaResult<Map<String, Object?>> safeEncode(
    OkfLogEntry value, {
    String? debugName,
  }) => _okfLogEntrySchema.safeEncode(value, debugName: debugName);

  static Map<String, Object?> toJsonSchema() =>
      _okfLogEntrySchema.toJsonSchema();

  static AckSchemaModel toSchemaModel() =>
      AckSchemaModelExtension(_okfLogEntrySchema).toSchemaModel();
}

OkfLogEntry _$OkfLogEntryFromRuntime(Map<String, Object?> value) =>
    _$OkfLogEntryFromJson(Map<String, dynamic>.from(value));

Map<String, Object?> _$OkfLogEntryToRuntime(OkfLogEntry model) =>
    <String, Object?>{..._$OkfLogEntryToJson(model)};

mixin _$OkfLogEntryAck {
  OkfLogEntry copyWith({String? date, String? action, String? description}) {
    final self = this as OkfLogEntry;
    return OkfLogEntry(
      date: date ?? self.date,
      action: action ?? self.action,
      description: description ?? self.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OkfLogEntry || runtimeType != other.runtimeType) {
      return false;
    }
    final self = this as OkfLogEntry;
    return deepEquals(self.date, other.date) &&
        deepEquals(self.action, other.action) &&
        deepEquals(self.description, other.description);
  }

  @override
  int get hashCode {
    final self = this as OkfLogEntry;
    return Object.hashAll([
      runtimeType,
      deepHashCode(self.date),
      deepHashCode(self.action),
      deepHashCode(self.description),
    ]);
  }

  @override
  String toString() {
    final self = this as OkfLogEntry;
    return 'OkfLogEntry(date: ${self.date}, action: ${self.action}, description: ${self.description})';
  }

  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(OkfLogEntrySchema.encode(this as OkfLogEntry));

  SchemaResult<Map<String, Object?>> safeToJson() =>
      OkfLogEntrySchema.safeEncode(this as OkfLogEntry);
}

String _ackOkfLogEntryFromRuntimeDate(Object? value) => value as String;
Object? _ackOkfLogEntryToRuntimeDate(String value) => value;
String _ackOkfLogEntryFromRuntimeAction(Object? value) => value as String;
Object? _ackOkfLogEntryToRuntimeAction(String value) => value;
String _ackOkfLogEntryFromRuntimeDescription(Object? value) => value as String;
Object? _ackOkfLogEntryToRuntimeDescription(String value) => value;
