// 🔊 🎧 ▶ ▶️
// ignore_for_file: unused_local_variable, unused_import

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:float_column/float_column.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart';
import 'dart:math' as math;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MapOffset {
  int value = 0;
}

class ReadingCanvasScreen extends ConsumerStatefulWidget {
  final List<PageData> documentPages;
  final List<ParagraphData> audioScripts; // 🌟 اضافه شد
  const ReadingCanvasScreen({
    super.key,
    required this.documentPages,
    required this.audioScripts,
  });

  @override
  ConsumerState<ReadingCanvasScreen> createState() {
    return _ReadingCanvasScreenState();
  }
}

class _ReadingCanvasScreenState extends ConsumerState<ReadingCanvasScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final _box = GetStorage();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final GlobalKey _targetParaKey = GlobalKey();

  // ── وضعیت zoom و شمارش انگشتان ─────────────────────────────────────────
  int _pointerCount = 0;
  double _currentScale = 1.0;

  bool get _isZoomed => _currentScale > 1.02;
  bool get _isPinching => _pointerCount >= 2;

  // ── رفع پرش اولیه اسکرول ────────────────────────────────────────────────
  // ScrollablePositionedList از دو ListView داخلی استفاده می‌کند.
  // اولین scroll از initialScrollIndex، یک transition بین این دو فعال می‌کند → پرش.
  // راه‌حل: صفحه را نامرئی نگه‌داریم، jumpTo را در پس‌زمینه اجرا کنیم
  // (transition بی‌صدا انجام شود)، سپس صفحه را نشان دهیم.
  bool _isReady = false;
  int _savedIndex = 0;
  double _savedAlignment = 0.0;

  // 🌟 دیبانس‌کردن ذخیره‌سازی موقعیت اسکرول: قبلاً روی هر فریمِ اسکرول
  // (ده‌ها بار در ثانیه) مستقیم روی دیسک نوشته می‌شد که یکی از عوامل
  // اصلی ناروان بودن اسکرول (به‌خصوص اسکرول اول) بود.
  Timer? _scrollPersistDebounce;

  // 🌟 نشانِ معلقِ شماره‌ی صفحه (مثل تلگرام) + پرش به صفحه
  int _currentPage = 1;
  bool _showPageBadge = false;
  Timer? _badgeTimer;

  // 🌟 رفع مشکل اسکرول نادقیق جستجو: این دو فیلد مطمئن می‌شوند که
  // Scrollable.ensureVisible فقط زمانی اجرا می‌شود که widget tree واقعاً
  // با هدف جدید (occurrence جدید) rebuild شده باشد، نه یک context قدیمی
  // و باقی‌مانده از هدف قبلی.
  String? _lastBuiltTargetSignature;
  int? _lastBuiltTargetPageIndex;
  int _scrollRequestId = 0;
  // 🌟 جلوگیری از claim دوباره‌ی کلیدهای هدف اگر ScrollablePositionedList
  // (به‌خاطر معماری دو-لیستیِ داخلی‌اش، مخصوصاً حین یک جهشِ بزرگ) برای
  // همان pageIndex بیش از یک‌بار در همین build، itemBuilder صدا بزند
  bool _targetKeyClaimedThisBuild = false;
  String? _signatureFor(SearchResult? r) {
    if (r == null) return null;
    return '${r.pageNumber}:${r.paraIndex}:${r.occurrenceIndex}';
  }

  // وقتی transform تغییر می‌کند — فقط اگر در حال pinch باشیم setState می‌زنیم
  // این جلوگیری می‌کند از setState غیرضروری در حین اسکرول معمولی
  void _onTransformChanged() {
    if (!_isPinching) return;
    final s = _transformationController.value.getMaxScaleOnAxis();
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);

    // خواندن موقعیت ذخیره‌شده هنگام init (قبل از اولین build)
    final currentBook = ref.read(activeBookProvider);
    _savedIndex = _box.read('scroll_page_${currentBook?.id ?? "default"}') ?? 0;
    _savedAlignment =
        _box.read('scroll_align_${currentBook?.id ?? "default"}') ?? 0.0;

    _itemPositionsListener.itemPositions.addListener(() {
      // 🌟 این listener روی هر فریمِ اسکرول فراخوانی می‌شود. نوشتن مستقیم
      // روی GetStorage در همین لحظه یعنی ده‌ها بار در ثانیه I/O روی دیسک،
      // که خودش باعث افت فریم (jank) در طول اسکرول می‌شود. به‌جای آن،
      // فقط آخرین موقعیت را نگه می‌داریم و ۲۵۰ میلی‌ثانیه بعد از توقف
      // اسکرول، یک‌بار می‌نویسیم.
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;

      // 🌟 پیدا کردن بالاترین آیتمی که هم‌اکنون در کادر در حال نمایش است
      final topItem = positions
          .where((p) => p.itemTrailingEdge > 0)
          .reduce((min, p) => p.index < min.index ? p : min);

      // 🌟 شماره‌ی صفحه‌ی جاری + نمایشِ نشان هنگام اسکرول (مثل تلگرام)
      final newPage = topItem.index + 1;
      if (newPage != _currentPage || !_showPageBadge) {
        setState(() {
          _currentPage = newPage;
          _showPageBadge = true;
        });
      }
      _badgeTimer?.cancel();
      _badgeTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showPageBadge = false);
      });

      _scrollPersistDebounce?.cancel();
      _scrollPersistDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        final currentBook = ref.read(activeBookProvider);
        if (currentBook != null) {
          _box.write('scroll_page_${currentBook.id}', topItem.index);
          // 🌟 ذخیره نقطه دقیق (Offset) آیتم برای بازگشت به همان مکان
          _box.write('scroll_align_${currentBook.id}', topItem.itemLeadingEdge);
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ── مرحله ۱: پرش بی‌صدا به موقعیت ذخیره‌شده ─────────────────────────
      // چون opacity=0 است کاربر هیچ‌چیز نمی‌بیند.
      // این jumpTo باعث می‌شود dual-list transition پیش از تعامل کاربر اتفاق بیفتد.
      if (_itemScrollController.isAttached && _savedIndex > 0) {
        final safeIndex = _savedIndex < widget.documentPages.length
            ? _savedIndex
            : 0;
        _itemScrollController.jumpTo(
          index: safeIndex,
          alignment: _savedAlignment,
        );
      }

      // ── مرحله ۲: صبر برای تکمیل transition (۲ فریم کافی است) ──────────
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      // ── مرحله ۳: نمایش صفحه — کاربر اکنون صفحه درست را می‌بیند ─────────
      setState(() => _isReady = true);

      // ── مرحله ۴: در صورت وجود search target، به آن اسکرول کن ─────────────
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            _ensureTargetVisible(expectedSignature: _lastBuiltTargetSignature),
      );
    });
  }

  // 🌟 چون GlobalObjectKey با identical() مقایسه می‌شود نه محتوای رشته،
  // باید خودمان شیء GlobalKey را برای هر «امضا» فقط یک‌بار بسازیم و
  // همیشه همان شیء را برگردانیم — وگرنه هر بار صدا زدن گتر یک کلید
  // «متفاوت» از نگاه فلاتر تولید می‌کند، حتی برای همان هدف قبلی.
  final Map<String, GlobalKey> _navKeyCache = {};

  GlobalKey _keyFor(String prefix) {
    final id = '${prefix}_${_lastBuiltTargetSignature ?? "none"}';
    return _navKeyCache.putIfAbsent(id, () => GlobalKey());
  }

  GlobalKey get _fallbackParaKey => _keyFor('fallback');
  GlobalKey get _exactMatchKey => _keyFor('exact');
  GlobalKey get _pageAnchorKey => _keyFor('anchor');

  // 🌟 اسکرول دقیق — تلاش دوم.
  //
  // تلاش قبلی (خواندن/نوشتن مستقیم روی position.pixels نزدیک‌ترین
  // Scrollable) کار نکرد: طبق لاگ واقعی از دستگاه، pixels همیشه ۰.۰
  // خوانده می‌شد و افست‌های منفیِ محاسبه‌شده به minScrollExtent=0
  // clamp می‌شدند — یعنی عملاً هیچ اسکرولی اتفاق نمی‌افتاد. علتش این
  // است که ScrollablePositionedList موقعیت اسکرول را با منطق داخلی و
  // سفارشی خودش (نه یک pixels خطی ساده) مدیریت می‌کند، پس دستکاری مستقیم
  // ScrollPosition نزدیک‌ترین Scrollable قابل‌اعتماد نیست.
  //
  // راه‌حل: به‌جای دست‌کاری مستقیم اسکرول، فاصله‌ی هدف را نسبت به «بالای
  // خودِ صفحه» اندازه می‌گیریم (این فاصله کاملاً مستقل از موقعیت فعلی
  // اسکرول است و همیشه درست می‌ماند)، آن را به یک مقدار «alignment»
  // تبدیل می‌کنیم، و کار نهایی اسکرول را کاملاً به خودِ پکیج
  // (ItemScrollController.scrollTo) می‌سپاریم — همان API که خودِ پکیج
  // برای اسکرول دقیق و انیمیت‌شده به یک آیتم طراحی کرده.
  bool _scrollToRenderContext(BuildContext targetContext, int pageIndex) {
    final RenderObject? targetRO = targetContext.findRenderObject();
    if (targetRO == null ||
        targetRO is! RenderBox ||
        !targetRO.attached ||
        !targetRO.hasSize) {
      return false;
    }

    final RenderObject? pageRO = _pageAnchorKey.currentContext
        ?.findRenderObject();
    if (pageRO == null ||
        pageRO is! RenderBox ||
        !pageRO.attached ||
        !pageRO.hasSize) {
      return false;
    }

    final ScrollableState? scrollable = Scrollable.maybeOf(targetContext);
    if (scrollable == null) return false;

    final RenderObject? viewportRO = scrollable.context.findRenderObject();
    if (viewportRO == null || viewportRO is! RenderBox || !viewportRO.hasSize) {
      return false;
    }

    // فاصله‌ی هدف از بالای خودِ صفحه — مستقل از اسکرول فعلی
    final Matrix4 transform = targetRO.getTransformTo(pageRO);
    final double offsetWithinPage = MatrixUtils.transformPoint(
      transform,
      Offset.zero,
    ).dy;

    final double viewportHeight = viewportRO.size.height;
    const double desiredAlignment = 0.15; // جلوگیری از مخفی شدن زیر نوار بالا

    // اگر alignment=0 یعنی «بالای آیتم روی بالای viewport»، برای اینکه
    // نقطه‌ای offsetWithinPage پیکسل پایین‌تر از بالای آیتم دقیقاً روی
    // ۱۵٪ از بالای viewport بنشیند، باید alignment را همین مقدار عقب برد:
    final double alignment =
        desiredAlignment - (offsetWithinPage / viewportHeight);

    try {
      _itemScrollController.scrollTo(
        index: pageIndex,
        alignment: alignment,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } catch (e) {
      return false;
    }
    return true;
  }

  // 🌟 متد اسکرول دقیق به هدف جستجو.
  //
  // مشکل قبلی: _exactMatchKey و _fallbackParaKey دو GlobalKey سراسری‌اند که
  // در هر build به پاراگراف/کلمه‌ی هدفِ *جدید* منتقل می‌شوند. اما وقتی این
  // متد از داخل ref.listen صدا زده می‌شود (دکمه‌ی بعدی/قبلی)، ممکن است هنوز
  // یک فریم طول بکشد تا build() با activeTarget تازه اجرا شود. اگر در همان
  // لحظه currentContext غیر-null باشد (چون هنوز به هدفِ *قبلی* وصل است)،
  // کد قدیم به اشتباه همان‌جا (هدف قبلی) را معتبر می‌دانست و اسکرول را آنجا
  // متوقف می‌کرد → دقیقاً همان «رفتن به جای دیگری، قبل یا بعد از هدف واقعی».
  //
  // راه‌حل: هر بار که این متد صدا زده می‌شود، «امضای» هدف مورد انتظار
  // (expectedSignature) را می‌گیریم و currentContext را فقط زمانی معتبر
  // می‌دانیم که _lastBuiltTargetSignature (که در build() به‌روزرسانی می‌شود)
  // دقیقاً با همان امضا یکی باشد. همچنین با _scrollRequestId، اگر کاربر
  // سریع چند بار روی بعدی/قبلی بزند، تلاش‌های قدیمی‌تر بی‌صدا لغو می‌شوند
  // تا انیمیشنِ یک هدفِ منسوخ، جای هدف تازه را نگیرد.
  void _ensureTargetVisible({String? expectedSignature}) {
    final int myRequestId = ++_scrollRequestId;
    int attempts = 0;

    void tryScroll() {
      if (!mounted) return;
      if (myRequestId != _scrollRequestId) return;

      final bool targetIsBuilt =
          expectedSignature == null ||
          expectedSignature == _lastBuiltTargetSignature;

      // این‌طور (چون exactMatchKey دیگر هرگز به چیزی وصل نمی‌شود):
      final targetContext = targetIsBuilt
          ? (_exactMatchKey.currentContext ?? _fallbackParaKey.currentContext)
          : null;

      bool handled = false;
      if (targetContext != null && _lastBuiltTargetPageIndex != null) {
        try {
          handled = _scrollToRenderContext(
            targetContext,
            _lastBuiltTargetPageIndex!,
          );
        } catch (e) {
          debugPrint("خطا در اسکرول: $e");
        }
      }

      if (!handled) {
        attempts++;
        if (attempts < 20) {
          // 🌟 در صورت پیدا نشدن، ۵۰ میلی‌ثانیه دیگر صبر می‌کند (تا سقف ۱ ثانیه)
          Future.delayed(const Duration(milliseconds: 50), () {
            if (myRequestId != _scrollRequestId) return;
            tryScroll();
          });
        }
      }
    }

    // همیشه در فریم بعدی استارت می‌زنیم تا چرخه‌ی فعلیِ چیدمان تمام شود
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (myRequestId != _scrollRequestId) return;
      tryScroll();
    });
  }

  @override
  void dispose() {
    _scrollPersistDebounce?.cancel();
    _badgeTimer?.cancel();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  // 🌟 دیالوگِ «رفتن به صفحه» (مثل PDF‌خوان‌ها)
  Future<void> _openJumpToPageDialog() async {
    final total = widget.documentPages.length;
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفتن به صفحه'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'شماره‌ای بین ۱ تا $total',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
              child: const Text('برو'),
            ),
          ],
        ),
      ),
    );

    if (n != null && n >= 1 && n <= total && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: n - 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double canvasWidth = MediaQuery.of(context).size.width > 800
        ? 760.0
        : MediaQuery.of(context).size.width - 24;
    final currentBook = ref.read(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    int initialIndex =
        _box.read('scroll_page_${currentBook?.id ?? "default"}') ?? 0;
    // 🌟 فراخوانی نقطه دقیق (Offset) ذخیره شده
    double initialAlignment =
        _box.read('scroll_align_${currentBook?.id ?? "default"}') ?? 0.0;

    final activeTarget =
        (searchSession != null && searchSession.results.isNotEmpty)
        ? searchSession.results[searchSession.currentIndex] as SearchResult
        : null;

    if (activeTarget != null) {
      int pIndex = widget.documentPages.indexWhere(
        (p) => p.pageNumber == activeTarget.pageNumber,
      );
      if (pIndex != -1) {
        initialIndex = pIndex;
        // 🌟 در هنگام جستجو، می‌خواهیم نتیجه مستقیماً از ابتدای کادر نشان داده شود
        initialAlignment = 0.0;
      }
    }

    // 🌟 این خط، «امضای» هدفی را که همین build با آن _exactMatchKey/
    // _fallbackParaKey را به پاراگراف/کلمه‌ی درست وصل کرده ثبت می‌کند.
    // _ensureTargetVisible از روی همین امضا تشخیص می‌دهد که آیا واقعاً به
    // build تازه رسیده‌ایم یا هنوز context قدیمی در دست است.
    final newSignature = _signatureFor(activeTarget);
    // if (newSignature != _lastBuiltTargetSignature) {
    //   // 🌟 هدف واقعاً عوض شده → کلیدهای تازه بساز تا با کلیدِ زیردرختِ
    //   // احتمالاً هنوز زنده‌ی صفحه‌ی قبلی (به‌خاطر AutomaticKeepAliveClientMixin)
    //   // تصادم نکند
    //   _fallbackParaKey = GlobalKey();
    //   _exactMatchKey = GlobalKey();
    //   _pageAnchorKey = GlobalKey();
    // }
    _lastBuiltTargetSignature = newSignature;
    _lastBuiltTargetSignature = _signatureFor(activeTarget);
    // 🌟 ایندکس صفحه‌ی همین هدف را هم نگه می‌داریم تا _ensureTargetVisible
    // برای مرحله‌ی دوم (scrollTo با alignment دقیق) به آن نیاز نداشته باشد
    // که دوباره جستجویش کند.
    _lastBuiltTargetPageIndex = activeTarget == null
        ? null
        : widget.documentPages.indexWhere(
            (p) => p.pageNumber == activeTarget.pageNumber,
          );
    _targetKeyClaimedThisBuild =
        false; // 🌟 اضافه شد — شروع تازه برای این build

    ref.listen<SearchSession?>(activeSearchProvider, (previous, next) async {
      if (next != null && next.results.isNotEmpty) {
        if (previous?.query != next.query ||
            previous?.currentIndex != next.currentIndex ||
            previous?.jumpTrigger != next.jumpTrigger) {
          final target = next.results[next.currentIndex] as SearchResult;
          final targetSignature = _signatureFor(target);
          int pageIndex = widget.documentPages.indexWhere(
            (p) => p.pageNumber == target.pageNumber,
          );

          if (pageIndex != -1 && _itemScrollController.isAttached) {
            final visiblePositions = _itemPositionsListener.itemPositions.value;
            bool isPageVisible = visiblePositions.any(
              (pos) => pos.index == pageIndex,
            );

            if (!isPageVisible) {
              // فقط به صفحه پرش می‌کنیم
              try {
                _itemScrollController.jumpTo(index: pageIndex, alignment: 0.0);
              } catch (e) {
                debugPrint("خطا در jumpTo: $e");
              }
            }

            // 🌟 موتور هوشمند جستجو خودش منتظر می‌ماند تا آیتم لود شود
            // *و* build با هدف تازه انجام شود، سپس اسکرول دقیق می‌کند
            _ensureTargetVisible(expectedSignature: targetSignature);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade200,

      // دکمه ریست زوم (فقط هنگام زوم) + نشانِ معلقِ شماره‌ی صفحه
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isZoomed)
            FloatingActionButton.small(
              heroTag: 'zoomReset',
              onPressed: () => setState(() {
                _transformationController.value = Matrix4.identity();
                _currentScale = 1.0;
              }),
              backgroundColor: Colors.orange,
              elevation: 4,
              tooltip: 'بازگشت به اندازه اصلی',
              child: const Icon(Icons.zoom_out_map, color: Colors.white),
            ),
          const SizedBox(height: 8),
          // 🌟 نشانِ شماره‌ی صفحه: هنگام اسکرول ظاهر و بعد از توقف محو می‌شود؛
          // ضربه روی آن دیالوگِ «رفتن به صفحه» را باز می‌کند
          IgnorePointer(
            ignoring: !_showPageBadge,
            child: AnimatedOpacity(
              opacity: _showPageBadge ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: FloatingActionButton.extended(
                heroTag: 'pageBadge',
                onPressed: _openJumpToPageDialog,
                backgroundColor: Colors.black.withOpacity(0.75),
                elevation: 3,
                icon: const Icon(
                  Icons.menu_book,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'صفحه $_currentPage از ${widget.documentPages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            TelegramAudioPlayer(audioScripts: widget.audioScripts),

            Expanded(
              // ── Listener: شمارش انگشتان (قبل از gesture arena) ─────────────
              child: Listener(
                onPointerDown: (e) {
                  _pointerCount++;
                  // فقط در لحظه لمس انگشت دوم rebuild لازم است
                  if (_pointerCount == 2) setState(() {});
                },
                onPointerUp: (e) {
                  final prev = _pointerCount;
                  _pointerCount = (_pointerCount - 1).clamp(0, 10);
                  if (prev == 2) {
                    setState(() {}); // rebuild فقط هنگام خروج از pinch
                  }
                },
                onPointerCancel: (e) {
                  final prev = _pointerCount;
                  _pointerCount = (_pointerCount - 1).clamp(0, 10);
                  if (prev == 2) setState(() {});
                },
                child: InteractiveViewer(
                  transformationController: _transformationController,

                  // ── منطق pan ──────────────────────────────────────────────
                  // زوم نشده: panEnabled:false → IV هرگز با scroll رقابت نمی‌کند
                  // زوم شده:  panEnabled:true  → فقط افق pan می‌کند (PanAxis.horizontal)
                  //           scroll عمودی کاملاً دست‌نخورده باقی می‌ماند
                  panEnabled: _isZoomed,
                  panAxis: PanAxis.horizontal,
                  // scale همیشه فعال — pinch را در هر لحظه تشخیص می‌دهد
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 3.5,
                  clipBehavior: Clip.hardEdge,

                  // وقتی کاربر انگشتان را برمی‌دارد:
                  // اگر scale ≈ 1 بود → ریست کامل transform
                  onInteractionEnd: (_) {
                    final s = _transformationController.value
                        .getMaxScaleOnAxis();
                    if (s <= 1.02) {
                      _transformationController.value = Matrix4.identity();
                      if (_isZoomed) setState(() => _currentScale = 1.0);
                    }
                  },

                  child: Center(
                    child: SizedBox(
                      width: canvasWidth,
                      child: AbsorbPointer(
                        absorbing: _isPinching,
                        child: Opacity(
                          // ── نامرئی تا زمانی که jumpTo تکمیل شود ────────────
                          opacity: _isReady ? 1.0 : 0.0,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler
                                  .noScaling, // 🌟 خنثی‌کردن اسکیل فونت سیستم فقط برای این صفحه
                            ),
                            child: ScrollablePositionedList.builder(
                              itemCount: widget.documentPages.length,
                              itemScrollController: _itemScrollController,
                              itemPositionsListener: _itemPositionsListener,

                              // ── کلید رفع پرش اولیه ───────────────────────────
                              // همیشه از index 0 شروع کن؛ jumpTo در initState
                              // موقعیت را بی‌صدا (opacity=0) تنظیم می‌کند.
                              initialScrollIndex: 0,
                              initialAlignment: 0,

                              // ── pre-build آیتم‌ها قبل از ورود به viewport ────
                              // 🌟 رفع اصلیِ مشکل کندی اسکرول (ریشه‌ی واقعی):
                              // با بررسی خروجی DevTools Performance مشخص شد که
                              // بدترین فریم‌ها (بعضی تا ۱۶۰ میلی‌ثانیه!) کاملاً
                              // روی UI thread (build+layout) اتفاق می‌افتند، نه
                              // GPU/raster. علتش این مقدار ۳ برابر ارتفاع صفحه
                              // بود: چون هر «آیتم» در این لیست یک صفحه‌ی کامل
                              // کتاب است (که می‌تواند خودش چند پاراگراف/جدول
                              // داشته باشد)، یک cache extent به این بزرگی یعنی
                              // در یک جهش بزرگ (مثلاً پرش جستجو یا اسکرول تند)،
                              // فلاتر مجبور می‌شود دوجین‌ها صفحه را همزمان و در
                              // یک فریم بسازد و لایه‌بندی کند — دقیقاً همان چیزی
                              // که در داده‌های واقعی دیدیم (بیش از ۳۷۰ پاراگراف
                              // در یک فریم!). با کاهش این مقدار، فلاتر فقط کمی
                              // جلوتر از viewport واقعی می‌سازد، و بقیه‌ی صفحات
                              // در فریم‌های بعدی (طی خودِ اسکرول) به‌تدریج ساخته
                              // می‌شوند — یعنی همان هزینه‌ی کل، اما پخش‌شده روی
                              // فریم‌های بیشتر به‌جای فشرده در یک فریم.
                              // اگر هنوز حین اسکرولِ خیلی سریع، صفحه‌ی خالی/جای‌
                              // خالی برای یک لحظه دیده شد، این عدد را کمی (نه به
                              // همان ۳ برابر) افزایش دهید.
                              minCacheExtent:
                                  MediaQuery.of(context).size.height * 0.5,

                              physics: _isPinching
                                  ? const NeverScrollableScrollPhysics()
                                  : const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                vertical: 24.0,
                              ),
                              itemBuilder: (context, pageIndex) {
                                final page = widget.documentPages[pageIndex];
                                bool hasTarget =
                                    activeTarget != null &&
                                    pageIndex == _lastBuiltTargetPageIndex &&
                                    !_targetKeyClaimedThisBuild; // 🌟 اضافه شد
                                if (hasTarget)
                                  _targetKeyClaimedThisBuild =
                                      true; // 🌟 اضافه شد

                                return RepaintBoundary(
                                  child: BookPageWidget(
                                    page: page,
                                    activeTarget: activeTarget,
                                    searchSession: searchSession,
                                    canvasWidth: canvasWidth,
                                    screenWidth: MediaQuery.of(
                                      context,
                                    ).size.width,
                                    targetKey: hasTarget
                                        ? _fallbackParaKey
                                        : null,
                                    exactMatchKey: hasTarget
                                        ? _exactMatchKey
                                        : null,
                                    pageAnchorKey: hasTarget
                                        ? _pageAnchorKey
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookPageWidget extends ConsumerStatefulWidget {
  final PageData page;
  final SearchResult? activeTarget;
  final SearchSession? searchSession;
  final double canvasWidth;
  final double screenWidth;
  final GlobalKey? targetKey;
  final GlobalKey? exactMatchKey; // 🌟 اضافه شد
  final GlobalKey? pageAnchorKey; // 🌟 اضافه شد

  const BookPageWidget({
    super.key,
    required this.page,
    this.activeTarget,
    this.searchSession,
    required this.canvasWidth,
    required this.screenWidth,
    this.targetKey,
    this.exactMatchKey, // 🌟 اضافه شد
    this.pageAnchorKey, // 🌟 اضافه شد
  });

  @override
  ConsumerState<BookPageWidget> createState() => _BookPageWidgetState();
}

class _BookPageWidgetState extends ConsumerState<BookPageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── کش ویجت‌های پاراگراف ──────────────────────────────────────────────────
  //
  // مشکل: هر setState در ReadingCanvasScreen (تغییر _pointerCount، zoom، ...)
  //        باعث می‌شود build() همه BookPageWidgetهای visible دوباره اجرا شوند.
  //        بدون کش: هر build() → حلقه کامل پاراگراف‌ها + _buildOccurrenceMap → jank
  //        با کش:    هر build() → null check + return cached → ~0ms
  //
  // AutomaticKeepAliveClientMixin مانع rebuild هنگام off-screen می‌شود.
  // این کش مانع rebuild هنگام parent-setState می‌شود.
  // ترکیب هر دو: build() فقط یک بار واقعی اجرا می‌شود.
  List<Widget>? _cachedWidgets;

  @override
  void didUpdateWidget(BookPageWidget old) {
    super.didUpdateWidget(old);
    // 🌟 شرط تغییر currentIndex اضافه شد تا کش فوراً باطل شود و کلید (_targetParaKey) به پاراگراف جدید منتقل شود
    if (old.searchSession?.query != widget.searchSession?.query ||
        old.searchSession?.currentIndex != widget.searchSession?.currentIndex ||
        old.activeTarget != widget.activeTarget ||
        old.canvasWidth != widget.canvasWidth ||
        old.screenWidth != widget.screenWidth ||
        old.targetKey != widget.targetKey ||
        old.exactMatchKey != widget.exactMatchKey ||
        old.pageAnchorKey != widget.pageAnchorKey) {
      // 🌟 اضافه شد
      _cachedWidgets = null;
    }
  }

  List<Widget> _buildParaWidgets(BuildContext context) {
    final List<Widget> result = [];
    final currentBook = ref.read(activeBookProvider);

    // 🌟 رفع باگ دکمه‌های بعدی/قبلیِ پلیر صوتی:
    // قبلاً هر لینک صوتی هنگام پخش، یک پلی‌لیستِ تک‌عضوی (فقط خودش) به
    // پلیر می‌داد؛ چون دکمه‌ی بعدی/قبلی بر اساس همین پلی‌لیست کار می‌کند،
    // همیشه چیزی برای «بعدی/قبلی» وجود نداشت. اینجا، یک‌بار برای کل صفحه،
    // تمام لینک‌های صوتی (span.url با پیشوند "audio:") را به ترتیب ظاهرشدن
    // جمع‌آوری و به مسیر واقعی‌شان (فایل آفلاین یا asset) resolve می‌کنیم؛
    // همین لیست به هر InlineAudioLink پاس داده می‌شود تا دکمه‌های
    // بعدی/قبلی واقعاً بین همه‌ی صداهای این صفحه حرکت کنند.
    final List<String> pageAudioPlaylist = [];
    final Set<String> seenAudioFiles = {};
    for (final p in widget.page.paragraphs) {
      for (final s in p.spans) {
        if (s.url != null && s.url!.startsWith("audio:")) {
          final fileName = s.url!.replaceFirst("audio:", "");
          if (fileName.isNotEmpty && seenAudioFiles.add(fileName)) {
            pageAudioPlaylist.add(
              InlineAudioLink.resolveAudioPath(fileName, currentBook),
            );
          }
        }
      }
    }

    for (int pIndex = 0; pIndex < widget.page.paragraphs.length; pIndex++) {
      var para = widget.page.paragraphs[pIndex];
      final isTarget =
          widget.activeTarget != null &&
          widget.activeTarget!.pageNumber == widget.page.pageNumber &&
          widget.activeTarget!.paraIndex == pIndex;

      List<int>? rootHighlightMap;
      if (widget.searchSession?.query != null &&
          widget.searchSession!.query.isNotEmpty) {
        rootHighlightMap = _buildOccurrenceMap(
          _extractFullText(para),
          widget.searchSession!.query,
        );
      }

      Widget w = _buildParagraph(
        para,
        widget.canvasWidth,
        widget.screenWidth,
        context,
        activeBook: currentBook,
        pageInteractives: widget.page.interactives,
        interactivesPattern: widget.page.interactivesPattern, // 🌟 اضافه شد
        interactivesByText: widget.page.interactivesByText, // 🌟 اضافه شد
        pageAudioPlaylist: pageAudioPlaylist, // 🌟 اضافه شد
        rootHighlightMap: rootHighlightMap,
        mapOffset: MapOffset(),
        keyClaim:
            KeyClaim(), // 🐞 یک claim تازه به ازای هر پاراگراف (نه هر اسپن)
        activeOccurrence: isTarget
            ? widget.activeTarget!.occurrenceIndex
            : null,
        exactMatchKey: isTarget
            ? widget.exactMatchKey
            : null, // 🌟 انتقال به درون پاراگراف
      );

      if (isTarget && widget.targetKey != null) {
        w = Container(key: widget.targetKey, child: w);
      }
      result.add(w);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ??=  →  فقط اولین بار یا پس از باطل‌شدن کش، محاسبه می‌کند
    if (_cachedWidgets == null) {
      final sw = Stopwatch()..start();
      _cachedWidgets = _buildParaWidgets(context);
      sw.stop();

      // 🌟 لاگ تشخیصیِ موقت: فقط برای پیدا کردن اینکه دقیقاً کدام صفحه‌ها
      // و به چه دلیل (تعداد پاراگراف/جدول/تصویر) کند هستند. بعد از پیدا
      // شدن علت، این بلوک کامل حذف می‌شود.
      int imageCount = 0;
      int tableCount = 0;
      for (final p in widget.page.paragraphs) {
        for (final s in p.spans) {
          if (s.type == 'image') imageCount++;
          if (s.type == 'table') tableCount++;
        }
      }
      // debugPrint(
      //   '⏱️ صفحه ${widget.page.pageNumber}: ${sw.elapsedMilliseconds}ms '
      //   '| پاراگراف=${widget.page.paragraphs.length} '
      //   '| کلمه‌دیکشنری=${widget.page.interactives.length} '
      //   '| تصویر=$imageCount | جدول=$tableCount',
      // );
    }

    return Column(
      key:
          widget.pageAnchorKey, // 🌟 لنگر ثابت برای اندازه‌گیری مستقل از اسکرول
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPageDivider(widget.page.pageNumber),
        Container(
          margin: const EdgeInsets.only(bottom: 24.0, left: 8.0, right: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _cachedWidgets!,
          ),
        ),
      ],
    );
  }
}

class TextSearchMapper {
  final String rawText;
  late final String cleanText;
  late final List<int> cleanToRaw;

  TextSearchMapper(this.rawText) {
    StringBuffer clean = StringBuffer();
    cleanToRaw = [];
    int rawIdx = 0;

    while (rawIdx < rawText.length) {
      if (rawText.startsWith('{blk}', rawIdx)) {
        rawIdx += 5;
        continue;
      }
      if (rawText.startsWith('{/blk}', rawIdx)) {
        rawIdx += 6;
        continue;
      }
      clean.write(rawText[rawIdx]);
      cleanToRaw.add(rawIdx);
      rawIdx++;
    }
    cleanText = clean.toString();
  }
}

String _normalizeText(String text) {
  return text
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('\u200c', ' ');
}

String _extractFullText(ParagraphData para) {
  StringBuffer sb = StringBuffer();
  for (var span in para.spans) {
    if (span.type == "text" && span.content != null) {
      sb.write(span.content);
    } else if (span.type == "table" && span.tableRows != null) {
      for (var row in span.tableRows) {
        for (var cell in row.cells) {
          for (var cellPara in cell.paragraphs) {
            sb.write(_extractFullText(cellPara));
          }
        }
      }
    }
  }
  return sb.toString();
}

List<int> _buildOccurrenceMap(String fullText, String query) {
  TextSearchMapper mapper = TextSearchMapper(fullText);
  String nText = _normalizeText(mapper.cleanText);
  String nQuery = _normalizeText(query);
  List<int> map = List.filled(fullText.length, -1);
  if (nQuery.isEmpty) return map;

  int matchIndex = nText.indexOf(nQuery);
  int occ = 0;
  while (matchIndex != -1) {
    for (int i = 0; i < nQuery.length; i++) {
      if (matchIndex + i < mapper.cleanToRaw.length) {
        int rawIndex = mapper.cleanToRaw[matchIndex + i];
        map[rawIndex] = occ;
      }
    }
    occ++;
    matchIndex = nText.indexOf(nQuery, matchIndex + nQuery.length);
  }
  return map;
}

Widget _buildPageDivider(int pageNumber) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0, left: 8.0, right: 8.0),
    child: Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "PAGE $pageNumber",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.0)),
      ],
    ),
  );
}

String _mapFontFamily(String rawFontName) {
  String normalized = rawFontName
      .toLowerCase()
      .replaceAll("-", "")
      .replaceAll(" ", "");
  if (normalized.contains("sourcesans")) return "Source Sans 3";
  if (normalized.contains("times") || normalized.contains("major")) {
    return "Times New Roman";
  }
  if (normalized.contains("arial")) return "Arial";
  if (normalized.contains("tahoma")) return "Tahoma";
  if (normalized.contains("verdana")) return "Verdana";
  if (normalized.contains("gadugi")) return "Gadugi";
  if (normalized.contains("emoji")) return "Segoe UI Emoji";
  if (normalized.contains("zar")) return "Zar";
  if (normalized.contains("titr")) return "Titr";
  if (normalized.contains("yekan")) {
    if (normalized.contains("light")) return "YekanBakhLight";
    if (normalized.contains("extra")) return "YekanBakhExtraBold";
    return "YekanBakhBold";
  }
  return "Source Sans 3";
}

Color? _hexToColor(String? hexString) {
  if (hexString == null ||
      hexString.isEmpty ||
      hexString.toLowerCase() == 'auto') {
    return null;
  }
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return null;
  }
}

// 🐞 رفع باگ شماره‌ی لیست: تشخیص می‌دهد که آیا کل محتوای پاراگراف فقط
// یک جای‌خالیِ {blk}...{/blk} است (مثل تمرین ۰۵) یا نه (مثل تمرین ۰۴ که
// متنِ آزادِ قابل‌مشاهده قبل یا بعد از {blk} دارد). فقط در حالت اول
// می‌خواهیم شماره‌ی لیست را در نمای جمع‌شده (کنار آیکون چشم) مخفی کنیم و
// به‌جایش داخل مودالِ بازشده نشان دهیم.
bool _isWhollyOneBlank(ParagraphData para) {
  if (para.spans.length != 1) return false;
  final span = para.spans.first;
  if (span.type != "text") return false;
  final trimmed = span.content.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^\{blk\}[\s\S]*\{/blk\}$').hasMatch(trimmed);
}

Widget _buildParagraph(
  ParagraphData para,
  double canvasWidth,
  double screenWidth,
  BuildContext context, {
  bool isImageCell = false,
  bool isInsideTableCell = false,
  ParagraphData? prevPara,
  ParagraphData? nextPara,
  List<int>? rootHighlightMap,
  MapOffset? mapOffset,
  int? activeOccurrence,
  required BookModel? activeBook,
  required List<InteractiveWord> pageInteractives, // 🌟 پارامتر جدید
  RegExp? interactivesPattern, // 🌟 اضافه شد
  Map<String, InteractiveWord>? interactivesByText, // 🌟 اضافه شد
  List<String> pageAudioPlaylist = const [], // 🌟 اضافه شد
  GlobalKey? exactMatchKey, // 🌟 اضافه شد
  // 🐞 رفع کرش «RenderBox did not set its size»: وقتی occurrence فعالِ
  // جستجو بین دو اسپن یا بین دو سلولِ جدولِ همین پاراگراف شکسته می‌شود،
  // هر دو طرف باید بدانند کلید قبلاً claim شده یا نه. برای همین یک
  // KeyClaim مشترک برای کل پاراگراف (نه یکی جدا به ازای هر اسپن) از اینجا
  // به پایین‌دست پاس داده می‌شود.
  KeyClaim? keyClaim,
}) {
  if (para.spans.isEmpty ||
      (para.spans.length == 1 &&
          para.spans.first.type == "text" &&
          (para.spans.first.content == "\n" ||
              (para.spans.first.content).trim().isEmpty))) {
    return const SizedBox.shrink();
  }

  mapOffset ??= MapOffset();
  keyClaim ??= KeyClaim();

  // 🐞 رفع باگ شماره‌ی لیست: یک‌بار همین اول محاسبه می‌شود تا هم برای
  // پنهان‌کردن شماره از نمای جمع‌شده و هم برای پاس‌دادنش به مودالِ
  // جای‌خالی (وقتی کل پاراگراف یک {blk} است) استفاده شود.
  final bool wholeParaIsBlank = _isWhollyOneBlank(para);

  List<Object> blockElements = [];
  List<InlineSpan> currentInlineSpans = [];
  TextAlign textAlign = TextAlign.left;
  if (para.alignment == "C") textAlign = TextAlign.center;
  if (para.alignment == "R") textAlign = TextAlign.right;
  if (para.alignment == "J") textAlign = TextAlign.justify;

  // 🌟 بررسی وجود متن معنادار در پاراگراف برای تشخیص حالت ترکیبی (تصویر + متن)
  bool hasText = para.spans.any(
    (span) => span.type == "text" && (span.content ?? "").trim().isNotEmpty,
  );

  // 🌟 اگر در جدول هستیم و متن هم وجود دارد، تصاویر به‌صورت Inline رندر شوند
  bool renderInline = isInsideTableCell && hasText;

  void flushText() {
    if (currentInlineSpans.isNotEmpty) {
      blockElements.add(
        WrappableText(
          text: TextSpan(children: List.from(currentInlineSpans)),
          textAlign: textAlign,
        ),
      );
      currentInlineSpans.clear();
    }
  }

  bool isLargeScreen = screenWidth >= 600;
  // 🌟 جادوی تورفتگی خط اول (First Line Indent)
  if (para.indentFirstLine != null && para.indentFirstLine! > 0) {
    currentInlineSpans.add(
      WidgetSpan(child: SizedBox(width: para.indentFirstLine)),
    );
  }

  for (var span in para.spans) {
    if (span.type == "text") {
      String content = span.content; // ✅ هندل کردن حالت Null

      List<int>? localMap;
      if (rootHighlightMap != null &&
          content.isNotEmpty &&
          mapOffset.value + content.length <= rootHighlightMap.length) {
        localMap = rootHighlightMap.sublist(
          mapOffset.value,
          mapOffset.value + content.length,
        );
      }
      currentInlineSpans.addAll(
        _buildStyledInteractiveText(
          span,
          pageInteractives, // 🌟 استفاده از اینتراکتیوهای سطح صفحه
          context,
          isInsideTableCell: isInsideTableCell,
          para: para,
          localMap: localMap,
          activeOccurrence: activeOccurrence,
          exactMatchKey: exactMatchKey, // 🌟 انتقال به انجین متن
          interactivesPattern: interactivesPattern, // 🌟 اضافه شد
          interactivesByText: interactivesByText, // 🌟 اضافه شد
          pageAudioPlaylist: pageAudioPlaylist, // 🌟 اضافه شد
          keyClaim: keyClaim, // 🐞 مشترک بین همه‌ی اسپن‌های همین پاراگراف
          // 🐞 رفع باگ شماره‌ی لیست: فقط وقتی کل پاراگراف یک {blk} است
          // شماره را تا مودال رد کن؛ برای پاراگراف‌های حالت تمرین-۰۴
          // (متنِ آزادِ قابل‌مشاهده + {blk}) چیزی رد نمی‌شود چون شماره
          // همین‌جا (بالاتر) کنار متنِ آزاد نشان داده می‌شود.
          listMarker: wholeParaIsBlank ? para.listMarker : null,
        ),
      );
      mapOffset.value += content.length;
    } else if (span.type == "image") {
      if (!isLargeScreen) {
        flushText();
      }
      String imagePath = span.url ?? span.content; // ✅ هندل کردن حالت Null
      if (imagePath.isNotEmpty) {
        if (renderInline) {
          if (span.url!.contains('p8_s1_img7.png')) {
            String test = '';
          }
          // 🌟 حالت اول: قرار دادن تصویر به صورت Inline در کنار متن (بدون فراخوانی flushText)
          // اگر در موتور C# ابعاد تصویر (عرض و ارتفاع) را از فایل ورد استخراج کرده‌اید،
          // می‌توانید از آن‌ها در اینجا استفاده کنید. در غیر این صورت روی یک ارتفاع منطقی محدودش می‌کنیم.
          int? inlineWidth =
              span.imageWidth; // (اختیاری) اگر این فیلد را در خروجی JSON دارید
          int? inlineHeight =
              span.imageHeight; // (اختیاری) اگر این فیلد را در خروجی JSON دارید

          currentInlineSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // اگر ارتفاع تصویر در دیتای ورد موجود بود همان را اعمال کن،
                  // در غیر این صورت نهایتاً 35 پیکسل (حدوداً ارتفاع یک خط متن با فاصله) فضا بگیرد.
                  maxHeight: inlineHeight?.toDouble() ?? 35.0,
                  maxWidth:
                      inlineWidth?.toDouble() ??
                      screenWidth * 0.5, // جلوگیری از اشغال کل عرض
                ),
                child: _buildLocalImage(
                  imagePath,
                  isMobile: !isLargeScreen,
                  screenWidth: screenWidth,
                  isImageCell: isImageCell,
                  activeBook: activeBook,
                  context: context,
                ),
              ),
            ),
          );
        } else {
          // 🌟 حالت دوم: منطق قبلی برای تصویر مستقل در یک پاراگراف مجزا
          flushText();
          FCFloat floatAlign = FCFloat.none;
          if (isLargeScreen) {
            if (span.floatPosition == 'left') floatAlign = FCFloat.left;
            if (span.floatPosition == 'right') floatAlign = FCFloat.right;
          }
          blockElements.add(
            Floatable(
              float: floatAlign,
              clear: floatAlign == FCFloat.none ? FCClear.both : FCClear.none,
              padding: floatAlign == FCFloat.left
                  ? const EdgeInsets.only(right: 16.0, bottom: 8.0, top: 4.0)
                  : floatAlign == FCFloat.right
                  ? const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 4.0)
                  : EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 8.0),
              child: floatAlign == FCFloat.none
                  ? Center(
                      child: _buildLocalImage(
                        imagePath,
                        isMobile: !isLargeScreen,
                        screenWidth: screenWidth,
                        isImageCell: isImageCell,
                        activeBook: activeBook,
                        context: context,
                      ),
                    )
                  : _buildLocalImage(
                      imagePath,
                      isMobile: false,
                      screenWidth: screenWidth,
                      isImageCell: isImageCell,
                      activeBook: activeBook,
                      context: context,
                    ),
            ),
          );
        }
      }
    } else if (span.type == "table") {
      flushText();
      blockElements.add(
        _buildTable(
          span,
          canvasWidth,
          screenWidth,
          context,
          rootHighlightMap,
          mapOffset,
          activeOccurrence,
          activeBook,
          pageInteractives,
          isNestedTable: isInsideTableCell,
          exactMatchKey: exactMatchKey, // 🌟 انتقال به جدول
          interactivesPattern: interactivesPattern, // 🌟 اضافه شد
          interactivesByText: interactivesByText, // 🌟 اضافه شد
          pageAudioPlaylist: pageAudioPlaylist, // 🌟 اضافه شد
          keyClaim: keyClaim, // 🐞 مشترک بین پاراگراف و همه‌ی سلول‌های جدولش
        ),
      );
    }
  }

  flushText();

  Widget paragraphContent = TranslatableContentWrapper(
    translationFa: para.translationFa,
    translationAr: para.translationAr,
    originalContent: Directionality(
      textDirection: para.direction == "RTL"
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: FloatColumn(
        children: blockElements,
        crossAxisAlignment: CrossAxisAlignment.stretch,
      ),
    ),
  );
  // 🌟 لیست‌ها: مارکر با تورفتگی معلق (hanging indent) مانند Word
  // 🐞 رفع باگ شماره‌ی لیست: اگر کل پاراگراف فقط یک {blk} است (تمرین ۰۵)،
  // شماره را اینجا (کنار آیکون چشمِ جمع‌شده) نشان نده؛ به‌جایش بالاتر
  // به InteractiveBlankWord پاس داده شده تا داخل مودال prepend شود.
  if (para.listMarker != null &&
      para.listMarker!.isNotEmpty &&
      !wholeParaIsBlank) {
    final bool rtl = para.direction == "RTL";
    const double indentStep = 22.0; // تورفتگی هر سطح
    const double markerWidth = 28.0; // عرض ناحیه‌ی مارکر
    final double levelIndent = para.listLevel * indentStep;

    paragraphContent = Padding(
      padding: EdgeInsets.only(
        left: rtl ? 0 : levelIndent,
        right: rtl ? levelIndent : 0,
      ),
      child: Row(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: markerWidth,
            child: Text(
              para.listMarker!,
              textAlign: rtl ? TextAlign.left : TextAlign.right,
              style: const TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: paragraphContent),
        ],
      ),
    );
  }
  bool hasBgColor = para.fillColor != null && para.fillColor!.isNotEmpty;

  double defaultBoxPadding = 6.0,
      internalTopPadding = 0.0,
      internalBottomPadding = 0.0,
      externalTopMargin = 0.0,
      externalBottomMargin = 0.0;
  bool sameColorBefore =
      prevPara != null && prevPara.fillColor == para.fillColor && hasBgColor;
  bool sameColorAfter =
      nextPara != null && nextPara.fillColor == para.fillColor && hasBgColor;
  double spaceBefore = isImageCell ? 0.0 : para.spaceBefore;
  double spaceAfter = isImageCell ? 0.0 : para.spaceAfter;

  if (hasBgColor) {
    internalTopPadding = sameColorBefore
        ? spaceBefore
        : (defaultBoxPadding + spaceBefore);
    internalBottomPadding = sameColorAfter
        ? spaceAfter
        : (defaultBoxPadding + spaceAfter);
  } else {
    externalTopMargin = spaceBefore;
    externalBottomMargin = spaceAfter;
  }

  // 🌟 اعمال فاصله‌های تورفتگی کلی چپ و راست
  double leftMargin = (para.indentLeft != null && para.indentLeft! > 0)
      ? para.indentLeft!
      : 0.0;
  double rightMargin = (para.indentRight != null && para.indentRight! > 0)
      ? para.indentRight!
      : 0.0;
  double topMargin = externalTopMargin > 0 ? externalTopMargin : 0.0;
  double bottomMargin = externalBottomMargin > 0 ? externalBottomMargin : 0.0;

  double topInternal = internalTopPadding > 0 ? internalTopPadding : 0.0;
  double bottomInternal = internalBottomPadding > 0
      ? internalBottomPadding
      : 0.0;
  bool showBorder =
      para.borders != null &&
      para.borders!.val != 'none' &&
      para.borders!.val != 'nil';

  if (hasBgColor || showBorder) {
    Color borderColor =
        _hexToColor(para.borders?.color) ?? Colors.grey.shade600;
    double borderWidth = para.borders?.width ?? 1.5;
    paragraphContent = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _hexToColor(para.fillColor),
        border: showBorder
            ? Border(
                left: BorderSide(color: borderColor, width: borderWidth),
                right: BorderSide(color: borderColor, width: borderWidth),
                top: sameColorBefore
                    ? BorderSide.none
                    : BorderSide(color: borderColor, width: borderWidth),
                bottom: sameColorAfter
                    ? BorderSide.none
                    : BorderSide(color: borderColor, width: borderWidth),
              )
            : null,
        borderRadius: showBorder
            ? BorderRadius.only(
                topLeft: sameColorBefore
                    ? Radius.zero
                    : const Radius.circular(6),
                topRight: sameColorBefore
                    ? Radius.zero
                    : const Radius.circular(6),
                bottomLeft: sameColorAfter
                    ? Radius.zero
                    : const Radius.circular(6),
                bottomRight: sameColorAfter
                    ? Radius.zero
                    : const Radius.circular(6),
              )
            : null,
      ),
      padding: (isInsideTableCell && showBorder)
          ? EdgeInsets.zero
          : EdgeInsets.only(
              left: isInsideTableCell ? 2.0 : 10.0,
              right: isInsideTableCell ? 2.0 : 10.0,
              top: topInternal,
              bottom: bottomInternal,
            ),
      child: paragraphContent,
    );
  }

  return Padding(
    padding: EdgeInsets.only(
      top: topMargin, // 🌟 استفاده از مقادیر ایمن
      bottom: bottomMargin, // 🌟 استفاده از مقادیر ایمن
      left: leftMargin, // 🌟 اعمال تورفتگی چپ
      right: rightMargin, // 🌟 اعمال تورفتگی راست
    ),
    child: paragraphContent,
  );
}

Widget _buildTable(
  SpanData tableSpan,
  double canvasWidth,
  double screenWidth,
  BuildContext context,
  List<int>? rootMap,
  MapOffset? mapOffset,
  int? activeOcc,
  BookModel? activeBook,
  List<InteractiveWord> pageInteractives, {
  bool isNestedTable = false,
  GlobalKey? exactMatchKey,
  RegExp? interactivesPattern,
  Map<String, InteractiveWord>? interactivesByText,
  List<String> pageAudioPlaylist = const [],
  KeyClaim? keyClaim, // 🐞 مشترک بین پاراگراف مادر و همه‌ی سلول‌های این جدول
}) {
  final bool isLargeScreen = screenWidth > 600;
  final String rawStyle =
      (tableSpan.tableStyleId ?? tableSpan.tableStyleName ?? "")
          .toLowerCase()
          .replaceAll(" ", "")
          .replaceAll("_", "");

  // 🌟 اول فیلدهای declarativeِ جدید، بعد فال‌بکِ نام استایل (سازگاری با دادهٔ قدیم)
  final String strategy = tableSpan.responsiveStrategy ?? "";
  final String? borderVal = tableSpan.borders?.val?.toLowerCase();

  final bool isBorderedTable =
      strategy == "horizontalScroll" || rawStyle.contains("borderedtable");
  final bool isColumnStack =
      strategy == "stack" ||
      tableSpan.layoutReflow == "stack" ||
      rawStyle.contains("columnstack");
  final bool isDotted =
      strategy == "collapseToCards" ||
      borderVal == "dotted" ||
      rawStyle.contains("dottedtable");

  final bool hideBorders =
      isDotted || isColumnStack || rawStyle.contains("tablegrid");
  final bool applyColumnStack = isColumnStack && !isLargeScreen;

  double defaultBorderWidth =
      tableSpan.borderWidth ?? (isBorderedTable ? 1.0 : 0.5);
  Color defaultBorderColor =
      _hexToColor(tableSpan.borders?.color) ??
      (isBorderedTable ? Colors.black : Colors.grey.shade400);

  final bool showBorders =
      !hideBorders &&
      (isBorderedTable ||
          tableSpan.hasBorders == "true" ||
          (borderVal != null &&
              borderVal != "none" &&
              borderVal != "nil" &&
              borderVal != "dotted"));

  TableCellVerticalAlignment getVAlign(String? vAlign) {
    if (vAlign == "center") return TableCellVerticalAlignment.middle;
    if (vAlign == "bottom") return TableCellVerticalAlignment.bottom;
    return TableCellVerticalAlignment.top;
  }

  List<Widget> rowWidgets = [];
  List<List<Widget>> allGridCells = [];

  for (int rowIndex = 0; rowIndex < tableSpan.tableRows.length; rowIndex++) {
    var row = tableSpan.tableRows[rowIndex];
    List<Widget> cellWidgets = [];
    bool hasAnyImage = false, hasAnyText = false;

    for (var cell in row.cells) {
      bool isImg = cell.paragraphs.any(
        (p) => p.spans.any((s) => s.type == "image"),
      );
      bool isEmpty = cell.paragraphs.every(
        (p) =>
            p.spans.isEmpty ||
            (p.spans.length == 1 &&
                p.spans.first.type == "text" &&
                (p.spans.first.content ?? "").trim().isEmpty),
      );
      if (isImg) {
        hasAnyImage = true;
      } else if (!isEmpty) {
        hasAnyText = true;
      }
    }
    bool isImageRow = hasAnyImage && !hasAnyText;

    Map<int, TableColumnWidth> columnWidths = {};

    // تنظیمات داینامیک مرزها برای هر ردیف
    double currentTopWidth = defaultBorderWidth;
    double currentBottomWidth = defaultBorderWidth;
    double currentLeftWidth = defaultBorderWidth;
    double currentRightWidth = defaultBorderWidth;
    double currentInsideVWidth = defaultBorderWidth;

    Color currentTopColor = defaultBorderColor;
    Color currentBottomColor = defaultBorderColor;
    Color currentLeftColor = defaultBorderColor;
    Color currentRightColor = defaultBorderColor;
    Color currentInsideVColor = defaultBorderColor;

    for (var cell in row.cells) {
      if (cell.borders != null) {
        var cb = cell.borders;
        if (cb?.bottom?.width != null) {
          currentBottomWidth = cb!.bottom!.width!.toDouble();
        }
        if (cb?.top?.width != null) {
          currentTopWidth = cb!.top!.width!.toDouble();
        }
        if (cb!.left?.width != null) {
          currentLeftWidth = cb.left!.width!.toDouble();
        }
        if (cb.right?.width != null) {
          currentRightWidth = cb.right!.width!.toDouble();
        }

        if (cb.bottom?.color != null) {
          currentBottomColor =
              _hexToColor(cb.bottom!.color) ?? defaultBorderColor;
        }
        if (cb.top?.color != null) {
          currentTopColor = _hexToColor(cb.top!.color) ?? defaultBorderColor;
        }
        if (cb.left?.color != null) {
          currentLeftColor = _hexToColor(cb.left!.color) ?? defaultBorderColor;
        }
        if (cb.right?.color != null) {
          currentRightColor =
              _hexToColor(cb.right!.color) ?? defaultBorderColor;
        }
      }
      try {
        var dynamicCell = cell as dynamic;
        if (dynamicCell.borderBottomWidth != null) {
          currentBottomWidth = dynamicCell.borderBottomWidth.toDouble();
        }
        if (dynamicCell.borderTopWidth != null) {
          currentTopWidth = dynamicCell.borderTopWidth.toDouble();
        }
        if (dynamicCell.borderLeftWidth != null) {
          currentLeftWidth = dynamicCell.borderLeftWidth.toDouble();
        }
        if (dynamicCell.borderRightWidth != null) {
          currentRightWidth = dynamicCell.borderRightWidth.toDouble();
        }
      } catch (_) {}
    }

    // زاپاس ردیف اول برای جداول استاندارد ورد
    if (rowIndex == 0 &&
        currentBottomWidth == defaultBorderWidth &&
        isBorderedTable) {
      currentBottomWidth = defaultBorderWidth * 2.2;
    }

    for (int i = 0; i < row.cells.length; i++) {
      var cell = row.cells[i];
      List<Widget> cellParagraphs = [];

      bool hasTextInCell = cell.paragraphs.any(
        (p) => p.spans.any(
          (s) =>
              s.type == "text" &&
              s.content != null &&
              s.content.trim().isNotEmpty,
        ),
      );
      bool hasImageInCell = cell.paragraphs.any(
        (p) => p.spans.any((s) => s.type == "image"),
      );
      bool isImageCell = hasImageInCell && !hasTextInCell;

      for (int pIndex = 0; pIndex < cell.paragraphs.length; pIndex++) {
        cellParagraphs.add(
          _buildParagraph(
            cell.paragraphs[pIndex],
            canvasWidth,
            screenWidth,
            context,
            isImageCell: isImageCell,
            isInsideTableCell: true,
            prevPara: pIndex > 0 ? cell.paragraphs[pIndex - 1] : null,
            nextPara: pIndex < cell.paragraphs.length - 1
                ? cell.paragraphs[pIndex + 1]
                : null,
            rootHighlightMap: rootMap,
            mapOffset: mapOffset,
            activeOccurrence: activeOcc,
            activeBook: activeBook,
            pageInteractives: pageInteractives,
            exactMatchKey: exactMatchKey,
            interactivesPattern: interactivesPattern,
            interactivesByText: interactivesByText,
            pageAudioPlaylist: pageAudioPlaylist,
            keyClaim: keyClaim, // 🐞 همان claim مشترکِ کل پاراگراف/جدول
          ),
        );
      }

      EdgeInsetsGeometry cellPadding = isImageCell
          ? const EdgeInsets.all(2.0)
          : EdgeInsets.only(
              top: cell.paddingTop ?? 4.0,
              bottom: cell.paddingBottom ?? 4.0,
              left: cell.paddingLeft ?? 8.0,
              right: cell.paddingRight ?? 8.0,
            );

      Widget cellContent = Container(
        padding: cellPadding,
        decoration: BoxDecoration(color: _hexToColor(cell.fillColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: cellParagraphs,
        ),
      );

      cellWidgets.add(cellContent);

      if (cell.widthPercent != null && cell.widthPercent! > 0) {
        columnWidths[i] = FlexColumnWidth(cell.widthPercent!);
      } else {
        columnWidths[i] = const FlexColumnWidth(1);
      }
    }

    if (applyColumnStack) {
      allGridCells.add(cellWidgets);
    } else {
      if (isLargeScreen || isBorderedTable || isImageRow || isNestedTable) {
        List<Widget> tableCellWidgets = [];
        for (int i = 0; i < cellWidgets.length; i++) {
          tableCellWidgets.add(
            TableCell(
              verticalAlignment: getVAlign(row.cells[i].vAlign),
              child: cellWidgets[i],
            ),
          );
        }

        final BorderSide topSide = BorderSide(
          color: currentTopColor,
          width: currentTopWidth,
        );
        final BorderSide bottomSide = BorderSide(
          color: currentBottomColor,
          width: currentBottomWidth,
        );
        final BorderSide leftSide = BorderSide(
          color: currentLeftColor,
          width: currentLeftWidth,
        );
        final BorderSide rightSide = BorderSide(
          color: currentRightColor,
          width: currentRightWidth,
        );
        final BorderSide insideVSide = BorderSide(
          color: currentInsideVColor,
          width: currentInsideVWidth,
        );

        rowWidgets.add(
          Table(
            columnWidths: columnWidths,
            border: showBorders
                ? TableBorder(
                    // 🌟 خط بالایی کل جدول فقط و فقط توسط ردیف اول رسم می‌شود
                    top: rowIndex == 0 ? topSide : BorderSide.none,
                    bottom: bottomSide,
                    left: leftSide,
                    right: rightSide,
                    verticalInside: insideVSide,
                  )
                : const TableBorder.symmetric(),
            children: [TableRow(children: tableCellWidgets)],
          ),
        );
      } else {
        rowWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cellWidgets,
          ),
        );
      }
    }
  }

  if (applyColumnStack && allGridCells.isNotEmpty) {
    int maxCols = allGridCells.fold(
      0,
      (max, rowCells) => rowCells.length > max ? rowCells.length : max,
    );
    for (int colIndex = 0; colIndex < maxCols; colIndex++) {
      List<Widget> columnCells = [];
      for (int rowIndex = 0; rowIndex < allGridCells.length; rowIndex++) {
        if (colIndex < allGridCells[rowIndex].length) {
          columnCells.add(allGridCells[rowIndex][colIndex]);
        }
      }
      rowWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columnCells,
          ),
        ),
      );
    }
  }

  // 🌟 اصلاح نهایی: حذف پارامتر border از کانتینر بیرونی برای جلوگیری از تداخل و دابل‌بوردر شدن سایدها
  Widget tableContainer = Container(
    margin: isNestedTable
        ? const EdgeInsets.only(top: 2.0)
        : const EdgeInsets.symmetric(vertical: 12.0),
    decoration: BoxDecoration(
      color: _hexToColor(tableSpan.fillColor),
      // کدهای تداخل‌زا حذف شدند 💥
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    ),
  );

  if (isBorderedTable && tableSpan.tableWidthPercent != null) {
    if (isLargeScreen) {
      Alignment tableAlign = Alignment.centerLeft;
      if (tableSpan.tableAlignment == "center") tableAlign = Alignment.center;
      if (tableSpan.tableAlignment == "right") {
        tableAlign = Alignment.centerRight;
      }
      return Align(
        alignment: tableAlign,
        child: SizedBox(
          width: canvasWidth * (tableSpan.tableWidthPercent! / 100),
          child: tableContainer,
        ),
      );
    } else {
      if (tableSpan.tableWidthPercent! < 40) {
        return Align(
          alignment: Alignment.center,
          child: SizedBox(width: canvasWidth * 0.6, child: tableContainer),
        );
      }
      return tableContainer;
    }
  }
  return tableContainer;
}

