import 'package:flutter_riverpod/legacy.dart';
import 'dart:convert';
import 'dart:io';

import 'package:ielts_assistant/models/data_models.dart';

// مدل برای هر قطعه از متن (برای همگام‌سازی اسکرول)
class TextSegment {
  final String mainText;
  final String translationText;
  TextSegment(this.mainText, this.translationText);
}

// مدل وضعیت برای LessonContentScreen
class LessonContentState {
  final bool showTranslation; // وضعیت نمایش ترجمه
  final List<TextSegment> segments; // لیست قطعات متن و ترجمه

  LessonContentState({required this.showTranslation, required this.segments});

  LessonContentState copyWith({
    bool? showTranslation,
    List<TextSegment>? segments,
  }) {
    return LessonContentState(
      showTranslation: showTranslation ?? this.showTranslation,
      segments: segments ?? this.segments,
    );
  }
}

// کلاس مدیریت وضعیت محتوای درس (Notifier)
class LessonContentNotifier extends StateNotifier<LessonContentState> {
  LessonContentNotifier(SubTopic topic)
    : super(
        LessonContentState(
          showTranslation: false,
          segments: const [], // لیست خالی در ابتدا
        ),
      ) {
    _loadContent(topic);
  }

  // متد لود محتوا از فایل‌های JSON
  Future<void> _loadContent(SubTopic topic) async {
    List<dynamic> mainList = [];
    List<dynamic> transList = [];

    try {
      // ۱. خواندن فایل اصلی
      if (topic.jsonFilePath.isNotEmpty) {
        final mainJson = await File(topic.jsonFilePath).readAsString();
        mainList = jsonDecode(mainJson);
      }
      // ۲. خواندن فایل ترجمه
      if (topic.translationFilePath.isNotEmpty) {
        final transJson = await File(topic.translationFilePath).readAsString();
        transList = jsonDecode(transJson);
      }
    } catch (e) {
      print('Error loading or parsing content for ${topic.name}: $e');
      // در صورت خطا، با لیست خالی ادامه می‌دهیم
    }

    // ۳. ساخت لیست قطعات TextSegment برای همگام‌سازی
    final int count = mainList.length;
    List<TextSegment> newSegments = List.generate(count, (index) {
      final mainText = mainList[index].toString();
      // اگر لیست ترجمه کوتاه‌تر بود، از رشته خالی استفاده می‌کنیم
      final transText = (index < transList.length)
          ? transList[index].toString()
          : '';
      return TextSegment(mainText, transText);
    });

    // به‌روزرسانی وضعیت با قطعات لود شده
    state = state.copyWith(segments: newSegments);
  }

  // متد برای فعال/غیرفعال کردن نمایش ترجمه
  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }
}

// Provider که به SubTopic وابسته است
final lessonContentProvider = StateNotifierProvider.autoDispose
    .family<LessonContentNotifier, LessonContentState, SubTopic>((ref, topic) {
      return LessonContentNotifier(topic);
    });
