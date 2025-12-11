import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/mini_player_widget.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/player_display_state.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:ielts_assistant/services/lesson_content_service.dart'; // import 'audio_player_widget.dart'; // برای استفاده از AudioPlayerWidget یا MiniPlayerWidget (اختیاری)

// کلاس اصلی
class LessonContentScreen extends ConsumerStatefulWidget {
  // ✅ بله، topic از نوع SubTopic است.
  final SubTopic topic;
  const LessonContentScreen({required this.topic, super.key});

  @override
  ConsumerState<LessonContentScreen> createState() =>
      _LessonContentScreenState();
}

class _LessonContentScreenState extends ConsumerState<LessonContentScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _translationScrollController = ScrollController();

  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
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
    if (_scrolling) return;

    if (_mainScrollController.hasClients &&
        _translationScrollController.hasClients) {
      if (_mainScrollController.position.isScrollingNotifier.value) {
        _scrolling = true;
        // اگر اسکرولر ترجمه می‌تواند جابجا شود (مقدار دهی شده باشد)
        if (_translationScrollController.position.maxScrollExtent >=
            _mainScrollController.offset) {
          _translationScrollController.jumpTo(_mainScrollController.offset);
        }
      } else if (_translationScrollController
          .position
          .isScrollingNotifier
          .value) {
        _scrolling = true;
        // اگر اسکرولر اصلی می‌تواند جابجا شود
        if (_mainScrollController.position.maxScrollExtent >=
            _translationScrollController.offset) {
          _mainScrollController.jumpTo(_translationScrollController.offset);
        }
      }
    }

    // تأخیر کوچک برای ریست پرچم
    Future.delayed(
      const Duration(milliseconds: 10),
    ).then((_) => _scrolling = false);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ دسترسی به topic از طریق widget.topic
    final contentState = ref.watch(lessonContentProvider(widget.topic));
    final notifier = ref.read(lessonContentProvider(widget.topic).notifier);
    final displayMode = ref.watch(playerDisplayProvider);

    final playerState = ref.watch(audioPlayerProvider);
    // ✅ رفع خطا: دسترسی به currentTopic از طریق playerState
    final isPlayingThisTopic =
        playerState.currentTopic?.realmId == widget.topic.realmId;

    final bool hasTranslation = contentState.translationSegments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.name), // ✅ استفاده از widget.topic.name
        actions: [
          if (hasTranslation)
            IconButton(
              icon: Icon(
                Icons.translate,
                color: contentState.showTranslation ? Colors.blue : Colors.grey,
              ),
              onPressed: notifier.toggleTranslation,
            ),
        ],
      ),
      bottomSheet:
          (isPlayingThisTopic && (displayMode == PlayerDisplayMode.minimized))
          ? MiniPlayerWidget(subTopic: widget.topic)
          : null,
      body: contentState.segments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ۱. نمایش پلیر (کنترل‌های اصلی)
                if (isPlayingThisTopic)
                  // 💡 اینجا باید ویجت کنترل‌های پخش کامل شما قرار گیرد.
                  // فرض می‌کنیم ویجتی به نام AudioControlsWidget دارید یا از یک نسخه کوچک AudioPlayerWidget استفاده می‌کنید.
                  // اگر از AudioPlayerWidget برای نمایش در کل صفحه استفاده می‌کنید، باید آن را به این صفحه بیاورید:
                  Container(
                    // مثال: نمایش کنترل‌های اصلی فقط در این صفحه
                    height: 150,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Center(
                      child: Text(
                        'کنترل‌های پخش صوتی مرتبط با ${widget.topic.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                // ۲. محتوای درس (متن و ترجمه)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: contentState.showTranslation
                        ? _buildDualView(contentState.segments)
                        : _buildSingleView(contentState.segments),
                  ),
                ),
              ],
            ),
    );
  }

  // ویجت برای نمایش تک ستونه (متن اصلی)
  Widget _buildSingleView(List<TextSegment> segments) {
    // return ListView.builder(
    //   itemCount: segments.length,
    //   itemBuilder: (context, index) {
    //     return Padding(
    //       padding: const EdgeInsets.only(bottom: 12.0),
    //       child: Text(segments[index].mainText),
    //     );
    //   },
    // );
    final List<TextSpan> spans = data.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)

      return TextSpan(
        text: item.text, // اعمال استایل بر اساس status
        style: TextStyle(
          color: item.isInteractive ? Colors.deepOrange : Colors.black,
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
  }

  // ویجت برای نمایش دو ردیفی همگام‌سازی شده (بالا و پایین)
  Widget _buildDualView(List<TextSegment> segments) {
    return Column(
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        // ردیف اول: متن اصلی
        Expanded(
          child: ListView.builder(
            controller: _mainScrollController,
            itemCount: segments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  segments[index].mainText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        const Divider(height: 20),
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
