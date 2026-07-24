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

// 🐞 برای قابلیتِ «پلی‌لیستِ کتاب + برگشتن به نقطه‌ی درست در متن»: مشخص
// می‌کند فایلِ در حال پخش از چه راهی انتخاب شده — این تصمیم می‌گیرد که
// دکمه‌ی «برو به متن» باید کاربر را به کجای کتاب ببرد.
enum AudioTrackSource {
  none,
  // از طریق دکمه‌های قبلی/بعدیِ پلیر یا خودِ لیستِ پخش → به اولین وقوعِ
  // این فایل در کتاب می‌رویم (چون این انتخاب به یک نقطه‌ی خاص از متن وصل
  // نبوده).
  sequential,
  // از طریق دکمه‌ی صوتیِ داخلِ متنِ کتاب (یک وقوعِ مشخص) → دقیقاً به همان
  // نقطه‌ای می‌رویم که کاربر رویش تپ کرده.
  explicitLocation,
}

// یک موقعیتِ مشخص از کتاب که این فایلِ صوتی در آن ظاهر شده (شماره‌ی صفحه +
// اندیسِ پاراگراف)؛ اولین موردِ هر فایل برای حالتِ sequential استفاده می‌شود.
class AudioLocation {
  final int pageNumber;
  final int paraIndex;
  const AudioLocation({required this.pageNumber, required this.paraIndex});
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
  // 🐞 اولین وقوعِ هر فایل در کتاب (برای رفتنِ sequential) — از رویِ همین
  // پلی‌لیستِ کتاب‌محور پر می‌شود.
  final Map<String, AudioLocation> firstOccurrence;
  final AudioTrackSource lastSource;
  // 🐞 موقعیتِ هدف برای دکمه‌ی «برو به متن»: یا اولین وقوع (sequential) یا
  // همان وقوعِ دقیقی که رویش تپ شده (explicitLocation).
  final AudioLocation? targetLocation;

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
    this.firstOccurrence = const {},
    this.lastSource = AudioTrackSource.none,
    this.targetLocation,
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
    Map<String, AudioLocation>? firstOccurrence,
    AudioTrackSource? lastSource,
    AudioLocation? Function()? targetLocation,
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
      firstOccurrence: firstOccurrence ?? this.firstOccurrence,
      lastSource: lastSource ?? this.lastSource,
      targetLocation: targetLocation != null
          ? targetLocation()
          : this.targetLocation,
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

  // 🌟 متد ثبت لیست پخش (صداهای کل کتاب) + اولین وقوعِ هر فایل در کتاب
  void setPlaylist(
    List<String> files, {
    Map<String, AudioLocation>? firstOccurrence,
  }) {
    if (files.isNotEmpty) {
      state = state.copyWith(
        playlist: files,
        firstOccurrence: firstOccurrence ?? state.firstOccurrence,
      );
    }
  }

  Future<void> playFile(
    String path, {
    List<String>? newPlaylist,
    Map<String, AudioLocation>? newFirstOccurrence,
    // 🐞 اگر مشخص شود، یعنی این پخش از رویِ یک وقوعِ دقیق در متن بوده
    // (دکمه‌ی صوتیِ داخلِ کتاب) — همین را به‌عنوانِ هدفِ «برو به متن» ذخیره
    // می‌کنیم. اگر مشخص نشود، از firstOccurrence همان فایل استفاده می‌شود
    // (یعنی این انتخاب sequential بوده، مثلِ لیستِ پخش یا قبلی/بعدی).
    AudioLocation? explicitLocation,
  }) async {
    try {
      if (newPlaylist != null) {
        setPlaylist(newPlaylist, firstOccurrence: newFirstOccurrence);
      }

      final AudioLocation? resolvedTarget =
          explicitLocation ??
          newFirstOccurrence?[path] ??
          state.firstOccurrence[path];
      final AudioTrackSource resolvedSource = explicitLocation != null
          ? AudioTrackSource.explicitLocation
          : AudioTrackSource.sequential;

      if (state.currentPath == path && _player.duration != null) {
        state = state.copyWith(
          lastSource: resolvedSource,
          targetLocation: () => resolvedTarget,
        );
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
        lastSource: resolvedSource,
        targetLocation: () => resolvedTarget,
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
      // 🐞 از طریقِ دکمه‌ی بعدی → sequential (explicitLocation پاس داده
      // نمی‌شود، پس playFile خودش از firstOccurrence استفاده می‌کند)
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
