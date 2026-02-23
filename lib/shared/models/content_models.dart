import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
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
  const factory Book({
    required String name,
    required List<Unit> units,
    // required List<OtherContent>? otherContents,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

@freezed
sealed class Unit with _$Unit {
  const factory Unit({
    required String name,
    required List<Topic> topics,
    // required List<OtherContent>? otherContents,
  }) = _Unit;

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
sealed class OtherContent with _$OtherContent {
  const factory OtherContent({
    required String name,
    required String realmId,
    required List<FinalTopic> finalTopics,
  }) = _OtherContent;

  factory OtherContent.fromJson(Map<String, dynamic> json) =>
      _$OtherContentFromJson(json);
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
  String text;
  String? originText;
  bool isInteractive;

  bool? isBold;
  bool? isBlank;
  bool? isItalic;
  bool? isUnderLine;
  bool? isLineThrough;
  bool? isHighlight;

  bool? hasSubItems;
  List<TextSegmentEnglish>? subItems;
  bool? isSearchHighlighted;
  String? translation; // ترجمه فارسی
  String? explanation; // توضیحات تکمیلی
  String? cerfLevel; //
  String? pronounce;
  bool? isRtl;
  // Map<String, dynamic>? extra;

  TextSegmentEnglish({
    required this.text,
    required this.isInteractive,
    this.isBlank,
    this.hasSubItems,
    this.subItems,
    this.isBold,
    this.isItalic,
    this.isUnderLine,
    this.isLineThrough,
    this.isHighlight,
    this.originText,
    this.isSearchHighlighted,
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
    if (isBlank != null) {
      result['isBlank'] = isBlank;
    }
    if (hasSubItems != null) {
      result['hasSubItems'] = hasSubItems;
    }
    if (subItems != null) {
      // result['subItems'] = subItems;
      result['subItems'] = subItems!.map((e) => e.toJson()).toList();
    }
    if (isBold != null) {
      result['isBold'] = isBold;
    }
    if (isSearchHighlighted != null) {
      result['isSearchHighlighted'] = isSearchHighlighted;
    }
    if (translation != null) {
      result['translation'] = translation;
    }
    if (explanation != null) {
      result['explanation'] = explanation;
    }
    if (cerfLevel != null) {
      result['cerfLevel'] = cerfLevel;
    }
    if (pronounce != null) {
      result['pronounce'] = pronounce;
    }
    if (isRtl != null) {
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
      pronounce: json['pronounce'] as String?,
      cerfLevel: json['cerfLevel'] as String?,
      isBlank: json['isBlank'] as bool?,
      hasSubItems: json['hasSubItems'] as bool?,
      // subItems: json['subItems'] as List<dynamic>?,
      subItems: json["subItems"] == null
          ? null
          : (json["subItems"] as List)
                .map((e) => TextSegmentEnglish.fromJson(e))
                .toList(),
      isBold: json['isBold'] as bool?,
    );
  }
}

class TextSegmentPersian {
  String text;

  String? translation; // ترجمه فارسی
  String? explanation; // توضیحات تکمیلی

  bool? isBold;
  bool? isItalic;
  bool? isUnderLine;
  bool? isLineThrough;
  bool? isHighlight;

  bool? isSearchHighlighted;

  TextSegmentPersian({
    required this.text,

    this.translation,
    this.explanation,
    this.isBold,
    this.isItalic,
    this.isUnderLine,
    this.isLineThrough,
    this.isHighlight,
    this.isSearchHighlighted,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {'text': text};

    if (isBold != null) {
      result['isBold'] = isBold;
    }
    if (isSearchHighlighted != null) {
      result['isSearchHighlighted'] = isSearchHighlighted;
    }
    if (translation != null) {
      result['translation'] = translation;
    }
    if (explanation != null) {
      result['explanation'] = explanation;
    }
    return result;
  }

  factory TextSegmentPersian.fromJson(Map<String, dynamic> json) {
    return TextSegmentPersian(
      text: json['text'] as String,
      isBold: json['isBold'] as bool?,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
    );
  }
}

/*
class TextSegmentPersianTempelate {
  final String text;

  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی
  final bool? isBold;
  final bool? isSearchHighlighted;

  TextSegmentPersianTempelate({
    required this.text,

    this.isBold,
    this.translation,
    this.explanation,
    this.isSearchHighlighted,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {'text': text};
    if (isBold != null) {
      result['isBold'] = isBold;
    }
    if (translation != null) {
      result['translation'] = translation;
    }
    if (explanation != null) {
      result['explanation'] = explanation;
    }
    if (isSearchHighlighted != null) {
      result['isSearchHighlighted'] = isSearchHighlighted;
    }
    return result;
  }

  factory TextSegmentPersianTempelate.fromJson(Map<String, dynamic> json) {
    return TextSegmentPersianTempelate(
      text: json['text'] as String,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
      isBold: json['isBold'] as bool?,
    );
  }
}
*/
class OriginalContent {
  final Book book;
  final Unit unit;
  final Topic topic;
  final PageContent page;
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