List<InlineSpan> _buildStyledInteractiveText(
  SpanData span,
  List<InteractiveWord> interactives,
  BuildContext context, {
  bool isInsideTableCell = false,
  required ParagraphData para,
  List<int>? localMap,
  int? activeOccurrence,
  GlobalKey? exactMatchKey,
  RegExp? interactivesPattern,
  Map<String, InteractiveWord>? interactivesByText,
  List<String> pageAudioPlaylist = const [],
  KeyClaim? keyClaim, // 🐞 مشترک بین همه‌ی اسپن‌های همین پاراگراف
  String?
  listMarker, // 🐞 فقط برای پاراگراف‌های کاملاً-یک-بلانک؛ تا مودال رد می‌شود
}) {
  double fontSize = 14.0;
  String? fontFamily;
  for (var marker in span.markers) {
    if (marker.startsWith("sz:")) {
      double? parsedSize = double.tryParse(marker.substring(3));
      if (parsedSize != null) fontSize = parsedSize / 2;
    } else if (marker.startsWith("fn:")) {
      fontFamily = _mapFontFamily(marker.substring(3));
    }
  }

  Color? effectiveBgColor =
      _hexToColor(span.fillColor) ?? _hexToColor(para.fillColor);
  Color interactiveColor = Colors.blue;
  if (effectiveBgColor != null) {
    interactiveColor = effectiveBgColor.computeLuminance() < 0.4
        ? Colors.lightBlueAccent
        : Colors.blue.shade900;
  }
  Color? customTextColor = _hexToColor(span.textColor);
  bool isAudioLink = span.url != null && span.url!.startsWith("audio:");
  if (isAudioLink) customTextColor = interactiveColor;

  // 🌟 اصلاح اساسی: تشخیص بسیار منعطف‌تر برای رسم باکس اطراف تکه متن
  final String bordersStr =
      span.hasBorders?.toString().toLowerCase().trim() ?? "false";
  bool hasBorderFlag = bordersStr == "true" || bordersStr == "1";
  bool hasBorderObject = span.borders != null;

  // اگر در JSON به هر شکلی به حاشیه اشاره شده باشد (یا فلگ true باشد یا آبجکت borders وجود داشته باشد)
  bool isInlineBorder = hasBorderFlag || hasBorderObject;

  TextStyle baseStyle = TextStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    color: customTextColor ?? Colors.black87,
    height: para.lineSpacing ?? 1.3, // 🌟 به‌جای عددِ ثابت
    // 🌟 اگر قرار است باکس داشته باشیم، رنگ پس‌زمینه را به Container می‌دهیم نه به استایلِ متن
    backgroundColor: !isInlineBorder ? _hexToColor(span.fillColor) : null,
    fontWeight: span.markers.contains("b")
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: span.markers.contains("i") ? FontStyle.italic : FontStyle.normal,
    decoration: (span.markers.contains("u"))
        ? TextDecoration.underline
        : TextDecoration.none,
  );

  List<InlineSpan> interactiveSpans = [];
  if (isAudioLink) {
    interactiveSpans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineAudioLink(
          fileName: span.url!.replaceFirst("audio:", ""),
          text: span.content ?? "",
          baseColor: interactiveColor,
          playlist: pageAudioPlaylist,
        ),
      ),
    );
  } else {
    interactiveSpans = TextRenderEngine.buildInteractiveText(
      span.content ?? "",
      interactives,
      context,
      baseStyle,
      interactiveColor: interactiveColor,
      localHighlightMap: localMap,
      activeOccurrence: activeOccurrence,
      translationFa: para.translationFa, // 🌟 حفظ پشتیبانی از ترجمه‌های دوزبانه
      translationAr: para.translationAr,
      innerSpans: span.innerSpans,
      exactMatchKey: isInlineBorder ? null : exactMatchKey,
      // 🌟 وقتی محتوا قرار است داخل باکسِ border در یک Text.rich تودرتو
      // بنشیند (خط ۱۶۵۹ به بعد)، کلید را نمی‌دهیم تا WidgetSpanِ دومی
      // ساخته نشود. برای همه‌ی حالت‌های دیگر (آیکون چشم، جای‌خالی،
      // لینک صوتی، کلمه‌ی معمولی) کلید واقعی داده می‌شود و دقتِ
      // کلمه‌به‌کلمه‌ی قبلی برمی‌گردد.
      interactivesPattern: interactivesPattern,
      interactivesByText: interactivesByText,
      sharedKeyClaim: keyClaim, // 🐞 رفع کرش: claim مشترکِ سطح پاراگراف
      listMarker: listMarker, // 🐞 فقط برای پاراگراف‌های کاملاً-یک-بلانک
    );
  }

  // 🌟 ساختاردهی به باکسی که در UI رندر می‌شود
  if (isInlineBorder) {
    return [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: isInsideTableCell
              ? const EdgeInsets.symmetric(horizontal: 0.0, vertical: 1.0)
              : const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          margin: isInsideTableCell
              ? const EdgeInsets.symmetric(horizontal: 0.0) //EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: _hexToColor(span.fillColor), // تزریق رنگ پس‌زمینه به باکس
            border: Border.all(
              color: _hexToColor(span.borders?.color) ?? Colors.grey.shade600,
              width:
                  span.borders?.width ??
                  1.2, // خواندن ضخامت از JSON در صورت وجود
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text.rich(TextSpan(children: interactiveSpans)),
        ),
      ),
    ];
  }

  return interactiveSpans;
}

