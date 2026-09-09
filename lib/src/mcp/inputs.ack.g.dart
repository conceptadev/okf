// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'inputs.dart';

// **************************************************************************
// AckJsonSerializableGenerator
// **************************************************************************

ListConceptsInput _$ListConceptsInputFromJson(Map<String, dynamic> json) =>
    ListConceptsInput(
      prefix: ListConceptsInput._ackFromRuntimePrefix(json['prefix']),
      type: ListConceptsInput._ackFromRuntimeType(json['type']),
      query: ListConceptsInput._ackFromRuntimeQuery(json['query']),
    );

Map<String, dynamic> _$ListConceptsInputToJson(ListConceptsInput instance) =>
    <String, dynamic>{
      'prefix': ?ListConceptsInput._ackToRuntimePrefix(instance.prefix),
      'type': ?ListConceptsInput._ackToRuntimeType(instance.type),
      'query': ?ListConceptsInput._ackToRuntimeQuery(instance.query),
    };

LookupConceptInput _$LookupConceptInputFromJson(Map<String, dynamic> json) =>
    LookupConceptInput(id: LookupConceptInput._ackFromRuntimeId(json['id']));

Map<String, dynamic> _$LookupConceptInputToJson(LookupConceptInput instance) =>
    <String, dynamic>{'id': LookupConceptInput._ackToRuntimeId(instance.id)};

ValidateInput _$ValidateInputFromJson(Map<String, dynamic> json) =>
    ValidateInput(strict: ValidateInput._ackFromRuntimeStrict(json['strict']));

Map<String, dynamic> _$ValidateInputToJson(ValidateInput instance) =>
    <String, dynamic>{
      'strict': ?ValidateInput._ackToRuntimeStrict(instance.strict),
    };

CreateConceptInput _$CreateConceptInputFromJson(Map<String, dynamic> json) =>
    CreateConceptInput(
      id: CreateConceptInput._ackFromRuntimeId(json['id']),
      type: CreateConceptInput._ackFromRuntimeType(json['type']),
      title: CreateConceptInput._ackFromRuntimeTitle(json['title']),
      description: CreateConceptInput._ackFromRuntimeDescription(
        json['description'],
      ),
      tags: CreateConceptInput._ackFromRuntimeTags(json['tags']),
      body: CreateConceptInput._ackFromRuntimeBody(json['body']),
    );

Map<String, dynamic> _$CreateConceptInputToJson(CreateConceptInput instance) =>
    <String, dynamic>{
      'id': CreateConceptInput._ackToRuntimeId(instance.id),
      'type': CreateConceptInput._ackToRuntimeType(instance.type),
      'title': ?CreateConceptInput._ackToRuntimeTitle(instance.title),
      'description': ?CreateConceptInput._ackToRuntimeDescription(
        instance.description,
      ),
      'tags': ?CreateConceptInput._ackToRuntimeTags(instance.tags),
      'body': ?CreateConceptInput._ackToRuntimeBody(instance.body),
    };

UpdateConceptInput _$UpdateConceptInputFromJson(Map<String, dynamic> json) =>
    UpdateConceptInput(
      id: UpdateConceptInput._ackFromRuntimeId(json['id']),
      type: UpdateConceptInput._ackFromRuntimeType(json['type']),
      title: UpdateConceptInput._ackFromRuntimeTitle(json['title']),
      description: UpdateConceptInput._ackFromRuntimeDescription(
        json['description'],
      ),
      tags: UpdateConceptInput._ackFromRuntimeTags(json['tags']),
      body: UpdateConceptInput._ackFromRuntimeBody(json['body']),
    );

Map<String, dynamic> _$UpdateConceptInputToJson(UpdateConceptInput instance) =>
    <String, dynamic>{
      'id': UpdateConceptInput._ackToRuntimeId(instance.id),
      'type': ?UpdateConceptInput._ackToRuntimeType(instance.type),
      'title': ?UpdateConceptInput._ackToRuntimeTitle(instance.title),
      'description': ?UpdateConceptInput._ackToRuntimeDescription(
        instance.description,
      ),
      'tags': ?UpdateConceptInput._ackToRuntimeTags(instance.tags),
      'body': ?UpdateConceptInput._ackToRuntimeBody(instance.body),
    };

LinkConceptsInput _$LinkConceptsInputFromJson(Map<String, dynamic> json) =>
    LinkConceptsInput(
      source: LinkConceptsInput._ackFromRuntimeSource(json['source']),
      target: LinkConceptsInput._ackFromRuntimeTarget(json['target']),
      relationship: LinkConceptsInput._ackFromRuntimeRelationship(
        json['relationship'],
      ),
    );

Map<String, dynamic> _$LinkConceptsInputToJson(LinkConceptsInput instance) =>
    <String, dynamic>{
      'source': LinkConceptsInput._ackToRuntimeSource(instance.source),
      'target': LinkConceptsInput._ackToRuntimeTarget(instance.target),
      'relationship': LinkConceptsInput._ackToRuntimeRelationship(
        instance.relationship,
      ),
    };

DeprecateConceptInput _$DeprecateConceptInputFromJson(
  Map<String, dynamic> json,
) => DeprecateConceptInput(
  id: DeprecateConceptInput._ackFromRuntimeId(json['id']),
  note: DeprecateConceptInput._ackFromRuntimeNote(json['note']),
);

Map<String, dynamic> _$DeprecateConceptInputToJson(
  DeprecateConceptInput instance,
) => <String, dynamic>{
  'id': DeprecateConceptInput._ackToRuntimeId(instance.id),
  'note': ?DeprecateConceptInput._ackToRuntimeNote(instance.note),
};
