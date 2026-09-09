// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'inputs.dart';

// **************************************************************************
// AckModelGenerator
// **************************************************************************

final class _ListConceptsInputCopyWithUnset {
  const _ListConceptsInputCopyWithUnset();
}

/// Immutable model generated from `listConceptsInputSchema`.
@AckInfer.jsonSerializable
final class ListConceptsInput {
  ListConceptsInput({this.prefix, this.type, this.query});

  factory ListConceptsInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory ListConceptsInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  static const _ListConceptsInputCopyWithUnset _ackCopyWithUnset =
      _ListConceptsInputCopyWithUnset();

  final String? prefix;

  final String? type;

  /// Case-insensitive substring matched against each concept ID and title.
  final String? query;

  static final $ack = AckModelAdapter(
    schema: () => listConceptsInputSchema,
    fromRuntime: ListConceptsInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<ListConceptsInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  ListConceptsInput copyWith({
    Object? prefix = _ackCopyWithUnset,
    Object? type = _ackCopyWithUnset,
    Object? query = _ackCopyWithUnset,
  }) => ListConceptsInput(
    prefix: identical(prefix, _ackCopyWithUnset)
        ? this.prefix
        : prefix as String?,
    type: identical(type, _ackCopyWithUnset) ? this.type : type as String?,
    query: identical(query, _ackCopyWithUnset) ? this.query : query as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListConceptsInput &&
          runtimeType == other.runtimeType &&
          deepEquals(prefix, other.prefix) &&
          deepEquals(type, other.type) &&
          deepEquals(query, other.query));

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    deepHashCode(prefix),
    deepHashCode(type),
    deepHashCode(query),
  ]);

  @override
  String toString() =>
      'ListConceptsInput(prefix: $prefix, type: $type, query: $query)';

  static ListConceptsInput _fromAckRuntime(Map<String, Object?> value) =>
      _$ListConceptsInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$ListConceptsInputToJson(this),
  };

  static String? _ackFromRuntimePrefix(Object? value) => value as String?;

  static Object? _ackToRuntimePrefix(String? value) => value;

  static String? _ackFromRuntimeType(Object? value) => value as String?;

  static Object? _ackToRuntimeType(String? value) => value;

  static String? _ackFromRuntimeQuery(Object? value) => value as String?;

  static Object? _ackToRuntimeQuery(String? value) => value;
}

/// Immutable model generated from `lookupConceptInputSchema`.
@AckInfer.jsonSerializable
final class LookupConceptInput {
  LookupConceptInput({required this.id});

  factory LookupConceptInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory LookupConceptInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  final OkfConceptId id;

  static final $ack = AckModelAdapter(
    schema: () => lookupConceptInputSchema,
    fromRuntime: LookupConceptInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<LookupConceptInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  LookupConceptInput copyWith({OkfConceptId? id}) =>
      LookupConceptInput(id: id ?? this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookupConceptInput &&
          runtimeType == other.runtimeType &&
          deepEquals(id, other.id));

  @override
  int get hashCode => Object.hashAll([runtimeType, deepHashCode(id)]);

  @override
  String toString() => 'LookupConceptInput(id: $id)';

  static LookupConceptInput _fromAckRuntime(Map<String, Object?> value) =>
      _$LookupConceptInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$LookupConceptInputToJson(this),
  };

  static OkfConceptId _ackFromRuntimeId(Object? value) => value as OkfConceptId;

  static Object? _ackToRuntimeId(OkfConceptId value) => value;
}

final class _ValidateInputCopyWithUnset {
  const _ValidateInputCopyWithUnset();
}

/// Immutable model generated from `validateInputSchema`.
@AckInfer.jsonSerializable
final class ValidateInput {
  ValidateInput({this.strict});

  factory ValidateInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory ValidateInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  static const _ValidateInputCopyWithUnset _ackCopyWithUnset =
      _ValidateInputCopyWithUnset();

  /// Fail on advisories, as `--warnings-as-errors` does.
  final bool? strict;

