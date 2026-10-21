import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/answer_display.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/translation_groups.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';
import 'package:ielts_assistant/core/text/document_text_utils.dart';

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
// - **گروه (TR-7):** پاراگراف‌های کوتاهِ به‌هم‌چسبیده (translation_groups.dart) با یک لمسِ
//   طولانی ترجمه‌ی همه را با هم نشان می‌دهند و همه هایلایت می‌شوند.

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

  /// TR-7: گروهِ این پاراگراف (null = تنها). داخلِ ظرفِ پاسخ نادیده گرفته می‌شود.
  final TranslationGroup? group;

  /// اندیسِ همین پاراگراف در [group].
  final int groupIndex;

  const TranslatableContentWrapper({
    super.key,
    required this.originalContent,
    this.translationFa,
    this.translationAr,
    this.isDarkMode = false,
    this.toggle = TranslationToggle.none,
    this.study,
    this.group,
    this.groupIndex = -1,
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

  /// TR-7: آخرین وضعیتی که به گروه گزارش شده، و پاپ‌آپِ همین عضو (تا لمسِ طولانی روی عضوِ
  /// دیگرِ گروه ببندَدَش).
  bool _reportedOpen = false;
  AnswerPopupHandle? _popup;

  TranslationGroup? get _group =>
      widget.groupIndex >= 0 ? widget.group : null;

  @override
  void didUpdateWidget(TranslatableContentWrapper old) {
    super.didUpdateWidget(old);
    if (!identical(old.group, widget.group) ||
        old.groupIndex != widget.groupIndex) {
      if (old.groupIndex >= 0) old.group?.detach(old.groupIndex, context);
      if (_reportedOpen) {
        final TranslationGroup? g = old.group;
        _reportedOpen = false;
        _later(() => g?.report(this, false));
      }
    }
  }

  @override
  void dispose() {
    final TranslationGroup? g = _group;
    if (g != null) {
      g.detach(widget.groupIndex, context);
      if (_reportedOpen) _later(() => g.report(this, false));
    }
    super.dispose();
  }

  /// تغییرِ وضعیتِ گروه بعد از همین فریم (عضوهای دیگر را بازسازی می‌کند؛ وسطِ build/dispose
  /// مجاز نیست).
  static void _later(VoidCallback f) {
    SchedulerBinding.instance.addPostFrameCallback((_) => f());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _reportOpen(bool open) {
    final TranslationGroup? g = _group;
    if (g == null || open == _reportedOpen) return;
    _reportedOpen = open;
    _later(() => g.report(this, open));
  }

  /// پاپ‌آپِ گروه را می‌بندد (لمسِ طولانی روی عضوِ دیگرِ همان گروه).
  void _closeGroupPopup() => _popup?.close();

  /// دوزبانه: ترجمه‌ی زبانِ انتخابی؛ اگر خالی بود، زبانِ دیگر تا خالی نماند.
  /// عضوِ گروه (TR-7): ترجمه‌ی همه‌ی عضوها، هرکدام یک سطر.
  String _translation() {
    final bool preferAr = ref.watch(languageProvider) == 'ar';
    final TranslationGroup? g = _group;
    if (g != null) {
      final String all = g.translation(preferAr: preferAr);
      if (all.isNotEmpty) return all;
    }
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

    final TranslationGroup? group = _group;
    group?.attach(widget.groupIndex, context);

    // TR-1: روی صفحه — لنگرِ پاپ‌آپ همان پاراگراف است.
    return AnswerPopupAnchor(
      builder: (anchorContext, popup) {
        _popup = popup;
        final bool ownOpen = popup.isOpen || _sheetOpen;
        _reportOpen(ownOpen);
        Widget highlight(bool active) => _SourceHighlight(
          active: active,
          color: accent,
          savedColor: saved?.color,
          child: widget.originalContent,
        );
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
                // TR-7: ترجمه‌ی گروه که باز است، همه‌ی عضوها هایلایت می‌شوند.
                if (group == null)
                  highlight(ownOpen)
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: group.anyOpen,
                    builder: (_, anyOpen, __) => highlight(ownOpen || anyOpen),
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

    // TR-7: ترجمه‌ی همین گروه را عضوِ دیگری باز کرده ← لمسِ طولانیِ دوباره می‌بندد.
    final TranslationGroup? group = _group;
    if (group != null) {
      final List<Object> others = [
        for (final Object o in group.openOwners)
          if (!identical(o, this)) o,
      ];
      if (others.isNotEmpty) {
        for (final Object o in others) {
          if (o is _TranslatableContentWrapperState) o._closeGroupPopup();
        }
        return;
      }
    }

    switch (settings.translation) {
      case AnswerDisplayMode.popup:
        final RenderObject? ro = context.findRenderObject();
        final Size size = ro is RenderBox && ro.hasSize ? ro.size : Size.zero;
        final double x = localPosition.dx.clamp(0.0, size.width);
        // اول کلِ پاراگراف — یا کلِ گروه (TR-7) — تا حباب زیر/بالای آن باز شود و متن دیده
        // بماند؛ اگر آن‌قدر بلند است که جایی نمی‌ماند، همان خطی که لمس شد.
        final Rect? groupBounds = group != null && ro is RenderBox && ro.hasSize
            ? group.boundsIn(ro)
            : null;
        final double top = groupBounds?.top ?? 0;
        final double bottom = groupBounds?.bottom ?? size.height;
        final List<Rect> rects = [
          Rect.fromLTRB(x - 1, top, x + 1, bottom),
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
          preferredWidth: _popupWidth(translation),
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

  /// TR-6: عرضِ حباب به اندازه‌ی محتوا، نه تمام‌عرض: ترجمه‌ی کوتاه («بندر») حبابِ
  /// باریک می‌گیرد؛ ترجمه‌ی بلند حداکثر ۳۶۰px تا خطِ فارسی خوانا بماند (روی گوشیِ
  /// افقی و تبلت، حباب دیگر نیمی از صفحه را نمی‌پوشاند). نوارِ «مرورِ من» هم جا
  /// می‌خواهد (در حالتِ ذخیره‌شده ستاره‌ها و دکمه‌ها؛ اگر جا نشد خودش می‌شکند).
  double _popupWidth(String translation) {
    double w = 0;
    // ترجمه‌ی گروه (TR-7) چند سطر است: پهن‌ترین سطر.
    for (final String line in translation.split('\n')) {
      if (line.trim().isEmpty) continue;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: stripBlankMarkers(line), style: _kTranslationStyle),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      w = math.max(w, tp.width);
      tp.dispose();
    }
    final StudyPassageRef? study = widget.study;
    if (study != null) {
      final bool saved = ref.read(studyProvider)[study.id] != null;
      w = math.max(w, saved ? 280.0 : 160.0);
    }
    // padding‌ِ حباب (۱۴+۱۴) و کمی جا برای گردکردنِ اندازه‌ی متن
    return (w + 34).clamp(140.0, 360.0).toDouble();
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

  Widget _buildInline(String rawTranslation, Color accent) {
    // TR-8: داخلِ پنجره‌ی پاسخ، پاسخ دیگر پنهان نیست.
    final String translation = stripBlankMarkers(rawTranslation);
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

/// TR-3: هایلایتِ پاراگرافی که ترجمه‌اش باز است — زمینه‌ی کم‌رنگ **فقط پشتِ خودِ متن**
/// (هر سطر به اندازه‌ی نوشته‌اش، مثلِ انتخابِ متن؛ نه کلِ عرضِ پاراگراف) و نوارِ باریکی
/// در سمتِ چپ (بیرون از متن). اندازه و چیدمانِ پاراگراف عوض نمی‌شود.
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
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: active ? 1 : 0),
          duration: d,
          builder: (_, t, content) =>
              _TextLinesHighlight(color: color, amount: t, child: content),
          child: child,
        ),
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

/// زمینه‌ی رنگی پشتِ سطرهای متنِ [child]: کادرِ هر سطرِ هر `RenderParagraph`ِ داخلش
/// (شماره‌ی فهرست، آیکونِ چشم و کلماتِ تعاملی هم، چون جزوِ همان سطرند). [amount] از ۰ تا ۱
/// برای محو/ظاهرشدن.
class _TextLinesHighlight extends SingleChildRenderObjectWidget {
  const _TextLinesHighlight({
    required this.color,
    required this.amount,
    super.child,
  });

  final Color color;
  final double amount;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTextLinesHighlight(color, amount);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTextLinesHighlight renderObject,
  ) {
    renderObject
      ..color = color
      ..amount = amount;
  }
}

class _RenderTextLinesHighlight extends RenderProxyBox {
  _RenderTextLinesHighlight(this._color, this._amount);

  Color _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    if (_amount > 0) markNeedsPaint();
  }

  double _amount;
  set amount(double v) {
    if (v == _amount) return;
    _amount = v;
    markNeedsPaint();
  }

  /// کادرِ سطرها در مختصاتِ همین جعبه؛ کادرهای یک سطر (چند اسپن/ویجت) یکی می‌شوند.
  List<Rect> _lineRects() {
    final List<Rect> boxes = [];
    final Rect bounds = Offset.zero & size;
    void visit(RenderObject o) {
      // متنِ داخلِ اسکرولِ افقیِ جدول ممکن است بیرون از دید باشد؛ آن‌جا زمینه نمی‌گیرد.
      if (o is RenderAbstractViewport) return;
      if (o is RenderParagraph && o.attached && o.hasSize) {
        final int len = o.text
            .toPlainText(includeSemanticsLabels: false)
            .length;
        if (len > 0) {
          final Matrix4 m = o.getTransformTo(this);
          for (final TextBox b in o.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: len),
          )) {
            final Rect r = MatrixUtils.transformRect(
              m,
              b.toRect(),
            ).intersect(bounds);
            if (r.width > 0.5 && r.height > 0.5) boxes.add(r);
          }
        }
      }
      o.visitChildren(visit);
    }

    final RenderBox? c = child;
    if (c != null) visit(c);
    boxes.sort((a, b) => a.top.compareTo(b.top));
    final List<Rect> lines = [];
    for (final Rect r in boxes) {
      int hit = -1;
      for (int i = 0; i < lines.length; i++) {
        final Rect l = lines[i];
        final double overlap =
            math.min(l.bottom, r.bottom) - math.max(l.top, r.top);
        if (overlap >= math.min(l.height, r.height) * 0.5) {
          hit = i;
          break;
        }
      }
      if (hit < 0) {
        lines.add(r);
      } else {
        lines[hit] = lines[hit].expandToInclude(r);
      }
    }
    return lines;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_amount > 0 && child != null) {
      final Paint paint = Paint()
        ..color = _color.withOpacity(0.14 * _amount.clamp(0.0, 1.0));
      for (final Rect r in _lineRects()) {
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(
            r.shift(offset).inflate(2),
            const Radius.circular(3),
          ),
          paint,
        );
      }
    }
    super.paint(context, offset);
  }
}

const TextStyle _kTranslationStyle = TextStyle(
  fontFamily: 'YekanBakh',
  fontSize: 14,
  height: 1.6,
);

/// متنِ ترجمه، راست‌به‌چپ (بدنه‌ی پاپ‌آپ).
///
/// 🌟 TR-8: بخشی از ترجمه که پاسخِ جای خالی است (`{blk}…{/blk}` در داده، G-9ِ اکسترکتور) پنهان
/// است: به جایش آیکونِ کوچکِ چشم می‌آید و لمسش همان بخش را نشان می‌دهد (لمسِ دوباره روی متنِ
/// آشکارشده دوباره پنهانش می‌کند). وگرنه ترجمه‌ی جمله پاسخ را پیش از بازکردنِ چشمِ خودِ متن
/// لو می‌داد.
class _TranslationText extends StatefulWidget {
  const _TranslationText({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  State<_TranslationText> createState() => _TranslationTextState();
}

class _TranslationTextState extends State<_TranslationText> {
  static final RegExp _hidden = RegExp(r'\{blk\}(.*?)\{/blk\}', dotAll: true);

  final Set<int> _revealed = {};
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(_TranslationText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _revealed.clear();
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _toggle(int i) => setState(() {
    if (!_revealed.remove(i)) _revealed.add(i);
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final TextStyle style = _kTranslationStyle.copyWith(
      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
    );
    final String text = widget.text;
    if (!text.contains('{blk}')) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Text(text, textAlign: TextAlign.start, style: style),
      );
    }

    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final Color accent = translationAccent(isDark);
    final List<InlineSpan> spans = [];
    int pos = 0;
    int index = 0;
    for (final RegExpMatch m in _hidden.allMatches(text)) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final int i = index++;
      final String answer = m.group(1) ?? '';
      if (_revealed.contains(i)) {
        final TapGestureRecognizer r = TapGestureRecognizer()
          ..onTap = () => _toggle(i);
        _recognizers.add(r);
        spans.add(
          TextSpan(
            text: answer,
            recognizer: r,
            style: TextStyle(
              backgroundColor: accent.withOpacity(isDark ? 0.25 : 0.14),
            ),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _toggle(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.visibility_rounded, size: 14, color: accent),
              ),
            ),
          ),
        );
      }
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(style: style, children: spans),
        textAlign: TextAlign.start,
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
