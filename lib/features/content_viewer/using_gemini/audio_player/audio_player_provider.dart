// lib/features/audio_player/providers/audio_player_provider.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'audio_player_provider.g.dart';

// 🌟 Enum جدید برای مدیریت رفتار پایان فایل
enum PlaybackMode {
  stop, // توقف بعد از اتمام
  repeatOne, // تکرار همین فایل
  autoAdvance, // رفتن به فایل بعدی
}

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String? currentPath;
  final Duration? pointA;
  final Duration? pointB;
  final double speed;
  final PlaybackMode playbackMode; // 🌟 اضافه شد
  final List<String> playlist; // 🌟 لیست فایل‌ها برای قبلی/بعدی

  AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentPath,
    this.pointA,
    this.pointB,
    this.speed = 1.0,
    this.playbackMode = PlaybackMode.stop, // پیش‌فرض: توقف
    this.playlist = const [],
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentPath,
    Duration? Function()? pointA,
    Duration? Function()? pointB,
    double? speed,
    PlaybackMode? playbackMode,
    List<String>? playlist,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentPath: currentPath ?? this.currentPath,
      pointA: pointA != null ? pointA() : this.pointA,
      pointB: pointB != null ? pointB() : this.pointB,
      speed: speed ?? this.speed,
      playbackMode: playbackMode ?? this.playbackMode,
      playlist: playlist ?? this.playlist,
    );
  }
}

@riverpod
class AudioPlayerNotifier extends _$AudioPlayerNotifier {
  late AudioPlayer _player;
  final _box = GetStorage();
  StreamSubscription? _playStateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();

    // 🌟 خواندن حالت ذخیره شده برای رفتار پایان فایل
    final savedModeIndex = _box.read('playback_mode') ?? 0;
    final savedMode = PlaybackMode.values[savedModeIndex];

    // لیسنرها (چون کدهای داخل لیسنر به صورت Asynchronous و بعداً اجرا می‌شوند،
    // دسترسی آن‌ها به state مشکلی ایجاد نمی‌کند)
    _playStateSub = _player.playingStream.listen((playing) {
      if (ref.mounted) state = state.copyWith(isPlaying: playing);
    });

    _posSub = _player.positionStream.listen((pos) {
      if (!ref.mounted) return;

      state = state.copyWith(position: pos);

      // منطق A-B Repeat
      if (state.pointA != null && state.pointB != null) {
        if (pos >= state.pointB!) {
          _player.seek(state.pointA!);
        }
      }
      if (state.currentPath != null) {
        _box.write('pos_${state.currentPath}', pos.inMilliseconds);
      }
    });

    _player.processingStateStream.listen((status) {
      if (status == ProcessingState.completed) {
        if (state.playbackMode == PlaybackMode.repeatOne) {
          _player.seek(Duration.zero);
          _player.play();
        } else if (state.playbackMode == PlaybackMode.autoAdvance) {
          playNext();
        } else {
          // PlaybackMode.stop
          _player.seek(Duration.zero);
          _player.pause();
          state = state.copyWith(position: Duration.zero);
          if (state.currentPath != null) {
            _box.write('pos_${state.currentPath}', 0);
          }
        }
      }
    });

    _durSub = _player.durationStream.listen((dur) {
      if (ref.mounted) {
        state = state.copyWith(duration: dur ?? Duration.zero);
        if (state.currentPath != null && dur != null) {
          _box.write('dur_${state.currentPath}', dur.inMilliseconds);
        }
      }
    });

    ref.onDispose(() {
      _playStateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _player.dispose();
    });