  static final $ack = AckModelAdapter(
    schema: () => validateInputSchema,
    fromRuntime: ValidateInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<ValidateInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  ValidateInput copyWith({Object? strict = _ackCopyWithUnset}) => ValidateInput(
    strict: identical(strict, _ackCopyWithUnset)
        ? this.strict
        : strict as bool?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValidateInput &&
          runtimeType == other.runtimeType &&
          deepEquals(strict, other.strict));

  @override
  int get hashCode => Object.hashAll([runtimeType, deepHashCode(strict)]);

  @override
  String toString() => 'ValidateInput(strict: $strict)';

  static ValidateInput _fromAckRuntime(Map<String, Object?> value) =>
      _$ValidateInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$ValidateInputToJson(this),
  };

  static bool? _ackFromRuntimeStrict(Object? value) => value as bool?;

  static Object? _ackToRuntimeStrict(bool? value) => value;
}

final class _CreateConceptInputCopyWithUnset {
  const _CreateConceptInputCopyWithUnset();
}

/// Immutable model generated from `createConceptInputSchema`.
@AckInfer.jsonSerializable
final class CreateConceptInput {
  CreateConceptInput({
    required this.id,
    required this.type,
    this.title,
    this.description,
    List<String>? tags,
    this.body,
  }) : tags = switch (tags) {
         null => null,
         final fieldValue => List<String>.unmodifiable(
           fieldValue.map((item) => item),
         ),
       };

  factory CreateConceptInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory CreateConceptInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  static const _CreateConceptInputCopyWithUnset _ackCopyWithUnset =
      _CreateConceptInputCopyWithUnset();

  final OkfConceptId id;

  final String type;

  final String? title;

  final String? description;

  final List<String>? tags;

  final String? body;

  static final $ack = AckModelAdapter(
    schema: () => createConceptInputSchema,
    fromRuntime: CreateConceptInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<CreateConceptInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  CreateConceptInput copyWith({
    OkfConceptId? id,
    String? type,
    Object? title = _ackCopyWithUnset,
    Object? description = _ackCopyWithUnset,
    Object? tags = _ackCopyWithUnset,
    Object? body = _ackCopyWithUnset,
  }) => CreateConceptInput(
    id: id ?? this.id,
    type: type ?? this.type,
    title: identical(title, _ackCopyWithUnset) ? this.title : title as String?,
    description: identical(description, _ackCopyWithUnset)
        ? this.description
        : description as String?,
    tags: identical(tags, _ackCopyWithUnset)
        ? this.tags
        : tags as List<String>?,
    body: identical(body, _ackCopyWithUnset) ? this.body : body as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreateConceptInput &&
          runtimeType == other.runtimeType &&
          deepEquals(id, other.id) &&
          deepEquals(type, other.type) &&
          deepEquals(title, other.title) &&
          deepEquals(description, other.description) &&
          deepEquals(tags, other.tags) &&
          deepEquals(body, other.body));

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    deepHashCode(id),
    deepHashCode(type),
    deepHashCode(title),
    deepHashCode(description),
    deepHashCode(tags),
    deepHashCode(body),
  ]);

  @override
  String toString() =>
      'CreateConceptInput(id: $id, type: $type, title: $title, description: $description, tags: $tags, body: $body)';

  static CreateConceptInput _fromAckRuntime(Map<String, Object?> value) =>
      _$CreateConceptInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$CreateConceptInputToJson(this),
  };

  static OkfConceptId _ackFromRuntimeId(Object? value) => value as OkfConceptId;

  static Object? _ackToRuntimeId(OkfConceptId value) => value;

  static String _ackFromRuntimeType(Object? value) => value as String;

  static Object? _ackToRuntimeType(String value) => value;

  static String? _ackFromRuntimeTitle(Object? value) => value as String?;

  static Object? _ackToRuntimeTitle(String? value) => value;

  static String? _ackFromRuntimeDescription(Object? value) => value as String?;

  static Object? _ackToRuntimeDescription(String? value) => value;

  static List<String>? _ackFromRuntimeTags(Object? value) => switch (value) {
    null => null,
    final fieldValue =>
      (fieldValue as List).map((item) => item as String).toList(),
  };

  static Object? _ackToRuntimeTags(List<String>? value) => switch (value) {
    null => null,
    final fieldValue => fieldValue.map((item) => item).toList(growable: false),
  };

  static String? _ackFromRuntimeBody(Object? value) => value as String?;

  static Object? _ackToRuntimeBody(String? value) => value;
}

