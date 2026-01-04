import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:io';

part 'audio_notifier.g.dart';
part 'audio_notifier.freezed.dart';

@freezed
sealed class PlayerState with _$PlayerState {
  const factory PlayerState({
    @Default(false) bool isPlaying,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    Duration? startA,
    Duration? endB,
  }) = _PlayerState;
}

@riverpod
class Player extends _$Player {
  late AudioPlayer _audioPlayer;

  @override
  PlayerState build() {
    _audioPlayer = AudioPlayer();

    // گوش دادن به تغییرات پلیر و آپدیت وضعیت
    _audioPlayer.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      // منطق A-B Repeat
      if (state.startA != null && state.endB != null && pos >= state.endB!) {
        _audioPlayer.seek(state.startA!);
      }
    });

    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    return const PlayerState();
  }

  void setPointA() => state = state.copyWith(startA: state.position);
  void setPointB() => state = state.copyWith(endB: state.position);

  // متدهای دیگر: play, pause, seek...
}
