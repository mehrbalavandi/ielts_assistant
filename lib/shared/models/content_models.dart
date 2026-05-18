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

  factory FinalTopic.fromDirectory(Directory mainTopicDir) {
    return CfPublic().parseFinalTopic(mainTopicDir);
  }
}

class TextSegmentEnglish {
  final String text;
  final bool isInteractive;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final bool? isLineThrough;
  final bool? isBlank;
  final String? highlightColor; // کد رنگ به صورت هگز (مثلاً #FFFF00)

  final String? translation;
  final String? pronounce;
  final String? explanation;
  final String? cerfLevel;
  final List<TextSegmentEnglish>? children;

  TextSegmentEnglish({
    required this.text,
    required this.isInteractive,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.isLineThrough,
    this.isBlank,
    this.highlightColor,
    this.translation,
    this.pronounce,
    this.explanation,
    this.cerfLevel,
    this.children,
  });
  // متد کمکی برای حذف مارکرها از متن همین سگمنت
  String get plainText => text.replaceAll(RegExp(r'\{.*?\}'), '');
  // متد copyWith برای تغییرات در کپی شیء (بسیار کاربردی در عملیات جستجو)
  TextSegmentEnglish copyWith({
    String? text,
    bool? isInteractive,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isLineThrough,
    bool? isBlank,
    String? highlightColor,
    String? translation,
    String? pronounce,
    String? explanation,
    String? cerfLevel,
    List<TextSegmentEnglish>? children,
  }) {
    return TextSegmentEnglish(
      text: text ?? this.text,
      isInteractive: isInteractive ?? this.isInteractive,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isLineThrough: isLineThrough ?? this.isLineThrough,
      isBlank: isBlank ?? this.isBlank,
      highlightColor: highlightColor ?? this.highlightColor,
      translation: translation ?? this.translation,
      pronounce: pronounce ?? this.pronounce,
      explanation: explanation ?? this.explanation,
      cerfLevel: cerfLevel ?? this.cerfLevel,
      children: children ?? this.children,
    );
  }

  factory TextSegmentEnglish.fromJson(Map<String, dynamic> json) {
    return TextSegmentEnglish(
      text: json['text'] ?? "",
      isInteractive: json['isInteractive'] ?? false,
      isBold: json['isBold'],
      isItalic: json['isItalic'],
      isUnderline: json['isUnderline'],
      isLineThrough: json['isLineThrough'],
      isBlank: json['isBlank'],
      highlightColor: json['highlightColor'],
      translation: json['translation'],
      pronounce: json['pronounce'],
      explanation: json['explanation'],
      cerfLevel: json['cerfLevel'],
      children: json['children'] != null
          ? (json['children'] as List)
                .map((i) => TextSegmentEnglish.fromJson(i))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'text': text,
      'isInteractive': isInteractive,
    };
    if (isBold != null) data['isBold'] = isBold;
    if (isItalic != null) data['isItalic'] = isItalic;
    if (isUnderline != null) data['isUnderline'] = isUnderline;
    if (isLineThrough != null) data['isLineThrough'] = isLineThrough;
    if (isBlank != null) data['isBlank'] = isBlank;
    if (highlightColor != null) data['highlightColor'] = highlightColor;
    if (translation != null) data['translation'] = translation;
    if (pronounce != null) data['pronounce'] = pronounce;
    if (explanation != null) data['explanation'] = explanation;
    if (cerfLevel != null) data['cerfLevel'] = cerfLevel;
    if (children != null) {
      data['children'] = children!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class TextSegmentPersian {
  final String text;
  final String? translation;
  final String? explanation; // توضیحات تکمیلی
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final bool? isLineThrough;
  final bool? isBlank;
  final String? highlightColor; // کد رنگ به صورت هگز (مثلاً #FFFF00)
  final List<TextSegmentPersian>? children;

  TextSegmentPersian({
    required this.text,
    this.translation,
    this.explanation,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.isLineThrough,
    this.isBlank,
    this.highlightColor,
    this.children,
  });
  // متد کمکی برای حذف مارکرها از متن همین سگمنت
  String get plainText => text.replaceAll(RegExp(r'\{.*?\}'), '');

  TextSegmentPersian copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isLineThrough,
    bool? isBlank,
    String? highlightColor,
    List<TextSegmentPersian>? children,
  }) {
    return TextSegmentPersian(
      text: text ?? this.text,
      translation: translation,
      explanation: explanation,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isLineThrough: isLineThrough ?? this.isLineThrough,
      isBlank: isBlank ?? this.isBlank,
      highlightColor: highlightColor ?? this.highlightColor,
      children: children ?? this.children,
    );
  }

  factory TextSegmentPersian.fromJson(Map<String, dynamic> json) {
    return TextSegmentPersian(
      text: json['text'],
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
      isBold: json['isBold'],
      isItalic: json['isItalic'],
      isUnderline: json['isUnderline'],
      isLineThrough: json['isLineThrough'],
      isBlank: json['isBlank'],
      highlightColor: json['highlightColor'],
      children: json['children'] != null
          ? (json['children'] as List)
                .map((i) => TextSegmentPersian.fromJson(i))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {'text': text};

    if (translation != null) {
      data['translation'] = translation;
    }
    if (explanation != null) {
      data['explanation'] = explanation;
    }
    if (isBold != null) {
      data['isBold'] = isBold;
    }
    if (isItalic != null) {
      data['isItalic'] = isItalic;
    }
    if (isUnderline != null) {
      data['isUnderline'] = isUnderline;
    }
    if (isLineThrough != null) {
      data['isLineThrough'] = isLineThrough;
    }
    if (isBlank != null) {
      data['isBlank'] = isBlank;
    }
    if (highlightColor != null) {
      data['highlightColor'] = highlightColor;
    }
    if (children != null) {
      data['children'] = children!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

// کلاس کمکی برای ذخیره بازه‌های پیدا شده در جستجو
class SearchRange {
  final int start;
  final int end;
  SearchRange(this.start, this.end);
}

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
