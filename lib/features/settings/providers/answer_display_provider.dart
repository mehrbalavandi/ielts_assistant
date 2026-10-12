import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 قانونِ H-5 تا H-7 (RULES-rendering.md): کاربر خودش انتخاب می‌کند جوابِ
// پنهانِ پشتِ آیکونِ چشم کجا نشان داده شود — جدا برای جواب‌های کوتاه و بلند.

/// سه شیوه‌ی نمایشِ جواب.
enum AnswerDisplayMode {
  /// حبابِ کوچک کنارِ همان آیکونِ چشم (مثلِ دولینگو)؛ صفحه قفل نمی‌شود.
  popup,

  /// کارتِ کشویی از بالای صفحه.
  banner,

  /// برگه‌ی پایینِ صفحه (bottom sheet)، قابلِ کشیدن.
  modal;

  String get label => switch (this) {
    AnswerDisplayMode.popup => 'پاپ‌آپ',
    AnswerDisplayMode.banner => 'بنر',
    AnswerDisplayMode.modal => 'مودال',
  };

  IconData get icon => switch (this) {
    AnswerDisplayMode.popup => Icons.chat_bubble_outline_rounded,
    AnswerDisplayMode.banner => Icons.vertical_align_top_rounded,
    AnswerDisplayMode.modal => Icons.vertical_align_bottom_rounded,
  };

  String get description => switch (this) {
    AnswerDisplayMode.popup =>
      'حبابی کنارِ همان آیکون باز می‌شود و متن را نمی‌پوشاند؛ با لمسِ بیرون یا لمسِ دوباره‌ی آیکون بسته می‌شود.',
    AnswerDisplayMode.banner =>
      'کارتی از بالای صفحه پایین می‌آید؛ با لمسِ بیرون بسته می‌شود.',
    AnswerDisplayMode.modal =>
      'برگه‌ای از پایینِ صفحه بالا می‌آید و با کشیدن بزرگ‌تر می‌شود؛ مناسبِ جواب‌های طولانی.',
  };

  static AnswerDisplayMode parse(String? name, AnswerDisplayMode fallback) {
    for (final m in AnswerDisplayMode.values) {
      if (m.name == name) return m;
    }
    return fallback;
  }
}

@immutable
class AnswerDisplaySettings {
  /// جوابِ کوتاه: متنِ ساده‌ی کمتر از ۴۰ نویسه، بدونِ لغتِ دیکشنری (H-5).
  final AnswerDisplayMode short;

  /// جوابِ بلند: بقیه، از جمله جواب‌های جدول/عکس‌دار.
  final AnswerDisplayMode long;

  const AnswerDisplaySettings({required this.short, required this.long});

  AnswerDisplayMode modeFor({required bool isShort}) => isShort ? short : long;
}

class AnswerDisplayNotifier extends Notifier<AnswerDisplaySettings> {
  static const String _shortKey = 'answer_display_short';
  static const String _longKey = 'answer_display_long';

  /// پیش‌فرض: کوتاه ← پاپ‌آپ (نزدیک‌ترین جا به خودِ سؤال)، بلند ← مودال (جا برای
  /// متنِ طولانی و جدول).
  static const AnswerDisplayMode defaultShort = AnswerDisplayMode.popup;
  static const AnswerDisplayMode defaultLong = AnswerDisplayMode.modal;

  final GetStorage _box = GetStorage();

  @override
  AnswerDisplaySettings build() => AnswerDisplaySettings(
    short: AnswerDisplayMode.parse(_box.read(_shortKey), defaultShort),
    long: AnswerDisplayMode.parse(_box.read(_longKey), defaultLong),
  );

  void setShort(AnswerDisplayMode mode) {
    state = AnswerDisplaySettings(short: mode, long: state.long);
    _box.write(_shortKey, mode.name);
  }

  void setLong(AnswerDisplayMode mode) {
    state = AnswerDisplaySettings(short: state.short, long: mode);
    _box.write(_longKey, mode.name);
  }
}

final answerDisplayProvider =
    NotifierProvider<AnswerDisplayNotifier, AnswerDisplaySettings>(
      AnswerDisplayNotifier.new,
    );
