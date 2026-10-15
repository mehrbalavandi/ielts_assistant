import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/answer_display.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';

// 🌟 قانون‌های TR-1 تا TR-4 (RULES-rendering.md): ترجمه‌ی پاراگراف با لمسِ طولانی.
//
// - **روی صفحه (TR-1):** ترجمه در ظرفی که کاربر در تنظیمات انتخاب کرده باز می‌شود —
//   پاپ‌آپ (پیش‌فرض)، بنر یا مودال — نه با بازشدنِ متن زیرِ پاراگراف (که بقیه‌ی صفحه را
//   پایین می‌راند).
// - **هایلایتِ مبدأ (TR-3):** تا ترجمه باز است، خودِ پاراگراف زمینه‌ی رنگی و نوارِ
//   کناری می‌گیرد، هم‌رنگِ خطِ دورِ حباب، تا معلوم باشد ترجمه مالِ کدام پاراگراف است.
//   در بنر و مودال اگر پاراگراف زیرِ ظرف بماند، صفحه کمی جابه‌جا می‌شود.
// - **داخلِ ظرفِ پاسخ (TR-2):** ظرف روی ظرف باز نمی‌شود؛ ترجمه همان‌جا زیرِ متن
//   باز و بسته می‌شود (با لمسِ طولانی یا دکمه‌ی کوچکِ ترجمه).
// - **مرورِ من (ST-4):** همان ظرفِ لمسِ طولانی نوارِ «افزودن به مرور» (اهمیت،
//   یادداشت) را هم دارد؛ پس پاراگرافِ بی‌ترجمه هم لمسِ طولانی دارد. پاراگرافِ
//   ذخیره‌شده نوارِ باریکی به رنگِ اهمیتش در سمتِ راست می‌گیرد.

/// رنگِ هایلایت/خطِ دورِ ترجمه (همان رنگ‌های قبلیِ کادرِ ترجمه).
Color translationAccent(bool isDark) =>
    isDark ? Colors.orangeAccent : Colors.blueAccent;

/// TR-2: دکمه‌ی کوچکِ «ترجمه» داخلِ ظرفِ پاسخ کجا باشد.
enum TranslationToggle {
  /// بدونِ دکمه؛ فقط لمسِ طولانی (پاراگراف‌های داخلِ جوابِ غنی).
  none,

  /// کنارِ متن (جوابِ متنی؛ عرضِ حباب برایش جا دارد).
  side,

  /// زیرِ محتوا (جوابِ جدول/عکس‌دار، که عرضش را لازم دارد).
  below,
}

class TranslatableContentWrapper extends ConsumerStatefulWidget {
  final Widget originalContent;
  final String? translationFa;
  final String? translationAr;
  final bool isDarkMode;

  /// فقط داخلِ ظرفِ پاسخ معنا دارد (TR-2).
  final TranslationToggle toggle;

  /// ST-4: این پاراگرافِ صفحه را می‌شود به مرور افزود (null داخلِ ظرف‌ها،
  /// اسکریپتِ صوتی و پاراگراف‌های بی‌متن).
  final StudyPassageRef? study;

  const TranslatableContentWrapper({
    super.key,
    required this.originalContent,
    this.translationFa,
    this.translationAr,
    this.isDarkMode = false,
    this.toggle = TranslationToggle.none,
    this.study,
  });

  /// آیا برای این دو ترجمه چیزی برای نمایش هست؟
  static bool hasAny(String? fa, String? ar) =>
      (fa != null && fa.trim().isNotEmpty) ||
      (ar != null && ar.trim().isNotEmpty);

  @override
  ConsumerState<TranslatableContentWrapper> createState() =>
      _TranslatableContentWrapperState();
}