Widget _buildLocalImage(
  String imageName, {
  required bool isMobile,
  required double screenWidth,
  required bool isImageCell,
  required BookModel? activeBook, // 🌟 اضافه شد
  required BuildContext context, // 🌟 اضافه شد برای محاسبه‌ی cacheWidth
}) {
  String fallbackPath = 'assets/data/testbook/images/$imageName';
  File? localFile;

  // 🌟 هوشمندی: خواندن از فایل آفلاین
  if (activeBook != null && activeBook.activeJsonPath.isNotEmpty) {
    final bookFolderPath = File(activeBook.activeJsonPath).parent.path;
    final possibleFile = File('$bookFolderPath/$imageName');

    if (possibleFile.existsSync()) {
      localFile = possibleFile;
    }
  }

  final double? logicalWidth = null;
  // (isMobile) ? screenWidth * 0.85 : null;

  // 🌟 رفع یک منبع واقعی و بزرگ جنک (تأییدشده با DevTools: میانگین ۲۶۷ms
  // به ازای هر تصویر!): بدون cacheWidth، فلاتر تصویر را در رزولوشن اصلی
  // فایل دیکود می‌کند، حتی اگر فایل چند برابر بزرگ‌تر از چیزی باشد که روی
  // صفحه نشان داده می‌شود. این هم دیکود را کند می‌کند و هم حافظه‌ی زیادی
  // برای یک بیت‌مپ بزرگ‌تر از نیاز نگه می‌دارد — که مستقیماً فشار GC را هم
  // بالا می‌برد. با محدود کردن cacheWidth به اندازه‌ی واقعیِ نمایش (ضرب‌شده
  // در devicePixelRatio دستگاه)، فلاتر مستقیماً در همان اندازه‌ی کوچک
  // دیکود می‌کند.
  final double dpr = MediaQuery.of(context).devicePixelRatio;
  final int cacheWidth = ((logicalWidth ?? screenWidth) * dpr).round().clamp(
    1,
    4000,
  );

  return Padding(
    padding: EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 4.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(isImageCell ? 0 : 6),
      child: localFile != null
          ? Image.file(
              localFile,
              fit: BoxFit.contain,
              width: logicalWidth,
              cacheWidth: cacheWidth, // 🌟 اضافه شد
              errorBuilder: (context, error, stackTrace) =>
                  _errorImage(imageName),
            )
          : Image.asset(
              fallbackPath,
              fit: BoxFit.contain,
              width: logicalWidth,
              cacheWidth: cacheWidth, // 🌟 اضافه شد
              errorBuilder: (context, error, stackTrace) =>
                  _errorImage(imageName),
            ),
    ),
  );
}
// متد کمکی برای جلوگیری از تکرار کد خطا

