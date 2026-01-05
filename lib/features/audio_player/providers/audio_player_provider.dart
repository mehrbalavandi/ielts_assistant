// lib/features/audio_player/providers/audio_player_provider.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'audio_player_provider.g.dart';

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? currentPath;
  final bool isRepeatEnabled; // قابلیت تکرار
  final Duration? pointA; // نقطه شروع A
  final Duration? pointB; // نقطه پایان B

  AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentPath,
    this.isRepeatEnabled = false,
    this.pointA,
    this.pointB,
  });

  // متد copyWith برای بروزرسانی وضعیت
  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentPath,
    bool? isRepeatEnabled, // استفاده از تابع برای اجازه دادن به پاس دادن null
    Duration? Function()? pointA,
    Duration? Function()? pointB,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentPath: currentPath ?? this.currentPath,
      isRepeatEnabled: isRepeatEnabled ?? this.isRepeatEnabled,
      pointA: pointA != null ? pointA() : this.pointA,
      pointB: pointB != null ? pointB() : this.pointB,
    );
  }
}

@riverpod
class AudioPlayerNotifier extends _$AudioPlayerNotifier {
  late AudioPlayer _player;
  final _box = GetStorage();
  // تعریف متغیرهایی برای نگه داشتن اشتراک‌ها
  StreamSubscription? _playStateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();

    _playStateSub = _player.playingStream.listen((playing) {
      if (ref.mounted) state = state.copyWith(isPlaying: playing);
    });

    _posSub = _player.positionStream.listen((pos) {
      if (!ref.mounted) return;

      state = state.copyWith(position: pos);

      // منطق A-B Repeat
      if (state.pointA != null && state.pointB != null) {
        if (pos >= state.pointB!) {
          _player.seek(state.pointA!); // پرش به نقطه A
        }
      }
      if (state.currentPath != null) {
        _box.write('pos_${state.currentPath}', pos.inMilliseconds);
      }
    });

    _durSub = _player.durationStream.listen((dur) {
      if (ref.mounted) state = state.copyWith(duration: dur ?? Duration.zero);
    });

    // لغو کردن تمام استریم‌ها و آزاد کردن حافظه موقع نابودی پرووایدر
    ref.onDispose(() {
      _playStateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _player.dispose();
    });

    return AudioPlayerState();
  }

  Future<void> playFile(String path) async {
    try {
      // اگر همین فایل در حال پخش است، فقط ادامه بده
      if (state.currentPath == path && _player.duration != null) {
        _player.play();
        return;
      }
      await _player.stop();

      final lastPosMs = _box.read('pos_$path') ?? 0;

      state = state.copyWith(
        currentPath: path,
        pointA: null,
        pointB: null,
        position: Duration(milliseconds: lastPosMs),
      );
      await _player.setFilePath(path);
      await _player.seek(Duration(milliseconds: lastPosMs));
      _player.play();
    } catch (e) {
      if (e is PlayerInterruptedException) {
        debugPrint("بارگذاری قبلی متوقف شد تا فایل جدید لود شود.");
      } else {
        debugPrint("خطا در پخش فایل: $e");
      }
    }
  }

  // مدیریت A-B Repeat
  void setPointA() {
    // اگر نقطه B قبلاً ست شده و زمان فعلی بعد از B است، اجازه نده
    if (state.pointB != null && state.position >= state.pointB!) {
      // می‌توانید اینجا یک Snackbar نشان دهید یا فقط عملیات را انجام ندهید
      return;
    }
    state = state.copyWith(pointA: () => state.position);
  }

  void setPointB() {
    // فقط در صورتی اجازه بده که نقطه B بعد از نقطه A باشد
    if (state.pointA != null && state.position <= state.pointA!) {
      // خطای منطقی: نقطه پایان نمی‌تواند قبل از شروع باشد
      return;
    }
    state = state.copyWith(pointB: () => state.position);
  }

  void clearAB() {
    // ارسال تابع که null برمی‌گرداند برای ریست کردن مقادیر
    state = state.copyWith(pointA: () => null, pointB: () => null);
  }

  // تکرار کل فایل
  void toggleRepeat() {
    final nextMode = !state.isRepeatEnabled;
    state = state.copyWith(isRepeatEnabled: nextMode);
    _player.setLoopMode(nextMode ? LoopMode.one : LoopMode.off);
  }

  void stopAndClear() {
    _player.stop();
    state = AudioPlayerState(); // ریست کامل پلیر
  }

  void pause() => _player.pause();
  void resume() => _player.play();
  void seek(Duration position) => _player.seek(position);
  void skip10Sec(bool forward) {
    final target = forward
        ? state.position + const Duration(seconds: 10)
        : state.position - const Duration(seconds: 10);
    _player.seek(target);
  }
}
