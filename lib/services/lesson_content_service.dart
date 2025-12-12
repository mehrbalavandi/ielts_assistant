import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'dart:convert';
import 'dart:io';

import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/storage_service.dart';

// مدل برای هر قطعه از متن (برای همگام‌سازی اسکرول)
class TextSegment {
  final String text;
  final bool isInteractive;
  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی

  TextSegment({
    required this.text,
    required this.isInteractive,
    this.translation,
    this.explanation,
  });

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      text: json['text'] as String,
      isInteractive: json['isInteractive'] as bool,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
    );
  }
}

class TranslationTextSegment {
  final String text;
  final bool isBold;

  TranslationTextSegment({required this.text, required this.isBold});

  factory TranslationTextSegment.fromJson(Map<String, dynamic> json) {
    return TranslationTextSegment(
      text: json['text'] as String,
      isBold: json['isBold'] as bool,
    );
  }
}

final _storageBox = GetStorage();

// مدل وضعیت برای LessonContentScreen
class LessonContentState {
  final bool showTranslation; // وضعیت نمایش ترجمه
  final List<TextSegment> segments; // لیست قطعات متن
  final List<TranslationTextSegment> translationSegments; // لیست قطعات ترجمه

  LessonContentState({
    required this.showTranslation,
    required this.segments,
    required this.translationSegments,
  });

  LessonContentState copyWith({
    bool? showTranslation,
    List<TextSegment>? segments,
    List<TranslationTextSegment>? translationSegments,
  }) {
    return LessonContentState(
      showTranslation: showTranslation ?? this.showTranslation,
      segments: segments ?? this.segments,
      translationSegments: translationSegments ?? this.translationSegments,
    );
  }
}

// کلاس مدیریت وضعیت محتوای درس (Notifier)
class LessonContentNotifier extends StateNotifier<LessonContentState> {
  final _storageService = StorageService();
  LessonContentNotifier(SubTopic topic)
    : super(
        LessonContentState(
          showTranslation: StorageService().getShowTranslation(),
          segments: const [],
          translationSegments: [], // لیست خالی در ابتدا
        ),
      ) {
    _loadContent(topic);
  }

  // متد لود محتوا از فایل‌های JSON
  Future<void> _loadContent(SubTopic topic) async {
    List<dynamic> mainList = [];
    List<dynamic> transList = [];

    try {
      if (topic.jsonFilePath.isNotEmpty) {
        final mainJson = await File(topic.jsonFilePath).readAsString();
        mainList = jsonDecode(mainJson);
      }
      if (topic.translationFilePath.isNotEmpty) {
        final transJson = await File(topic.translationFilePath).readAsString();
        transList = jsonDecode(transJson);
      }
    } catch (e) {
      debugPrint('Error loading or parsing content for ${topic.name}: $e');
    }

    List<TextSegment> newSegments = mainList
        .map((json) => TextSegment.fromJson(json as Map<String, dynamic>))
        .toList();
    List<TranslationTextSegment> newTranslationSegments = transList
        .map(
          (json) =>
              TranslationTextSegment.fromJson(json as Map<String, dynamic>),
        )
        .toList();
    // به‌روزرسانی وضعیت با قطعات لود شده
    state = state.copyWith(
      segments: newSegments,
      translationSegments: newTranslationSegments,
    );
  }

  // متد برای فعال/غیرفعال کردن نمایش ترجمه
  void toggleTranslation() {
    final newValue = !state.showTranslation;
    state = state.copyWith(showTranslation: newValue);

    // ✅ ذخیره وضعیت جدید
    _storageService.saveShowTranslation(newValue);
  }
}

// Provider که به SubTopic وابسته است
final lessonContentProvider = StateNotifierProvider.autoDispose
    .family<LessonContentNotifier, LessonContentState, SubTopic>((ref, topic) {
      return LessonContentNotifier(topic);
    });
