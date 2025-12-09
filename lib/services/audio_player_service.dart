import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

// تابع کمکی برای نمایش زمان به فرمت 00:00 (برای استفاده در پرینت‌ها و منطق)
String _formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

// مدل برای نگهداری وضعیت پخش کنونی (به روز رسانی شده برای A-B Loop)
class AudioState {
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;
  final int? currentIndex;
  final Duration? loopStart; // نقطه A
  final Duration? loopEnd; // نقطه B

  AudioState({
    this.isPlaying = false,
    this.position,
    this.duration,
    this.currentIndex,
    this.loopStart,
    this.loopEnd,
  });

  // متد کمکی برای به روز رسانی ساده وضعیت
  AudioState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    int? currentIndex,
    Object? loopStart = const _Sentinel(),
    Object? loopEnd = const _Sentinel(),
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentIndex: currentIndex ?? this.currentIndex,
      loopStart: loopStart is _Sentinel
          ? this.loopStart
          : loopStart as Duration?,
      loopEnd: loopEnd is _Sentinel ? this.loopEnd : loopEnd as Duration?,
    );
  }
}

// کلاس کمکی برای تشخیص عدم ارسال پارامتر
class _Sentinel {
  const _Sentinel();
}

class AudioPlayerNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();
  Topic? _currentTopic;

  // متغیرهای داخلی برای نگهداری نقاط A و B
  Duration? _loopStart;
  Duration? _loopEnd;

  AudioPlayerNotifier() : super(AudioState()) {
    _initStreams();
  }

  void _initStreams() {
    // گوش دادن به تغییر وضعیت پلیر
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      state = state.copyWith(isPlaying: isPlaying);
    });

    // گوش دادن به تغییر موقعیت پخش و اعمال منطق A-B
    _player.positionStream.listen((position) {
      // ۱. منطق چک کردن A-B را اجرا می‌کنیم
      _checkLoopBoundary(position);

      // ۲. وضعیت UI را به‌روزرسانی می‌کنیم
      state = state.copyWith(
        position: position,
        duration: _player.duration,
        currentIndex: _player.currentIndex,
      );
    });

    _player.durationStream.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _player.sequenceStateStream.listen((sequenceState) {
      state = state.copyWith(currentIndex: _player.currentIndex);
    });
  }

  void _checkLoopBoundary(Duration position) {
    if (_loopStart != null && _loopEnd != null) {
      if (_loopStart! < _loopEnd!) {
        const threshold = Duration(milliseconds: 30);

        if (position >= (_loopEnd! - threshold)) {
          _player.seek(_loopStart);
          // مهم: پس از پرش، باید مطمئن شویم که پخش ادامه دارد
          // جلوگیری از اجرای چند seek پشت هم
          Future.delayed(Duration(milliseconds: 10), () {
            if (!_player.playing) {
              _player.play();
            }
          });
        }
      }
    }
  }

  // متدها برای تنظیم نقطه شروع A
  void setLoopStart(Duration? position) {
    if (_loopStart != null) {
      _loopEnd = null;
    }
    _loopStart = position;
    _updateStateWithLoopPoints();
  }

  // متدها برای تنظیم نقطه پایان B
  void setLoopEnd(Duration? position) {
    if (_loopStart == null) {
      return;
    }
    if (position != null && position <= _loopStart!) {
      _loopEnd = null;
      return;
    }
    // debugPrint('لاگ: set B To $position');
    _loopEnd = position;
    _updateStateWithLoopPoints();
  }

  // به روز رسانی وضعیت Riverpod با نقاط A و B
  void _updateStateWithLoopPoints() {
    state = state.copyWith(loopStart: _loopStart, loopEnd: _loopEnd);
  }

  // لود کردن و پخش لیست صوت
  Future<void> loadPlaylist(Topic topic) async {
    _currentTopic = topic;
    await _player.stop();
    // ✅ ریست کردن نقاط A و B هنگام لود لیست پخش جدید
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints(); // به‌روزرسانی وضعیت UI

    // ریست کردن نقاط A و B هنگام لود لیست پخش جدید
    state = state.copyWith(loopStart: null, loopEnd: null);

    final List<AudioSource> sources = topic.audioFilePaths
        .map((path) => AudioSource.uri(Uri.file(path)))
        .toList();
    final ConcatenatingAudioSource playlist = ConcatenatingAudioSource(
      children: sources,
    );

    await _player.setAudioSource(
      playlist,
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    _player.play();
  }

  // متد ذخیره سازی پیشرفت (برای رفع خطای "متد تعریف نشده")
  void saveProgress() {
    if (_currentTopic != null && _player.currentIndex != null) {
      final index = _player.currentIndex!;
      final position = _player.position.inSeconds;

      // TODO: منطق ذخیره (topicId, index, position) در GetStorage یا Realm
      print(
        'Saving progress for ${_currentTopic!.name}: file index $index, position $position seconds.',
      );
    }
  }

  // کنترل‌های پخش
  void play() => _player.play();
  void pause() => _player.pause();

  // توقف کامل (همراه با ریست A و B)
  void stop() {
    _player.stop();
    state = state.copyWith(
      loopStart: null,
      loopEnd: null,
      isPlaying: false, // مطمئن شوید که isPlaying هم false شود
      position: Duration.zero, // موقعیت هم ریست شود
    );
  }

  void seekNext() {
    _player.seekToNext();
    // ✅ ریست A و B پس از پرش به قطعه جدید
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints();
  }

  void seekPrevious() {
    _player.seekToPrevious();
    // ✅ ریست A و B پس از پرش به قطعه جدید
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints();
  }

  void seek(Duration position) => _player.seek(position);
  void skipToItem(int index) => _player.seek(Duration.zero, index: index);

  // Getter برای دسترسی به مبحث در حال پخش در UI
  Topic? get currentTopic => _currentTopic;

  @override
  void dispose() {
    // فراخوانی متد ذخیره قبل از حذف شدن
    saveProgress();
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioState>((ref) {
      return AudioPlayerNotifier();
    });
