import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/audio_notifier.dart';
import 'package:just_audio/just_audio.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    // اگر فایلی انتخاب نشده باشد، پلیر را مخفی کن یا یک فضای خالی برگردان
    if (playerState.currentFilePath == null) return const SizedBox.shrink();

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // اسلایدر زمان
          _buildSlider(playerState, notifier),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // دکمه تکرار A-B
              _buildABButton(playerState, notifier),

              // کنترل‌های پخش
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => notifier.playPrevious(ref),
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 45,
                    ),
                    onPressed: () => playerState.isPlaying
                        ? notifier.pause()
                        : notifier.resume(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => notifier.playNext(ref),
                  ),
                ],
              ),

              // دکمه تکرار معمولی (Loop)
              IconButton(
                icon: Icon(
                  Icons.loop,
                  color: playerState.loopMode != LoopMode.off
                      ? Colors.blue
                      : Colors.grey,
                ),
                onPressed: () => notifier.toggleLoop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(playerState, notifier) {
    return Slider(
      value: playerState.position.inSeconds.toDouble(),
      max: playerState.duration.inSeconds.toDouble() > 0
          ? playerState.duration.inSeconds.toDouble()
          : 100,
      onChanged: (value) => notifier.seek(Duration(seconds: value.toInt())),
    );
  }

  Widget _buildABButton(playerState, notifier) {
    // منطق تغییر رنگ و متن دکمه بر اساس وضعیت A-B
    bool isA = playerState.startA != null;
    bool isB = playerState.endB != null;

    return ActionChip(
      label: Text(isB ? "Clear A-B" : (isA ? "Set B" : "Set A")),
      backgroundColor: isB
          ? Colors.red[100]
          : (isA ? Colors.orange[100] : null),
      onPressed: () {
        if (!isA)
          notifier.setPointA();
        else if (!isB)
          notifier.setPointB();
        else
          notifier.clearAB();
      },
    );
  }
}
