import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';

// 🌟 قانون‌های H-5 تا H-7 (RULES-rendering.md): سه شیوه‌ی نمایشِ جوابِ پنهان —
// پاپ‌آپِ چسبیده به آیکونِ چشم، بنرِ بالا، و مودالِ پایین. محتوا در هر سه یکی
// است (همان سازنده‌ی بدنه از InteractiveBlankWord)؛ این فایل فقط «ظرف» است.
// TR-1: ترجمه‌ی پاراگراف (لمسِ طولانی) هم از همین سه ظرف استفاده می‌کند.

const Color _kDarkSurface = Color(0xFF1E212A);

/// رنگ‌های مشترکِ ظرف‌ها (هم‌رنگِ مودال و بنرِ قبلی).
Color answerSurfaceColor(bool isDarkTheme) =>
    isDarkTheme ? _kDarkSurface : Colors.white;

/// همه‌ی پاپ‌آپ‌های باز را می‌بندد (دکمه‌ی «بستنِ همه»، و در حالتِ «فقط یک
/// پاپ‌آپ» قبل از بازکردنِ بنر/مودال — H-6، H-9).
void closeAllAnswerPopups() => _AnswerPopupAnchorState.closeAll();

/// H-9: تعدادِ پاپ‌آپ‌های بازی که در حالتِ «چند پاپ‌آپ هم‌زمان» باز شده‌اند؛ دکمه‌ی
/// «بستنِ همه» به این گوش می‌دهد. در حالتِ «فقط یکی» همیشه صفر است.
final ValueNotifier<int> answerPopupsOpenCount = ValueNotifier<int>(0);

/// 🌟 TR-2: محتوای داخلِ یک ظرفِ پاسخ یا ترجمه (پاپ‌آپ، بنر، مودال). ترجمه‌ی
/// پاراگراف‌های داخلِ آن به‌جای ظرفِ تازه، همان‌جا زیرِ متن باز می‌شود — ظرف روی ظرف
/// نمی‌آید.
class AnswerContainerScope extends InheritedWidget {
  const AnswerContainerScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AnswerContainerScope>() != null;

  @override
  bool updateShouldNotify(AnswerContainerScope oldWidget) => false;
}

// ─────────────────────────────── مودال ───────────────────────────────

