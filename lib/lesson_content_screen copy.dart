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
}

/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/lesson_content_service.dart';

class LessonContentScreen extends ConsumerStatefulWidget {
  final SubTopic subtopic;
  const LessonContentScreen({required this.subtopic, super.key});

  @override
  ConsumerState<LessonContentScreen> createState() =>
      _LessonContentScreenState();
}

class _LessonContentScreenState extends ConsumerState<LessonContentScreen> {
  // کنترلرهای اسکرول برای همگام‌سازی
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _translationScrollController = ScrollController();

  // پرچم برای جلوگیری از لوپ اسکرول در Listener
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    // اتصال Listenerها برای همگام‌سازی
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

  // منطق همگام‌سازی اسکرول
  void _syncScroll() {
    if (_scrolling) return;

    // بررسی اینکه کدام ScrollController توسط کاربر جابجا شده است
    if (_mainScrollController.hasClients &&
        _translationScrollController.hasClients) {
      // استفاده از position.isScrollingNotifier.value برای تشخیص اسکرول فعال
      if (_mainScrollController.position.isScrollingNotifier.value) {
        // اسکرول توسط کاربر روی متن اصلی
        _scrolling = true;
        _translationScrollController.jumpTo(_mainScrollController.offset);
      } else if (_translationScrollController
          .position
          .isScrollingNotifier
          .value) {
        // اسکرول توسط کاربر روی ترجمه
        _scrolling = true;
        _mainScrollController.jumpTo(_translationScrollController.offset);
      }
    }

    // با تأخیر کم پرچم را ریست می‌کنیم تا ورودی‌های بعدی ثبت شوند
    Future.delayed(
      const Duration(milliseconds: 10),
    ).then((_) => _scrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    // مشاهده وضعیت محتوای درس با استفاده از widget.topic
    final contentState = ref.watch(lessonContentProvider(widget.subtopic));
    final notifier = ref.read(lessonContentProvider(widget.subtopic).notifier);

    // بررسی وجود محتوای ترجمه
    final bool hasTranslation = contentState.segments.any(
      (s) => s.translationText.isNotEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subtopic.name),
        actions: [
          // دکمه فعال/غیرفعال کردن ترجمه
          if (hasTranslation)
            IconButton(
              icon: Icon(
                // از آیکون استاندارد translate استفاده می‌کنیم
                Icons.translate,
                // تغییر رنگ برای نمایش حالت فعال/غیرفعال
                color: contentState.showTranslation ? Colors.blue : Colors.grey,
              ),
              onPressed: notifier.toggleTranslation,
            ),
        ],
      ),
      body: contentState.segments.isEmpty
          ? const Center(child: CircularProgressIndicator()) // نمایش لودینگ
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: contentState.showTranslation
                  ? _buildDualView(
                      contentState.segments,
                    ) // نمایش دو ستونه همگام
                  : _buildSingleView(contentState.segments), // نمایش تک ستونه
            ),
    );
  }

  // ویجت برای نمایش تک ستونه (متن اصلی)
  Widget _buildSingleView(List<TextSegment> segments) {
    return ListView.builder(
      // در حالت تک ستونه، نیازی به همگام‌سازی نیست، از کنترلر جدید استفاده می‌کنیم
      itemCount: segments.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(segments[index].mainText),
        );
      },
    );
  }

  // ویجت برای نمایش دو ستونه همگام‌سازی شده
  Widget _buildDualView(List<TextSegment> segments) {
    return Row(
      children: [
        // ستون اول: متن اصلی
        Expanded(
          child: ListView.builder(
            controller: _mainScrollController, // اتصال کنترلر اصلی
            itemCount: segments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(segments[index].mainText),
              );
            },
          ),
        ),
        const VerticalDivider(width: 20),
        // ستون دوم: ترجمه
        Expanded(
          child: ListView.builder(
            controller: _translationScrollController, // اتصال کنترلر ترجمه
            itemCount: segments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(segments[index].translationText),
              );
            },
          ),
        ),
      ],
    );
  }
}
*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:ielts_assistant/services/lesson_content_service.dart';

class LessonContentScreen extends ConsumerStatefulWidget {
  final SubTopic subtopic;
  const LessonContentScreen({required this.subtopic, super.key});

  @override
  ConsumerState<LessonContentScreen> createState() =>
      _LessonContentScreenState();
}

class _LessonContentScreenState extends ConsumerState<LessonContentScreen> {
  // کنترلرهای اسکرول برای همگام‌سازی
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _translationScrollController = ScrollController();

  // پرچم برای جلوگیری از لوپ اسکرول در Listener
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    // اتصال Listenerها برای همگام‌سازی
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

