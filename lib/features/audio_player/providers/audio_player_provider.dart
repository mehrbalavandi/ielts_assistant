// lib/features/audio_player/providers/audio_player_provider.dart

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'audio_player_provider.g.dart';

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? currentPath;

  AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentPath,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentPath,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentPath: currentPath ?? this.currentPath,
    );
  }
}

@riverpod
class AudioPlayerNotifier extends _$AudioPlayerNotifier {
  late AudioPlayer _player;
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
      if (ref.mounted) state = state.copyWith(position: pos);
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

      // توقف کامل هر پخش یا بارگذاری قبلی برای جلوگیری از وقفه (Interruption)
      await _player.stop();

      state = state.copyWith(currentPath: path, isPlaying: false);

      // بارگذاری فایل جدید
      // استفاده از setFilePath به تنهایی گاهی باعث خطا می‌شود، بهتر است از وقفه کوتاه استفاده کنید
      await _player.setFilePath(path);

      _player.play();
    } catch (e) {
      // اگر خطا از نوع Interruption بود، معمولاً نادیده گرفته می‌شود
      if (e is PlayerInterruptedException) {
        print("بارگذاری قبلی متوقف شد تا فایل جدید لود شود.");
      } else {
        print("خطا در پخش فایل: $e");
      }
    }
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
