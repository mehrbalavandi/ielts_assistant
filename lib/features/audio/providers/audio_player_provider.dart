// lib/features/audio_player/providers/audio_player_provider.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ielts_assistant/features/settings/providers/audio_settings_provider.dart';
import 'package:ielts_assistant/features/audio/data/media_session_service.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';

part 'audio_player_provider.g.dart';

// 🌟 Enum جدید برای مدیریت رفتار پایان فایل
// 🌟 AU-5: سه حالتِ تکرارِ دامنه‌دار اضافه شد (ترتیب مهم است: اندیس در GetStorage ذخیره می‌شود،
// پس حالت‌های تازه آخر می‌آیند).
enum PlaybackMode {
  stop, // توقف بعد از اتمام
  repeatOne, // تکرار همین فایل
  autoAdvance, // رفتن به فایل بعدی (تا آخرِ کتاب، بعد توقف)
  repeatSection, // تکرارِ فایل‌های همین مهارتِ همین درس (مثلاً Listeningِ درس ۸)
  repeatUnit, // تکرارِ همه‌ی فایل‌های همین درس
  repeatBook, // تکرارِ همه‌ی فایل‌های کتاب
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
  StreamSubscription? _playerStateSub;

  // 🌟 AU-5/AU-6: فهرستِ کتاب (برای دامنه‌ی تکرار و برچسبِ درس/مهارت در اعلان)، نام و جلدِ کتاب.
  List<OutlineEntry> _outline = const [];
  String? _bookTitle;
  String? _coverPath;
  late MediaSessionCallbacks _sessionCallbacks;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();

    // 🌟 AU-6: اعلانِ رسانه و صفحه‌ی قفل (فقط اندروید؛ روی بقیه handler تهی است).
    _sessionCallbacks = MediaSessionCallbacks(
      onPlay: () {
        if (state.currentPath != null) _player.play();
      },
      onPause: () => _player.pause(),
      onNext: playNext,
      onPrevious: playPrevious,
      onStop: stopAndClear,
      onSeek: seek,
    );
    MediaSessionService.handler?.attach(_sessionCallbacks);
    _playerStateSub = _player.playerStateStream.listen((_) {
      if (ref.mounted) _syncSession();
    });

