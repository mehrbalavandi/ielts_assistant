import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';

class AudioPlayerWidget extends ConsumerWidget {
  final Topic topic;
  const AudioPlayerWidget({required this.topic, super.key});

  // تابع کمکی برای نمایش زمان به فرمت 00:00
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);

    // لود کردن لیست پخش مبحث هنگام اولین بار مشاهده
    // این منطق بهتر است در onTap دکمه در صفحه قبل باشد یا از طریق یک متد lifecycle اجرا شود.
    // در اینجا برای سادگی در اولین بیلد قرار داده شده:
    // Future.microtask(() => notifier.loadPlaylist(topic));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مبحث: ${topic.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            // نمایش نام فایل در حال پخش
            Text(
              'فایل: ${audioState.currentIndex != null && topic.audioFilePaths.isNotEmpty ? topic.audioFilePaths[audioState.currentIndex!].split('/').last : '---'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),

            // نوار پیشرفت پخش
            Slider(
              min: 0,
              max: audioState.duration?.inSeconds.toDouble() ?? 0.0,
              value: audioState.position?.inSeconds.toDouble() ?? 0.0,
              onChanged: (double value) {
                // پرش (Seek) دستی کاربر
                notifier.seek(Duration(seconds: value.toInt()));
              },
            ),

            // نمایش زمان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(audioState.position ?? Duration.zero)),
                  Text(_formatDuration(audioState.duration ?? Duration.zero)),
                ],
              ),
            ),

            // دکمه‌های کنترل
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // دکمه قبلی
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 40),
                  onPressed: notifier.seekPrevious,
                ),

                // دکمه پخش/توقف
                IconButton(
                  icon: Icon(
                    audioState.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64,
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

                // دکمه بعدی
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 40),
                  onPressed: notifier.seekNext,
                ),

                // دکمه توقف کامل (اختیاری)
                IconButton(
                  icon: const Icon(Icons.stop, size: 40),
                  onPressed: notifier.stop,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // نمایش لیست قطعات (برای ناوبری آسان)
            SizedBox(
              height: 100, // محدود کردن ارتفاع
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: topic.audioFilePaths.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == audioState.currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text('قطعه ${index + 1}'),
                      backgroundColor: isCurrent
                          ? Colors.indigo.withOpacity(0.2)
                          : null,
                      side: isCurrent
                          ? const BorderSide(color: Colors.indigo)
                          : null,
                      onPressed: () => notifier.skipToItem(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
