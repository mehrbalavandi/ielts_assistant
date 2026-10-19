import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 RM-1: شیوه‌ی نمایشِ کتاب — «مطابقِ کتاب» (همان Word، پیش‌فرض) یا «خوانا» (متنِ
// درشت‌تر و یکدست، فاصله‌ی خطِ راحت، جدول‌های عریض روی گوشی زیرِ هم). اندازه‌ی متن فقط
// در حالتِ خوانا اعمال می‌شود؛ حالتِ کتاب چیدمانِ سند را دقیق نگه می‌دارد.

enum ReadingMode {
  book('مطابقِ کتاب'),
  readable('خوانا');

  const ReadingMode(this.label);
  final String label;

  static ReadingMode parse(Object? v) => ReadingMode.values.firstWhere(
    (m) => m.name == v,
    orElse: () => ReadingMode.book,
  );
}

@immutable
class ReadingAppearance {
  final ReadingMode mode;

  /// ضریبِ اندازه‌ی متن در حالتِ خوانا (۰٫۸۵ تا ۱٫۵).
  final double fontScale;

  const ReadingAppearance({
    this.mode = ReadingMode.book,
    this.fontScale = 1.0,
  });

  bool get readable => mode == ReadingMode.readable;

  ReadingAppearance copyWith({ReadingMode? mode, double? fontScale}) =>
      ReadingAppearance(
        mode: mode ?? this.mode,
        fontScale: fontScale ?? this.fontScale,
      );

  @override
  bool operator ==(Object other) =>
      other is ReadingAppearance &&
      other.mode == mode &&
      other.fontScale == fontScale;

  @override
  int get hashCode => Object.hash(mode, fontScale);
}

class ReadingAppearanceNotifier extends Notifier<ReadingAppearance> {
  static const String modeKey = 'reading_mode';
  static const String scaleKey = 'reading_font_scale';
  static const double minScale = 0.85;
  static const double maxScale = 1.5;

  final GetStorage _box = GetStorage();

  @override
  ReadingAppearance build() {
    double scale = 1.0;
    try {
      scale = ((_box.read(scaleKey) as num?)?.toDouble() ?? 1.0)
          .clamp(minScale, maxScale)
          .toDouble();
    } catch (_) {}
    return ReadingAppearance(
      mode: ReadingMode.parse(_box.read(modeKey)),
      fontScale: scale,
    );
  }

  void setMode(ReadingMode mode) {
    state = state.copyWith(mode: mode);
    _box.write(modeKey, mode.name);
  }

  /// 🌟 SET-1: «تنظیماتِ پیش‌فرض».
  void reset() {
    _box.remove(modeKey);
    _box.remove(scaleKey);
    state = const ReadingAppearance();
  }

  void setFontScale(double scale) {
    final double s = (scale.clamp(minScale, maxScale) * 20).round() / 20;
    if (s == state.fontScale) return;
    state = state.copyWith(fontScale: s);
    _box.write(scaleKey, s);
  }
}

final readingAppearanceProvider =
    NotifierProvider<ReadingAppearanceNotifier, ReadingAppearance>(
      ReadingAppearanceNotifier.new,
    );