    // 🌟 اینجا به جای آپدیت استیت در بالا، متغیر خوانده شده را
    // مستقیماً برای مقداردهی اولیه ریترن می‌کنیم
    return AudioPlayerState(playbackMode: savedMode);
  }

  // 🌟 متد ثبت لیست پخش (صداهای صفحه فعلی)
  void setPlaylist(List<String> files) {
    if (files.isNotEmpty) {
      state = state.copyWith(playlist: files);
    }
  }

  Future<void> playFile(String path, {List<String>? newPlaylist}) async {
    try {
      if (newPlaylist != null) {
        setPlaylist(newPlaylist);
      }

      if (state.currentPath == path && _player.duration != null) {
        _player.play();
        return;
      }
      await _player.stop();

      final lastPosMs = _box.read('pos_$path') ?? 0;

      state = state.copyWith(
        currentPath: path,
        pointA: () => null,
        pointB: () => null,
        position: Duration(milliseconds: lastPosMs),
      );

      if (path.startsWith('assets/')) {
        await _player.setAsset(path);
      } else {
        final uri = Uri.file(path).toString();
        debugPrint(uri);
        await _player.setUrl(uri);
        // await _player.setFilePath(path);
      }

      await _player.seek(Duration(milliseconds: lastPosMs));
      _player.play();
    } catch (e) {
      debugPrint("خطا در پخش فایل: $e");
    }
  }

  // 🌟 متدهای بعدی و قبلی
  void playNext() {
    if (state.playlist.isEmpty || state.currentPath == null) return;
    int currentIndex = state.playlist.indexOf(state.currentPath!);
    if (currentIndex != -1 && currentIndex < state.playlist.length - 1) {
      playFile(state.playlist[currentIndex + 1]);
    } else {
      // اگر به آخر لیست رسیدیم توقف کن
      _player.stop();
      state = state.copyWith(position: Duration.zero);
    }
  }

  void playPrevious() {
    if (state.playlist.isEmpty || state.currentPath == null) return;
    int currentIndex = state.playlist.indexOf(state.currentPath!);
    if (currentIndex > 0) {
      playFile(state.playlist[currentIndex - 1]);
    } else if (currentIndex == 0) {
      _player.seek(Duration.zero); // اگر فایل اول بود، از اول پخشش کن
    }
  }

  // 🌟 تغییر حالت رفتار پایان فایل (Stop -> AutoAdvance -> RepeatOne)
  void togglePlaybackMode() {
    PlaybackMode nextMode;
    switch (state.playbackMode) {
      case PlaybackMode.stop:
        nextMode = PlaybackMode.autoAdvance;
        break;
      case PlaybackMode.autoAdvance:
        nextMode = PlaybackMode.repeatOne;
        break;
      case PlaybackMode.repeatOne:
        nextMode = PlaybackMode.stop;
        break;
    }

    state = state.copyWith(playbackMode: nextMode);
    _box.write('playback_mode', nextMode.index); // ذخیره در حافظه
  }

  // مدیریت A-B Repeat
  void setPointA() {
    if (state.pointB != null) {
      if (state.position < state.pointB!) {
        state = state.copyWith(pointA: () => state.position);
      } else {
        state = state.copyWith(
          pointA: () => state.position,
          pointB: () => null,
        );
      }
    } else {
      state = state.copyWith(pointA: () => state.position);
    }
  }

  void setPointB() {
    if (state.pointB != null) {
      state = state.copyWith(pointB: () => null);
      return;
    }
    if (state.pointA != null && state.position <= state.pointA!) return;
    state = state.copyWith(pointB: () => state.position);
  }

  void clearAB() {
    state = state.copyWith(pointA: () => null, pointB: () => null);
  }

  void stopAndClear() {
    _player.stop();
    state = AudioPlayerState(
      playbackMode: state.playbackMode,
      playlist: state.playlist,
    );
  }

  bool isPlaying() => _player.playing;
  void pause() => _player.pause();
  void resume() => _player.play();
  void seek(Duration position) => _player.seek(position);

  void skip10Sec(bool forward) {
    final target = forward
        ? state.position + const Duration(seconds: 10)
        : state.position - const Duration(seconds: 10);
    _player.seek(target);
  }

  void setSpeed(double newSpeed) {
    _player.setSpeed(newSpeed);
    state = state.copyWith(speed: newSpeed);
  }
}