/// برگه‌ی پایینِ قابلِ کشیدن (همان ظاهرِ قبلی). [rich] = جوابِ جدول/عکس‌دار که
/// از ابتدا بازتر است. [initialSize]: ارتفاعِ اولیه (کسری از صفحه)، برای ترجمه
/// کوتاه‌تر. [barrierColor]: ترجمه پس‌زمینه را کم‌رنگ‌تر تیره می‌کند تا پاراگرافِ
/// هایلایت‌شده دیده شود (TR-3). Future وقتی کامل می‌شود که برگه بسته شده باشد.
Future<void> showAnswerSheet(
  BuildContext context, {
  required bool isDarkTheme,
  required WidgetBuilder body,
  bool rich = false,
  bool closePopups = true,
  double? initialSize,
  Color? barrierColor,
}) {
  if (closePopups) closeAllAnswerPopups();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: barrierColor,
    backgroundColor: answerSurfaceColor(isDarkTheme),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: initialSize ?? (rich ? 0.6 : 0.4),
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
                      child: AnswerContainerScope(child: Builder(builder: body)),
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
/// [onCardBottom]: بعد از اولین layout، لبه‌ی پایینِ نهاییِ کارت (مختصاتِ صفحه) را
/// می‌دهد تا ترجمه بداند پاراگرافش زیرِ کارت مانده یا نه (TR-3).
Future<void> showAnswerBanner(
  BuildContext context, {
  required bool isDarkTheme,
  required WidgetBuilder body,
  bool closePopups = true,
  Color? barrierColor,
  ValueChanged<double>? onCardBottom,
}) {
  if (closePopups) closeAllAnswerPopups();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AnswerBanner',
    barrierColor: barrierColor ?? Colors.black45,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final double maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.6;
      final double topInset = MediaQuery.paddingOf(dialogContext).top;
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: _HeightReporter(
              // کارت با SlideTransition وارد می‌شود، پس جای فعلی‌اش هنوز نهایی
              // نیست؛ لبه‌ی پایینِ نهایی = حاشیه‌ی امنِ بالا + ۱۶ + ارتفاعِ کارت.
              onHeight: onCardBottom == null
                  ? null
                  : (h) => onCardBottom(topInset + h),
              child: Container(
              margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              // TR-6: روی صفحه‌ی عریض (گوشیِ افقی، تبلت) کارت تمام‌عرض نمی‌شود.
              constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
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
                  child: AnswerContainerScope(child: Builder(builder: body)),
                ),
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

/// کنترلِ پاپ‌آپِ یک لنگر (آیکونِ چشم یا پاراگرافِ ترجمه‌دار)؛ [AnswerPopupAnchor]
/// به builderش می‌دهد.
abstract class AnswerPopupHandle {
  bool get isOpen;

  /// باز اگر بسته است، بسته اگر باز است (لمسِ دوباره‌ی همان آیکون).
  /// [preferredWidth]: عرضِ تخمینیِ جوابِ کوتاه تا حباب به اندازه‌ی متن باشد، نه
  /// تمام‌عرض (بدنه‌ها خودشان کشیده‌اند، پس اندازه‌ی ذاتیِ آن‌ها قابلِ اتکا نیست).
  /// [direction]: H-8. [single]: H-9 — true یعنی پاپ‌آپ‌های دیگر بسته شوند و لمسِ
  /// بیرون این یکی را ببندد؛ false یعنی کنارِ بقیه باز بماند.
  /// [anchorRects]: TR-1 — مستطیل‌هایی در مختصاتِ خودِ لنگر که حباب به آن‌ها
  /// می‌چسبد، به ترتیبِ ترجیح: اولی که سمتِ انتخابی‌اش دست‌کم ۱۲۰px جا دارد
  /// انتخاب می‌شود (وگرنه آخری). null = کلِ لنگر (آیکونِ چشم).
  /// [anchorTapToggles]: true = لمسِ خودِ لنگر را onTapِ آن جواب می‌دهد، پس «لمسِ
  /// بیرون» آن را نادیده می‌گیرد (آیکونِ چشم). برای پاراگراف false است: لمسِ کوتاه
  /// روی پاراگراف هم «بیرونِ حباب» است و آن را می‌بندد.
  /// [accentColor]: رنگِ خطِ دورِ حباب (ترجمه: همان رنگِ هایلایتِ پاراگراف).
  void toggle({
    required WidgetBuilder body,
    required bool isDarkTheme,
    double? preferredWidth,
    AnswerPopupDirection direction = AnswerPopupDirection.auto,
    bool single = true,
    List<Rect>? anchorRects,
    bool anchorTapToggles = true,
    Color? accentColor,
  });

  void close();
}

/// 🌟 H-6: پاپ‌آپِ جواب، چسبیده به آیکونِ چشم (مثلِ حبابِ راهنمای دولینگو). TR-1:
/// پاپ‌آپِ ترجمه هم همین است، چسبیده به پاراگراف.
///
/// ملاحظات:
/// - **فقط یکی (پیش‌فرض، H-9):** بازکردنِ هر پاپ‌آپ (یا بنر/مودال) پاپ‌آپِ قبلی را
///   می‌بندد — جز پاپ‌آپی که این لنگر داخلِ خودش است (ترجمه‌ی داخلِ حبابِ پاسخ،
///   حبابِ پاسخ را نمی‌بندد). اگر کاربر در تنظیمات خاموشش کند، چند پاپ‌آپ کنارِ
///   هم باز می‌مانند، لمسِ بیرون دیگر نمی‌بندد و دکمه‌ی «بستنِ همه» ظاهر می‌شود.
/// - **بستن:** لمسِ بیرونِ حباب (فقط در حالتِ «یکی»، H-10)، لمسِ دوباره‌ی همان
///   آیکون، دکمه‌ی برگشت (اول پاپ‌آپ‌ها بسته می‌شوند، نه صفحه)، بیرون‌رفتنِ لنگر از
///   کادرِ لیست با اسکرول، چرخشِ صفحه، و از بین رفتنِ خودِ لنگر (عوض‌شدنِ صفحه/کتاب).
/// - **کشیدن ≠ لمس:** شروعِ اسکرول پاپ‌آپ را نمی‌بندد؛ حباب با خودِ لنگر
///   حرکت می‌کند (CompositedTransformFollower، بدونِ تأخیرِ یک‌فریمی).
/// - **جا (H-8):** طبقِ تنظیم بالا یا پایینِ لنگر (خودکار: زیر اگر جا هست)؛ اگر
///   سمتِ انتخابی واقعاً جا ندارد، سمتِ دیگر؛ افقی داخلِ صفحه می‌ماند و
///   دُمِ حباب همیشه به خودِ لنگر اشاره می‌کند. بلندتر از جای موجود ← اسکرول.
/// - **لایه:** با OverlayPortal روی همان صفحه کشیده می‌شود، پس دیکشنری/ترجمه‌ای
///   که از داخلِ حباب باز شود رویِ آن می‌آید و با بستنِ صفحه، حباب هم می‌رود.
/// - صفحه قفل نمی‌شود (پس‌زمینه‌ی تیره ندارد): بقیه‌ی متن قابلِ خواندن و لمس است.
class AnswerPopupAnchor extends StatefulWidget {
  const AnswerPopupAnchor({super.key, required this.builder});

  final Widget Function(BuildContext context, AnswerPopupHandle popup) builder;

  @override
  State<AnswerPopupAnchor> createState() => _AnswerPopupAnchorState();
}

DateTime? _closedByTapAt;

/// 🌟 AS-6: آیا همین لمس یک پاپ‌آپِ پاسخ/ترجمه را با «لمسِ بیرون» بست؟ (یک‌بارمصرف.) کارِ
/// لمس روی چیزِ زیرِ آن (مثلاً پرشِ پلیر در اسکریپتِ صوتی) برای همین لمس انجام نمی‌شود؛ لمسِ بعدی
/// عادی است.
bool answerPopupClosedByThisTap() {
  final DateTime? t = _closedByTapAt;
  _closedByTapAt = null;
  return t != null && DateTime.now().difference(t).inMilliseconds < 500;
}

class _PopupPlacement {
  final bool below; // حباب زیرِ لنگر است (دُم رو به بالا)
  final double maxWidth;
  final double maxHeight;
  final double anchorX; // مرکزِ افقیِ مستطیلِ لنگر در مختصاتِ Overlay (جای دُم)
  final double originX; // لبه‌ی چپِ خودِ لنگر در مختصاتِ Overlay
  final Rect localRect; // مستطیلِ انتخاب‌شده، در مختصاتِ لنگر
  final Size screenSize; // اندازه‌ی Overlay
  final Size mediaSize; // اندازه‌ی صفحه هنگامِ باز شدن (برای تشخیصِ چرخش)
  // 🐞 H-11: بزرگ‌نماییِ لنگر نسبت به Overlay (زومِ صفحه‌ی مطالعه، InteractiveViewer). دنبال‌کننده
  // (CompositedTransformFollower) همین بزرگ‌نمایی را از لنگر می‌گیرد؛ حباب با 1/scale خنثی‌اش می‌کند.
  final double scale;

  const _PopupPlacement({
    required this.below,
    required this.maxWidth,
    required this.maxHeight,
    required this.anchorX,
    required this.originX,
    required this.localRect,
    required this.screenSize,
    required this.mediaSize,
    this.scale = 1,
  });
}

/// علامتِ ریشه‌ی حبابِ یک پاپ‌آپ در درختِ ویجت؛ لنگرهای داخلِ حباب با آن
/// پاپ‌آپِ «والد»شان را پیدا می‌کنند (تا در حالتِ «فقط یکی» آن را نبندند).
class _PopupOverlayMarker extends StatelessWidget {
  const _PopupOverlayMarker({required this.owner, required this.child});

  final _AnswerPopupAnchorState owner;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _AnswerPopupAnchorState extends State<AnswerPopupAnchor>
    with SingleTickerProviderStateMixin
    implements AnswerPopupHandle {
  /// همه‌ی پاپ‌آپ‌های بازِ اپ، به ترتیبِ باز شدن.
  static final Set<_AnswerPopupAnchorState> _openAnchors = {};

  static void closeAll() {
    for (final a in _openAnchors.toList()) {
      a.close();
    }
  }

  /// شمارنده‌ی دکمه‌ی «بستنِ همه». با تأخیرِ یک microtask، چون close از dispose
  /// (وسطِ قفلِ درختِ ویجت) هم صدا زده می‌شود و آن‌جا setState مجاز نیست.
  static void _syncCount() {
    scheduleMicrotask(() {
      answerPopupsOpenCount.value = _openAnchors.where((a) => !a._single).length;
    });
  }

  /// لمس داخلِ حبابِ یکی از پاپ‌آپ‌های باز است؟ (لمس داخلِ حبابِ ترجمه‌ای که
  /// داخلِ حبابِ پاسخ باز شده، برای حبابِ پاسخ «بیرون» حساب نمی‌شود.)
  static bool _insideAnyBubble(Offset globalPosition) {
    for (final a in _openAnchors) {
      final ro = a._bubbleKey.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        final Rect r = ro.localToGlobal(Offset.zero) & ro.size;
        if (r.inflate(2).contains(globalPosition)) return true;
      }
    }
    return false;
  }

  static const double _tailHeight = 10;
  static const double _tailWidth = 20;
  static const double _screenMargin = 12;

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _bubbleKey = GlobalKey();
  // با بازشدن، PopScope دورِ لنگر اضافه می‌شود؛ این کلید زیردرختِ لنگر را (که برای
  // ترجمه کلِ پاراگراف است) جابه‌جا می‌کند به‌جای این‌که از نو بسازد — حالتِ
  // ویجت‌های داخلش (پاپ‌آپ‌های پاسخِ باز، صوت، …) از بین نمی‌رود.
  final GlobalKey _targetKey = GlobalKey();
  // فقط با اولین بازشدن ساخته می‌شود: صفحه ده‌ها آیکونِ چشم دارد و بیشترشان
  // هرگز پاپ‌آپ باز نمی‌کنند (و ساختنش در dispose مجاز نیست).
  AnimationController? _animOrNull;
  AnimationController get _anim => _animOrNull ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 120),
  );

  bool _open = false;
  bool _single = true;
  bool _anchorTapToggles = true;
  WidgetBuilder? _body;
  bool _isDark = false;
  Color? _accent;
  _PopupPlacement? _placement;
  final List<ScrollableState> _scrollables = [];
  bool _visibilityCheckScheduled = false;
  ModalRoute<dynamic>? _route;
  bool _pointerRouteAdded = false;
  Offset? _outsideDown;
  int? _outsidePointer;

  @override
  bool get isOpen => _open;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // در رویدادِ لمس نمی‌شود ModalRoute.of صدا زد؛ این‌جا نگه داشته می‌شود.
    _route = ModalRoute.of(context);
  }

  @override
  void toggle({
    required WidgetBuilder body,
    required bool isDarkTheme,
    double? preferredWidth,
    AnswerPopupDirection direction = AnswerPopupDirection.auto,
    bool single = true,
    List<Rect>? anchorRects,
    bool anchorTapToggles = true,
    Color? accentColor,
  }) {
    if (_open) {
      close();
    } else {
      _show(
        body,
        isDarkTheme,
        preferredWidth,
        direction,
        single,
        anchorRects,
        anchorTapToggles,
        accentColor,
      );
    }
  }

  /// پاپ‌آپ‌هایی که این لنگر داخلِ حبابشان است (والدها).
  Set<_AnswerPopupAnchorState> _enclosingPopups() {
    final Set<_AnswerPopupAnchorState> owners = {};
    context.visitAncestorElements((e) {
      final w = e.widget;
      if (w is _PopupOverlayMarker) owners.add(w.owner);
      return true;
    });
    return owners;
  }

  void _show(
    WidgetBuilder body,
    bool isDarkTheme,
    double? preferredWidth,
    AnswerPopupDirection direction,
    bool single,
    List<Rect>? anchorRects,
    bool anchorTapToggles,
    Color? accentColor,
  ) {
    // H-6/H-9: در حالتِ «فقط یکی»، قبل از بازکردن پاپ‌آپ‌های دیگر بسته می‌شوند —
    // جز پاپ‌آپی که خودِ این لنگر داخلِ آن است (بستنش این لنگر را هم از بین می‌برد).
    if (single) {
      final Set<_AnswerPopupAnchorState> keep = _enclosingPopups();
      for (final a in _openAnchors.toList()) {
        if (!identical(a, this) && !keep.contains(a)) a.close();
      }
    }
    final placement = _computePlacement(preferredWidth, direction, anchorRects);
    if (placement == null) return; // هنوز layout نشده
    _openAnchors.add(this);
    _single = single;
    _anchorTapToggles = anchorTapToggles;
    _syncCount();
    setState(() {
      _open = true;
      _body = body;
      _isDark = isDarkTheme;
      _accent = accentColor;
      _placement = placement;
    });
    _portal.show();
    _anim.forward();
    _listenToScrollables();
    _addPointerRoute();
  }

  @override
  void close() {
    if (!_open) return;
    _openAnchors.remove(this);
    _syncCount();
    _stopListening();
    _removePointerRoute();
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
    // لنگر از درخت رفت (صفحه عوض شد، کتاب بسته شد، آیتمِ لیست دور ریخته شد).
    if (_openAnchors.remove(this)) _syncCount();
    _stopListening();
    _removePointerRoute();
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

  _PopupPlacement? _computePlacement(
    double? preferredWidth,
    AnswerPopupDirection direction,
    List<Rect>? anchorRects,
  ) {
    final RenderBox? anchorBox = _anchorBox;
    final overlayRo = Overlay.of(context).context.findRenderObject();
    if (anchorBox == null || overlayRo is! RenderBox || !overlayRo.hasSize) {
      return null;
    }
    final Matrix4 toOverlay = anchorBox.getTransformTo(overlayRo);
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
    final List<Rect> candidates = (anchorRects == null || anchorRects.isEmpty)
        ? [Offset.zero & anchorBox.size]
        : anchorRects;

    for (int i = 0; i < candidates.length; i++) {
      final Rect local = candidates[i];
      final Rect anchor = MatrixUtils.transformRect(toOverlay, local);
      final double spaceBelow = band.bottom - anchor.bottom - gap;
      final double spaceAbove = anchor.top - band.top - gap;
      // H-8: سمتِ انتخابیِ کاربر، مگر آن‌جا کمتر از ۱۲۰px جا باشد و سمتِ دیگر بیشتر.
      final bool below = switch (direction) {
        AnswerPopupDirection.auto =>
          spaceBelow >= 160 || spaceBelow >= spaceAbove,
        AnswerPopupDirection.below =>
          spaceBelow >= 120 || spaceBelow >= spaceAbove,
        AnswerPopupDirection.above =>
          !(spaceAbove >= 120 || spaceAbove >= spaceBelow),
      };
      final double space = below ? spaceBelow : spaceAbove;
      // TR-1: پاراگرافِ بلند جا برای حباب نمی‌گذارد؛ آن‌وقت مستطیلِ بعدی (همان
      // خطی که لمس شد) امتحان می‌شود.
      if (space < 120 && i < candidates.length - 1) continue;

      return _PopupPlacement(
        below: below,
        maxWidth: math.max(
          _tailWidth + 40,
          math.min(
            math.min(screen.width - _screenMargin * 2, 420.0),
            preferredWidth ?? double.infinity,
          ),
        ),
        maxHeight: space.clamp(90.0, screen.height * 0.6),
        anchorX: anchor.center.dx,
        originX: MatrixUtils.transformPoint(toOverlay, Offset.zero).dx,
        localRect: local,
        screenSize: screen,
        mediaSize: MediaQuery.sizeOf(context),
        scale: toOverlay.getMaxScaleOnAxis(),
      );
    }
    return null;
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

  /// مرکزِ مستطیلِ لنگر هنوز داخلِ کادرِ همه‌ی لیست‌های والد هست؟
  bool _anchorStillVisible() {
    final RenderBox? anchorBox = _anchorBox;
    if (anchorBox == null) return false;
    final Rect local = _placement?.localRect ?? (Offset.zero & anchorBox.size);
    final Offset center = anchorBox.localToGlobal(local.center);
    for (final s in _scrollables) {
      if (!s.mounted) continue;
      final ro = s.context.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) continue;
      final Rect r = ro.localToGlobal(Offset.zero) & ro.size;
      if (!r.contains(center)) return false;
    }
    return true;
  }

  // ───────── لمسِ بیرون (H-10) ─────────
  //
  // 🐞 قبلاً یک Listenerِ شفافِ تمام‌صفحه داخلِ همان Overlay بود. لمس فقط وقتی به آن
  // می‌رسید که hit-testِ Overlay واقعاً تا آن لایه پایین برود، و این همیشه برقرار
  // نبود. حالا مثلِ BookOutlineNavigator (N-9) از مسیرِ سراسریِ GestureBinding
  // گوش می‌دهیم: هر لمسی در اپ، مستقل از این‌که کدام ویجت آن را می‌گیرد، این‌جا
  // دیده می‌شود. فقط تا وقتی پاپ‌آپ باز است ثبت است.

  void _addPointerRoute() {
    if (_pointerRouteAdded) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    _pointerRouteAdded = true;
  }

  void _removePointerRoute() {
    if (!_pointerRouteAdded) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    _pointerRouteAdded = false;
    _outsideDown = null;
    _outsidePointer = null;
  }

  void _onGlobalPointer(PointerEvent e) {
    // H-9: در حالتِ «چند پاپ‌آپ» لمسِ بیرون نمی‌بندد — وگرنه بازکردنِ دومی (که
    // لمسی بیرونِ اولی است) اولی را می‌بست.
    if (!_open || !_single) return;
    if (e is PointerDownEvent) {
      _outsideDown = null;
      _outsidePointer = null;
      // صفحه‌ی دیگری (دیکشنری، دیالوگ، مودالِ ترجمه) رویِ این صفحه باز است؛
      // لمس‌های آن‌جا ربطی به این حباب ندارد.
      if (_route != null && !_route!.isCurrent) return;
      if (_insideAnyBubble(e.position)) return;
      _outsideDown = e.position;
      _outsidePointer = e.pointer;
    } else if (e is PointerUpEvent) {
      final Offset? down = _outsideDown;
      if (down == null || e.pointer != _outsidePointer) return;
      _outsideDown = null;
      _outsidePointer = null;
      // کشیدن (اسکرول) لمس نیست؛ پاپ‌آپ می‌ماند و با لنگر حرکت می‌کند.
      if ((e.position - down).distance > kTouchSlop) return;
      // لمس روی خودِ آیکون را onTapِ آیکون (toggle) جواب می‌دهد، نه این‌جا؛ وگرنه
      // این‌جا می‌بست و onTap بلافاصله دوباره باز می‌کرد.
      if (_anchorTapToggles) {
        final RenderBox? anchorBox = _anchorBox;
        if (anchorBox != null) {
          final Rect a = anchorBox.localToGlobal(Offset.zero) & anchorBox.size;
          if (a.inflate(4).contains(e.position)) return;
        }
      }
      // 🌟 AS-6: این لمس فقط پاپ‌آپ را بست؛ onTapِ زیرش (که بعد از این مسیرِ سراسری، با پایانِ
      // gesture arena اجرا می‌شود) می‌تواند با answerPopupClosedByThisTap() کنار بکشد.
      _closedByTapAt = DateTime.now();
      close();
    } else if (e is PointerCancelEvent && e.pointer == _outsidePointer) {
      _outsideDown = null;
      _outsidePointer = null;
    }
  }

  // ───────── ساخت ─────────

  @override
  Widget build(BuildContext context) {
    Widget anchor = CompositedTransformTarget(
      key: _targetKey,
      link: _link,
      child: Builder(builder: (ctx) => widget.builder(ctx, this)),
    );
    if (_open) {
      // دکمه‌ی برگشت اول پاپ‌آپ را می‌بندد. PopScope فقط برای پاپ‌آپِ باز در
      // درخت است (نه برای صدها لنگرِ صفحه) تا ثبتِ مداوم در route هزینه نداشته باشد.
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
    final Color border =
        _accent ?? (_isDark ? Colors.white24 : Colors.black12);
    final double borderWidth = _accent != null ? 1.5 : 1;

    final Widget box = Container(
      key: _bubbleKey,
      constraints: BoxConstraints(maxHeight: p.maxHeight),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: borderWidth),
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
            child: AnswerContainerScope(child: Builder(builder: body)),
          ),
        ),
      ),
    );

    final Widget tail = CustomPaint(
      painter: _TailPainter(
        pointsUp: p.below,
        fill: surface,
        stroke: border,
        strokeWidth: borderWidth,
      ),
    );

    // نوارِ تمام‌عرضی که لبه‌ی چپش لبه‌ی چپِ صفحه است و به لنگر می‌چسبد. حباب
    // داخلِ آن تا ۴۲۰px (جوابِ کوتاه: به اندازه‌ی تخمینیِ متن) چیده می‌شود، افقی داخلِ صفحه می‌ماند
    // و دُم دقیقاً زیر/بالای مرکزِ مستطیلِ لنگر است. جاهای خالیِ نوار لمس را رد می‌کنند.
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

    // لبه‌ی بالا/پایینِ مستطیلِ لنگر، در مختصاتِ خودِ لنگر (نقطه‌ی مرجعِ دنبال‌کننده
    // گوشه‌ی بالا-چپِ لنگر است). جابه‌جاییِ افقیِ -originX لبه‌ی چپِ نوار را روی
    // لبه‌ی چپِ صفحه می‌گذارد.
    final double dy = p.below ? p.localRect.bottom + 2 : p.localRect.top - 2;

    // 🐞 H-11: صفحه زوم شده ← دنبال‌کننده همه‌چیز را scale برابر می‌کند. اندازه‌ی حباب ثابت می‌ماند:
    // از گوشه‌ای که به لنگر می‌چسبد 1/scale کوچک (یا بزرگ) می‌شود، و جابه‌جاییِ افقی (که در
    // مختصاتِ لنگر است) بر scale تقسیم می‌شود تا لبه‌ی چپِ نوار همچنان لبه‌ی چپِ صفحه باشد.
    // فاصله‌ی ۲px هم به پیکسلِ واقعی.
    final double s = (p.scale.isFinite && p.scale > 0.01) ? p.scale : 1.0;
    final bool zoomed = (s - 1).abs() > 0.001;
    final double dyScaled = p.below
        ? p.localRect.bottom + 2 / s
        : p.localRect.top - 2 / s;

    return _PopupOverlayMarker(
      owner: this,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: p.below ? Alignment.topLeft : Alignment.bottomLeft,
              offset: zoomed ? Offset(-p.originX / s, dyScaled) : Offset(-p.originX, dy),
              child: _zoomNeutral(
                zoomed: zoomed,
                scale: s,
                below: p.below,
                child: FadeTransition(
                opacity: _anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
                  // بزرگ‌شدن از نوکِ دُم، یعنی از خودِ لنگر
                  alignment: Alignment(
                    (p.anchorX / p.screenSize.width) * 2 - 1,
                    p.below ? -1 : 1,
                  ),
                  child: strip,
                ),
              ),
              ),
            ),
          ),
        ],
      ),
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
  final double strokeWidth;

  const _TailPainter({
    required this.pointsUp,
    required this.fill,
    required this.stroke,
    this.strokeWidth = 1,
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
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.pointsUp != pointsUp ||
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}

/// بعد از اولین layout، ارتفاعِ فرزند را گزارش می‌دهد (بنر ← لبه‌ی پایینِ کارت).
class _HeightReporter extends StatefulWidget {
  const _HeightReporter({required this.onHeight, required this.child});

  final ValueChanged<double>? onHeight;
  final Widget child;

  @override
  State<_HeightReporter> createState() => _HeightReporterState();
}

class _HeightReporterState extends State<_HeightReporter> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    if (!_reported && widget.onHeight != null) {
      _reported = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ro = context.findRenderObject();
        if (ro is RenderBox && ro.hasSize) widget.onHeight!(ro.size.height);
      });
    }
    return widget.child;
  }
}

