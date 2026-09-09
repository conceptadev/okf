// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'index_log.dart';

// **************************************************************************
// AckJsonSerializableGenerator
// **************************************************************************

OkfIndexEntry _$OkfIndexEntryFromJson(Map<String, dynamic> json) =>
    OkfIndexEntry(
      type: _ackOkfIndexEntryFromRuntimeType(json['type']),
      title: _ackOkfIndexEntryFromRuntimeTitle(json['title']),
      link: _ackOkfIndexEntryFromRuntimeLink(json['link']),
      description: _ackOkfIndexEntryFromRuntimeDescription(json['description']),
    );

Map<String, dynamic> _$OkfIndexEntryToJson(
  OkfIndexEntry instance,
) => <String, dynamic>{
  'type': _ackOkfIndexEntryToRuntimeType(instance.type),
  'title': _ackOkfIndexEntryToRuntimeTitle(instance.title),
  'link': _ackOkfIndexEntryToRuntimeLink(instance.link),
  'description': _ackOkfIndexEntryToRuntimeDescription(instance.description),
};

OkfLogEntry _$OkfLogEntryFromJson(Map<String, dynamic> json) => OkfLogEntry(
  date: _ackOkfLogEntryFromRuntimeDate(json['date']),
  action: _ackOkfLogEntryFromRuntimeAction(json['action']),
  description: _ackOkfLogEntryFromRuntimeDescription(json['description']),
);

Map<String, dynamic> _$OkfLogEntryToJson(OkfLogEntry instance) =>
    <String, dynamic>{
      'date': _ackOkfLogEntryToRuntimeDate(instance.date),
      'action': _ackOkfLogEntryToRuntimeAction(instance.action),
      'description': _ackOkfLogEntryToRuntimeDescription(instance.description),
    };
