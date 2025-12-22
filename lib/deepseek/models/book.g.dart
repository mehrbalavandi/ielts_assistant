// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Book _$BookFromJson(Map<String, dynamic> json) => _Book(
  id: json['id'] as String,
  name: json['name'] as String,
  folderPath: json['folderPath'] as String,
  lastOpened: (json['lastOpened'] as num?)?.toInt() ?? 0,
  isFavorite: json['isFavorite'] as bool? ?? false,
);

Map<String, dynamic> _$BookToJson(_Book instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'folderPath': instance.folderPath,
  'lastOpened': instance.lastOpened,
  'isFavorite': instance.isFavorite,
};

_Lesson _$LessonFromJson(Map<String, dynamic> json) => _Lesson(
  id: json['id'] as String,
  bookId: json['bookId'] as String,
  name: json['name'] as String,
  filePath: json['filePath'] as String,
  currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
  totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
  lastPosition: json['lastPosition'] == null
      ? Duration.zero
      : Duration(microseconds: (json['lastPosition'] as num).toInt()),
);

Map<String, dynamic> _$LessonToJson(_Lesson instance) => <String, dynamic>{
  'id': instance.id,
  'bookId': instance.bookId,
  'name': instance.name,
  'filePath': instance.filePath,
  'currentPage': instance.currentPage,
  'totalPages': instance.totalPages,
  'lastPosition': instance.lastPosition.inMicroseconds,
};