class _TranslatableContentWrapperState
    extends ConsumerState<TranslatableContentWrapper> {
  /// ترجمه در بنر/مودال باز است (پاپ‌آپ وضعیتِ خودش را دارد).
  bool _sheetOpen = false;

  /// ترجمه‌ی درجا، داخلِ ظرفِ پاسخ (TR-2).
  bool _inlineOpen = false;

  /// دوزبانه: ترجمه‌ی زبانِ انتخابی؛ اگر خالی بود، زبانِ دیگر تا خالی نماند.
  String _translation() {
    final bool preferAr = ref.watch(languageProvider) == 'ar';
    final String? primary = preferAr
        ? widget.translationAr
        : widget.translationFa;
    final String? secondary = preferAr
        ? widget.translationFa
        : widget.translationAr;
    return (primary?.trim().isNotEmpty ?? false) ? primary! : (secondary ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTranslation = TranslatableContentWrapper.hasAny(
      widget.translationFa,
      widget.translationAr,
    );
    final bool inside = AnswerContainerScope.isInside(context);
    final StudyPassageRef? study = inside ? null : widget.study;
    if (!hasTranslation && study == null) return widget.originalContent;

    final String translation = hasTranslation ? _translation() : '';
    final Color accent = translationAccent(widget.isDarkMode);

    if (inside) return _buildInline(translation, accent);

    // ST-4: پاراگرافِ ذخیره‌شده — نوارِ رنگِ اهمیت در سمتِ راست.
    final String? studyId = study?.id;
    final StudyImportance? saved = studyId == null
        ? null
        : ref.watch(studyProvider.select((m) => m[studyId]?.importance));

    // TR-1: روی صفحه — لنگرِ پاپ‌آپ همان پاراگراف است.
    return AnswerPopupAnchor(
      builder: (anchorContext, popup) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (d) =>
              _present(popup, d.localPosition, translation, accent),
          child: Directionality(
            textDirection: TextDirection.ltr,
            // همان Column(stretch)ِ نسخه‌ی قبلی، تا قیدهای عرضِ پاراگراف عوض نشود.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SourceHighlight(
                  active: popup.isOpen || _sheetOpen,
                  color: accent,
                  savedColor: saved?.color,
                  child: widget.originalContent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// بدنه‌ی ظرفِ لمسِ طولانی: ترجمه (اگر هست) و نوارِ «مرورِ من» (اگر این پاراگراف
  /// قابلِ ذخیره است). [card]: بنر/مودال (کادرِ ترجمه)؛ وگرنه پاپ‌آپ (متنِ ساده).
  Widget _body(String translation, Color accent, {required bool card}) {
    final bool isDark = widget.isDarkMode;
    final StudyPassageRef? study = widget.study;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (translation.isNotEmpty)
            card
                ? _TranslationCard(
                    text: translation,
                    isDark: isDark,
                    accent: accent,
                  )
                : _TranslationText(text: translation, isDark: isDark),
          if (study != null) ...[
            if (translation.isNotEmpty)
              card
                  ? const SizedBox(height: 8)
                  : Divider(
                      height: 14,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
            PassageStudyBar(
              passage: study,
              translationFa: widget.translationFa,
              translationAr: widget.translationAr,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // ───────── روی صفحه: پاپ‌آپ / بنر / مودال ─────────

  void _present(
    AnswerPopupHandle popup,
    Offset localPosition,
    String translation,
    Color accent,
  ) {
    final AnswerDisplaySettings settings = ref.read(answerDisplayProvider);
    final bool isDark = widget.isDarkMode;

    switch (settings.translation) {
      case AnswerDisplayMode.popup:
        final RenderObject? ro = context.findRenderObject();
        final Size size = ro is RenderBox && ro.hasSize ? ro.size : Size.zero;
        final double x = localPosition.dx.clamp(0.0, size.width);
        // اول کلِ پاراگراف (حباب زیر/بالای آن و پاراگراف دیده می‌ماند)؛ اگر پاراگراف
        // آن‌قدر بلند است که جایی نمی‌ماند، همان خطی که لمس شد.
        final List<Rect> rects = [
          Rect.fromLTRB(x - 1, 0, x + 1, size.height),
          Rect.fromLTRB(
            x - 1,
            math.max(0, localPosition.dy - 14),
            x + 1,
            math.min(size.height, localPosition.dy + 14),
          ),
        ];
        popup.toggle(
          body: (_) => _body(translation, accent, card: false),
          isDarkTheme: isDark,
          direction: settings.popupDirection,
          single: settings.singlePopup,
          anchorRects: rects,
          anchorTapToggles: false,
          accentColor: accent,
        );
      case AnswerDisplayMode.banner:
        if (_sheetOpen) return;
        setState(() => _sheetOpen = true);
        showAnswerBanner(
          context,
          isDarkTheme: isDark,
          closePopups: settings.singlePopup,
          barrierColor: Colors.black12,
          body: (_) => _body(translation, accent, card: true),
          onCardBottom: _revealBelowBanner,
        ).whenComplete(_onSheetClosed);
      case AnswerDisplayMode.modal:
        if (_sheetOpen) return;
        setState(() => _sheetOpen = true);
        const double sheetSize = 0.3;
        showAnswerSheet(
          context,
          isDarkTheme: isDark,
          closePopups: settings.singlePopup,
          initialSize: sheetSize,
          barrierColor: Colors.black12,
          body: (_) => _body(translation, accent, card: true),
        ).whenComplete(_onSheetClosed);
        final double screenH = MediaQuery.sizeOf(context).height;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revealAboveSheet(screenH * (1 - sheetSize));
        });
    }
  }

  void _onSheetClosed() {
    if (mounted) setState(() => _sheetOpen = false);
  }

  /// TR-3: اگر بالای پاراگراف زیرِ بنر مانده، آن‌قدر اسکرول کن که زیرِ بنر بیاید.
  void _revealBelowBanner(double bannerBottom) {
    if (!mounted) return;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final double top = ro.localToGlobal(Offset.zero).dy;
    if (top >= bannerBottom + 8) return;
    final double viewportTop = _viewportRect()?.top ?? 0;
    final double extra = math.max(0, bannerBottom - viewportTop + 8);
    ro.showOnScreen(
      rect: Rect.fromLTRB(0, -extra, ro.size.width, ro.size.height),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// TR-3: اگر پایینِ پاراگراف زیرِ مودال مانده، آن‌قدر اسکرول کن که بالای آن بیاید.
  void _revealAboveSheet(double sheetTop) {
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final double bottom = ro.localToGlobal(Offset(0, ro.size.height)).dy;
    if (bottom <= sheetTop - 8) return;
    final Rect? viewport = _viewportRect();
    final double viewportBottom =
        viewport?.bottom ?? MediaQuery.sizeOf(context).height;
    final double extra = math.max(0, viewportBottom - sheetTop + 8);
    ro.showOnScreen(
      rect: Rect.fromLTRB(0, 0, ro.size.width, ro.size.height + extra),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// کادرِ نزدیک‌ترین لیستِ عمودی، در مختصاتِ صفحه.
  Rect? _viewportRect() {
    final ScrollableState? s = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    );
    final RenderObject? ro = s?.context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  // ───────── داخلِ ظرفِ پاسخ: درجا ─────────

  Widget _buildInline(String translation, Color accent) {
    if (translation.isEmpty) return widget.originalContent;
    void flip() => setState(() => _inlineOpen = !_inlineOpen);

    final Widget source = _SourceHighlight(
      active: _inlineOpen,
      color: accent,
      // نوارِ کناری داخلِ ظرف جا ندارد (لبه‌ی حباب است)؛ فقط زمینه.
      showBar: false,
      child: widget.originalContent,
    );
    final Widget button = _TranslateButton(
      open: _inlineOpen,
      accent: accent,
      isDark: widget.isDarkMode,
      onTap: flip,
    );

    final Widget head = switch (widget.toggle) {
      TranslationToggle.side => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: source),
          const SizedBox(width: 4),
          button,
        ],
      ),
      _ => source,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: flip,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            head,
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TranslationCard(
                  text: translation,
                  isDark: widget.isDarkMode,
                  accent: accent,
                ),
              ),
              crossFadeState: _inlineOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOutCubic,
            ),
            if (widget.toggle == TranslationToggle.below)
              Align(alignment: Alignment.centerRight, child: button),
          ],
        ),
      ),
    );
  }
}

/// TR-3: هایلایتِ پاراگرافی که ترجمه‌اش باز است — زمینه‌ی کم‌رنگ و نوارِ باریکی در
/// سمتِ چپ (بیرون از متن). اندازه و چیدمانِ پاراگراف عوض نمی‌شود (StackFit.passthrough
/// همان قیدهای قبلی را به محتوا می‌دهد).
class _SourceHighlight extends StatelessWidget {
  const _SourceHighlight({
    required this.active,
    required this.color,
    required this.child,
    this.showBar = true,
    this.savedColor,
  });

  final bool active;
  final Color color;
  final Widget child;
  final bool showBar;

  /// ST-4: پاراگرافِ «در مرور» — نوارِ همیشگی در سمتِ راست، به رنگِ اهمیت.
  final Color? savedColor;

  @override
  Widget build(BuildContext context) {
    const Duration d = Duration(milliseconds: 200);
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: d,
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        child,
        if (showBar)
          Positioned(
            left: -6,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: d,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        if (savedColor != null)
          Positioned(
            right: -6,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: savedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// متنِ ترجمه، راست‌به‌چپ (بدنه‌ی پاپ‌آپ).
class _TranslationText extends StatelessWidget {
  const _TranslationText({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontFamily: 'YekanBakh',
          fontSize: 14,
          height: 1.6,
          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
        ),
      ),
    );
  }
}

/// کادرِ ترجمه با نوارِ رنگیِ سمتِ راست (بنر، مودال و ترجمه‌ی درجا).
class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.text,
    required this.isDark,
    required this.accent,
  });

  final String text;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.blue.withOpacity(0.05),
        border: Border(right: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _TranslationText(text: text, isDark: isDark),
    );
  }
}

/// TR-2: دکمه‌ی کوچکِ ترجمه داخلِ ظرفِ پاسخ.
class _TranslateButton extends StatelessWidget {
  const _TranslateButton({
    required this.open,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final bool open;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  /// عرضی که کنارِ متن می‌گیرد (برای تخمینِ عرضِ حبابِ جوابِ کوتاه).
  static const double sideWidth = 32;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? 'بستنِ ترجمه' : 'ترجمه',
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open ? accent : accent.withOpacity(isDark ? 0.18 : 0.10),
          ),
          child: Icon(
            Icons.translate_rounded,
            size: 16,
            color: open ? Colors.white : accent,
          ),
        ),
      ),
    );
  }
}

/// عرضی که دکمه‌ی ترجمه کنارِ جوابِ کوتاه می‌گیرد (TR-2).
const double kTranslateButtonSideWidth = _TranslateButton.sideWidth;
