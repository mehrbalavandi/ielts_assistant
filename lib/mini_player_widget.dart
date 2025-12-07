import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'player_display_state.dart';
import 'audio_player_widget.dart'; // ویجت Modal/Maximized قبلی

class MiniPlayerWidget extends ConsumerWidget {
  final Topic topic;
  const MiniPlayerWidget({required this.topic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final displayNotifier = ref.read(playerDisplayProvider.notifier);

    // تابع برای بزرگ کردن پلیر
    void maximizePlayer() {
      // ۱. تغییر حالت نمایش به maximized
      displayNotifier.maximize();

      // ۲. نمایش ویجت بزرگ (Modal)
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return AudioPlayerWidget(topic: topic);
        },
      ).then((_) {
        // ۳. پس از بسته شدن Modal، حالت را به minimized برگردان (یا اگر پخش متوقف شد، hidden)
        displayNotifier.minimize();
      });
    }

    return GestureDetector(
      onTap: maximizePlayer, // با زدن روی پلیر کوچک، بزرگ می‌شود
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.queue_music, color: Colors.indigo),

              // اطلاعات قطعه
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${topic.name} - ${audioState.currentIndex != null ? 'قطعه ${audioState.currentIndex! + 1}' : '---'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // دکمه پخش/توقف
              IconButton(
                icon: Icon(
                  audioState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.indigo,
                ),
                onPressed: () {
                  if (audioState.isPlaying) {
                    notifier.pause();
                  } else {
                    notifier.play();
                  }
                },
              ),

              // دکمه بستن
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: notifier.stop, // توقف کامل و پنهان شدن پلیر
              ),
            ],
          ),
        ),
      ),
    );
  }
}
