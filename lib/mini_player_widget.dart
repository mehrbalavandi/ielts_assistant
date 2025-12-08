import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'player_display_state.dart';
import 'audio_player_widget.dart'; // ویجت Modal/Maximized قبلی

// ... (ایمپورت‌ها)
// ...

class MiniPlayerWidget extends ConsumerWidget {
  final Topic topic;
  const MiniPlayerWidget({required this.topic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final displayNotifier = ref.read(playerDisplayProvider.notifier);

    // تابع برای بزرگ کردن پلیر (Modal نمایش داده و وضعیت را به Maximized می‌برد)
    void maximizePlayer() {
      displayNotifier.maximize();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          // استفاده از ویجت بزرگ قبلی (AudioPlayerWidget)
          return FractionallySizedBox(
            heightFactor: 0.45, // 90% صفحه را بگیرد
            child: AudioPlayerWidget(topic: topic),
          );
        },
      ).then((_) {
        // پس از بسته شدن Modal
        if (audioState.isPlaying) {
          displayNotifier.minimize(); // اگر پخش ادامه دارد، به کوچک برگرد
        } else {
          displayNotifier.hide(); // در غیر این صورت، پنهان کن
        }
      });
    }

    // استفاده از Container برای تعیین ارتفاع ثابت پلیر کوچک
    return GestureDetector(
      onTap: maximizePlayer,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
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

            // دکمه بستن (پنهان کردن و توقف پخش)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                notifier.stop(); // توقف پخش
                // displayNotifier.hide(); // پنهان کردن پلیر
              },
            ),
          ],
        ),
      ),
    );
  }
}
