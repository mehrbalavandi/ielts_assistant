import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/shared/models/data_models.dart';
import 'package:ielts_assistant/services/storage_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

// مدل برای نگهداری وضعیت پخش کنونی (به روز رسانی شده برای A-B Loop)
class AudioState {
  final bool isPlaying;
  final bool isLoading;
  final ProcessingState processingState;
  final Duration? position;
  final Duration? duration;
  final int? currentIndex;
  final Duration? loopStart; // نقطه A
  final Duration? loopEnd; // نقطه B
  final LoopMode loopMode;
  final FinalTopic? currentTopic;

  AudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.processingState = ProcessingState.idle,
    this.position,
    this.duration,
    this.currentIndex,
    this.loopStart,
    this.loopEnd,
    this.loopMode = LoopMode.off, // پیش‌فرض: خاموش
    this.currentTopic,
  });

  // متد کمکی برای به روز رسانی ساده وضعیت
  AudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    ProcessingState? processingState,
    Duration? position,
    Duration? duration,
    int? currentIndex,
    Object? loopStart = const _Sentinel(),
    Object? loopEnd = const _Sentinel(),
    LoopMode? loopMode,
    FinalTopic? currentTopic,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      processingState: processingState ?? this.processingState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentIndex: currentIndex ?? this.currentIndex,
      loopStart: loopStart is _Sentinel
          ? this.loopStart
          : loopStart as Duration?,
      loopEnd: loopEnd is _Sentinel ? this.loopEnd : loopEnd as Duration?,
      loopMode: loopMode ?? this.loopMode,
      currentTopic: currentTopic ?? this.currentTopic,
    );
  }
}

// کلاس کمکی برای تشخیص عدم ارسال پارامتر
class _Sentinel {
  const _Sentinel();
}

class AudioPlayerNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();
  final _storageService = StorageService();
  StreamSubscription? _positionSubscription;
  FinalTopic? _currentTopic;

  // متغیرهای داخلی برای نگهداری نقاط A و B
  Duration? _loopStart;
  Duration? _loopEnd;

  AudioPlayerNotifier() : super(AudioState()) {
    _initStreams();
    _loadSavedLoopMode();
    _tryRecoverLastSession();
  }
  LoopMode _getNextLoopMode(LoopMode current) {
    if (current == LoopMode.off) return LoopMode.all;
    if (current == LoopMode.all) return LoopMode.one;
    return LoopMode.off;
  }

  void _saveCurrentPosition() {
    if (state.currentTopic != null && _player.position.inMilliseconds > 1000) {
      _storageService.saveLastPlayedPosition(_player.position.inMilliseconds);
    } else {
      _storageService.saveLastPlayedPosition(0);
    }
  }

  Future<void> _tryRecoverLastSession() async {
    final lastTopicId = _storageService.getLastPlayedTopicId();
    final lastPositionMs = _storageService.getLastPlayedPositionMs();

    if (lastTopicId != null &&
        lastPositionMs != null &&
        lastPositionMs > 1000) {
      // ۱. پیدا کردن mainTopic بر اساس realmId (نیاز به یک Repository دارید!)
      // این بخش نیازمند دسترسی به لیست کامل دروس است

      // ❗ فرض: شما متدی به نام findTopicById در Repository دارید
      // final mainTopic? recoveredTopic = await _topicRepository.findTopicById(lastTopicId);

      // 💡 برای سادگی فعلاً از یک ساختار فرضی استفاده می‌کنیم.
      // شما باید منطق پیدا کردن mainTopic را بر اساس RealmId در اینجا پیاده کنید.
      final FinalTopic? recoveredTopic = await _findTopicByIdStub(lastTopicId);

      if (recoveredTopic != null) {
        // ۲. لود پلی‌لیست، اما بدون شروع پخش فوری
        await _loadAndSeek(
          recoveredTopic,
          Duration(milliseconds: lastPositionMs),
        );

        // ۳. به‌روزرسانی وضعیت (isPlaying را true نمی‌گذاریم تا کاربر خودش تصمیم بگیرد)
        state = state.copyWith(
          currentTopic: recoveredTopic,
          position: Duration(milliseconds: lastPositionMs),
        );
      }
    }
  }

  Future<void> _loadAndSeek(FinalTopic topic, Duration position) async {
    if (topic.audioFilePaths.isEmpty) return;

    state = state.copyWith(currentTopic: topic, isLoading: true);

    final List<AudioSource> sources = topic.audioFilePaths
        .map((path) => AudioSource.uri(Uri.file(path)))
        .toList();
    final ConcatenatingAudioSource playlist = ConcatenatingAudioSource(
      children: sources,
    );

    try {
      await _player.setAudioSource(
        playlist,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );

      // ذخیره realmId در storage
      _storageService.saveLastPlayedTopicId(topic.realmId);

      state = state.copyWith(
        isLoading: false,
        duration: _player.duration ?? Duration.zero,
      );
    } catch (e) {
      print("Error loading audio sources: $e");
      state = state.copyWith(
        currentTopic: null,
        isLoading: false,
        isPlaying: false,
      );
    }
  }

  Future<void> loadPlaylist(FinalTopic topic) async {
    if (state.currentTopic?.realmId != topic.realmId &&
        state.currentTopic != null) {
      _saveCurrentPosition();
    }
    if (state.currentTopic?.realmId == topic.realmId) {
      if (!state.isPlaying) {
        play();
      }
      return;
    }
    if (topic.audioFilePaths.isEmpty) {
      return;
    }
    _loopStart = null;
    _loopEnd = null;
    _updateStateWithLoopPoints();
    await _loadAndSeek(topic, Duration.zero);
    _player.play();
  }

  void _startPositionSaving() {
    // ابتدا سابسکرایپشن قبلی را کنسل می‌کنیم
    _positionSubscription?.cancel();

    // ذخیره‌سازی موقعیت هر ۵ ثانیه یا بیشتر
    _positionSubscription = _player.positionStream
        .throttleTime(const Duration(seconds: 5))
        .listen((position) {
          if (_player.playing) {
            _storageService.saveLastPlayedPosition(position.inMilliseconds);
          }
        });
  }

  void _loadSavedLoopMode() {
    final savedModeString = _storageService.getLoopMode();

    if (savedModeString != null) {
      // تبدیل String به enum (با فرض اینکه toString() استفاده شده است)
      LoopMode? savedMode;
      if (savedModeString == LoopMode.off.toString()) {
        savedMode = LoopMode.off;
      } else if (savedModeString == LoopMode.one.toString()) {
        savedMode = LoopMode.one;
      } else if (savedModeString == LoopMode.all.toString()) {
        savedMode = LoopMode.all;
      }

      if (savedMode != null) {
        _player.setLoopMode(savedMode);
      }
    }
  }

  void _initStreams() {
    // گوش دادن به تغییر وضعیت پلیر و پردازش
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      // ✅ انتقال ProcessingState
      final processingState = playerState.processingState;

      state = state.copyWith(
        isPlaying: isPlaying,
        processingState: processingState, // ✅ به‌روزرسانی مدل
      );
    });
    // ✅ اضافه کردن Stream Listener برای گوش دادن به تغییر حالت تکرار
    _player.loopModeStream.listen((mode) {
      state = state.copyWith(loopMode: mode);
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

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // ۱. موقعیت را به ابتدای فایل برمی‌گردانیم (بدون reset کردن currentTopic)
        _player.seek(Duration.zero);
        _player.pause(); // متوقف کردن پخش پس از رسیدن به انتها

        // ۲. موقعیت ذخیره‌شده را نیز ریست می‌کنیم (برای اجرای بعدی)
        _storageService.saveLastPlayedPosition(0);

        // ۳. به‌روزرسانی وضعیت در State (اگر لازم بود)
        this.state = this.state.copyWith(
          position: Duration.zero,
          isPlaying: false,
        );
      }
    });
  }

  void toggleRepeatMode() {
    final nextMode = _getNextLoopMode(state.loopMode);

    _player.setLoopMode(nextMode);
    _storageService.saveLoopMode(nextMode.toString());
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

  void play() {
    _player.play();
    state = state.copyWith(isPlaying: true);
    _startPositionSaving(); // شروع ذخیره‌سازی پیوسته
  }

  void pause() {
    _player.pause();
    state = state.copyWith(isPlaying: false);
    _saveCurrentPosition(); // ذخیره موقعیت هنگام توقف
    _positionSubscription?.cancel(); // توقف ذخیره‌سازی پیوسته
  }

  void stop() {
    _saveCurrentPosition();
    _player.seek(Duration.zero); // ✅ اضافه کردن این خط
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

  void seek(Duration position) {
    _player.seek(position);
    state = state.copyWith(position: position);
    _saveCurrentPosition(); // ذخیره موقعیت هنگام Seek
  }

  void skipToItem(int index) => _player.seek(Duration.zero, index: index);

  // Getter برای دسترسی به مبحث در حال پخش در UI
  FinalTopic? get currentTopic => _currentTopic;

  @override
  void dispose() {
    _saveCurrentPosition();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<FinalTopic?> _findTopicByIdStub(String realmId) async {
    // این تابع باید در دیتابیس یا لیست دروس شما جستجو کند
    // و mainTopic مربوطه را برگرداند.
    // اگر نتوانید این کار را انجام دهید، Recovery امکان‌پذیر نخواهد بود.
    return null; // فعلاً همیشه null برمی‌گرداند
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioState>((ref) {
      return AudioPlayerNotifier();
    });

final currentPlayingTopicProvider = StateProvider<FinalTopic?>((ref) => null);
