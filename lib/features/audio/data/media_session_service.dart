import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

// 🌟 AU-6 (RULES-rendering.md): کنترلِ پخش از بیرونِ برنامه — اعلانِ رسانه، صفحه‌ی قفل، دکمه‌های
// هدفون/بلوتوث (مثلِ Musicolet).
//
// پخشِ واقعی همچنان در AudioPlayerNotifier (just_audio) است؛ این‌جا فقط «جلسه‌ی رسانه»ی
// اندروید است: notifier حالت را این‌جا می‌فرستد (فایلِ فعلی، پخش/مکث، موقعیت) و دکمه‌های اعلان
// را از این‌جا می‌گیرد (پخش، مکث، قبلی، بعدی، بستن، جابه‌جاییِ نوارِ پیشرفت).
//
// فقط اندروید: audio_service روی ویندوز پیاده‌سازی ندارد (ویندوز کنترل‌های رسانه‌ای سیستم را
// جدا دارد و فعلاً لازم نیست).

/// دکمه‌هایی که اعلان به پلیر برمی‌گرداند.
class MediaSessionCallbacks {
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onStop;
  final void Function(Duration position) onSeek;

  const MediaSessionCallbacks({
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.onStop,
    required this.onSeek,
  });
}

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  MediaSessionCallbacks? _callbacks;

  void attach(MediaSessionCallbacks callbacks) => _callbacks = callbacks;

  void detach(MediaSessionCallbacks callbacks) {
    if (identical(_callbacks, callbacks)) _callbacks = null;
  }

  @override
  Future<void> play() async => _callbacks?.onPlay();

  @override
  Future<void> pause() async => _callbacks?.onPause();

  @override
  Future<void> skipToNext() async => _callbacks?.onNext();

  @override
  Future<void> skipToPrevious() async => _callbacks?.onPrevious();

  @override
  Future<void> stop() async {
    _callbacks?.onStop();
    clear();
  }

  @override
  Future<void> seek(Duration position) async => _callbacks?.onSeek(position);

  /// اعلان برداشته می‌شود (پلیر بسته شد).
  void clear() {
    mediaItem.add(null);
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
  }
}

class MediaSessionService {
  MediaSessionService._();

  static AppAudioHandler? _handler;

  /// null روی سکوهایی که پشتیبانی نمی‌شوند یا اگر راه‌اندازی شکست خورد.
  static AppAudioHandler? get handler => _handler;

  /// پیش از runApp (main.dart). خطا پخش را از کار نمی‌اندازد؛ فقط اعلان نخواهد بود.
  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _handler = await AudioService.init(
        builder: AppAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'ielts_assistant.audio',
          androidNotificationChannelName: 'پخشِ فایل‌های صوتی',
          androidNotificationChannelDescription:
              'کنترلِ پخشِ فایل‌های صوتیِ کتاب از اعلان و صفحه‌ی قفل',
          androidNotificationIcon: 'mipmap/launcher_icon',
          // مکث ← اعلان می‌ماند ولی با کشیدن کنار می‌رود (مثلِ Musicolet).
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      debugPrint('MediaSessionService.init: $e');
      _handler = null;
    }
  }

  /// فایلِ فعلی برای اعلان: عنوان = نامِ فایل، زیرعنوان = درس و مهارت، آلبوم = کتاب.
  static void setTrack({
    required String id,
    required String title,
    String? subtitle,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) {
    _handler?.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: subtitle,
        album: album,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  /// وضعیتِ پخش برای اعلان و صفحه‌ی قفل. موقعیت را سیستم با [speed] جلو می‌برد؛ لازم نیست هر
  /// لحظه فرستاده شود (فقط با پخش/مکث/پرش/تغییرِ فایل).
  static void setPlayback({
    required bool playing,
    required Duration position,
    required double speed,
    bool loading = false,
    bool completed = false,
  }) {
    final AppAudioHandler? h = _handler;
    if (h == null) return;
    h.playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: loading
            ? AudioProcessingState.loading
            : completed
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        speed: speed,
      ),
    );
  }

  static void clear() => _handler?.clear();
}
