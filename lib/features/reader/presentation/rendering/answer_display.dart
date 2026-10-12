import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// 🌟 قانون‌های H-5 تا H-7 (RULES-rendering.md): سه شیوه‌ی نمایشِ جوابِ پنهان —
// پاپ‌آپِ چسبیده به آیکونِ چشم، بنرِ بالا، و مودالِ پایین. محتوا در هر سه یکی
// است (همان سازنده‌ی بدنه از InteractiveBlankWord)؛ این فایل فقط «ظرف» است.

const Color _kDarkSurface = Color(0xFF1E212A);

/// رنگ‌های مشترکِ ظرف‌ها (هم‌رنگِ مودال و بنرِ قبلی).
Color answerSurfaceColor(bool isDarkTheme) =>
    isDarkTheme ? _kDarkSurface : Colors.white;

/// هر پاپ‌آپِ بازی را می‌بندد. قبل از بازکردنِ بنر/مودال صدا زده می‌شود تا دو
/// جواب هم‌زمان روی صفحه نباشند (H-6).
void closeAnswerPopup() => _AnswerPopupAnchorState.closeCurrent();

// ─────────────────────────────── مودال ───────────────────────────────

/// برگه‌ی پایینِ قابلِ کشیدن (همان ظاهرِ قبلی). [rich] = جوابِ جدول/عکس‌دار که
/// از ابتدا بازتر است.
void showAnswerSheet(
  BuildContext context, {
  required bool isDarkTheme,
  required WidgetBuilder body,
  bool rich = false,
}) {
  closeAnswerPopup();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: answerSurfaceColor(isDarkTheme),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: rich ? 0.6 : 0.4,
        minChildSize: rich ? 0.25 : 0.2,
        maxChildSize: rich ? 0.92 : 0.8,
        expand: false,
        builder: (sheetContext, scrollController) {
          return Padding(
            padding: rich
                ? const EdgeInsets.fromLTRB(16, 20, 16, 16)
                : const EdgeInsets.all(20.0),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: EdgeInsets.only(bottom: rich ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Builder(builder: body),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ─────────────────────────────── بنر ───────────────────────────────

/// کارتِ کشویی از بالا (همان انیمیشنِ فنریِ قبلی). حالا برای جوابِ بلند هم قابلِ
/// استفاده است: حداکثر ۶۰٪ِ ارتفاعِ صفحه و بیشتر از آن اسکرول می‌شود.
void showAnswerBanner(
  BuildContext context, {
  required bool isDarkTheme,
  required WidgetBuilder body,
}) {
  closeAnswerPopup();
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AnswerBanner',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final double maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.6;
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: answerSurfaceColor(isDarkTheme),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Builder(builder: body),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: child,
      );
    },
  );
}

// ─────────────────────────────── پاپ‌آپ ───────────────────────────────

/// کنترلِ پاپ‌آپِ یک آیکونِ چشم؛ [AnswerPopupAnchor] به builderش می‌دهد.
abstract class AnswerPopupHandle {
  bool get isOpen;

  /// باز اگر بسته است، بسته اگر باز است (لمسِ دوباره‌ی همان آیکون).
  /// [preferredWidth]: عرضِ تخمینیِ جوابِ کوتاه تا حباب به اندازه‌ی متن باشد، نه
  /// تمام‌عرض (بدنه‌ها خودشان کشیده‌اند، پس اندازه‌ی ذاتیِ آن‌ها قابلِ اتکا نیست).
  void toggle({
    required WidgetBuilder body,
    required bool isDarkTheme,
    double? preferredWidth,
  });

  void close();
}

/// 🌟 H-6: پاپ‌آپِ جواب، چسبیده به آیکونِ چشم (مثلِ حبابِ راهنمای دولینگو).
///
/// ملاحظات:
/// - **فقط یکی:** بازکردنِ هر پاپ‌آپ (یا بنر/مودال) پاپ‌آپِ قبلی را می‌بندد.
/// - **بستن:** لمسِ بیرونِ حباب، لمسِ دوباره‌ی همان آیکون، دکمه‌ی برگشت (اول
///   پاپ‌آپ بسته می‌شود، نه صفحه)، بیرون‌رفتنِ آیکون از کادرِ لیست با اسکرول،
///   چرخشِ صفحه، و از بین رفتنِ خودِ آیکون (عوض‌شدنِ صفحه/کتاب).
/// - **کشیدن ≠ لمس:** شروعِ اسکرول پاپ‌آپ را نمی‌بندد؛ حباب با خودِ آیکون
///   حرکت می‌کند (CompositedTransformFollower، بدونِ تأخیرِ یک‌فریمی).
/// - **جا:** زیرِ آیکون اگر جا هست، وگرنه بالایش؛ افقی داخلِ صفحه می‌ماند و
///   دُمِ حباب همیشه به خودِ آیکون اشاره می‌کند. بلندتر از جای موجود ← اسکرول.
/// - **لایه:** با OverlayPortal روی همان صفحه کشیده می‌شود، پس دیکشنری/ترجمه‌ای
///   که از داخلِ حباب باز شود رویِ آن می‌آید و با بستنِ صفحه، حباب هم می‌رود.
/// - صفحه قفل نمی‌شود (پس‌زمینه‌ی تیره ندارد): بقیه‌ی متن قابلِ خواندن و لمس است.
class AnswerPopupAnchor extends StatefulWidget {
  const AnswerPopupAnchor({super.key, required this.builder});

  final Widget Function(BuildContext context, AnswerPopupHandle popup) builder;

  @override
  State<AnswerPopupAnchor> createState() => _AnswerPopupAnchorState();
}

class _PopupPlacement {
  final bool below; // حباب زیرِ آیکون است (دُم رو به بالا)
  final double maxWidth;
  final double maxHeight;
  final double anchorX; // مرکزِ افقیِ آیکون در مختصاتِ Overlay
  final Size screenSize; // اندازه‌ی Overlay
  final Size mediaSize; // اندازه‌ی صفحه هنگامِ باز شدن (برای تشخیصِ چرخش)

  const _PopupPlacement({
    required this.below,
    required this.maxWidth,
    required this.maxHeight,
    required this.anchorX,
    required this.screenSize,
    required this.mediaSize,
  });
}

class _AnswerPopupAnchorState extends State<AnswerPopupAnchor>
    with SingleTickerProviderStateMixin
    implements AnswerPopupHandle {
  /// پاپ‌آپِ بازِ فعلی در کلِ اپ (H-6: فقط یکی).
  static _AnswerPopupAnchorState? _current;

  static void closeCurrent() => _current?.close();

  static const double _tailHeight = 10;
  static const double _tailWidth = 20;
  static const double _screenMargin = 12;

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  // فقط با اولین بازشدن ساخته می‌شود: صفحه ده‌ها آیکونِ چشم دارد و بیشترشان
  // هرگز پاپ‌آپ باز نمی‌کنند (و ساختنش در dispose مجاز نیست).
  AnimationController? _animOrNull;
  AnimationController get _anim => _animOrNull ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 120),
  );

  bool _open = false;
  WidgetBuilder? _body;
  bool _isDark = false;
  _PopupPlacement? _placement;
  final List<ScrollableState> _scrollables = [];
  bool _visibilityCheckScheduled = false;
  Offset? _outsideDown;

  @override
  bool get isOpen => _open;

  @override
  void toggle({
    required WidgetBuilder body,
    required bool isDarkTheme,
    double? preferredWidth,
  }) {
    if (_open) {
      close();
    } else {
      _show(body, isDarkTheme, preferredWidth);
    }
  }

  void _show(WidgetBuilder body, bool isDarkTheme, double? preferredWidth) {
    // H-6: قبل از بازکردن، پاپ‌آپِ قبلی (روی هر آیکونی) بسته می‌شود.
    if (_current != null && !identical(_current, this)) _current!.close();
    final placement = _computePlacement(preferredWidth);
    if (placement == null) return; // هنوز layout نشده
    _current = this;
    setState(() {
      _open = true;
      _body = body;
      _isDark = isDarkTheme;
      _placement = placement;
    });
    _portal.show();
    _anim.forward();
    _listenToScrollables();
  }

  @override
  void close() {
    if (!_open) return;
    if (identical(_current, this)) _current = null;
    _stopListening();
    if (!mounted) return;
    setState(() => _open = false);
    // اگر وسطِ انیمیشنِ بستن دوباره باز شود، forward این Future را لغو می‌کند
    // و then هرگز اجرا نمی‌شود — پس حباب پنهان نمی‌ماند.
    _anim.reverse().then((_) {
      if (!mounted || _open) return;
      _portal.hide();
      setState(() => _body = null);
    });
  }

  @override
  void dispose() {
    // آیکون از درخت رفت (صفحه عوض شد، کتاب بسته شد، آیتمِ لیست دور ریخته شد).
    if (identical(_current, this)) _current = null;
    _stopListening();
    _animOrNull?.dispose();
    super.dispose();
  }

  // ───────── جایابی ─────────

  RenderBox? get _anchorBox {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) return ro;
    return null;
  }

  Rect? _rectIn(RenderBox box, RenderBox ancestor) {
    if (!box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
  }

  _PopupPlacement? _computePlacement(double? preferredWidth) {
    final RenderBox? anchorBox = _anchorBox;
    final overlayRo = Overlay.of(context).context.findRenderObject();
    if (anchorBox == null || overlayRo is! RenderBox || !overlayRo.hasSize) {
      return null;
    }
    final Rect anchor = _rectIn(anchorBox, overlayRo)!;
    final Size screen = overlayRo.size;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // نوارِ عمودیِ قابلِ دید: صفحه منهای نوارِ وضعیت/کیبورد، و داخلِ کادرِ
    // نزدیک‌ترین لیستِ عمودی (حباب روی AppBar نمی‌رود مگر جای دیگری نباشد).
    Rect band = Rect.fromLTRB(
      0,
      padding.top,
      screen.width,
      screen.height - math.max(padding.bottom, keyboard),
    );
    final ScrollableState? vertical = _nearestScrollable(Axis.vertical);
    final RenderObject? vro = vertical?.context.findRenderObject();
    if (vro is RenderBox) {
      final Rect? r = _rectIn(vro, overlayRo);
      if (r != null) {
        final Rect inter = band.intersect(r);
        if (inter.height > 120) band = inter;
      }
    }

    const double gap = _tailHeight + 4;
    final double spaceBelow = band.bottom - anchor.bottom - gap;
    final double spaceAbove = anchor.top - band.top - gap;
    final bool below = spaceBelow >= 160 || spaceBelow >= spaceAbove;
    final double maxHeight = (below ? spaceBelow : spaceAbove).clamp(
      90.0,
      screen.height * 0.6,
    );

    return _PopupPlacement(
      below: below,
      maxWidth: math.max(
        _tailWidth + 40,
        math.min(
          math.min(screen.width - _screenMargin * 2, 420.0),
          preferredWidth ?? double.infinity,
        ),
      ),
      maxHeight: maxHeight,
      anchorX: anchor.center.dx,
      screenSize: screen,
      mediaSize: MediaQuery.sizeOf(context),
    );
  }

  ScrollableState? _nearestScrollable(Axis axis) {
    BuildContext ctx = context;
    for (int i = 0; i < 6; i++) {
      final s = ctx.findAncestorStateOfType<ScrollableState>();
      if (s == null) return null;
      if (axisDirectionToAxis(s.axisDirection) == axis) return s;
      ctx = s.context;
    }
    return null;
  }

  // ───────── بستن با اسکرول ─────────

  void _listenToScrollables() {
    _stopListening();
    BuildContext ctx = context;
    for (int i = 0; i < 6; i++) {
      final s = ctx.findAncestorStateOfType<ScrollableState>();
      if (s == null) break;
      _scrollables.add(s);
      s.position.addListener(_onScroll);
      ctx = s.context;
    }
  }

  void _stopListening() {
    for (final s in _scrollables) {
      // ScrollPosition ممکن است عوض شده باشد؛ removeListener روی نمونه‌ی فعلی
      // بی‌خطر است حتی اگر قبلاً اضافه نشده باشد.
      if (s.mounted) s.position.removeListener(_onScroll);
    }
    _scrollables.clear();
  }

  void _onScroll() {
    // اعلانِ اسکرول ممکن است وسطِ layout برسد؛ بررسی بعد از فریم با layoutِ تازه.
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted || !_open) return;
      if (!_anchorStillVisible()) close();
    });
  }

  /// مرکزِ آیکون هنوز داخلِ کادرِ همه‌ی لیست‌های والد هست؟
  bool _anchorStillVisible() {
    final RenderBox? anchorBox = _anchorBox;
    if (anchorBox == null) return false;
    final Offset center = anchorBox.localToGlobal(
      anchorBox.size.center(Offset.zero),
    );
    for (final s in _scrollables) {
      if (!s.mounted) continue;
      final ro = s.context.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) continue;
      final Rect r = ro.localToGlobal(Offset.zero) & ro.size;
      if (!r.contains(center)) return false;
    }
    return true;
  }

  // ───────── لمسِ بیرون ─────────

  void _onOutsidePointerUp(PointerUpEvent e) {
    final Offset? down = _outsideDown;
    _outsideDown = null;
    if (down == null || !_open) return;
    // کشیدن (اسکرول) لمس نیست؛ پاپ‌آپ می‌ماند و با آیکون حرکت می‌کند.
    if ((e.position - down).distance > kTouchSlop) return;
    // لمس روی خودِ آیکون را onTapِ آیکون (toggle) جواب می‌دهد، نه این‌جا؛ وگرنه
    // این‌جا می‌بست و onTap بلافاصله دوباره باز می‌کرد.
    final RenderBox? anchorBox = _anchorBox;
    if (anchorBox != null) {
      final Rect a = anchorBox.localToGlobal(Offset.zero) & anchorBox.size;
      if (a.inflate(4).contains(e.position)) return;
    }
    close();
  }

  // ───────── ساخت ─────────

  @override
  Widget build(BuildContext context) {
    Widget anchor = CompositedTransformTarget(
      link: _link,
      child: Builder(builder: (ctx) => widget.builder(ctx, this)),
    );
    if (_open) {
      // دکمه‌ی برگشت اول پاپ‌آپ را می‌بندد. PopScope فقط برای پاپ‌آپِ باز در
      // درخت است (نه برای صدها آیکونِ صفحه) تا ثبتِ مداوم در route هزینه نداشته باشد.
      anchor = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: anchor,
      );
    }
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: anchor,
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final _PopupPlacement? p = _placement;
    final WidgetBuilder? body = _body;
    if (p == null || body == null) return const SizedBox.shrink();

    // چرخشِ صفحه/تغییرِ اندازه‌ی پنجره: جایابی دیگر معتبر نیست ← بستن.
    final Size now = MediaQuery.sizeOf(overlayContext);
    if (_open &&
        ((now.width - p.mediaSize.width).abs() > 1 ||
            (now.height - p.mediaSize.height).abs() > 1)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) close();
      });
    }

    final Color surface = answerSurfaceColor(_isDark);
    final Color border = _isDark ? Colors.white24 : Colors.black12;

    final Widget box = Container(
      constraints: BoxConstraints(maxHeight: p.maxHeight),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            physics: const BouncingScrollPhysics(),
            child: Builder(builder: body),
          ),
        ),
      ),
    );

    final Widget tail = CustomPaint(
      painter: _TailPainter(pointsUp: p.below, fill: surface, stroke: border),
    );

    // نوارِ تمام‌عرضی که لبه‌ی چپش لبه‌ی چپِ صفحه است و به آیکون می‌چسبد. حباب
    // داخلِ آن تا ۴۲۰px (جوابِ کوتاه: به اندازه‌ی تخمینیِ متن) چیده می‌شود، افقی داخلِ صفحه می‌ماند
    // و دُم دقیقاً زیر/بالای مرکزِ آیکون است. جاهای خالیِ نوار لمس را رد می‌کنند.
    final Widget strip = SizedBox(
      width: p.screenSize.width,
      height: p.maxHeight + _tailHeight,
      child: CustomMultiChildLayout(
        delegate: _BubbleLayoutDelegate(
          below: p.below,
          anchorX: p.anchorX,
          maxWidth: p.maxWidth,
          margin: _screenMargin,
          tailSize: const Size(_tailWidth, _tailHeight),
        ),
        children: [
          LayoutId(
            id: _BubbleSlot.box,
            child: Material(type: MaterialType.transparency, child: box),
          ),
          LayoutId(id: _BubbleSlot.tail, child: tail),
        ],
      ),
    );

    final Animation<double> curved = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    return Stack(
      children: [
        // لایه‌ی شفافِ تمام‌صفحه فقط برای «لمسِ بیرون»: translucent است، پس
        // لمس به متنِ زیر هم می‌رسد (مثلاً لمسِ آیکونِ دیگر همان لحظه آن را باز
        // می‌کند و اسکرول هم کار می‌کند).
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _outsideDown = e.position,
            onPointerUp: _onOutsidePointerUp,
            onPointerCancel: (_) => _outsideDown = null,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: p.below
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            followerAnchor: p.below ? Alignment.topLeft : Alignment.bottomLeft,
            offset: Offset(-p.anchorX, p.below ? 2 : -2),
            child: FadeTransition(
              opacity: _anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
                // بزرگ‌شدن از نوکِ دُم، یعنی از خودِ آیکون
                alignment: Alignment(
                  (p.anchorX / p.screenSize.width) * 2 - 1,
                  p.below ? -1 : 1,
                ),
                child: strip,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _BubbleSlot { box, tail }

/// چیدنِ حباب و دُم داخلِ نوارِ تمام‌عرض: حباب به اندازه‌ی محتوا، وسط‌چین روی
/// آیکون ولی داخلِ صفحه؛ دُم روی مرکزِ آیکون، دور از گوشه‌های گردِ حباب.
class _BubbleLayoutDelegate extends MultiChildLayoutDelegate {
  final bool below;
  final double anchorX;
  final double maxWidth;
  final double margin;
  final Size tailSize;

  _BubbleLayoutDelegate({
    required this.below,
    required this.anchorX,
    required this.maxWidth,
    required this.margin,
    required this.tailSize,
  });

  @override
  void performLayout(Size size) {
    final double tw = tailSize.width, th = tailSize.height;
    final Size box = layoutChild(
      _BubbleSlot.box,
      BoxConstraints(
        minWidth: tw + 40,
        maxWidth: maxWidth,
        maxHeight: size.height - th + 1,
      ),
    );
    final double left = (anchorX - box.width / 2).clamp(
      margin,
      math.max(margin, size.width - margin - box.width),
    );
    // قاعده‌ی دُم یک پیکسل روی خطِ دورِ حباب می‌نشیند تا آن را بپوشاند.
    final double boxTop = below ? th - 1 : size.height - th + 1 - box.height;
    positionChild(_BubbleSlot.box, Offset(left, boxTop));

    layoutChild(_BubbleSlot.tail, BoxConstraints.tight(tailSize));
    final double tailLeft = (anchorX - tw / 2).clamp(
      left + 12,
      left + box.width - 12 - tw,
    );
    positionChild(
      _BubbleSlot.tail,
      Offset(tailLeft, below ? 0 : size.height - th),
    );
  }

  @override
  bool shouldRelayout(_BubbleLayoutDelegate old) =>
      old.below != below ||
      old.anchorX != anchorX ||
      old.maxWidth != maxWidth ||
      old.margin != margin ||
      old.tailSize != tailSize;
}

/// دُمِ مثلثیِ حباب، با خطِ دورِ هم‌رنگِ کادر (قاعده‌اش خطِ کادر را می‌پوشاند).
class _TailPainter extends CustomPainter {
  final bool pointsUp;
  final Color fill;
  final Color stroke;

  const _TailPainter({
    required this.pointsUp,
    required this.fill,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path edges = Path();
    if (pointsUp) {
      edges
        ..moveTo(0, h)
        ..lineTo(w / 2, 0)
        ..lineTo(w, h);
    } else {
      edges
        ..moveTo(0, 0)
        ..lineTo(w / 2, h)
        ..lineTo(w, 0);
    }
    final Path filled = Path.from(edges)..close();
    canvas.drawPath(filled, Paint()..color = fill);
    canvas.drawPath(
      edges,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.pointsUp != pointsUp || old.fill != fill || old.stroke != stroke;
}
