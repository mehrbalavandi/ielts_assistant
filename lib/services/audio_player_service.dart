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
    Duration? loopStart,
    Duration? loopEnd,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentIndex: currentIndex ?? this.currentIndex,
      loopStart: loopStart ?? this.loopStart,
      loopEnd: loopEnd ?? this.loopEnd,
    );
  }
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

  // منطق اصلی چک کردن نقطه پایان B و پرش به A
  void _checkLoopBoundary(Duration position) {
    if (_loopStart != null && _loopEnd != null) {
      // اطمینان از اینکه A قبل از B است
      if (_loopStart! < _loopEnd!) {
        // تلورانس کوچک برای جلوگیری از عبور ناگهانی و توقف پخش
        const threshold = Duration(milliseconds: 50);

        // اگر موقعیت کنونی به نقطه پایان (B) نزدیک شد یا از آن عبور کرد
        if (position >= (_loopEnd! - threshold)) {
          // پرش به نقطه شروع (A)
          _player.seek(_loopStart);
          print(
            'A-B Loop: Jumping from ${_formatDuration(_loopEnd!)} to ${_formatDuration(_loopStart!)}',
          );
        }
      }
    }
  }

  // متدها برای تنظیم نقطه شروع A
  void setLoopStart(Duration? position) {
    _loopStart = position;
    // اگر A بعد از B تنظیم شد، B را ریست کن
    if (_loopStart != null && _loopEnd != null && _loopStart! > _loopEnd!) {
      _loopEnd = null;
    }
    _updateStateWithLoopPoints();
  }

  // متدها برای تنظیم نقطه پایان B
  void setLoopEnd(Duration? position) {
    _loopEnd = position;
    // اگر B قبل از A تنظیم شد، A را ریست کن
    if (_loopStart != null && _loopEnd != null && _loopEnd! < _loopStart!) {
      _loopStart = null;
    }
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

    // ریست کردن نقاط A و B هنگام لود لیست پخش جدید
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints();

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
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints();
  }

  void seekNext() => _player.seekToNext();
  void seekPrevious() => _player.seekToPrevious();
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
