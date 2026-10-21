import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ielts_assistant/features/audio/domain/audio_skill.dart';
import 'package:path_provider/path_provider.dart';

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

  // ───────── 🌟 AU-9: تصویرِ اعلان به رنگِ مهارت ─────────

  static final Map<AudioSkill, Uri> _skillArt = {};
  static final Map<AudioSkill, Future<Uri?>> _skillArtPending = {};

  static Uri? cachedSkillArtwork(AudioSkill skill) => _skillArt[skill];

  /// تصویرِ ۵۱۲×۵۱۲ با زمینه‌ی رنگِ مهارت، آیکونش و نامش (یک‌بار برای هر مهارت، در پوشه‌ی موقت).
  /// اندروید رنگِ پس‌زمینه‌ی پلیرِ اعلان و صفحه‌ی قفل را از همین تصویر برمی‌دارد.
  static Future<Uri?> skillArtwork(AudioSkill skill) {
    if (_handler == null) return Future.value(null);
    final Uri? done = _skillArt[skill];
    if (done != null) return Future.value(done);
    return _skillArtPending[skill] ??= _drawSkillArtwork(skill).then((Uri? u) {
      _skillArtPending.remove(skill);
      if (u != null) _skillArt[skill] = u;
      return u;
    });
  }

  static Future<Uri?> _drawSkillArtwork(AudioSkill skill) async {
    try {
      const double size = 512;
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas canvas = Canvas(rec);
      final Color deep = audioSkillDeepColor(skill);
      final Color light = audioSkillColor(skill) ?? deep;
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(size, size),
            [Color.lerp(light, deep, 0.35)!, deep],
          ),
      );
      final IconData icon = audioSkillIcon(skill);
      final TextPainter iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 220,
            color: const Color(0xF2FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset((size - iconPainter.width) / 2, 92),
      );
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: audioSkillName(skill).toUpperCase(),
          style: const TextStyle(
            fontSize: 54,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: Color(0xE6FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size - 40);
      label.paint(canvas, Offset((size - label.width) / 2, 352));
      iconPainter.dispose();
      label.dispose();

      final ui.Image img = await rec.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (png == null) return null;
      final dir = await getTemporaryDirectory();
      final File f = File('${dir.path}/media_art_${skill.name}_v1.png');
      await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return Uri.file(f.path);
    } catch (e) {
      debugPrint('MediaSessionService.skillArtwork: $e');
      return null;
    }
  }
}