Widget _errorImage(String imageName) {
  return Container(
    padding: const EdgeInsets.all(16),
    color: Colors.grey[200],
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image, color: Colors.red),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            "Image not found: $imageName",
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class InlineAudioLink extends ConsumerWidget {
  final String fileName;
  final String text;
  final Color baseColor;
  // 🌟 پلی‌لیستِ همه‌ی فایل‌های صوتیِ این صفحه (مسیرهای resolve‌شده)، تا
  // دکمه‌های بعدی/قبلی در پلیر واقعاً چیزی برای رفتن داشته باشند. قبلاً هر
  // لینک هنگام پخش فقط خودش را به‌عنوان یک پلی‌لیستِ تک‌عضوی می‌فرستاد، پس
  // دکمه‌ی بعدی/قبلی همیشه در انتهای لیست بود و کاری نمی‌کرد.
  final List<String> playlist;

  const InlineAudioLink({
    super.key,
    required this.fileName,
    required this.text,
    required this.baseColor,
    this.playlist = const [],
  });

  // 🌟 رفع مشکل لرزش/جنکِ اسکرول هنگام پخش صدا:
  //
  // قبلاً این ویجت با `ref.watch(audioPlayerProvider)` کل شیء وضعیت پلیر
  // را نگاه می‌کرد. چون `position` چندین بار در ثانیه تغییر می‌کند، این
  // یعنی همه‌ی لینک‌های صوتی مونتاژشده روی صفحه (حتی آن‌هایی که اصلاً در
  // حال پخش نیستند و AutomaticKeepAliveClientMixin آن‌ها را زنده نگه
  // داشته) با هر تیکِ پخش دوباره rebuild می‌شدند — و هر rebuild هم شامل
  // یک چک هم‌زمانِ فایل‌سیستم (`existsSync`) و خواندن از GetStorage بود.
  // نتیجه دقیقاً همان لرزشی بود که هنگام اسکرول + پخش صدا حس می‌کردید،
  // چون این کارها روی UI thread رقیب اسکرول می‌شدند.
  //
  // راه‌حل: فقط فیلدهای کم‌تغییر (currentPath، isPlaying) را همیشه watch
  // می‌کنیم؛ فیلد پرتغییر (position/duration) را فقط وقتی این لینکِ خاص
  // همان فایل در حال پخش است می‌خوانیم. یعنی از بین ده‌ها لینک صوتیِ
  // ممکن روی صفحه، فقط همان یکی که واقعاً پخش می‌شود با هر تیک rebuild
  // می‌شود، نه همه‌شان.
  static final Map<String, String> _resolvedPathCache = {};

  // 🌟 اکنون static و public (بدون آندرلاین) تا _buildParaWidgets هم
  // بتواند برای ساختن پلی‌لیستِ کل صفحه از همین منطق resolve استفاده کند
  // (و از همان کش مشترک بهره ببرد، بدون نیاز به existsSync تکراری).
  static String resolveAudioPath(String fileName, BookModel? activeBook) {
    final cacheKey = '${activeBook?.id ?? ''}::$fileName';
    return _resolvedPathCache.putIfAbsent(cacheKey, () {
      String targetPath = 'assets/data/audio/$fileName';
      if (activeBook != null && activeBook.activeJsonPath.isNotEmpty) {
        final bookFolderPath = File(activeBook.activeJsonPath).parent.path;
        final localAudioFile = File('$bookFolderPath/$fileName');
        if (localAudioFile.existsSync()) {
          targetPath = localAudioFile.path;
        }
      }
      return targetPath;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // فیلدهای کم‌تغییر — فقط وقتی پخش شروع/متوقف/عوض شود rebuild می‌کند
    final currentPath = ref.watch(
      audioPlayerProvider.select((s) => s.currentPath),
    );
    final isPlayingGlobal = ref.watch(
      audioPlayerProvider.select((s) => s.isPlaying),
    );
    final activeBook = ref.watch(activeBookProvider);

    // 🌟 دیگر هر بار existsSync صدا زده نمی‌شود؛ فقط یک‌بار برای هر فایل
    final targetPath = InlineAudioLink.resolveAudioPath(fileName, activeBook);

    bool isCurrent = currentPath == targetPath;
    bool isPlaying = isCurrent && isPlayingGlobal;

    final storagePosKey = 'pos_$targetPath';
    final storageDurKey = 'dur_$targetPath';

    int currentPosMs;
    int currentDurMs;
    if (isCurrent) {
      // 🌟 فقط همینجا (فقط برای لینکِ در حال پخش) فیلد پرتغییر را watch کن
      currentPosMs = ref.watch(
        audioPlayerProvider.select((s) => s.position.inMilliseconds),
      );
      currentDurMs = ref.watch(
        audioPlayerProvider.select((s) => s.duration.inMilliseconds),
      );
      if (currentDurMs <= 0) {
        currentDurMs = GetStorage().read(storageDurKey) ?? 0;
      }
    } else {
      final box = GetStorage();
      currentPosMs = box.read(storagePosKey) ?? 0;
      currentDurMs = box.read(storageDurKey) ?? 0;
    }

    double progress = currentDurMs > 0
        ? (currentPosMs / currentDurMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (isPlaying) {
          ref.read(audioPlayerProvider.notifier).pause();
        } else {
          // 🌟 رفع باگ دکمه‌های بعدی/قبلی: قبلاً اینجا `newPlaylist:
          // [targetPath]` فرستاده می‌شد — یعنی یک پلی‌لیستِ تک‌عضوی که
          // خودش تنها عضوش بود. چون playNext/playPrevious بر اساس
          // اندیسِ فایل فعلی در همین لیست حرکت می‌کنند، همیشه یا اول یا
          // آخر لیست بودیم و دکمه‌ها هیچ‌وقت جایی برای رفتن نداشتند. حالا
          // پلی‌لیستِ واقعیِ همه‌ی لینک‌های صوتیِ این صفحه (به ترتیب ظاهر
          // شدنشان در متن) پاس داده می‌شود.
          final effectivePlaylist = playlist.contains(targetPath)
              ? playlist
              : [targetPath];
          ref
              .read(audioPlayerProvider.notifier)
              .playFile(targetPath, newPlaylist: effectivePlaylist);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4.0, top: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: baseColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    backgroundColor: baseColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                  ),
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16,
                    color: baseColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              text,
              style: TextStyle(
                color: baseColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis, // 🌟 اگر جا نبود نقطه‌چین می‌شود
            ),
          ],
        ),
      ),
    );
  }
}

