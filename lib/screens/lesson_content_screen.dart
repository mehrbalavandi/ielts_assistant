import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/widgets/mini_player_widget.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/states/player_display_state.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:ielts_assistant/services/lesson_content_service.dart'; // import 'audio_player_widget.dart'; // برای استفاده از AudioPlayerWidget یا MiniPlayerWidget (اختیاری)

// کلاس اصلی
class unitContentScreen extends ConsumerStatefulWidget {
  // ✅ بله، topic از نوع mainTopic است.
  final FinalTopic topic;
  const unitContentScreen({required this.topic, super.key});

  @override
  ConsumerState<unitContentScreen> createState() => _unitContentScreenState();
}

class _unitContentScreenState extends ConsumerState<unitContentScreen> {
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
    final contentState = ref.watch(unitContentProvider(widget.topic));
    final notifier = ref.read(unitContentProvider(widget.topic).notifier);
    final displayMode = ref.watch(playerDisplayProvider);

    final playerState = ref.watch(audioPlayerProvider);
    // ✅ رفع خطا: دسترسی به currentTopic از طریق playerState
    final isPlayingThisTopic =
        playerState.currentTopic?.realmId == widget.topic.realmId;

    final bool hasTranslation = contentState.translationSegments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
      // bottomSheet:
      //     (isPlayingThisTopic && (displayMode == PlayerDisplayMode.minimized))
      //     ? MiniPlayerWidget(mainTopic: widget.topic)
      //     : null,
      body: contentState.segments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                /*
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
*/
                // ۲. محتوای درس (متن و ترجمه)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: contentState.showTranslation
                        ? _buildDualView(
                            contentState.segments,
                            contentState.translationSegments,
                          )
                        : _buildSingleView(contentState.segments),
                  ),
                ),
                if (isPlayingThisTopic &&
                    (displayMode == PlayerDisplayMode.minimized))
                  MiniPlayerWidget(mainTopic: widget.topic),
              ],
            ),
    );
  }

  // ویجت برای نمایش تک ستونه (متن اصلی)
  Widget _buildSingleView(List<TextSegment> segments) {
    int interactiveIndex = 0;
    final List<InlineSpan> spans = segments.map((item) {
      if (item.isInteractive) {
        return TextSpan(
          text:
              '(${++interactiveIndex})${item.text}', // اعمال استایل بر اساس status
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
            fontSize: 20.0,
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
      } else {
        return TextSpan(
          text: item.text, // اعمال استایل بر اساس status
          style: item.isBold
              ? TextStyle(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  // fontStyle: FontStyle.italic,
                  fontSize: 20.0,
                )
              : TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20.0,
                ),
        );
      }
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
  Widget _buildDualView(
    List<TextSegment> segments,
    List<TranslationTextSegment> translationTextSegments,
  ) {
    final List<TextSpan> spans = translationTextSegments.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)

      return TextSpan(
        text: item.text, // اعمال استایل بر اساس status
        style: TextStyle(
          color: item.isBold
              ? Colors.deepOrange
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: item.isBold ? FontWeight.bold : null,
          fontSize: item.isBold ? 17.0 : 17.0,
        ),
      );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        // ردیف اول: متن اصلی
        Expanded(child: _buildSingleView(segments)),
        const Divider(height: 20),
        // ردیف دوم: ترجمه
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: AlignmentGeometry.centerRight,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: TextSpan(children: spans),
                ),
              ),
            ),
          ),
        ),
      ],
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
