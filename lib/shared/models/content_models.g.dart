// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StudyContent _$StudyContentFromJson(Map<String, dynamic> json) =>
    _StudyContent(
      books: (json['books'] as List<dynamic>)
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$StudyContentToJson(_StudyContent instance) =>
    <String, dynamic>{'books': instance.books};

_Book _$BookFromJson(Map<String, dynamic> json) => _Book(
  name: json['name'] as String,
  units: (json['units'] as List<dynamic>)
      .map((e) => Unit.fromJson(e as Map<String, dynamic>))
      .toList(),
  dayContents: (json['dayContents'] as List<dynamic>?)
      ?.map((e) => DayContent.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BookToJson(_Book instance) => <String, dynamic>{
  'name': instance.name,
  'units': instance.units,
  'dayContents': instance.dayContents,
};

_Unit _$UnitFromJson(Map<String, dynamic> json) => _Unit(
  name: json['name'] as String,
  topics: (json['topics'] as List<dynamic>)
      .map((e) => Topic.fromJson(e as Map<String, dynamic>))
      .toList(),
  listeningContent: (json['listeningContent'] as List<dynamic>?)
      ?.map((e) => ListeningContent.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UnitToJson(_Unit instance) => <String, dynamic>{
  'name': instance.name,
  'topics': instance.topics,
  'listeningContent': instance.listeningContent,
};

_Topic _$TopicFromJson(Map<String, dynamic> json) => _Topic(
  name: json['name'] as String,
  realmId: json['realmId'] as String,
  pageContents: (json['pageContents'] as List<dynamic>)
      .map((e) => PageContent.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TopicToJson(_Topic instance) => <String, dynamic>{
  'name': instance.name,
  'realmId': instance.realmId,
  'pageContents': instance.pageContents,
};

_PageContent _$PageContentFromJson(Map<String, dynamic> json) => _PageContent(
  name: json['name'] as String,
  realmId: json['realmId'] as String,
  finalTopics: (json['finalTopics'] as List<dynamic>)
      .map((e) => FinalTopic.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PageContentToJson(_PageContent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'realmId': instance.realmId,
      'finalTopics': instance.finalTopics,
    };

_DayContent _$DayContentFromJson(Map<String, dynamic> json) => _DayContent(
  name: json['name'] as String,
  realmId: json['realmId'] as String,
  finalTopics: (json['finalTopics'] as List<dynamic>)
      .map((e) => FinalTopic.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DayContentToJson(_DayContent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'realmId': instance.realmId,
      'finalTopics': instance.finalTopics,
    };

_ListeningContent _$ListeningContentFromJson(Map<String, dynamic> json) =>
    _ListeningContent(
      name: json['name'] as String,
      realmId: json['realmId'] as String,
      finalTopics: (json['finalTopics'] as List<dynamic>)
          .map((e) => FinalTopic.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ListeningContentToJson(_ListeningContent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'realmId': instance.realmId,
      'finalTopics': instance.finalTopics,
    };

_FinalTopic _$FinalTopicFromJson(Map<String, dynamic> json) => _FinalTopic(
  name: json['name'] as String,
  realmId: json['realmId'] as String,
  filePathEnglish: json['filePathEnglish'] as String,
  filePathPersian: json['filePathPersian'] as String,
  contentEnglish: (json['contentEnglish'] as List<dynamic>)
      .map((e) => TextSegmentEnglish.fromJson(e as Map<String, dynamic>))
      .toList(),
  contentPersian: (json['contentPersian'] as List<dynamic>)
      .map((e) => TextSegmentPersian.fromJson(e as Map<String, dynamic>))
      .toList(),
  notesFilePath: json['notesFilePath'] as String,
  audioFileName: json['audioFileName'] as String?,
);

Map<String, dynamic> _$FinalTopicToJson(_FinalTopic instance) =>
    <String, dynamic>{
      'name': instance.name,
      'realmId': instance.realmId,
      'filePathEnglish': instance.filePathEnglish,
      'filePathPersian': instance.filePathPersian,
      'contentEnglish': instance.contentEnglish,
      'contentPersian': instance.contentPersian,
      'notesFilePath': instance.notesFilePath,
      'audioFileName': instance.audioFileName,
    };
