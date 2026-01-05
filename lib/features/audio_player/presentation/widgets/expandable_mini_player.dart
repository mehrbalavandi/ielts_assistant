// lib/features/audio_player/presentation/widgets/expandable_mini_player.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';

final isPlayerExpandedProvider = StateProvider<bool>((ref) => false);

class ExpandableMiniPlayer extends ConsumerWidget {
  const ExpandableMiniPlayer({super.key});

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
        height: isExpanded ? 220 : 75,
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
        ),
        child: SingleChildScrollView(
          // برای جلوگیری از خطای Overflow هنگام انیمیشن
          physics: const NeverScrollableScrollPhysics(),
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
      height: 75,
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
        ],
      ),
    );
  }

  // حالت باز شده (کامل)
  Widget _buildFullView(AudioPlayerState state, WidgetRef ref) {
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
        Slider(
          value: state.position.inSeconds.toDouble(),
          max: state.duration.inSeconds.toDouble() > 0
              ? state.duration.inSeconds.toDouble()
              : 1.0,
          onChanged: (v) => ref
              .read(audioPlayerProvider.notifier)
              .seek(Duration(seconds: v.toInt())),
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.white24,
        ),

        // زمان‌سنج
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(state.position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