    // 🌟 خواندن حالت ذخیره شده برای رفتار پایان فایل
    final int savedModeIndex = _box.read('playback_mode') ?? 0;
    final PlaybackMode savedMode =
        savedModeIndex >= 0 && savedModeIndex < PlaybackMode.values.length
        ? PlaybackMode.values[savedModeIndex]
        : PlaybackMode.values.first;

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
        } else if (state.playbackMode == PlaybackMode.repeatSection ||
            state.playbackMode == PlaybackMode.repeatUnit ||
            state.playbackMode == PlaybackMode.repeatBook) {
          _advanceInScope(state.playbackMode); // 🌟 AU-5
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
        _syncTrack(); // AU-6: طولِ فایل در اعلان
      }
    });

    ref.onDispose(() {
      _playStateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _playerStateSub?.cancel();
      MediaSessionService.handler?.detach(_sessionCallbacks);
      MediaSessionService.clear();
      _player.dispose();
    });

    // 🌟 اینجا به جای آپدیت استیت در بالا، متغیر خوانده شده را
    // مستقیماً برای مقداردهی اولیه ریترن می‌کنیم
    return AudioPlayerState(playbackMode: savedMode);
  }

  /// 🌟 AU-5/AU-6: فهرستِ کتاب، نام و جلدش (از صفحه‌ی مطالعه، همراهِ setPlaylist).
  void setBookContext({
    required List<OutlineEntry> outline,
    String? bookTitle,
    String? coverPath,
  }) {
    _outline = outline;
    _bookTitle = bookTitle;
    _coverPath = coverPath;
  }

  /// AU-5: جای اولین دکمه‌ی [path] در فهرستِ کتاب؛ null اگر نامعلوم.
  ({int unit, int section})? _scopeOf(String path) {
    final AudioLocation? loc = state.firstOccurrence[path];
    if (loc == null || _outline.isEmpty) return null;
    final pos = outlineIndicesAt(_outline, loc.pageNumber, loc.paraIndex);
    return pos.unit < 0 ? null : pos;
  }

  /// AU-5: آیا [other] با [current] در یک دامنه‌ی تکرار است؟ (جای نامعلوم ← فقط تکرارِ کلِ کتاب
  /// معنا دارد، پس کلِ کتاب.)
  bool _sameScope(PlaybackMode mode, String current, String other) {
    if (mode == PlaybackMode.repeatBook) return true;
    final a = _scopeOf(current);
    final b = _scopeOf(other);
    if (a == null || b == null) return true;
    if (mode == PlaybackMode.repeatUnit) return a.unit == b.unit;
    return a.unit == b.unit && a.section == b.section;
  }

  /// AU-5: بعد از پایانِ فایل در حالت‌های تکرارِ دامنه‌دار: فایلِ بعدیِ همان دامنه به ترتیبِ کتاب،
  /// و بعد از آخری دوباره اولی. اگر دامنه فقط همین فایل است، همین فایل دوباره.
  void _advanceInScope(PlaybackMode mode) {
    final String? current = state.currentPath;
    final List<String> list = state.playlist;
    if (current == null) return;
    final int cur = list.indexOf(current);
    final List<int> scope = [
      for (int i = 0; i < list.length; i++)
        if (_sameScope(mode, current, list[i])) i,
    ];
    if (cur < 0 || scope.length <= 1) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    final int next = scope.firstWhere((i) => i > cur, orElse: () => scope.first);
    playFile(list[next], seekToMs: 0);
  }

  /// AU-6: برچسبِ درس و مهارتِ [path] («درس 8: Natural World · Listening»).
  String? trackLocationLabel(String path) {
    final AudioLocation? loc = state.firstOccurrence[path];
    if (loc == null || _outline.isEmpty) return null;
    return outlineLocationLabel(_outline, loc.pageNumber, loc.paraIndex);
  }

  /// AU-6: فایلِ فعلی در اعلانِ رسانه.
  void _syncTrack() {
    if (MediaSessionService.handler == null) return;
    final String? path = state.currentPath;
    if (path == null) return;
    String name = path.split('/').last.split(r'\').last;
    final int dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    final String? cover = _coverPath;
    MediaSessionService.setTrack(
      id: path,
      title: name,
      subtitle: trackLocationLabel(path),
      album: _bookTitle,
      duration: _player.duration,
      artUri: cover == null ? null : Uri.file(cover),
    );
  }

  /// AU-6: وضعیتِ پخش در اعلان (با هر پخش/مکث/پرش/تغییرِ وضعیتِ بارگذاری).
  void _syncSession() {
    if (MediaSessionService.handler == null) return;
    if (state.currentPath == null) {
      MediaSessionService.clear();
      return;
    }
    final ProcessingState ps = _player.processingState;
    MediaSessionService.setPlayback(
      playing: _player.playing,
      position: _player.position,
      speed: _player.speed,
      loading: ps == ProcessingState.loading || ps == ProcessingState.buffering,
      completed: ps == ProcessingState.completed,
    );
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
    // 🐞 اگر false باشد، فایل لود و به موقعیتِ موردنظر seek می‌شود ولی
    // پخش شروع نمی‌شود (و اگر همین الان چیزِ دیگری در حالِ پخش بود،
    // pause می‌شود) — برای «فقط بردنِ پلیر به این نقطه» به‌جای «پخشِ
    // فوری» (مثلاً وقتی از یک نتیجه‌ی جستجو می‌آییم).
    bool autoPlay = true,
    // 🐞 اگر داده شود، به‌جای ادامه از آخرین موقعیتِ ذخیره‌شده‌ی این فایل،
    // دقیقاً به همین میلی‌ثانیه seek می‌شود.
    int? seekToMs,
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
        if (seekToMs != null) {
          await _player.seek(Duration(milliseconds: seekToMs));
        }
        if (autoPlay) {
          _player.play();
        } else {
          _player.pause();
        }
        return;
      }
      await _player.stop();

      // 🌟 AU-1: فایلی که تازه باز می‌شود، طبقِ تنظیمات از آخرین نقطه یا از ابتدا.
      // (همان فایلی که الان در پلیر است بالاتر برگشت داده شد: توقف/پخشِ دوباره‌اش
      // همیشه ادامه می‌دهد. قبلی/بعدی هم seekToMs: 0 می‌فرستند.)
      final int lastPosMs =
          seekToMs ??
          (AudioStartNotifier.read() == AudioStartMode.resume
              ? (_box.read('pos_$path') ?? 0)
              : 0);
      // 🌟 S-10: آخرین فایلی که باز شد — پلی‌لیست بعد از بستن/بازکردنِ برنامه هم
      // روی همین فایل باز می‌شود.
      _box.write(_lastAudioKey, path);

      state = state.copyWith(
        currentPath: path,
        pointA: () => null,
        pointB: () => null,
        position: Duration(milliseconds: lastPosMs),
        lastSource: resolvedSource,
        targetLocation: () => resolvedTarget,
      );
      _syncTrack(); // AU-6

      if (path.startsWith('assets/')) {
        await _player.setAsset(path);
      } else {
        final uri = Uri.file(path).toString();
        debugPrint(uri);
        await _player.setUrl(uri);
        // await _player.setFilePath(path);
      }

      await _player.seek(Duration(milliseconds: lastPosMs));
      if (autoPlay) {
        _player.play();
      } else {
        // 🐞 حتی اگر قبل از این فایلِ دیگری در حالِ پخش بود، await
        // _player.stop() بالاتر آن را از قبل متوقف کرده؛ این pause فقط
        // برای اطمینان است که پخشِ این فایلِ تازه‌لودشده هم خودکار شروع
        // نشود.
        _player.pause();
      }
    } catch (e) {
      debugPrint("خطا در پخش فایل: $e");
    }
  }

  static const String _lastAudioKey = 'last_audio_path';

  /// 🌟 S-10: آخرین فایلی که پخش یا باز شد (حتی از اجرای قبلیِ برنامه)؛ null اگر
  /// هنوز هیچ.
  String? get lastPlayedPath {
    try {
      final v = _box.read(_lastAudioKey);
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }

  // 🌟 متدهای بعدی و قبلی
  void playNext() {
    if (state.playlist.isEmpty || state.currentPath == null) return;
    int currentIndex = state.playlist.indexOf(state.currentPath!);
    if (currentIndex != -1 && currentIndex < state.playlist.length - 1) {
      // 🐞 از طریقِ دکمه‌ی بعدی → sequential (explicitLocation پاس داده
      // نمی‌شود، پس playFile خودش از firstOccurrence استفاده می‌کند)
      // 🐞 فایلِ بعدی همیشه از اول پخش می‌شود (seekToMs: 0)، نه از آخرین
      // موقعیتِ ذخیره‌شده‌اش — همین برای «پخشِ پیوسته» هم که از همین متد
      // می‌گذرد درست است.
      playFile(state.playlist[currentIndex + 1], seekToMs: 0);
    } else if (state.playbackMode == PlaybackMode.repeatBook &&
        state.playlist.isNotEmpty) {
      // 🌟 AU-5: تکرارِ کلِ کتاب ← بعد از آخرین فایل، اولی.
      playFile(state.playlist.first, seekToMs: 0);
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
      // 🐞 فایلِ قبلی هم از اول، نه از موقعیتِ ذخیره‌شده.
      playFile(state.playlist[currentIndex - 1], seekToMs: 0);
    } else if (currentIndex == 0) {
      _player.seek(Duration.zero); // اگر فایل اول بود، از اول پخشش کن
    }
  }

  /// 🌟 AU-5: انتخابِ رفتارِ پایانِ فایل (منوی دکمه‌ی تکرار).
  void setPlaybackMode(PlaybackMode mode) {
    state = state.copyWith(playbackMode: mode);
    _box.write('playback_mode', mode.index); // ذخیره در حافظه
  }

  // 🌟 تغییر حالت رفتار پایان فایل، چرخشی میانِ همه‌ی حالت‌ها
  void togglePlaybackMode() {
    final List<PlaybackMode> all = PlaybackMode.values;
    setPlaybackMode(all[(all.indexOf(state.playbackMode) + 1) % all.length]);
  }

  /// 🌟 SET-1: «تنظیماتِ پیش‌فرض» — رفتارِ پایانِ فایل به حالتِ اول برمی‌گردد.
  void resetPlaybackMode() {
    _box.remove('playback_mode');
    state = state.copyWith(playbackMode: PlaybackMode.values.first);
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
      firstOccurrence: state.firstOccurrence,
    );
    MediaSessionService.clear(); // AU-6: اعلان هم می‌رود
  }

  bool isPlaying() => _player.playing;
  void pause() => _player.pause();
  void resume() => _player.play();
  void seek(Duration position) {
    _player.seek(position).then((_) {
      if (ref.mounted) _syncSession(); // AU-6
    });
  }

  void skip10Sec(bool forward) {
    final target = forward
        ? state.position + const Duration(seconds: 10)
        : state.position - const Duration(seconds: 10);
    _player.seek(target).then((_) {
      if (ref.mounted) _syncSession(); // AU-6
    });
  }

  void setSpeed(double newSpeed) {
    _player.setSpeed(newSpeed).then((_) {
      if (ref.mounted) _syncSession(); // AU-6
    });
    state = state.copyWith(speed: newSpeed);
  }
}
