import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_notifier.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دقت کنید: نام پرووایدر طبق فایل .g.dart شما احتمالا 'playerProvider' است
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Container(
      child: Column(
        children: [
          // حالا playerState مستقیماً به فیلدها دسترسی دارد
          Text("Position: ${playerState.position.inSeconds}"),
          Slider(
            max: playerState.duration.inSeconds.toDouble(),
            value: playerState.position.inSeconds.toDouble(),
            onChanged: (v) => notifier.seek(Duration(seconds: v.toInt())),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.start,
                  color: playerState.startA != null ? Colors.red : null,
                ),
                onPressed: () => notifier.setPointA(),
              ),
              IconButton(
                icon: Icon(
                  Icons.end,
                  color: playerState.endB != null ? Colors.red : null,
                ),
                onPressed: () => notifier.setPointB(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
