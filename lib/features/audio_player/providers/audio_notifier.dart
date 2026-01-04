import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'player_state.dart';

part 'audio_notifier.g.dart';

@riverpod
class Player extends _$Player {
  late AudioPlayer _audioPlayer;

  @override
  PlayerState build() {
    _audioPlayer = AudioPlayer();

    // گوش دادن به وضعیت پخش (Playing/Paused)
    _audioPlayer.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    // گوش دادن به تغییرات زمان (Position) و مدیریت A-B Repeat
    _audioPlayer.positionStream.listen((pos) {
      state = state.copyWith(position: pos);

      // اگر هر دو نقطه تعیین شده باشند و از نقطه B عبور کنیم
      if (state.startA != null && state.endB != null) {
        if (pos >= state.endB!) {
          _audioPlayer.seek(state.startA!); // پرش به نقطه A
        }
      }
    });

    // گوش دادن به مدت زمان کل فایل
    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    // پاکسازی منابع هنگام از بین رفتن پرووایدر
    ref.onDispose(() => _audioPlayer.dispose());

    return const PlayerState();
  }

  // --- متدهای کنترلی ---

  Future<void> playFile(String path) async {
    try {
      await _audioPlayer.setFilePath(path);
      state = state.copyWith(currentFilePath: path, startA: null, endB: null);
      _audioPlayer.play();
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  void resume() => _audioPlayer.play();
  void pause() => _audioPlayer.pause();
  void stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
  }

  void seek(Duration pos) => _audioPlayer.seek(pos);

  // عقب و جلو بردن نسبی (مثلاً ۱۰ ثانیه)
  void seekRelative(int seconds) {
    final newPos = state.position + Duration(seconds: seconds);
    _audioPlayer.seek(newPos);
  }

  // تکرار کل فایل
  void toggleLoop() {
    final nextMode = state.loopMode == LoopMode.off
        ? LoopMode.one
        : LoopMode.off;
    _audioPlayer.setLoopMode(nextMode);
    state = state.copyWith(loopMode: nextMode);
  }

  // --- منطق A-B Repeat ---

  void setPointA() {
    state = state.copyWith(startA: state.position);
  }

  void setPointB() {
    if (state.startA != null && state.position > state.startA!) {
      state = state.copyWith(endB: state.position);
    }
  }

  void clearAB() {
    state = state.copyWith(startA: null, endB: null);
  }

  // این متدها را به کلاس Player اضافه کنید:

  void playNext(WidgetRef ref) {
    final navState = ref.read(navigationProvider);
    if (navState.selectedPage == null) return;

    final topics = navState.selectedPage!.finalTopics;
    // پیدا کردن ایندکس فایلی که در حال حاضر پخش می‌شود
    final currentIndex = topics.indexWhere(
      (t) => t.audioFileName == state.currentFileName,
    );

    if (currentIndex != -1 && currentIndex < topics.length - 1) {
      final nextTopic = topics[currentIndex + 1];
      if (nextTopic.audioFileName != null) {
        // استفاده از مسیر ریشه ذخیره شده در تنظیمات
        final rootPath = ref.read(settingsProvider) ?? "";
        playFile(
          "${rootPath}/${nextTopic.audioFileName}",
          nextTopic.audioFileName!,
        );
      }
    }
  }

  void playPrevious(WidgetRef ref) {
    final navState = ref.read(navigationProvider);
    if (navState.selectedPage == null) return;

    final topics = navState.selectedPage!.finalTopics;
    final currentIndex = topics.indexWhere(
      (t) => t.audioFileName == state.currentFileName,
    );

    if (currentIndex > 0) {
      final prevTopic = topics[currentIndex - 1];
      if (prevTopic.audioFileName != null) {
        final rootPath = ref.read(settingsProvider) ?? "";
        playFile(
          "${rootPath}/${prevTopic.audioFileName}",
          prevTopic.audioFileName!,
        );
      }
    }
  }
}
