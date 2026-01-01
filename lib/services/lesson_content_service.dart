import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'dart:convert';
import 'dart:io';

import 'package:ielts_assistant/shared/models/data_models.dart';
import 'package:ielts_assistant/services/storage_service.dart';

// مدل برای هر قطعه از متن (برای همگام‌سازی اسکرول)
class TextSegment {
  final String text;
  final bool isInteractive;
  final bool? isBold;
  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی

  TextSegment({
    required this.text,
    required this.isInteractive,
    this.isBold,
    this.translation,
    this.explanation,
  });

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      text: json['text'] as String,
      isInteractive: json['isInteractive'] as bool,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
      isBold: json['isBold'] as bool?,
    );
  }
}

class TranslationTextSegment {
  final String text;
  final bool? isBold;

  TranslationTextSegment({required this.text, this.isBold});

  factory TranslationTextSegment.fromJson(Map<String, dynamic> json) {
    return TranslationTextSegment(
      text: json['text'] as String,
      isBold: json['isBold'] as bool?,
    );
  }
}

// مدل وضعیت برای unitContentScreen
class unitContentState {
  final bool showTranslation; // وضعیت نمایش ترجمه
  final List<TextSegment> segments; // لیست قطعات متن
  final List<TranslationTextSegment> translationSegments; // لیست قطعات ترجمه

  unitContentState({
    required this.showTranslation,
    required this.segments,
    required this.translationSegments,
  });

  unitContentState copyWith({
    bool? showTranslation,
    List<TextSegment>? segments,
    List<TranslationTextSegment>? translationSegments,
  }) {
    return unitContentState(
      showTranslation: showTranslation ?? this.showTranslation,
      segments: segments ?? this.segments,
      translationSegments: translationSegments ?? this.translationSegments,
    );
  }
}

// کلاس مدیریت وضعیت محتوای درس (Notifier)
class unitContentNotifier extends StateNotifier<unitContentState> {
  final _storageService = StorageService();
  unitContentNotifier(FinalTopic topic)
    : super(
        unitContentState(
          showTranslation: StorageService().getShowTranslation(),
          segments: const [],
          translationSegments: [], // لیست خالی در ابتدا
        ),
      ) {
    _loadContent(topic);
  }

  // متد لود محتوا از فایل‌های JSON
  Future<void> _loadContent(FinalTopic topic) async {
    List<dynamic> mainList = [];
    List<dynamic> transList = [];

    try {
      if (topic.jsonFilePath.isNotEmpty) {
        final mainJson = await File(topic.jsonFilePath).readAsString();
        mainList = jsonDecode((mainJson));
      }
      if (topic.translationFilePath.isNotEmpty) {
        final transJson = await File(topic.translationFilePath).readAsString();
        transList = jsonDecode((transJson));
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

  String normalizeText(String text) {
    return text.replaceAll('\\n', '\n');
  }

  /*
  String sanitizeJsonString(String input) {
    return input
        // حذف BOM اگر وجود داشته باشد
        .replaceAll('\uFEFF', '')
        // تبدیل newline واقعی به escape استاندارد JSON
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\n')
        // تبدیل tab
        .replaceAll('\t', '\\t')
        // حذف کاراکترهای کنترلی نامعتبر (0x00–0x1F به‌جز \n و \t)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }
  String sanitizeJsonString(String input) {
    return input
        // حذف BOM
        .replaceAll('\uFEFF', '')
        // تبدیل tab واقعی به space
        .replaceAll('\t', ' ')
        // نرمال‌سازی bullet
        .replaceAll('•', '-')
        // نرمال‌سازی newline
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\n')
        // حذف کاراکترهای کنترلی خطرناک
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }
  String sanitizeJsonStringKeepBullets(String input) {
    return input
        // حذف BOM
        .replaceAll('\uFEFF', '')
        // 🔴 TAB واقعی خطرناک است → تبدیل به space
        .replaceAll('\t', ' ')
        // 🔴 newline واقعی → escape استاندارد JSON
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\n')
        // 🔴 حذف کاراکترهای کنترلی نامعتبر
        // (bullet جزو این‌ها نیست و حذف نمی‌شود)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }

  String escapeJsonString(String input) {
    return input
        // حذف BOM
        .replaceAll('\uFEFF', '')
        // escape backslash
        .replaceAll(r'\', r'\\')
        // escape double quotes
        .replaceAll('"', r'\"')
        // نرمال‌سازی newline
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\n')
        // تبدیل tab به space
        .replaceAll('\t', ' ')
        // حذف کاراکترهای کنترلی نامعتبر
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }
  */

  // متد برای فعال/غیرفعال کردن نمایش ترجمه
  void toggleTranslation() {
    final newValue = !state.showTranslation;
    state = state.copyWith(showTranslation: newValue);

    // ✅ ذخیره وضعیت جدید
    _storageService.saveShowTranslation(newValue);
  }
}

// Provider که به mainTopic وابسته است
final unitContentProvider = StateNotifierProvider.autoDispose
    .family<unitContentNotifier, unitContentState, FinalTopic>((ref, topic) {
      return unitContentNotifier(topic);
    });
