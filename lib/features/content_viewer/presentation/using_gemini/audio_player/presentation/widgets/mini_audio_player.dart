import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/audio_player_provider.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);

    // اگر فایلی انتخاب نشده باشد، فضای خالی برگردان
    if (playerState.currentPath == null) return const SizedBox.shrink();

    return Container(
      height: 120,
      decoration: const BoxDecoration(
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

              // کنترل‌های پخش (متدهای قبلی و بعدی چون در پرووایدر نیستند حذف یا جایگزین با عقب و جلو شدند)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => notifier.skip10Sec(false),
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
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => notifier.skip10Sec(true),
                  ),
                ],
              ),

              // دکمه تکرار معمولی
              IconButton(
                icon: Icon(
                  Icons.loop,
                  color: playerState.isRepeatEnabled
                      ? Colors.blue
                      : Colors.grey,
                ),
                onPressed: () => notifier.toggleRepeat(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    AudioPlayerState playerState,
    AudioPlayerNotifier notifier,
  ) {
    final posSec = playerState.position.inSeconds.toDouble();
    final durSec = playerState.duration.inSeconds.toDouble();

    return Slider(
      value: posSec.clamp(0.0, durSec > 0 ? durSec : 100.0),
      max: durSec > 0 ? durSec : 100.0,
      onChanged: (value) => notifier.seek(Duration(seconds: value.toInt())),
    );
  }

  Widget _buildABButton(
    AudioPlayerState playerState,
    AudioPlayerNotifier notifier,
  ) {
    bool isA = playerState.pointA != null;
    bool isB = playerState.pointB != null;

    return ActionChip(
      label: Text(isB ? "Clear A-B" : (isA ? "Set B" : "Set A")),
      backgroundColor: isB
          ? Colors.red[100]
          : (isA ? Colors.orange[100] : null),
      onPressed: () {
        if (!isA) {
          notifier.setPointA();
        } else if (!isB) {
          notifier.setPointB();
        } else {
          notifier.clearAB();
        }
      },
    );
  }
}
