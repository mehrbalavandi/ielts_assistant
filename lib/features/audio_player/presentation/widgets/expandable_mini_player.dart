// lib/features/audio_player/presentation/widgets/expandable_mini_player.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';

final isPlayerExpandedProvider = StateProvider<bool>((ref) => false);

class ExpandableMiniPlayer extends ConsumerWidget {
  final VoidCallback? onClose;
  const ExpandableMiniPlayer({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final isExpanded = ref.watch(isPlayerExpandedProvider);

    // اگر فایلی انتخاب نشده باشد، پلیر را کلاً نشان نده
    if (audioState.currentPath == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () =>
          ref.read(isPlayerExpandedProvider.notifier).state = !isExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        height: isExpanded ? 242 : 60,
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
        ),
        child: SingleChildScrollView(
          // برای جلوگیری از خطای Overflow هنگام انیمیشن
          // physics: const NeverScrollableScrollPhysics(),
          child: isExpanded
              ? _buildFullView(audioState, ref)
              : _buildMiniView(audioState, ref),
        ),
      ),
    );
  }

  // حالت کوچک شده
  Widget _buildMiniView(AudioPlayerState state, WidgetRef ref) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              state.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            color: Colors.white,
            iconSize: 40,
            onPressed: () => state.isPlaying
                ? ref.read(audioPlayerProvider.notifier).pause()
                : ref.read(audioPlayerProvider.notifier).resume(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.currentPath!.split('/').last,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_up, color: Colors.white54),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: onClose, // استفاده از پارامتر onClose
          ),
        ],
      ),
    );
  }

  // حالت باز شده (کامل)
  Widget _buildFullView(AudioPlayerState state, WidgetRef ref) {
    final totalMs = state.duration.inMilliseconds.toDouble();
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
        const SizedBox(height: 10),
        Text(
          state.currentPath!.split('/').last,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        // اسلایدر واقعی
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // نشانگر خط عمودی برای نقطه A
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
                  // نشانگر خط عمودی برای نقطه B
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
                  // خودِ اسلایدر
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
        ), // زمان‌سنج
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      // اگر زمان فعلی از B بیشتر باشد، دکمه A غیرفعال می‌شود
                      onPressed:
                          (state.pointB != null &&
                              state.position >= state.pointB!)
                          ? null
                          : () => ref
                                .read(audioPlayerProvider.notifier)
                                .setPointA(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.pointA != null
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      child: const Text('A'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      // اگر هنوز A ست نشده یا زمان فعلی قبل از A است، دکمه B غیرفعال است
                      onPressed:
                          (state.pointA == null ||
                              state.position <= state.pointA!)
                          ? null
                          : () => ref
                                .read(audioPlayerProvider.notifier)
                                .setPointB(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.pointB != null
                            ? Colors.red
                            : Colors.grey,
                      ),
                      child: const Text('B'),
                    ),
                    // دکمه پاک کردن همیشه فعال است
                    IconButton(
                      icon: const Icon(Icons.layers_clear, color: Colors.white),
                      onPressed: () =>
                          ref.read(audioPlayerProvider.notifier).clearAB(),
                    ),
                    PopupMenuButton<double>(
                      initialValue: state.speed,
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${state.speed}x",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onSelected: (double value) {
                        ref.read(audioPlayerProvider.notifier).setSpeed(value);
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<double>>[
                            const PopupMenuItem(
                              value: 0.5,
                              child: Text('0.5x (بسیار کند)'),
                            ),
                            const PopupMenuItem(
                              value: 0.8,
                              child: Text('0.8x (کند)'),
                            ),
                            const PopupMenuItem(
                              value: 1.0,
                              child: Text('1.0x (معمولی)'),
                            ),
                            const PopupMenuItem(
                              value: 1.2,
                              child: Text('1.2x (سریع)'),
                            ),
                            const PopupMenuItem(
                              value: 1.5,
                              child: Text('1.5x (بسیار سریع)'),
                            ),
                          ],
                    ),
                    IconButton(
                      icon: Icon(
                        state.isRepeatEnabled ? Icons.repeat_one : Icons.repeat,
                        color: state.isRepeatEnabled
                            ? Colors.blue
                            : Colors.white,
                      ),
                      onPressed: () =>
                          ref.read(audioPlayerProvider.notifier).toggleRepeat(),
                    ),
                  ],
                ),
              ),

              Text(
                _formatDuration(state.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // دکمه‌های کنترلی
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
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
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
              onPressed: () =>
                  ref.read(audioPlayerProvider.notifier).skip10Sec(true),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