final class _UpdateConceptInputCopyWithUnset {
  const _UpdateConceptInputCopyWithUnset();
}

/// Immutable model generated from `updateConceptInputSchema`.
@AckInfer.jsonSerializable
final class UpdateConceptInput {
  UpdateConceptInput({
    required this.id,
    this.type,
    this.title,
    this.description,
    List<String>? tags,
    this.body,
  }) : tags = switch (tags) {
         null => null,
         final fieldValue => List<String>.unmodifiable(
           fieldValue.map((item) => item),
         ),
       };

  factory UpdateConceptInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory UpdateConceptInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  static const _UpdateConceptInputCopyWithUnset _ackCopyWithUnset =
      _UpdateConceptInputCopyWithUnset();

  final OkfConceptId id;

  final String? type;

  final String? title;

  final String? description;

  final List<String>? tags;

  final String? body;

  static final $ack = AckModelAdapter(
    schema: () => updateConceptInputSchema,
    fromRuntime: UpdateConceptInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<UpdateConceptInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  UpdateConceptInput copyWith({
    OkfConceptId? id,
    Object? type = _ackCopyWithUnset,
    Object? title = _ackCopyWithUnset,
    Object? description = _ackCopyWithUnset,
    Object? tags = _ackCopyWithUnset,
    Object? body = _ackCopyWithUnset,
  }) => UpdateConceptInput(
    id: id ?? this.id,
    type: identical(type, _ackCopyWithUnset) ? this.type : type as String?,
    title: identical(title, _ackCopyWithUnset) ? this.title : title as String?,
    description: identical(description, _ackCopyWithUnset)
        ? this.description
        : description as String?,
    tags: identical(tags, _ackCopyWithUnset)
        ? this.tags
        : tags as List<String>?,
    body: identical(body, _ackCopyWithUnset) ? this.body : body as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpdateConceptInput &&
          runtimeType == other.runtimeType &&
          deepEquals(id, other.id) &&
          deepEquals(type, other.type) &&
          deepEquals(title, other.title) &&
          deepEquals(description, other.description) &&
          deepEquals(tags, other.tags) &&
          deepEquals(body, other.body));

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    deepHashCode(id),
    deepHashCode(type),
    deepHashCode(title),
    deepHashCode(description),
    deepHashCode(tags),
    deepHashCode(body),
  ]);

  @override
  String toString() =>
      'UpdateConceptInput(id: $id, type: $type, title: $title, description: $description, tags: $tags, body: $body)';

  static UpdateConceptInput _fromAckRuntime(Map<String, Object?> value) =>
      _$UpdateConceptInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$UpdateConceptInputToJson(this),
  };

  static OkfConceptId _ackFromRuntimeId(Object? value) => value as OkfConceptId;

  static Object? _ackToRuntimeId(OkfConceptId value) => value;

  static String? _ackFromRuntimeType(Object? value) => value as String?;

  static Object? _ackToRuntimeType(String? value) => value;

  static String? _ackFromRuntimeTitle(Object? value) => value as String?;

  static Object? _ackToRuntimeTitle(String? value) => value;

  static String? _ackFromRuntimeDescription(Object? value) => value as String?;

  static Object? _ackToRuntimeDescription(String? value) => value;

  static List<String>? _ackFromRuntimeTags(Object? value) => switch (value) {
    null => null,
    final fieldValue =>
      (fieldValue as List).map((item) => item as String).toList(),
  };

  static Object? _ackToRuntimeTags(List<String>? value) => switch (value) {
    null => null,
    final fieldValue => fieldValue.map((item) => item).toList(growable: false),
  };

  static String? _ackFromRuntimeBody(Object? value) => value as String?;

  static Object? _ackToRuntimeBody(String? value) => value;
}

/// Immutable model generated from `linkConceptsInputSchema`.
@AckInfer.jsonSerializable
final class LinkConceptsInput {
  LinkConceptsInput({
    required this.source,
    required this.target,
    required this.relationship,
  });

  factory LinkConceptsInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory LinkConceptsInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  final OkfConceptId source;

