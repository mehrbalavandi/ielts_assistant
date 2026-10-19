import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 AS-3: اندازه‌ی متنِ صفحه‌ی اسکریپتِ صوتی، جدا از تنظیمِ «خوانا»ی کتاب. با دکمه‌های
// A−/A+ بالای همان صفحه عوض می‌شود و روی دستگاه می‌ماند.

/// اندازه‌ی متنِ عادیِ اسکریپت (px) با ضریبِ ۱.
const double kAudioScriptBodyPx = 17.0;

class AudioScriptTextScaleNotifier extends Notifier<double> {
  static const String key = 'audio_script_font_scale';
  static const double minScale = 0.8;
  static const double maxScale = 1.8;
  static const double step = 0.1;

  final GetStorage _box = GetStorage();

  @override
  double build() {
    try {
      return ((_box.read(key) as num?)?.toDouble() ?? 1.0)
          .clamp(minScale, maxScale)
          .toDouble();
    } catch (_) {
      return 1.0;
    }
  }

  bool get canDecrease => state > minScale + 0.001;
  bool get canIncrease => state < maxScale - 0.001;

  void decrease() => _set(state - step);
  void increase() => _set(state + step);

  void _set(double v) {
    final double s = (v.clamp(minScale, maxScale) * 10).round() / 10;
    if (s == state) return;
    state = s;
    _box.write(key, s);
  }
}

final audioScriptTextScaleProvider =
    NotifierProvider<AudioScriptTextScaleNotifier, double>(
      AudioScriptTextScaleNotifier.new,
    );
