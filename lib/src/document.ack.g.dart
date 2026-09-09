// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'document.dart';

// **************************************************************************
// AckJsonSerializableGenerator
// **************************************************************************

OkfLegacyCitation _$OkfLegacyCitationFromJson(Map<String, dynamic> json) =>
    OkfLegacyCitation(
      number: _ackOkfLegacyCitationFromRuntimeNumber(json['number']),
      title: _ackOkfLegacyCitationFromRuntimeTitle(json['title']),
      target: _ackOkfLegacyCitationFromRuntimeTarget(json['target']),
      raw: _ackOkfLegacyCitationFromRuntimeRaw(json['raw']),
    );

Map<String, dynamic> _$OkfLegacyCitationToJson(OkfLegacyCitation instance) =>
    <String, dynamic>{
      'number': _ackOkfLegacyCitationToRuntimeNumber(instance.number),
      'title': _ackOkfLegacyCitationToRuntimeTitle(instance.title),
      'target': _ackOkfLegacyCitationToRuntimeTarget(instance.target),
      'raw': _ackOkfLegacyCitationToRuntimeRaw(instance.raw),
    };
