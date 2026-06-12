import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/audio_player_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';

// مدل فرضی برای سگمنت‌های متنی
class AudioSegment {
  final int startMs;
  final int endMs;
  final String text;
  AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

class AudioscriptViewerSheet extends ConsumerStatefulWidget {
  const AudioscriptViewerSheet({super.key});

  @override
  ConsumerState<AudioscriptViewerSheet> createState() =>
      _AudioscriptViewerSheetState();
}

class _AudioscriptViewerSheetState
    extends ConsumerState<AudioscriptViewerSheet> {
  // کنترلر برای اسکرول خودکار به خط در حال پخش
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;

  // نمونه داده فرضی (این داده‌ها باید بر اساس نام فایل صوتی جاری از دیتابیس یا فایل JSON لود شوند)
  final List<AudioSegment> _segments = [
    AudioSegment(
      startMs: 0,
      endMs: 3000,
      text: "Listen to the conversation between two students.",
    ),
    AudioSegment(
      startMs: 3000,
      endMs: 7500,
      text: "Hi Meer-shad! Have you found the classroom for the IELTS lecture?",
    ),
    AudioSegment(
      startMs: 7500,
      endMs: 12000,
      text:
          "Yes, it is on the second floor, right next to the main laboratory.",
    ),
    // خطوط بعدی...
  ];

  @override
  Widget build(BuildContext context) {
    // گوش دادن به وضعیت لحظه‌ای پلیر
    final audioState = ref.watch(audioPlayerProvider);
    final int currentPosMs = audioState.position.inMilliseconds;

    // پیدا کردن ایندکس خطی که در حال حاضر باید هایلایت باشد
    int activeIndex = _segments.indexWhere(
      (seg) => currentPosMs >= seg.startMs && currentPosMs <= seg.endMs,
    );

    // اگر خط تغییر کرد، اسکرول نرم به آن خط انجام شود
    if (activeIndex != -1 && activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: activeIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment:
                0.3, // قرار دادن خط فعال در ۳۰ درصدی بالای صفحه برای دید بهتر
          );
        }
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // ۸۵ درصد ارتفاع صفحه
      decoration: const BoxDecoration(
        color: Color(
          0xFF1E222D,
        ), // یک تم تاریک جذاب به سبک اسپاتیفای برای تمرکز بیشتر
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // دستگیره بالای مودال برای بستن (Drag Handle)
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

          // هدر مودال
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

          // لیست متون همگام‌سازی شده
          Expanded(
            child: ScrollablePositionedList.builder(
              itemCount: _segments.length,
              itemScrollController: _itemScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemBuilder: (context, index) {
                final segment = _segments[index];
                final bool isActive = index == activeIndex;

                // رندر متن با موتور کاستوم شما (جهت فعال بودن کلمات تعاملی)
                // فرض می‌کنیم لیست کلمات تعاملی این صفحه را از قبل داریم یا پاس می‌دهیم
                final List<dynamic> emptyInteractives = [];

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
                      children: TextRenderEngine.buildInteractiveText(
                        segment.text,
                        [], //segment.interactives, // کلمات تعاملی شما در اینجا قرار می‌گیرند
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
                    textAlign: TextAlign.left,
                  ),
                );
              },
            ),
          ),

          // یک مینی‌کنترلر کوچک در پایین دکمه لیریک (اختیاری برای راحتی کاربر جهت Play/Pause سریع)
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
}
