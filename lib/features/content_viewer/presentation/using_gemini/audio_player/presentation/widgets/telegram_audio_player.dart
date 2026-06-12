import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_script_viewer_sheet.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class TelegramAudioPlayer extends ConsumerWidget {
  final List<PageData> documentPages;

  const TelegramAudioPlayer({super.key, required this.documentPages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);

    // اگر فایلی برای پخش وجود ندارد، نوار را مخفی کن
    if (audioState.currentPath == null) return const SizedBox.shrink();

    return GestureDetector(
      // با کلیک روی نوار، مودال تمام‌صفحه از پایین باز می‌شود
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
            // دکمه پخش/توقف روی نوار
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
                // باز کردن صفحه متن صوتی به صورت تمام صفحه و مودال
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // برای اینکه بتواند تمام صفحه شود
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      AudioscriptViewerSheet(documentPages: documentPages),
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
            // دکمه ضربدر برای بستن کامل پلیر
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
      isScrollControlled: true, // اجازه می‌دهد ارتفاع را دستی تنظیم کنیم
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FullPlayerBottomSheet(),
    );
  }
}

// 🌟 مودالی که از پایین باز می‌شود (حاوی کدهای اورجینال A-B Repeat شما)
class _FullPlayerBottomSheet extends ConsumerWidget {
  const _FullPlayerBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final totalMs = state.duration.inMilliseconds.toDouble();

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900], // تم تاریکی که خودتان طراحی کرده بودید
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // دستگیره (Handle) بالای مودال
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

          // اسلایدر و نشانگرهای A-B
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
                        totalMs,
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

          // زمان‌سنج، کنترل سرعت و دکمه‌های A-B
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
                          if (state.pointA != null) {
                            ref.read(audioPlayerProvider.notifier).setPointB();
                          }
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

          // دکمه‌های کنترلی اصلی
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
