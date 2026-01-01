import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/shared/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:just_audio/just_audio.dart';

// تابع کمکی برای نمایش زمان به فرمت 00:00 (اگر قبلاً تعریف نشده)
String _formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

class AudioPlayerWidget extends ConsumerWidget {
  final FinalTopic mainTopic;
  const AudioPlayerWidget({required this.mainTopic, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    // وضعیت Loop Mode
    final loopMode = audioState.loopMode;

    // تعیین آیکون و رنگ دکمه بر اساس حالت
    IconData repeatIcon;
    Color repeatColor;
    switch (loopMode) {
      case LoopMode.off:
        repeatIcon = Icons.repeat;
        repeatColor = Colors.grey;
        break;
      case LoopMode.one:
        repeatIcon = Icons.repeat_one_on;
        repeatColor = Colors.blue;
        break;
      case LoopMode.all:
        repeatIcon = Icons.repeat_on;
        repeatColor = Colors.blue;
        break;
    }
    // وضعیت حلقه A-B
    final isALoopSet = audioState.loopStart != null;
    final isBLoopSet = audioState.loopEnd != null;

    // debugPrint('لاگ: isALoopSet = ${isALoopSet.toString()}');
    // debugPrint('لاگ: isBLoopSet = ${isBLoopSet.toString()}');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        // استفاده از SingleChildScrollView برای Modal
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // مبحث:
              mainTopic.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            // نمایش نام فایل در حال پخش
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                'فایل: ${audioState.currentIndex != null && mainTopic.audioFilePaths.isNotEmpty ? mainTopic.audioFilePaths[audioState.currentIndex!].split('/').last : '---'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
                // ✅ دکمه کنترل تکرار
                IconButton(
                  icon: // در AudioPlayerWidget یا MiniPlayerWidget، به جای IconButton:
                  GestureDetector(
                    onTap: notifier.toggleRepeatMode,
                    child: Icon(repeatIcon, color: repeatColor, size: 30.0),
                  ),
                  iconSize: 30.0,
                  onPressed: notifier.toggleRepeatMode, // فراخوانی متد جدید
                ),
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

            const SizedBox(height: 20),
            Directionality(
              textDirection: TextDirection.ltr,
              child: const Text('تکرار بخش (A-B Loop)'),
            ),
            const Divider(),

            // --- کنترل‌های تکرار A-B ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // دکمه A (شروع)
                _LoopButton(
                  label: 'A',
                  isActive: isALoopSet,
                  position: audioState.loopStart,
                  onTap: () {
                    // if (isALoopSet) {
                    //   notifier.setLoopStart(null); // پاک کردن A
                    // } else {
                    //   notifier.setLoopStart(
                    //     audioState.position,
                    //   ); // تنظیم A در موقعیت فعلی
                    // }
                    notifier.setLoopStart(audioState.position);
                  },
                ),

                const SizedBox(width: 40),

                // دکمه B (پایان)
                _LoopButton(
                  label: 'B',
                  isActive: isBLoopSet,
                  position: audioState.loopEnd,
                  onTap: () {
                    if (isBLoopSet) {
                      notifier.setLoopEnd(null);
                      // debugPrint('لاگ: set B To Null');
                    } else {
                      // debugPrint('لاگ: set B To ${audioState.position}');
                      notifier.setLoopEnd(audioState.position);
                    }
                    // notifier.setLoopEnd(audioState.position);
                  },
                ),
              ],
            ),

            const SizedBox(height: 8.0),
            /*
            // نمایش لیست قطعات (برای ناوبری آسان)
            SizedBox(
              height: 100, // محدود کردن ارتفاع
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mainTopic.audioFilePaths.length,
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
            */
          ],
        ),
      ),
    );
  }
}

// ویجت کمکی برای دکمه‌های A و B
class _LoopButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Duration? position;
  final VoidCallback onTap;

  const _LoopButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.position,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.red : Colors.grey;
    final positionText = position != null
        ? _formatDuration(position!)
        : 'تنظیم';

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: isActive ? 2 : 1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(positionText, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
