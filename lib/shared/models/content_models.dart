import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
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
    required String filePathEnglish,
    required String filePathPersian,
    required List<TextSegmentEnglish> contentEnglish,
    required List<TextSegmentPersian> contentPersian,
    required String notesFilePath,
    // required List<String> audioFilePaths,
    String? audioFileName,
  }) = _FinalTopic;

  factory FinalTopic.fromJson(Map<String, dynamic> json) =>
      _$FinalTopicFromJson(json);

  // static FileSystemEntity? _findJsonFileEnglish(
  //   List<FileSystemEntity> fileList,
  // ) {
  //   try {
  //     // استفاده از firstWhere و مدیریت خطای StateError
  //     return fileList.firstWhere((f) => f.path.endsWith('.english.json'));
  //   } on StateError {
  //     // اگر هیچ فایلی با پسوند .json پیدا نشد
  //     return null;
  //   }
  // }

  // static FileSystemEntity? _findJsonFileTranslation(
  //   List<FileSystemEntity> fileList,
  // ) {
  //   try {
  //     // استفاده از firstWhere و مدیریت خطای StateError
  //     return fileList.firstWhere((f) => f.path.endsWith('.translation.json'));
  //   } on StateError {
  //     // اگر هیچ فایلی با پسوند .json پیدا نشد
  //     return null;
  //   }
  // }

  // static FileSystemEntity? _findJsonFileNote(List<FileSystemEntity> fileList) {
  //   try {
  //     // استفاده از firstWhere و مدیریت خطای StateError
  //     return fileList.firstWhere((f) => f.path.endsWith('.notes.json'));
  //   } on StateError {
  //     // اگر هیچ فایلی با پسوند .json پیدا نشد
  //     return null;
  //   }
  // }

  // static String? _findAudioFile(List<FileSystemEntity> fileList) {
  //   try {
  //     FileSystemEntity? fileSystemEntity = fileList
  //         .where((f) => f.path.endsWith('.sound.txt'))
  //         .firstOrNull;
  //     if (fileSystemEntity != null) {
  //       String fileName = p
  //           .basenameWithoutExtension(fileSystemEntity.path)
  //           .replaceAll('.sound', '');
  //       return fileName;
  //     }
  //   } on StateError {
  //     return null;
  //   }
  //   return null;
  // }

  factory FinalTopic.fromDirectory(Directory mainTopicDir) {
    return CfPublic().parseFinalTopic(mainTopicDir);
  }
}

// class Sentence {
//   final String text;
//   final bool isSpecial; // آیا جمله‌ای است که قابلیت تغییر رنگ دارد؟

//   Sentence({required this.text, required this.isSpecial});
// }
class TextSegmentEnglish {
  final String text;
  final String? originText;
  final bool isInteractive;
  final bool? isBlank;
  final bool? hasSubItems;
  final List<dynamic>? subItems;
  final bool? isBold;
  final bool? isAmberHighlighted;
  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی
  final String? cerfLevel; // توضیحات تکمیلی
  final String? pronounce;
  final bool? isRtl;

  TextSegmentEnglish({
    required this.text,
    required this.isInteractive,
    this.isBlank,
    this.hasSubItems,
    this.subItems,
    this.isBold,
    this.originText,
    this.isAmberHighlighted,
    this.translation,
    this.explanation,
    this.cerfLevel,
    this.pronounce,
    this.isRtl,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {
      'text': text,
      'isInteractive': isInteractive,
    };
    if (originText != null) {
      result['originText'] = originText;
    }
    if (originText != null) {
      result['isBlank'] = isBlank;
    }
    if (originText != null) {
      result['hasSubItems'] = hasSubItems;
    }
    if (originText != null) {
      result['subItems'] = subItems;
    }
    if (originText != null) {
      result['isBold'] = isBold;
    }
    if (originText != null) {
      result['isAmberHighlighted'] = isAmberHighlighted;
    }
    if (originText != null) {
      result['translation'] = translation;
    }
    if (originText != null) {
      result['explanation'] = explanation;
    }
    if (originText != null) {
      result['cerfLevel'] = cerfLevel;
    }
    if (originText != null) {
      result['pronounce'] = pronounce;
    }
    if (originText != null) {
      result['isRtl'] = isRtl;
    }

    return result;
  }

  factory TextSegmentEnglish.fromJson(Map<String, dynamic> json) {
    return TextSegmentEnglish(
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

class TextSegmentPersian {
  final String text;
  final bool? isBold;
  final bool? isAmberHighlighted;

  TextSegmentPersian({
    required this.text,
    this.isBold,
    this.isAmberHighlighted,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {'text': text};
    if (isBold != null) {
      result['isBold'] = isBold;
    }
    if (isBold != null) {
      result['isAmberHighlighted'] = isAmberHighlighted;
    }
    return result;
  }

  factory TextSegmentPersian.fromJson(Map<String, dynamic> json) {
    return TextSegmentPersian(
      text: json['text'] as String,
      isBold: json['isBold'] as bool?,
    );
  }
}

class OriginalContent {
  final String book;
  final String unit;
  final String topic;
  final String page;
  final String root;
  final String originalContent;
  final FinalTopic finalTopic;
  OriginalContent({
    required this.book,
    required this.unit,
    required this.topic,
    required this.page,
    required this.root,
    required this.originalContent,
    required this.finalTopic,
  });
}
