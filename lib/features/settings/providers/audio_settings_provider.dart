import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 قانونِ AU-1 (RULES-rendering.md): وقتی کاربر یک فایلِ صوتی را باز می‌کند (دکمه‌ی
// صوتیِ داخلِ متن، انتخاب از فهرستِ پخش، یا بازشدنِ دوباره‌ی برنامه)، پخش از ابتدای
// فایل باشد یا از آخرین نقطه‌ای که شنیده شده. «قبلی/بعدی» و «پخشِ پیوسته» همیشه از
// ابتدای فایل‌اند، مستقل از این تنظیم. دکمه‌ی پخش/توقفِ پلیر هم همیشه ادامه می‌دهد.

enum AudioStartMode {
  /// از آخرین نقطه‌ی شنیده‌شده‌ی همان فایل (پیش‌فرض؛ رفتارِ قبلی).
  resume('از آخرین نقطه', 'هر فایل از جایی که آخرین بار شنیده‌اید ادامه پیدا می‌کند.'),

  /// همیشه از ابتدای فایل.
  fromStart('از ابتدا', 'هر بار که فایلی را باز می‌کنید، از ثانیه‌ی صفر پخش می‌شود.');

  const AudioStartMode(this.label, this.description);
  final String label;
  final String description;

  static AudioStartMode parse(Object? v) => AudioStartMode.values.firstWhere(
    (m) => m.name == v,
    orElse: () => AudioStartMode.resume,
  );
}

class AudioStartNotifier extends Notifier<AudioStartMode> {
  static const String storageKey = 'audio_start_mode';

  /// خواندنِ مستقیم برای پلیر (بدونِ وابستگیِ provider به provider).
  static AudioStartMode read() {
    try {
      return AudioStartMode.parse(GetStorage().read(storageKey));
    } catch (_) {
      return AudioStartMode.resume;
    }
  }

  @override
  AudioStartMode build() => read();

  void set(AudioStartMode mode) {
    state = mode;
    try {
      GetStorage().write(storageKey, mode.name);
    } catch (_) {}
  }
}

final audioStartProvider = NotifierProvider<AudioStartNotifier, AudioStartMode>(
  AudioStartNotifier.new,
);
