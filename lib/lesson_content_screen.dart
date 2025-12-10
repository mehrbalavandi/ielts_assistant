import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'dart:convert';
import 'dart:io';

import 'player_display_state.dart';
import 'mini_player_widget.dart'; // ویجت پلیر کوچک

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

// Provider برای نگه داشتن متن درس لود شده
final lessonContentProvider = FutureProvider.family<List<TextSegment>, String>((
  ref,
  jsonPath,
) async {
  final file = File(jsonPath);
  if (!await file.exists()) {
    throw Exception('فایل JSON درس یافت نشد.');
  }
  final contents = await file.readAsString();

  // return jsonDecode(contents) as Map<String, dynamic>;
  // 2. دیکد کردن JSON
  // فرض می‌کنیم که فایل یک لیست JSON از اشیاء است.
  final List<dynamic> jsonList = jsonDecode(contents);

  // 3. تبدیل به لیست مدل‌های StatusItem
  return jsonList
      .map((json) => TextSegment.fromJson(json as Map<String, dynamic>))
      .toList();
});

class LessonContentScreen extends ConsumerWidget {
  final SubTopic subtopic;
  const LessonContentScreen({required this.subtopic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مشاهده وضعیت نمایش پلیر برای تنظیم Padding
    final displayMode = ref.watch(playerDisplayProvider);
    final isMinimized = displayMode == PlayerDisplayMode.minimized;

    // لود محتوای JSON
    final contentAsyncValue = ref.watch(
      lessonContentProvider(subtopic.jsonFilePathEnglish),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(subtopic.name),
        backgroundColor: Colors.indigo.shade700,
      ),
      // بدنه اصلی که متن درس را نمایش می‌دهد
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          // افزودن PaddingBottom به اندازه پلیر کوچک
          padding: EdgeInsets.only(
            top: 16.0,
            bottom: isMinimized ? 32.0 : 16.0,
          ),
          child: contentAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) =>
                Center(child: Text('خطا در بارگذاری محتوای درس: $e')),
            data: (data) {
              final List<TextSpan> spans = data.map((item) {
                // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)

                return TextSpan(
                  text: item.text, // اعمال استایل بر اساس status
                  style: TextStyle(
                    color: item.isInteractive
                        ? Colors.deepOrange
                        : Colors.black,
                    fontWeight: item.isInteractive ? FontWeight.bold : null,
                    fontSize: item.isInteractive ? 17.0 : 17.0,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      _showPopup(
                        context,
                        item.text,
                        item.translation!,
                        item.explanation!,
                      );
                    },
                );
              }).toList();
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(children: spans),
                  ),
                ),
              );
            },
          ),
        ),
      ),

      // پلیر کوچک در پایین صفحه (Mini Player in the Bottom)
      bottomSheet: isMinimized ? MiniPlayerWidget(subTopic: subtopic) : null,
    );
  }

  void _showPopup(
    BuildContext context,
    String text,
    String translation,
    String explanation,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            text,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ), //! 💡
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'ترجمه فارسی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(translation, textDirection: TextDirection.rtl),
                SizedBox(height: 16.0),
                // const Divider(height: 20),
                Text(
                  'توضیحات تکمیلی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(explanation, textDirection: TextDirection.rtl),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'بستن',
                style: TextStyle(
                  fontFamily: FontFamily.yekanBakhBold.asText,
                  fontSize: 16.0,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
