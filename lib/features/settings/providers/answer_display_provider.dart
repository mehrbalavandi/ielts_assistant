import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 قانونِ H-5 تا H-9 (RULES-rendering.md): کاربر خودش انتخاب می‌کند جوابِ
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

/// H-8: جهتِ بازشدنِ پاپ‌آپ نسبت به آیکونِ چشم.
enum AnswerPopupDirection {
  /// هر طرف که جای بیشتری دارد (اول پایین).
  auto,

  /// بالای آیکون؛ فقط اگر آن‌جا واقعاً جا نباشد، پایین.
  above,

  /// پایینِ آیکون؛ فقط اگر آن‌جا واقعاً جا نباشد، بالا.
  below;

  String get label => switch (this) {
    AnswerPopupDirection.auto => 'خودکار',
    AnswerPopupDirection.above => 'بالا',
    AnswerPopupDirection.below => 'پایین',
  };

  IconData get icon => switch (this) {
    AnswerPopupDirection.auto => Icons.unfold_more_rounded,
    AnswerPopupDirection.above => Icons.north_rounded,
    AnswerPopupDirection.below => Icons.south_rounded,
  };

  static AnswerPopupDirection parse(String? name) {
    for (final d in AnswerPopupDirection.values) {
      if (d.name == name) return d;
    }
    return AnswerPopupDirection.auto;
  }
}

@immutable
class AnswerDisplaySettings {
  /// جوابِ کوتاه: متنِ ساده‌ی کمتر از ۴۰ نویسه، بدونِ لغتِ دیکشنری (H-5).
  final AnswerDisplayMode short;

  /// جوابِ بلند: بقیه، از جمله جواب‌های جدول/عکس‌دار.
  final AnswerDisplayMode long;

  /// H-8: جهتِ پاپ‌آپ.
  final AnswerPopupDirection popupDirection;

  /// H-9: true = بازکردنِ پاسخِ تازه پاپ‌آپِ قبلی را می‌بندد (پیش‌فرض)؛ false =
  /// چند پاپ‌آپ هم‌زمان باز می‌مانند و دکمه‌ی «بستنِ همه» ظاهر می‌شود.
  final bool singlePopup;

  const AnswerDisplaySettings({
    required this.short,
    required this.long,
    this.popupDirection = AnswerPopupDirection.auto,
    this.singlePopup = true,
  });

  AnswerDisplaySettings copyWith({
    AnswerDisplayMode? short,
    AnswerDisplayMode? long,
    AnswerPopupDirection? popupDirection,
    bool? singlePopup,
  }) => AnswerDisplaySettings(
    short: short ?? this.short,
    long: long ?? this.long,
    popupDirection: popupDirection ?? this.popupDirection,
    singlePopup: singlePopup ?? this.singlePopup,
  );

  AnswerDisplayMode modeFor({required bool isShort}) => isShort ? short : long;
}

class AnswerDisplayNotifier extends Notifier<AnswerDisplaySettings> {
  static const String _shortKey = 'answer_display_short';
  static const String _longKey = 'answer_display_long';
  static const String _directionKey = 'answer_popup_direction';
  static const String _singleKey = 'answer_popup_single';

  /// پیش‌فرض: کوتاه ← پاپ‌آپ (نزدیک‌ترین جا به خودِ سؤال)، بلند ← مودال (جا برای
  /// متنِ طولانی و جدول).
  static const AnswerDisplayMode defaultShort = AnswerDisplayMode.popup;
  static const AnswerDisplayMode defaultLong = AnswerDisplayMode.modal;

  final GetStorage _box = GetStorage();

  @override
  AnswerDisplaySettings build() => AnswerDisplaySettings(
    short: AnswerDisplayMode.parse(_box.read(_shortKey), defaultShort),
    long: AnswerDisplayMode.parse(_box.read(_longKey), defaultLong),
    popupDirection: AnswerPopupDirection.parse(_box.read(_directionKey)),
    singlePopup: _box.read<bool>(_singleKey) ?? true,
  );

  void setShort(AnswerDisplayMode mode) {
    state = state.copyWith(short: mode);
    _box.write(_shortKey, mode.name);
  }

  void setLong(AnswerDisplayMode mode) {
    state = state.copyWith(long: mode);
    _box.write(_longKey, mode.name);
  }

  void setPopupDirection(AnswerPopupDirection direction) {
    state = state.copyWith(popupDirection: direction);
    _box.write(_directionKey, direction.name);
  }

  void setSinglePopup(bool single) {
    state = state.copyWith(singlePopup: single);
    _box.write(_singleKey, single);
  }
}

final answerDisplayProvider =
    NotifierProvider<AnswerDisplayNotifier, AnswerDisplaySettings>(
      AnswerDisplayNotifier.new,
    );