  final OkfConceptId target;

  /// Producer-defined relationship type.
  final String relationship;

  static final $ack = AckModelAdapter(
    schema: () => linkConceptsInputSchema,
    fromRuntime: LinkConceptsInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<LinkConceptsInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  LinkConceptsInput copyWith({
    OkfConceptId? source,
    OkfConceptId? target,
    String? relationship,
  }) => LinkConceptsInput(
    source: source ?? this.source,
    target: target ?? this.target,
    relationship: relationship ?? this.relationship,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkConceptsInput &&
          runtimeType == other.runtimeType &&
          deepEquals(source, other.source) &&
          deepEquals(target, other.target) &&
          deepEquals(relationship, other.relationship));

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    deepHashCode(source),
    deepHashCode(target),
    deepHashCode(relationship),
  ]);

  @override
  String toString() =>
      'LinkConceptsInput(source: $source, target: $target, relationship: $relationship)';

  static LinkConceptsInput _fromAckRuntime(Map<String, Object?> value) =>
      _$LinkConceptsInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$LinkConceptsInputToJson(this),
  };

  static OkfConceptId _ackFromRuntimeSource(Object? value) =>
      value as OkfConceptId;

  static Object? _ackToRuntimeSource(OkfConceptId value) => value;

  static OkfConceptId _ackFromRuntimeTarget(Object? value) =>
      value as OkfConceptId;

  static Object? _ackToRuntimeTarget(OkfConceptId value) => value;

  static String _ackFromRuntimeRelationship(Object? value) => value as String;

  static Object? _ackToRuntimeRelationship(String value) => value;
}

final class _DeprecateConceptInputCopyWithUnset {
  const _DeprecateConceptInputCopyWithUnset();
}

/// Immutable model generated from `deprecateConceptInputSchema`.
@AckInfer.jsonSerializable
final class DeprecateConceptInput {
  DeprecateConceptInput({required this.id, this.note});

  factory DeprecateConceptInput.parse(Object? input) {
    return $ack.parse(input);
  }

  factory DeprecateConceptInput.fromJson(Map<String, dynamic> json) {
    return $ack.parse(json);
  }

  static const _DeprecateConceptInputCopyWithUnset _ackCopyWithUnset =
      _DeprecateConceptInputCopyWithUnset();

  final OkfConceptId id;

  /// Context recorded with the lifecycle change.
  final String? note;

  static final $ack = AckModelAdapter(
    schema: () => deprecateConceptInputSchema,
    fromRuntime: DeprecateConceptInput._fromAckRuntime,
    toRuntime: (model) => model._toAckRuntime(),
  );

  static SchemaResult<DeprecateConceptInput> safeParse(Object? input) =>
      $ack.safeParse(input);

  Map<String, dynamic> toJson() => Map<String, dynamic>.from($ack.encode(this));

  SchemaResult<Map<String, Object?>> safeToJson() => $ack.safeEncode(this);

  DeprecateConceptInput copyWith({
    OkfConceptId? id,
    Object? note = _ackCopyWithUnset,
  }) => DeprecateConceptInput(
    id: id ?? this.id,
    note: identical(note, _ackCopyWithUnset) ? this.note : note as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeprecateConceptInput &&
          runtimeType == other.runtimeType &&
          deepEquals(id, other.id) &&
          deepEquals(note, other.note));

  @override
  int get hashCode =>
      Object.hashAll([runtimeType, deepHashCode(id), deepHashCode(note)]);

  @override
  String toString() => 'DeprecateConceptInput(id: $id, note: $note)';

  static DeprecateConceptInput _fromAckRuntime(Map<String, Object?> value) =>
      _$DeprecateConceptInputFromJson(Map<String, dynamic>.from(value));

  Map<String, Object?> _toAckRuntime() => <String, Object?>{
    ..._$DeprecateConceptInputToJson(this),
  };

  static OkfConceptId _ackFromRuntimeId(Object? value) => value as OkfConceptId;

  static Object? _ackToRuntimeId(OkfConceptId value) => value;

  static String? _ackFromRuntimeNote(Object? value) => value as String?;

  static Object? _ackToRuntimeNote(String? value) => value;
}
