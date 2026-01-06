import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
part 'content_models.freezed.dart';
part 'content_models.g.dart';

@freezed
sealed class StudyContent with _$StudyContent {
  const factory StudyContent({required List<Book> books}) = _StudyContent;

  factory StudyContent.fromJson(Map<String, dynamic> json) =>
      _$StudyContentFromJson(json);
}

@freezed
sealed class Book with _$Book {
  const factory Book({required String name, required List<Unit> units}) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

@freezed
sealed class Unit with _$Unit {
  const factory Unit({required String name, required List<Topic> topics}) =
      _Unit;

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
}

@freezed
sealed class Topic with _$Topic {
  const factory Topic({
    required String name,
    required String realmId,
    required List<PageContent> pageContents,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}

@freezed
sealed class PageContent with _$PageContent {
  const factory PageContent({
    required String name,
    required String realmId,
    required List<FinalTopic> finalTopics,
  }) = _PageContent;

  factory PageContent.fromJson(Map<String, dynamic> json) =>
      _$PageContentFromJson(json);
}

@freezed
sealed class FinalTopic with _$FinalTopic {
  const factory FinalTopic({
    required String name,
    required String realmId,
    required String jsonFilePath,
    required String translationFilePath,
    // required List<String> audioFilePaths,
    String? audioFileName,
  }) = _FinalTopic;

  factory FinalTopic.fromJson(Map<String, dynamic> json) =>
      _$FinalTopicFromJson(json);

  static FileSystemEntity? _findJsonFileEnglish(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('.english.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  static FileSystemEntity? _findJsonFileTranslation(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('.translation.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  static String? _findAudioFile(List<FileSystemEntity> fileList) {
    try {
      FileSystemEntity? fileSystemEntity = fileList
          .where((f) => f.path.endsWith('.sound.txt'))
          .firstOrNull;
      if (fileSystemEntity != null) {
        String fileName = p
            .basenameWithoutExtension(fileSystemEntity.path)
            .replaceAll('.sound', '');
        return fileName;
      }
    } on StateError {
      return null;
    }
    return null;
  }

  factory FinalTopic.fromDirectory(Directory mainTopicDir) {
    final files = mainTopicDir.listSync();

    final audioFiles = files
        .where((f) => f.path.endsWith('.mp3'))
        .map((f) => f.path)
        .toList();

    final jsonFileEntityEnglish = _findJsonFileEnglish(files);

    final jsonFilePathEnglish = jsonFileEntityEnglish?.path ?? '';

    final jsonFileEntityTranslation = _findJsonFileTranslation(files);

    final jsonFilePathTranslation = jsonFileEntityTranslation?.path ?? '';

    return FinalTopic(
      name: p.basename(mainTopicDir.path),
      realmId: mainTopicDir.path, // مسیر کامل پوشه به عنوان ID
      // audioFilePaths: audioFiles.cast<String>(),
      audioFileName: _findAudioFile(files),
      jsonFilePath: jsonFilePathEnglish,
      translationFilePath: jsonFilePathTranslation,
    );
  }
}

// class Sentence {
//   final String text;
//   final bool isSpecial; // آیا جمله‌ای است که قابلیت تغییر رنگ دارد؟

//   Sentence({required this.text, required this.isSpecial});
// }
class MainTextSegment {
  final String text;
  final bool isInteractive;
  final bool? isBlank;
  final bool? hasSubItems;
  final List<dynamic>? subItems;
  final bool? isBold;
  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی

  MainTextSegment({
    required this.text,
    required this.isInteractive,
    this.isBlank,
    this.hasSubItems,
    this.subItems,
    this.isBold,
    this.translation,
    this.explanation,
  });

  factory MainTextSegment.fromJson(Map<String, dynamic> json) {
    return MainTextSegment(
      text: json['text'] as String,
      isInteractive: json['isInteractive'] as bool,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
      isBlank: json['isBlank'] as bool?,
      hasSubItems: json['hasSubItems'] as bool?,
      subItems: json['subItems'] as List<dynamic>?,
      isBold: json['isBold'] as bool?,
    );
  }
}

class PersianTextSegment {
  final String text;
  final bool? isBold;

  PersianTextSegment({required this.text, this.isBold});

  factory PersianTextSegment.fromJson(Map<String, dynamic> json) {
    return PersianTextSegment(
      text: json['text'] as String,
      isBold: json['isBold'] as bool?,
    );
  }
}
