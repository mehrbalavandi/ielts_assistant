import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';

class LessonContentState {
  final bool showTranslation; // وضعیت نمایش ترجمه
  final String mainContent;
  final String translationContent;

  LessonContentState({
    required this.showTranslation,
    required this.mainContent,
    required this.translationContent,
  });

  LessonContentState copyWith({
    bool? showTranslation,
    String? mainContent,
    String? translationContent,
  }) {
    return LessonContentState(
      showTranslation: showTranslation ?? this.showTranslation,
      mainContent: mainContent ?? this.mainContent,
      translationContent: translationContent ?? this.translationContent,
    );
  }
}

class LessonContentNotifier extends StateNotifier<LessonContentState> {
  LessonContentNotifier(SubTopic topic)
    : super(
        LessonContentState(
          showTranslation: false,
          mainContent: '',
          translationContent: '',
        ),
      ) {
    _loadContent(topic);
  }

  // لود محتوای درس از فایل‌های JSON
  Future<void> _loadContent(SubTopic topic) async {
    String main = '';
    String trans = '';

    try {
      if (topic.jsonFilePath.isNotEmpty) {
        // فرض می‌کنیم فایل‌ها حاوی یک آرایه متنی JSON هستند و آن را به یک رشته تبدیل می‌کنیم
        final mainJson = await File(topic.jsonFilePath).readAsString();
        main = _extractTextFromContent(mainJson);
      }
      if (topic.translationFilePath.isNotEmpty) {
        final transJson = await File(topic.translationFilePath).readAsString();
        trans = _extractTextFromContent(transJson);
      }
    } catch (e) {
      print('Error loading content: $e');
    }

    state = state.copyWith(mainContent: main, translationContent: trans);
  }

  // متد کمکی برای استخراج متن از JSON (بسته به ساختار JSON شما)
  String _extractTextFromContent(String jsonString) {
    // TODO: منطق تبدیل JSON به یک رشته متنی قابل نمایش (مثلاً اگر JSON یک آرایه از پاراگراف‌ها باشد)
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.join('\n\n'); // هر عنصر را با دو خط جدید جدا کن
    } catch (e) {
      return "Error parsing content.";
    }
  }

  // متد برای فعال/غیرفعال کردن نمایش ترجمه
  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }
}

// ✅ Provider جدید که به SubTopic وابسته است
final lessonContentProvider = StateNotifierProvider.autoDispose
    .family<LessonContentNotifier, LessonContentState, SubTopic>((ref, topic) {
      return LessonContentNotifier(topic);
    });
