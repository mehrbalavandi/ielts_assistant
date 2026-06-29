import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/text_render_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class TelegramAudioPlayer extends ConsumerWidget {
  // final List<PageData> documentPages;
  final List<ParagraphData> audioScripts; // 🌟 به جای documentPages

  const TelegramAudioPlayer({super.key, required this.audioScripts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);

    // اگر فایلی برای پخش وجود ندارد، نوار را مخفی کن
    if (audioState.currentPath == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showFullPlayerModal(context, ref),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                audioState.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.blueAccent,
                size: 38,
              ),
              onPressed: () {
                final notifier = ref.read(audioPlayerProvider.notifier);
                audioState.isPlaying ? notifier.pause() : notifier.resume();
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: "مشاهده متن صوتی",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      AudioscriptViewerSheet(audioScripts: audioScripts),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    audioState.currentPath!.split('/').last,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Tap to expand",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () =>
                  ref.read(audioPlayerProvider.notifier).stopAndClear(),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPlayerModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FullPlayerBottomSheet(),
    );
  }
}

class _FullPlayerBottomSheet extends ConsumerWidget {
  const _FullPlayerBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final totalMs = state.duration.inMilliseconds.toDouble();

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.currentPath?.split('/').last ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (state.pointA != null && totalMs > 0)
                      Positioned(
                        left:
                            (state.pointA!.inMilliseconds / totalMs) *
                                (constraints.maxWidth - 24) +
                            12,
                        top: 10,
                        bottom: 10,
                        child: Container(width: 2, color: Colors.orange),
                      ),
                    if (state.pointB != null && totalMs > 0)
                      Positioned(
                        left:
                            (state.pointB!.inMilliseconds / totalMs) *
                                (constraints.maxWidth - 24) +
                            12,
                        top: 10,
                        bottom: 10,
                        child: Container(width: 2, color: Colors.redAccent),
                      ),
                    Slider(
                      value: state.position.inMilliseconds.toDouble().clamp(
                        0,
                        totalMs > 0 ? totalMs : 1.0,
                      ),
                      max: totalMs > 0 ? totalMs : 1.0,
                      onChanged: (v) => ref
                          .read(audioPlayerProvider.notifier)
                          .seek(Duration(milliseconds: v.toInt())),
                      activeColor: Colors.blueAccent.withOpacity(0.7),
                      inactiveColor: Colors.white12,
                    ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildSmallCircleButton(
                        label: "A",
                        isActive: state.pointA != null,
                        onTap: () =>
                            ref.read(audioPlayerProvider.notifier).setPointA(),
                      ),
                      const SizedBox(width: 12.0),
                      _buildSmallCircleButton(
                        label: "B",
                        isActive: state.pointB != null,
                        onTap: () {
                          if (state.pointA != null)
                            ref.read(audioPlayerProvider.notifier).setPointB();
                        },
                      ),
                      if (state.pointA != null)
                        IconButton(
                          icon: const Icon(
                            Icons.layers_clear_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () =>
                              ref.read(audioPlayerProvider.notifier).clearAB(),
                          tooltip: 'پاک کردن',
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<double>(
                  initialValue: state.speed,
                  offset: const Offset(0, -200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${state.speed}x",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  onSelected: (value) =>
                      ref.read(audioPlayerProvider.notifier).setSpeed(value),
                  itemBuilder: (context) => <PopupMenuEntry<double>>[
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 0.8, child: Text('0.8x')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    const PopupMenuItem(value: 1.2, child: Text('1.2x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    state.isRepeatEnabled ? Icons.repeat_one : Icons.repeat,
                    color: state.isRepeatEnabled ? Colors.blue : Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(audioPlayerProvider.notifier).toggleRepeat(),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).skip10Sec(false),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(
                  state.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                color: Colors.white,
                iconSize: 65,
                onPressed: () => state.isPlaying
                    ? ref.read(audioPlayerProvider.notifier).pause()
                    : ref.read(audioPlayerProvider.notifier).resume(),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).skip10Sec(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildSmallCircleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.orangeAccent : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.orangeAccent : Colors.white54,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class AudioSegment {
  final int startMs;
  final int endMs;
  final ParagraphData paragraph;

  AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.paragraph,
  });
}

class AudioscriptViewerSheet extends ConsumerStatefulWidget {
  final List<ParagraphData> audioScripts; // 🌟 جایگزین شد

  const AudioscriptViewerSheet({super.key, required this.audioScripts});

  @override
  ConsumerState<AudioscriptViewerSheet> createState() =>
      _AudioscriptViewerSheetState();
}

class _AudioscriptViewerSheetState
    extends ConsumerState<AudioscriptViewerSheet> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final int currentPosMs = audioState.position.inMilliseconds;
    final currentFileName = audioState.currentPath?.split('/').last ?? '';

    List<AudioSegment> currentSegments = [];

    for (var para in widget.audioScripts) {
      if (para.startMs != null &&
          para.endMs != null &&
          para.audioTrackName == currentFileName) {
        currentSegments.add(
          AudioSegment(
            startMs: para.startMs!,
            endMs: para.endMs!,
            paragraph: para,
          ),
        );
      }
    }

    // 🌟 مهم: استفاده از < به جای <= تا جملاتِ به هم چسبیده، با هم هایلایت نشوند
    int activeIndex = currentSegments.indexWhere(
      (seg) => currentPosMs >= seg.startMs && currentPosMs < seg.endMs,
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

          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.orangeAccent,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  "برای مشاهده ترجمه، روی متن لمس طولانی (Long Press) کنید",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          Expanded(
            child: currentSegments.isEmpty
                ? const Center(
                    child: Text(
                      "هیچ متن صوتی همگام‌سازی شده‌ای برای این بخش یافت نشد.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ScrollablePositionedList.builder(
                    itemCount: currentSegments.length,
                    itemScrollController: _itemScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    itemBuilder: (context, index) {
                      final segment = currentSegments[index];
                      final bool isActive = index == activeIndex;

                      String fullContent = segment.paragraph.spans
                          .map((s) => s.content)
                          .join();

                      Widget englishContent = AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 4),
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

                      return TranslatableContentWrapper(
                        originalContent: englishContent,
                        translationFa: segment.paragraph.translationFa,
                        translationAr: segment.paragraph.translationAr,
                        isDarkMode: true,
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
}
