import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/lesson_content_service.dart';
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
  // class LessonContentScreen extends ConsumerStatefulWidget {
  final SubTopic subtopic;
  const LessonContentScreen({required this.subtopic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مشاهده وضعیت نمایش پلیر برای تنظیم Padding
    final displayMode = ref.watch(playerDisplayProvider);
    final isMinimized = displayMode == PlayerDisplayMode.minimized;

    // لود محتوای JSON
    final contentAsyncValue = ref.watch(
      lessonContentProvider(subtopic.jsonFilePath),
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

  // @override
  //   ConsumerState<LessonContentScreen> createState() => _LessonContentScreenState();
}
/*
class _LessonContentScreenState extends ConsumerState<LessonContentScreen> {
  // ✅ کنترلرهای اسکرول برای همگام‌سازی
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _translationScrollController = ScrollController();

  // پرچم برای جلوگیری از لوپ اسکرول (بسیار مهم)
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    // ✅ اتصال Listenerها برای همگام‌سازی
    _mainScrollController.addListener(_syncScroll);
    _translationScrollController.addListener(_syncScroll);
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_syncScroll);
    _translationScrollController.removeListener(_syncScroll);
    _mainScrollController.dispose();
    _translationScrollController.dispose();
    super.dispose();
  }

  void _syncScroll() {
    if (_scrolling) return; // اگر در حال حاضر اسکرول از طریق کد انجام می‌شود، نادیده بگیر

    if (_mainScrollController.hasClients && _translationScrollController.hasClients) {
      double mainOffset = _mainScrollController.offset;
      double transOffset = _translationScrollController.offset;

      if (_mainScrollController.position.isScrollingNotifier.value) {
        // اسکرول اصلی توسط کاربر انجام شده است
        _scrolling = true;
        _translationScrollController.jumpTo(mainOffset);
      } else if (_translationScrollController.position.isScrollingNotifier.value) {
        // اسکرول ترجمه توسط کاربر انجام شده است
        _scrolling = true;
        _mainScrollController.jumpTo(transOffset);
      }
    }
    
    // تأخیر کوچک برای رفع پرچم scrolling
    Future.delayed(const Duration(milliseconds: 10)).then((_) => _scrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ مشاهده وضعیت محتوای درس
    final contentState = ref.watch(lessonContentProvider(widget.topic));
    final notifier = ref.read(lessonContentProvider(widget.topic).notifier);
    
    // ... (UI ناوبری و عنوان)

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name),
        actions: [
          // ✅ دکمه فعال/غیرفعال کردن ترجمه
          if (contentState.translationContent.isNotEmpty)
            IconButton(
              icon: Icon(
                contentState.showTranslation ? Icons.translate_on : Icons.translate_off,
                color: contentState.showTranslation ? Colors.blue : Colors.grey,
              ),
              onPressed: notifier.toggleTranslation,
            ),
        ],
      ),
      body: contentState.mainContent.isEmpty
          ? const Center(child: CircularProgressIndicator()) // نمایش لودینگ تا بارگذاری محتوا
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: contentState.showTranslation
                  ? _buildDualView(contentState) // نمایش دو ستونه
                  : _buildSingleView(contentState.mainContent), // نمایش تک ستونه
            ),
    );
  }

  // ویجت برای نمایش تک ستونه
  Widget _buildSingleView(String content) {
    return SingleChildScrollView(
      child: Text(content),
    );
  }
  
  // ✅ ویجت برای نمایش دو ستونه همگام‌سازی شده
  Widget _buildDualView(LessonContentState contentState) {
    return Row(
      children: [
        // ستون اول: متن اصلی
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            child: Text(contentState.mainContent),
          ),
        ),
        const VerticalDivider(width: 20),
        // ستون دوم: ترجمه
        Expanded(
          child: SingleChildScrollView(
            controller: _translationScrollController,
            child: Text(contentState.translationContent),
          ),
        ),
      ],
    );
  }
}
*/