/// 🌟 H-9: دکمه‌ی «بستنِ همه‌ی پاپ‌آپ‌ها» (پاسخ و ترجمه). فقط وقتی دیده می‌شود که در حالتِ «چند
/// پاپ‌آپ هم‌زمان» دست‌کم یک پاپ‌آپ باز باشد؛ تعدادشان روی دکمه می‌آید. پایینِ
/// صفحه‌ی مطالعه، وسط (reading_canvas.dart).
class AnswerPopupsCloseAllButton extends StatelessWidget {
  const AnswerPopupsCloseAllButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: answerPopupsOpenCount,
      builder: (context, count, _) {
        final bool visible = count > 0;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: const Duration(milliseconds: 180),
            curve: visible ? Curves.easeOutBack : Curves.easeIn,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Material(
                color: scheme.inverseSurface,
                elevation: 4,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: closeAllAnswerPopups,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_rounded,
                            size: 18,
                            color: scheme.onInverseSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            // تعداد را هنگامِ محوشدن (۰) نگه نمی‌داریم؛ «۰» دیده نمی‌شود.
                            'بستنِ همه‌ی پاپ‌آپ‌ها ($count)',
                            style: TextStyle(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 🐞 H-11: حباب در زومِ صفحه اندازه‌ی واقعی‌اش را نگه می‌دارد: دنبال‌کننده بزرگ‌نماییِ لنگر را
/// می‌گیرد و این‌جا با 1/scale از همان گوشه‌ای که به لنگر چسبیده خنثی می‌شود (انیمیشنِ بازشدن هم
/// به پیکسلِ واقعی).
Widget _zoomNeutral({
  required bool zoomed,
  required double scale,
  required bool below,
  required Widget child,
}) {
  if (!zoomed) return child;
  return Transform.scale(
    scale: 1 / scale,
    alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
    child: child,
  );
}
