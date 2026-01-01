import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';

part 'content_models.freezed.dart';
part 'content_models.g.dart';

@freezed
abstract class StudyContent with _$StudyContent {
  const factory StudyContent({required List<Book> books}) = _StudyContent;

  factory StudyContent.fromJson(Map<String, dynamic> json) =>
      _$StudyContentFromJson(json);
}

@freezed
abstract class Book with _$Book {
  const factory Book({required String name, required List<Unit> units}) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

@freezed
abstract class Unit with _$Unit {
  const factory Unit({required String name, required List<Topic> topics}) =
      _Unit;

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
}

@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required String name,
    required String realmId,
    required List<PageContent> pageContents,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}

@freezed
abstract class PageContent with _$PageContent {
  const factory PageContent({
    required String name,
    required String realmId,
    required List<FinalTopic> finalTopics,
  }) = _PageContent;

  factory PageContent.fromJson(Map<String, dynamic> json) =>
      _$PageContentFromJson(json);
}

@freezed
abstract class FinalTopic with _$FinalTopic {
  const factory FinalTopic({
    required String name,
    required String realmId,
    required String jsonFilePath,
    required String translationFilePath,
    required List<String> audioFilePaths,
    String? audioFileName,
  }) = _FinalTopic;

  factory FinalTopic.fromJson(Map<String, dynamic> json) =>
      _$FinalTopicFromJson(json);

  static FileSystemEntity? _findJsonFileEnglish(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('english.json'));
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
      return fileList.firstWhere((f) => f.path.endsWith('translation.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  // متد سازنده کارخانه‌ای برای ساخت شیء mainTopic از روی پوشه نهایی
  factory FinalTopic.fromDirectory(Directory mainTopicDir) {
    final files = mainTopicDir.listSync();

    // ۱. استخراج مسیر فایل‌های صوتی (.mp3)
    final audioFiles = files
        .where((f) => f.path.endsWith('.mp3'))
        .map((f) => f.path)
        .toList();

    // ۲. استخراج فایل JSON
    final jsonFileEntityEnglish = _findJsonFileEnglish(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathEnglish = jsonFileEntityEnglish?.path ?? '';
    // ۲. استخراج فایل JSON
    final jsonFileEntityTranslation = _findJsonFileTranslation(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathTranslation = jsonFileEntityTranslation?.path ?? '';

    return FinalTopic(
      name: basename(mainTopicDir.path),
      realmId: mainTopicDir.path, // مسیر کامل پوشه به عنوان ID
      audioFilePaths: audioFiles.cast<String>(),
      jsonFilePath: jsonFilePathEnglish,
      translationFilePath: jsonFilePathTranslation,
    );
  }
}

// کلاس نهایی که فایل‌های صوتی و JSON را در خود دارد (سطح نهایی پیمایش)
class FinalTopicOld {
  final String name;
  final String realmId; // شناسه منحصر به فرد (مسیر کامل پوشه)
  final List<String> audioFilePaths;
  final String jsonFilePath; // مسیر فایل متنی درس
  final String translationFilePath; // مسیر فایل متنی ترجمه درس

  FinalTopicOld({
    required this.name,
    required this.realmId,
    required this.audioFilePaths,
    required this.jsonFilePath,
    required this.translationFilePath,
  });

  // تابع کمکی برای پیدا کردن فایل JSON و جلوگیری از خطای StateError
  // اگر فایل پیدا نشود، null برمی‌گرداند.
  static FileSystemEntity? _findJsonFileEnglish(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('english.json'));
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
      return fileList.firstWhere((f) => f.path.endsWith('translation.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  // متد سازنده کارخانه‌ای برای ساخت شیء mainTopic از روی پوشه نهایی
  factory FinalTopicOld.fromDirectory(Directory mainTopicDir) {
    final files = mainTopicDir.listSync();

    // ۱. استخراج مسیر فایل‌های صوتی (.mp3)
    final audioFiles = files
        .where((f) => f.path.endsWith('.mp3'))
        .map((f) => f.path)
        .toList();

    // ۲. استخراج فایل JSON
    final jsonFileEntityEnglish = _findJsonFileEnglish(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathEnglish = jsonFileEntityEnglish?.path ?? '';
    // ۲. استخراج فایل JSON
    final jsonFileEntityTranslation = _findJsonFileTranslation(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathTranslation = jsonFileEntityTranslation?.path ?? '';

    return FinalTopicOld(
      name: basename(mainTopicDir.path),
      realmId: mainTopicDir.path, // مسیر کامل پوشه به عنوان ID
      audioFilePaths: audioFiles.cast<String>(),
      jsonFilePath: jsonFilePathEnglish,
      translationFilePath: jsonFilePathTranslation,
    );
  }
}