  // منطق همگام‌سازی اسکرول
  void _syncScroll() {
    if (_scrolling) return;

    // بررسی اینکه کدام ScrollController توسط کاربر جابجا شده است
    if (_mainScrollController.hasClients &&
        _translationScrollController.hasClients) {
      // استفاده از position.isScrollingNotifier.value برای تشخیص اسکرول فعال
      if (_mainScrollController.position.isScrollingNotifier.value) {
        // اسکرول توسط کاربر روی متن اصلی
        _scrolling = true;
        _translationScrollController.jumpTo(_mainScrollController.offset);
      } else if (_translationScrollController
          .position
          .isScrollingNotifier
          .value) {
        // اسکرول توسط کاربر روی ترجمه
        _scrolling = true;
        _mainScrollController.jumpTo(_translationScrollController.offset);
      }
    }

    // با تأخیر کم پرچم را ریست می‌کنیم تا ورودی‌های بعدی ثبت شوند
    Future.delayed(
      const Duration(milliseconds: 10),
    ).then((_) => _scrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    // مشاهده وضعیت محتوای درس با استفاده از widget.topic
    final contentState = ref.watch(lessonContentProvider(widget.subtopic));
    final notifier = ref.read(lessonContentProvider(widget.subtopic).notifier);

    // بررسی وجود محتوای ترجمه
    final bool hasTranslation = contentState.segments.any(
      (s) => s.translationText.isNotEmpty,
    );
// 💡 مشاهده وضعیت پلیر برای نمایش MiniPlayer یا Player کامل
    final playerState = ref.watch(audioPlayerProvider);
    // فرض می‌کنیم Player اصلی در همین صفحه نمایش داده می‌شود
    final isPlayingThisTopic = playerState.currentTopic?.realmId == widget.topic.realmId;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subtopic.name),
        actions: [
          // دکمه فعال/غیرفعال کردن ترجمه
          if (hasTranslation)
            IconButton(
              icon: Icon(
                // از آیکون استاندارد translate استفاده می‌کنیم
                Icons.translate,
                // تغییر رنگ برای نمایش حالت فعال/غیرفعال
                color: contentState.showTranslation ? Colors.blue : Colors.grey,
              ),
              onPressed: notifier.toggleTranslation,
            ),
        ],
      ),
      body: contentState.segments.isEmpty
          ? const Center(child: CircularProgressIndicator()) // نمایش لودینگ
          : Column( // ✅ استفاده از Column به عنوان ویجت اصلی بدنه
              children: [
                
                // ----------------------------------------------------
                // ۱. نمایش پلیر (فقط اگر مرتبط با این درس باشد)
                // ----------------------------------------------------
                if (isPlayingThisTopic) 
                  // 💡 از MiniPlayerWidget یا AudioPlayerWidget (به عنوان یک ویجت داخلی) استفاده کنید. 
                  // اگر AudioPlayerWidget را در پایین قرار دهید، از اینجا حذف کنید.
                  // اگر هدف، نمایش Mini Player است:
                  // MiniPlayerWidget(), 
                  
                  // اگر هدف، نمایش کنترل‌های اصلی است:
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      // ❗ اینجا باید ویجت کنترل‌های پخش شما باشد (شاید AudioControlsWidget)
                      // برای مثال، اگر AudioPlayerWidget را در حالت کامل در اینجا قرار می‌دهید:
                      // AudioPlayerWidget(),
                      child: const Text('💡 کنترل‌های پخش در اینجا قرار می‌گیرند'),
                  ),

                // ----------------------------------------------------
                // ۲. محتوای درس (باقیمانده فضا)
                // ----------------------------------------------------
                Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: contentState.showTranslation
                          ? _buildDualView(contentState.segments) // دو ردیف
                          : _buildSingleView(contentState.segments), // تک ردیف
                  ),
                ),
              ],
          ),
    );
  }

  // ویجت برای نمایش تک ستونه (متن اصلی)
  Widget _buildSingleView(List<TextSegment> segments) {
    return ListView.builder(
      // در حالت تک ستونه، نیازی به همگام‌سازی نیست، از کنترلر جدید استفاده می‌کنیم
      itemCount: segments.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(segments[index].mainText),
        );
      },
    );
  }

  // ویجت برای نمایش دو ستونه همگام‌سازی شده
  Widget _buildDualView(List<TextSegment> segments) {
return Column(
      children: [
        // ردیف اول: متن اصلی
        Expanded(
          child: ListView.builder(
            controller: _mainScrollController, // اتصال کنترلر اصلی
            itemCount: segments.length,
            itemBuilder: (context, index) {
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(segments[index].mainText, style: const TextStyle(fontWeight: FontWeight.bold)),
                );
            },
          ),
        ),
        const Divider(height: 20), // ✅ جداکننده افقی
        // ردیف دوم: ترجمه
        Expanded(
          child: ListView.builder(
            controller: _translationScrollController, // اتصال کنترلر ترجمه
            itemCount: segments.length,
            itemBuilder: (context, index) {
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(segments[index].translationText),
                );
            },
          ),
        ),
      ],
    );
  }
}
*/
