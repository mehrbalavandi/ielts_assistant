import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
// import 'realm_service.dart'; // سرویس Realm

// مدل برای نگهداری وضعیت پخش کنونی
class AudioState {
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;
  final int? currentIndex;

  AudioState({
    this.isPlaying = false,
    this.position,
    this.duration,
    this.currentIndex,
  });
}

// نوتیفایر Riverpod برای مدیریت پخش
class AudioPlayerNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  Topic? _currentTopic; // مبحثی که در حال حاضر در حال پخش است

  AudioPlayerNotifier() : super(AudioState()) {
    _initStreams();
  }

  void _initStreams() {
    // گوش دادن به تغییر وضعیت پلیر (پخش، توقف، لودینگ)
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      state = AudioState(
        isPlaying: isPlaying,
        position: state.position,
        duration: state.duration,
        currentIndex: _player.currentIndex,
      );
    });

    // گوش دادن به تغییر موقعیت پخش
    _positionSubscription = _player.positionStream.listen((position) {
      // اینجا می‌توان منطق ذخیره در Realm را هر ۵ ثانیه پیاده‌سازی کرد
      state = AudioState(
        isPlaying: state.isPlaying,
        position: position,
        duration: _player.duration,
        currentIndex: _player.currentIndex,
      );
    });

    // گوش دادن به تغییرات لیست پخش (مثل پرش به قطعه بعدی)
    _player.sequenceStateStream.listen((sequenceState) {
      state = AudioState(
        isPlaying: state.isPlaying,
        position: state.position,
        duration: _player.duration,
        currentIndex: _player.currentIndex,
      );
    });

    // گوش دادن به تغییر طول کلی قطعه
    _player.durationStream.listen((duration) {
      state = AudioState(
        isPlaying: state.isPlaying,
        position: state.position,
        duration: duration,
        currentIndex: state.currentIndex,
      );
    });
  }

  // لود کردن و پخش لیست صوت
  Future<void> loadPlaylist(Topic topic) async {
    _currentTopic = topic;
    await _player.stop();

    // ۱. ساختن AudioSource برای هر فایل
    final List<AudioSource> sources = topic.audioFilePaths
        .map((path) => AudioSource.uri(Uri.file(path)))
        .toList();

    // ۲. ساختن لیست پخش (ConcatenatingAudioSource)
    final ConcatenatingAudioSource playlist = ConcatenatingAudioSource(
      children: sources,
    );

    // TODO: ۳. بازیابی موقعیت ذخیره شده از Realm
    // اگر از Realm استفاده می‌کنید، باید آخرین موقعیت و آخرین فایل پخش شده را
    // از Realm بخوانید و با پارامترهای initialIndex و initialPosition به setAudioSource بدهید.

    await _player.setAudioSource(
      playlist,
      initialIndex: 0,
      initialPosition: Duration.zero,
    );

    _player.play();
  }

  // دکمه‌ها
  void play() => _player.play();
  void pause() => _player.pause();
  void stop() => _player.stop();
  void seekNext() => _player.seekToNext();
  void seekPrevious() => _player.seekToPrevious();

  // پرش به یک موقعیت خاص در فایل کنونی
  void seek(Duration position) => _player.seek(position);

  // پرش به یک قطعه خاص در لیست پخش
  void skipToItem(int index) => _player.seek(Duration.zero, index: index);

  // ذخیره موقعیت در Realm هنگام بستن برنامه یا پرش
  void saveProgress() {
    if (_currentTopic != null) {
      final index = _player.currentIndex;
      final position = _player.position.inSeconds;

      // TODO: منطق ذخیره (topicId, index, position) در Realm
      print(
        'Saving progress for ${_currentTopic!.name}: index $index, position $position seconds.',
      );
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    saveProgress(); // ذخیره نهایی هنگام خروج
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioState>((ref) {
      // هنگام بستن provider، dispose صدا زده می‌شود
      return AudioPlayerNotifier();
    });
