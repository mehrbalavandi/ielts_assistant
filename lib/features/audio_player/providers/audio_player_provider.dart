// lib/features/audio_player/providers/audio_player_provider.dart

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

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();

    // گوش دادن به تغییرات وضعیت پخش (پخش/توقف)
    _player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    // گوش دادن به تغییرات موقعیت زمانی
    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    // گوش دادن به مدت زمان کل فایل
    _player.durationStream.listen((dur) {
      state = state.copyWith(duration: dur ?? Duration.zero);
    });

    return AudioPlayerState();
  }

  Future<void> playFile(String path) async {
    try {
      if (state.currentPath == path) {
        _player.play();
        return;
      }
      await _player.setFilePath(path);
      state = state.copyWith(currentPath: path);
      _player.play();
    } catch (e) {
      print("خطا در پخش فایل: $e");
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
