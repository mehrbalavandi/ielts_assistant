import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/reading_canvas_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';

// 🌟 مدل کمکی برای اتصال پاراگراف‌ها به سیستم اسکرول پلیر
class AudioSegment {
  final int startMs;
  final int endMs;
  final ParagraphData paragraph; // کل اطلاعات پاراگراف برای حفظ کلمات تعاملی

  AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.paragraph,
  });
}

class AudioscriptViewerSheet extends ConsumerStatefulWidget {
  // 1. تعریف متغیر
  final List<PageData> documentPages;

  // 2. اضافه کردن به سازنده
  const AudioscriptViewerSheet({super.key, required this.documentPages});

  @override
  ConsumerState<AudioscriptViewerSheet> createState() =>
      _AudioscriptViewerSheetState();
}

class _AudioscriptViewerSheetState
    extends ConsumerState<AudioscriptViewerSheet> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;
  List<AudioSegment> _segments = [];

  @override
  void initState() {
    super.initState();
    _extractAudioSegments();
  }

  // 🌟 استخراج هوشمند پاراگراف‌های زمان‌دار از کل داکیومنت
  void _extractAudioSegments() {
    for (var page in widget.documentPages) {
      for (var para in page.paragraphs) {
        if (para.startMs != null &&
            para.endMs != null &&
            para.spans.isNotEmpty) {
          _segments.add(
            AudioSegment(
              startMs: para.startMs!,
              endMs: para.endMs!,
              paragraph: para,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final int currentPosMs = audioState.position.inMilliseconds;

    int activeIndex = _segments.indexWhere(
      (seg) => currentPosMs >= seg.startMs && currentPosMs <= seg.endMs,
    );

    if (activeIndex != -1 && activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: activeIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.3,
          );
        }
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E222D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Audioscript (متن صوتی)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),

          Expanded(
            child: _segments.isEmpty
                ? const Center(
                    child: Text(
                      "هیچ متن صوتی همگام‌سازی شده‌ای برای این بخش یافت نشد.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ScrollablePositionedList.builder(
                    itemCount: _segments.length,
                    itemScrollController: _itemScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemBuilder: (context, index) {
                      final segment = _segments[index];
                      final bool isActive = index == activeIndex;

                      // متصل کردن مجدد تمام spanهای داخل این پاراگراف
                      String fullContent = segment.paragraph.spans
                          .map((s) => s.content)
                          .join();

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.orangeAccent.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.orangeAccent.withOpacity(0.4)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            // 🌟 تغذیه کردن موتور رندر با دیتای واقعیِ این پاراگراف
                            children: TextRenderEngine.buildInteractiveText(
                              fullContent,
                              segment.paragraph.interactives,
                              context,
                              TextStyle(
                                color: isActive
                                    ? Colors.orangeAccent
                                    : Colors.white70,
                                fontSize: isActive ? 17 : 15,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                height: 1.6,
                              ),
                              interactiveColor: isActive
                                  ? Colors.yellowAccent
                                  : Colors.cyanAccent,
                            ),
                          ),
                          textAlign: segment.paragraph.direction == "RTL"
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF161922),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      audioState.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                    ),
                    iconSize: 48,
                    color: Colors.orangeAccent,
                    onPressed: () {
                      if (audioState.isPlaying) {
                        ref.read(audioPlayerProvider.notifier).pause();
                      } else {
                        ref.read(audioPlayerProvider.notifier).resume();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // در فایل AudioscriptViewerSheet.dart

  Widget buildScriptList(List<ParagraphData> paragraphs) {
    return ListView.builder(
      itemCount: paragraphs.length,
      itemBuilder: (context, index) {
        final para = paragraphs[index];

        // ساخت ویجت محتوای اصلی (متن انگلیسی)
        Widget content = Text(
          para.spans.map((s) => s.content).join(" "),
          style: const TextStyle(fontSize: 16),
        );

        // 🌟 استفاده از همان Wrapper هوشمند برای فعال‌سازی ترجمه
        return TranslatableContentWrapper(
          translationFa: para.translationFa,
          translationAr: para.translationAr,
          originalContent: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: content,
          ),
        );
      },
    );
  }
}
