import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:just_audio/just_audio.dart';
part 'player_state.freezed.dart';

@freezed
sealed class PlayerState with _$PlayerState {
  const factory PlayerState({
    @Default(false) bool isPlaying,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(LoopMode.off) LoopMode loopMode,
    Duration? startA,
    Duration? endB,
    String? currentFilePath,
  }) = _PlayerState;
}