class TranslatableContentWrapper extends ConsumerStatefulWidget {
  final Widget originalContent;
  final String? translationFa;
  final String? translationAr;
  final bool isDarkMode;
  const TranslatableContentWrapper({
    super.key,
    required this.originalContent,
    this.translationFa,
    this.translationAr,
    this.isDarkMode = false,
  });
  @override
  ConsumerState<TranslatableContentWrapper> createState() =>
      _TranslatableContentWrapperState();
}

class _TranslatableContentWrapperState
    extends ConsumerState<TranslatableContentWrapper> {
  bool _showTranslation = false;
  @override
  Widget build(BuildContext context) {
    bool hasTranslation =
        (widget.translationFa != null && widget.translationFa!.isNotEmpty) ||
        (widget.translationAr != null && widget.translationAr!.isNotEmpty);
    if (!hasTranslation) return widget.originalContent;

    // 🌟 دوزبانه: بر اساس زبانِ انتخابی، ترجمه‌ی فارسی یا عربی را نشان بده
    // (اگر ترجمه‌ی زبانِ انتخابی خالی بود، به زبانِ دیگر برگرد تا خالی نماند)
    final lang = ref.watch(languageProvider);
    final bool preferAr = lang == 'ar';
    final String? primary = preferAr
        ? widget.translationAr
        : widget.translationFa;
    final String? secondary = preferAr
        ? widget.translationFa
        : widget.translationAr;
    final String finalTranslation = (primary?.isNotEmpty ?? false)
        ? primary!
        : (secondary ?? '');
    Color bgColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.08)
        : Colors.blue.withOpacity(0.05);
    Color borderColor = widget.isDarkMode
        ? Colors.orangeAccent
        : Colors.blueAccent;
    Color textColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.9)
        : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => setState(() => _showTranslation = !_showTranslation),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.originalContent,
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Container(
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    right: BorderSide(color: borderColor, width: 3),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  finalTranslation,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'YekanBakh',
                    fontSize: 14,
                    height: 1.6,
                    color: textColor,
                  ),
                ),
              ),
              crossFadeState: _showTranslation
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}
