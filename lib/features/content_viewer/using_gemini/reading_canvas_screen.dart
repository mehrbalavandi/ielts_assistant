// 🔊 🎧 ▶ ▶️
// ignore_for_file: unused_local_variable, unused_import

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:float_column/float_column.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/paged_book_store.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/search_text_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart';
import 'dart:math' as math;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MapOffset {
  int value = 0;
}

// 🐞 برای لودِ تنبل: وقتی یک صفحه هنوز در کشِ PagedBookStore نیست، این
// ویجت getPage (async) را درخواست می‌کند و تا رسیدنش یک پلیس‌هولدرِ ساده
// نشان می‌دهد؛ وقتی رسید، همان‌جا (بدونِ نیاز به rebuildِ کلِ لیست)
// خودش را با محتوای واقعی جایگزین می‌کند.
class _LazyPage extends StatefulWidget {
  final PagedBookStore store;
  final int pageIndex;
  final Widget Function(PageData page) builder;

  const _LazyPage({
    required this.store,
    required this.pageIndex,
    required this.builder,
  });

  @override
  State<_LazyPage> createState() => _LazyPageState();
}

class _LazyPageState extends State<_LazyPage> {
  PageData? _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _LazyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🐞 اگر همین آیتمِ لیست حالا به ایندکسِ دیگری اشاره کند (مثلاً به‌خاطرِ
    // تغییرِ کتاب)، دوباره از صفر لود می‌شود.
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.store != widget.store) {
      _page = null;
      _load();
    }
  }

  void _load() {
    widget.store
        .getPage(widget.pageIndex)
        .then((page) {
          if (mounted) setState(() => _page = page);
        })
        .catchError((Object e) {
          // 🐞 یک صفحه‌ی گم‌شده/خراب نباید کلِ کتاب را کرش کند — همان
          // پلیس‌هولدر می‌ماند.
        });
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    // 🐞 حتی با پیشگرمی (prewarmAround)، ممکن است بعضی صفحات (مثلاً همان
    // اولین صفحه‌ای که هنوز پیشگرمی برایش فرصت نداشته، یا حینِ فلینگِ
    // خیلی سریع) هنوز به کش نرسیده باشند؛ AnimatedSize باعث می‌شود
    // تغییرِ ارتفاعِ پلیس‌هولدر به ارتفاعِ واقعیِ صفحه به‌جای یک جهشِ
    // ناگهانی، به‌آرامی و در چند فریم انجام شود.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: page == null
          ? const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          : widget.builder(page),
    );
  }
}

class ReadingCanvasScreen extends ConsumerStatefulWidget {
  // 🐞 بازنویسیِ اصلیِ لودِ تنبل: قبلاً این‌جا کلِ کتاب به‌صورتِ
  // List<PageData>ِ کاملاً لودشده می‌آمد (مصرفِ حافظه/زمانِ بازشدنِ کتاب با
  // تعدادِ کل صفحات رشد می‌کرد). حالا به‌جایش یک PagedBookStore می‌آید که
  // فقط منیفستِ سبک (index.json، بدونِ محتوای صفحات) را از قبل لود کرده و
  // هر صفحه را فقط وقتی واقعاً دیده می‌شود (getPage) از دیسک می‌خواند و در
  // یک کشِ LRU با سقفِ ثابت نگه می‌دارد.
  final PagedBookStore pagedBookStore;
  final List<AudioScriptTrack> audioScripts; // 🌟 اضافه شد
  // 🐞 شاخصِ لینک‌های صوتیِ از‌قبل‌محاسبه‌شده (سمتِ C#) — اگر داده شود،
  // buildBookAudioPlaylist بدونِ گشتنِ زنده‌ی محتوای صفحات، مستقیم از
  // رویش پلی‌لیست می‌سازد؛ حالا با لودِ تنبل این تقریباً همیشه لازم است
  // (چون دیگر کل کتاب برای اسکن در دسترس نیست).
  final List<AudioLinkEntry> precomputedAudioLinksIndex;
  const ReadingCanvasScreen({
    super.key,
    required this.pagedBookStore,
    required this.audioScripts,
    this.precomputedAudioLinksIndex = const [],
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

  // 🐞 پلی‌لیستِ کتاب‌محور برای پلیر: چون این کار روی کلِ کتاب است، فقط
  // یک‌بار (به‌ازای همین pagedBookStore) محاسبه و کش می‌شود — نه در هر
  // rebuildِ هر صفحه.
  List<BookAudioEntry>? _cachedBookAudioEntries;
  PagedBookStore? _cachedForStore;
  List<String> _bookAudioPlaylist = const [];
  Map<String, AudioLocation> _bookAudioFirstOccurrence = const {};

  void _ensureBookAudioPlaylistBuilt() {
    if (_cachedBookAudioEntries != null &&
        _cachedForStore == widget.pagedBookStore) {
      return;
    }
    final currentBook = ref.read(activeBookProvider);
    // 🐞 دیگر لیستِ کاملِ صفحات برای اسکن در دسترس نیست (لودِ تنبل) — پس
    // pages خالی پاس داده می‌شود؛ چون precomputedAudioLinksIndex تقریباً
    // همیشه از index.json پر است، buildBookAudioPlaylist بدونِ نیاز به
    // pages مستقیم از رویِ همان کار می‌کند. فقط برای کتابِ خیلی قدیمی که
    // هنوز این شاخص را ندارد، پلی‌لیستِ کتاب‌محور خالی می‌ماند (تا وقتی
    // دوباره با ابزارِ جدید استخراج شود) — این یک محدودیتِ صریح و
    // مستندشده است، نه کرش یا رفتارِ نامشخص.
    final entries = buildBookAudioPlaylist(
      const [],
      currentBook,
      precomputedIndex: widget.precomputedAudioLinksIndex,
    );
    _cachedBookAudioEntries = entries;
    _cachedForStore = widget.pagedBookStore;
    _bookAudioPlaylist = entries.map((e) => e.resolvedPath).toList();
    _bookAudioFirstOccurrence = bookAudioFirstOccurrence(entries);

    // 🐞 قبلاً state.playlist/firstOccurrence فقط با اولین تپِ رویِ یک
    // دکمه‌ی صوتیِ داخلِ متن پر می‌شد — یعنی تا وقتی کاربر چیزی پخش نکرده
    // بود، پلی‌لیست (حتی اگر دکمه‌ی مستقلش را داشته باشد) خالی نشان داده
    // می‌شد. حالا همین‌جا، به‌محضِ آماده‌شدنِ پلی‌لیستِ کتاب، مستقیم در
    // پلیر هم ثبتش می‌کنیم — بدونِ نیاز به هیچ پخشی. اگر همین الان چیزی
    // در حالِ پخش باشد دست‌نخورده می‌ماند (setPlaylist فقط این دو فیلد را
    // عوض می‌کند). با addPostFrameCallback بعد از اتمامِ همین build اجرا
    // می‌شود تا با ویجت‌های دیگری که audioPlayerProvider را watch می‌کنند
    // تداخلِ «rebuild حین build» نداشته باشد.
    if (_bookAudioPlaylist.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(audioPlayerProvider.notifier)
            .setPlaylist(
              _bookAudioPlaylist,
              firstOccurrence: _bookAudioFirstOccurrence,
            );
      });
    }
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
      if (newPage != _currentPage) {
        // 🐞 رفع باگِ گزارش‌شده‌ی «پرش حینِ اسکرول»: با لودِ تنبل، وقتی
        // یک صفحه هنوز در کش نیست، _LazyPage یک پلیس‌هولدرِ ارتفاعِ‌ثابت
        // نشان می‌دهد که بعداً با ارتفاعِ واقعیِ صفحه (که می‌تواند خیلی
        // متفاوت باشد) جایگزین می‌شود — همین تغییرِ ارتفاعِ ناگهانی حینِ
        // اسکرول، باعثِ جابه‌جاییِ محتوا/«پرش» می‌شود. با پیش‌بارگذاریِ
        // چند صفحه‌ی جلوتر/عقب‌تر از همین الان (نه فقط دقیقاً همان صفحه‌ای
        // که دیده می‌شود)، تا وقتی کاربر واقعاً به آن صفحه برسد، معمولاً
        // از قبل در کش است — یعنی از مسیرِ سریعِ peekPage رد می‌شود، نه
        // پلیس‌هولدر. await نمی‌شود چون قرار است در پس‌زمینه، همزمان با
        // ادامه‌ی اسکرولِ کاربر، انجام شود.
        widget.pagedBookStore.prewarmAround(topItem.index);
      }
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
        final safeIndex = _savedIndex < widget.pagedBookStore.pageCount
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
    final total = widget.pagedBookStore.pageCount;
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

    // 🐞 پلی‌لیستِ کتاب‌محور برای پلیر — کش‌شده، فقط واقعاً یک‌بار به‌ازای
    // همین pagedBookStore محاسبه می‌شود.
    _ensureBookAudioPlaylistBuilt();

    final activeTarget =
        (searchSession != null && searchSession.results.isNotEmpty)
        ? searchSession.results[searchSession.currentIndex] as SearchResult
        : null;

    if (activeTarget != null) {
      int pIndex =
          widget.pagedBookStore.indexForPageNumber(activeTarget.pageNumber) ??
          -1;
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
        : widget.pagedBookStore.indexForPageNumber(activeTarget.pageNumber);
    _targetKeyClaimedThisBuild =
        false; // 🌟 اضافه شد — شروع تازه برای این build

    ref.listen<SearchSession?>(activeSearchProvider, (previous, next) async {
      if (next != null && next.results.isNotEmpty) {
        if (previous?.query != next.query ||
            previous?.currentIndex != next.currentIndex ||
            previous?.jumpTrigger != next.jumpTrigger) {
          final target = next.results[next.currentIndex] as SearchResult;

          // 🐞 رفعِ باگِ «دکمه‌های بعدی/قبلیِ جستجو رویِ نتایجِ صوتی کار
          // نمی‌کنند»: قبلاً این listener فقط مسیرِ اسکرول‌به‌صفحه را
          // امتحان می‌کرد — برای نتایجِ صوتی (pageNumber معنایی ندارد)،
          // pageIndex همیشه -1 می‌شد و هیچ اتفاقی نمی‌افتاد. حالا همان
          // تابعِ مشترکی که تپِ مستقیم رویِ نتیجه هم استفاده می‌کند
          // (openAudioSearchResult) این‌جا هم صدا زده می‌شود.
          if (target.audioTrackName != null) {
            final currentBook = ref.read(activeBookProvider);
            if (currentBook != null && context.mounted) {
              await openAudioSearchResult(
                context: context,
                ref: ref,
                session: next,
                target: target,
                pagedBookStore: widget.pagedBookStore,
                activeBook: currentBook,
              );
            }
            return;
          }

          final targetSignature = _signatureFor(target);
          int pageIndex =
              widget.pagedBookStore.indexForPageNumber(target.pageNumber) ?? -1;

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
                  'صفحه $_currentPage از ${widget.pagedBookStore.pageCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // 🐞 محتوای کتاب حالا با Positioned.fill کلِ فضا را پر می‌کند —
            // دقیقاً همان child که قبلاً زیرِ Expanded بود، بدونِ هیچ تغییرِ
            // دیگری. چون این‌جا داخلِ یک Stack است (نه یک Column که
            // موقعیتِ فرزندانش به هم وابسته است)، دیگر Column به التِ نوارِ
            // پلیر برای محاسبه‌ی جا وابسته نیست.
            Positioned.fill(
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
                              itemCount: widget.pagedBookStore.pageCount,
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
                                bool hasTarget =
                                    activeTarget != null &&
                                    pageIndex == _lastBuiltTargetPageIndex &&
                                    !_targetKeyClaimedThisBuild; // 🌟 اضافه شد
                                if (hasTarget)
                                  _targetKeyClaimedThisBuild =
                                      true; // 🌟 اضافه شد

                                Widget buildForPage(PageData page) {
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
                                      bookAudioPlaylist: _bookAudioPlaylist,
                                      bookAudioFirstOccurrence:
                                          _bookAudioFirstOccurrence,
                                    ),
                                  );
                                }

                                // 🐞 بازنویسیِ اصلیِ لودِ تنبل: اگر این صفحه از
                                // قبل در کشِ PagedBookStore باشد (peekPage،
                                // sync)، مستقیم رندر می‌شود — دقیقاً همان
                                // سرعتِ قبلی، بدونِ حتی یک فریم پرش. اگر هنوز
                                // نیامده، _LazyPage آن را (getPage، async)
                                // درخواست می‌کند و تا رسیدنش یک پلیس‌هولدرِ
                                // ساده نشان می‌دهد.
                                final cachedPage = widget.pagedBookStore
                                    .peekPage(pageIndex);
                                if (cachedPage != null) {
                                  return buildForPage(cachedPage);
                                }
                                return _LazyPage(
                                  store: widget.pagedBookStore,
                                  pageIndex: pageIndex,
                                  builder: buildForPage,
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
            // 🐞 نوارِ کوچکِ پلیرِ صوتی حالا یک overlayِ مستقل است، نه
            // فرزندِ یک Column کنارِ محتوای اصلی — ظاهر/ناپدیدشدنش (وقتی
            // فایلی پخش/متوقف می‌شود) دیگر باعثِ جابه‌جاییِ محتوای کتاب
            // نمی‌شود، چون هیچ فضایی از Stack اشغال نمی‌کند؛ فقط رویِ آن
            // می‌نشیند.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TelegramAudioPlayer(
                audioScripts: widget.audioScripts,
                pagedBookStore: widget.pagedBookStore,
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
  // 🐞 پلی‌لیستِ کتاب‌محور (نه فقط همین صفحه) + اولین وقوعِ هر فایل — از
  // ReadingCanvasScreen پاس داده می‌شود تا یک‌بار برای کل کتاب محاسبه شود،
  // نه به‌ازای هر صفحه.
  final List<String> bookAudioPlaylist;
  final Map<String, AudioLocation> bookAudioFirstOccurrence;

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
    this.bookAudioPlaylist = const [],
    this.bookAudioFirstOccurrence = const {},
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
        old.pageAnchorKey != widget.pageAnchorKey ||
        old.bookAudioPlaylist != widget.bookAudioPlaylist) {
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
    // همیشه چیزی برای «بعدی/قبلی» وجود نداشت. سپس یک‌بار برای کل صفحه
    // ساخته می‌شد؛ حالا برای قابلیتِ «پلی‌لیستِ کتاب + برو به متن»،
    // پلی‌لیست از سطحِ ReadingCanvasScreen (که کلِ کتاب را می‌بیند، نه فقط
    // این صفحه) پاس داده می‌شود — bookAudioPlaylist/bookAudioFirstOccurrence.
    final List<String> pageAudioPlaylist = widget.bookAudioPlaylist;
    final Map<String, AudioLocation> audioFirstOccurrence =
        widget.bookAudioFirstOccurrence;

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
        audioFirstOccurrence: audioFirstOccurrence, // 🐞 اضافه شد
        audioPageNumber: widget.page.pageNumber, // 🐞 اضافه شد
        audioParaIndex: pIndex, // 🐞 اضافه شد
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

String _normalizeText(String text) => normalizeText(text);

String _extractFullText(ParagraphData para) => extractFullText(para);

// آیا محتوای این اسپن یک {blk}...{/blk} تنها است (نه یک جای‌خالیِ کوچکِ داخلِ
// یک جملهٔ دیگر)؟ فقط در این حالت مارکرِ لیست باید داخلِ مودال هم تکرار شود؛
// برای جای‌خالیِ کوچکِ داخلِ یک پاراگرافِ عمدتاً-قابل‌مشاهده لازم نیست، چون
// شماره از قبل بیرون از آیکون دیده می‌شود.
bool _isWhollyOneBlank(String? content) {
  if (content == null) return false;
  final t = content.trim();
  if (!t.startsWith('{blk}') || !t.endsWith('{/blk}')) return false;
  return '{blk}'.allMatches(t).length == 1;
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

String mapFontFamily(String rawFontName) {
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
  // 🐞 رفع باگِ «کاراکترِ ناشناخته» برای Wingdings: قبلاً هیچ case‌ای برای
  // این خانواده‌ی فونت نبود، پس "Wingdings 3" (از marker "fn:Wingdings 3")
  // به پیش‌فرضِ آخر (Source Sans 3) می‌افتاد — که برای کدپوینت‌های
  // Private-Use-Area که Wingdings استفاده می‌کند (مثلاً U+F069) هیچ
  // گلیفی ندارد، پس جعبه‌ی «کاراکترِ ناشناخته» نشان داده می‌شد. خودِ فونت
  // در pubspec.yaml درست ثبت شده بود (family: "Wingdings 3" →
  // fonts/WINGDNG3.TTF)؛ فقط این نگاشت از قلم بیفتاده بود.
  if (normalized.contains("wingdings")) {
    if (normalized.contains("3")) return "Wingdings 3";
    if (normalized.contains("2")) return "Wingdings 2";
    return "Wingdings";
  }
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
  // 🐞 برای قابلیتِ «پلی‌لیستِ کتاب + برو به متن»: اولین وقوعِ هر فایل در
  // کتاب، و موقعیتِ خودِ همین پاراگراف (صفحه+اندیس) — تا هر InlineAudioLink
  // داخلِ این پاراگراف بداند دقیقاً کجای کتاب است.
  Map<String, AudioLocation> audioFirstOccurrence = const {},
  int? audioPageNumber,
  int? audioParaIndex,
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
          audioFirstOccurrence: audioFirstOccurrence, // 🐞 اضافه شد
          audioPageNumber: audioPageNumber, // 🐞 اضافه شد
          audioParaIndex: audioParaIndex, // 🐞 اضافه شد
          keyClaim: keyClaim, // 🐞 مشترک بین همه‌ی اسپن‌های همین پاراگراف
        ),
      );
      mapOffset.value += content.length;
    } else if (span.type == "image") {
      // 🐞 رفع باگِ «انبارشدنِ عمودیِ زیرنویس در صفحاتِ باریک»: این خط قبلاً
      // بدونِ توجه به renderInline، قبل از *هر* عکسی روی صفحه‌ی باریک
      // flushText صدا می‌زد. برای زیرنویسِ FigureTable (یک پاراگرافِ واحد:
      // آیکون+متن، آیکون+متن، آیکون+متن) این یعنی به‌ازای هر آیکون یک
      // WrappableTextِ جداگانه ساخته می‌شد — دقیقاً همان چیزی که در
      // اسکرین‌شات به‌شکلِ «سه ردیفِ روی‌همِ جدا» دیده شد، چون سه بلاکِ
      // block-level پشتِ‌سرِهم به‌جای یک جریانِ متنیِ پیوسته. حالا وقتی
      // renderInline==true (عکس قرار است داخلِ همان جریانِ متن بماند)، این
      // flush را رد می‌کنیم؛ برای عکسِ مستقل (renderInline==false) رفتارِ
      // قبلی دست‌نخورده می‌ماند.
      if (!isLargeScreen && !renderInline) {
        flushText();
      }
      String imagePath = span.url ?? span.content; // ✅ هندل کردن حالت Null
      if (imagePath.isNotEmpty) {
        if (renderInline) {
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
          // 🐞 رفع بکلاگ «اسکرول افقی خودکار برای تصویر عریض در صفحه‌ی
          // باریک»: اگر عرض واقعیِ تصویر (از Word استخراج‌شده، span.imageWidth)
          // از عرض قابل‌نمایشِ صفحه (canvasWidth) بیشتر باشد، به‌جای کوچک
          // کردنِ تصویر برای جاشدن (که جزئیات را نامفهوم می‌کند)، تصویر را
          // در اندازه‌ی طبیعی‌اش نگه می‌داریم و داخل یک اسکرولِ افقی
          // می‌گذاریم تا کاربر با سوایپ بقیه‌اش را ببیند.
          final int? naturalImgWidth = span.imageWidth;
          final bool imageNeedsHScroll =
              !isImageCell &&
              naturalImgWidth != null &&
              naturalImgWidth > canvasWidth;
          final double? imageExplicitWidth = imageNeedsHScroll
              ? naturalImgWidth.toDouble().clamp(canvasWidth, canvasWidth * 2.5)
              : null;

          Widget standaloneImage = _buildLocalImage(
            imagePath,
            isMobile: !isLargeScreen,
            screenWidth: screenWidth,
            isImageCell: isImageCell,
            activeBook: activeBook,
            context: context,
            explicitWidth: imageExplicitWidth,
          );
          if (imageNeedsHScroll) {
            // 🐞 رفع کرش «Scrollbar's ScrollController has no ScrollPosition
            // attached»: بدون controllerِ صریح، Scrollbar سعی می‌کند از
            // PrimaryScrollController استفاده کند که به این
            // SingleChildScrollViewِ افقیِ تودرتو وصل نیست (آن یکی معمولاً
            // به اسکرولِ عمودیِ کلِ صفحه وصل است). با یک ScrollController
            // مشترک بین خودِ Scrollbar و SingleChildScrollView این مشکل
            // رفع می‌شود.
            final ScrollController hCtrl = ScrollController();
            standaloneImage = Scrollbar(
              controller: hCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: hCtrl,
                scrollDirection: Axis.horizontal,
                // 🐞 همان فیکسِ فاصله: تا نوارِ اسکرول روی لبه‌ی پایینیِ
                // خودِ عکس لَم ندهد.
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: standaloneImage,
                ),
              ),
            );
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
                  ? (imageNeedsHScroll
                        ? standaloneImage
                        : Center(child: standaloneImage))
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
          audioFirstOccurrence: audioFirstOccurrence, // 🐞 اضافه شد
          audioPageNumber: audioPageNumber, // 🐞 اضافه شد
          audioParaIndex: audioParaIndex, // 🐞 اضافه شد
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
  bool _paraHasListMarker =
      false; // 🌟 برای جلوگیری از اعمالِ دوبارهٔ تورفتگی در ادامهٔ تابع
  // 🐞 رفع باگِ گزارش‌شده: وقتی کلِ پاراگراف فقط یک {blk} است (تمرین-۰۵
  // استایل، مثل صفحه‌ی ۲۴)، شماره‌ی خودکارِ لیست نباید کنارِ آیکونِ چشمِ
  // جمع‌شده دیده شود — چون خودِ محتوا هنوز مخفی است و این شماره را می‌شود
  // به‌جایش داخلِ مودالِ بازشده دید (کدِ پایین‌تر که listMarker را به
  // InteractiveBlankWord پاس می‌دهد دقیقاً همین کار را می‌کند). این با
  // شمارهٔ badge نتایج جستجو روی آیکونِ چشم (مثلاً «🟠 ۳») کاملاً فرق دارد
  // و آن دست‌نخورده می‌ماند. برای پاراگراف‌های تمرین-۰۴ استایل (متنِ آزادِ
  // قابل‌مشاهده + {blk} به‌عنوان بخشی از جمله)، چون چیزی مخفی نیست که
  // شماره افشایش بدهد، مثل قبل همین‌جا نمایش داده می‌شود.
  final bool wholeParaIsBlank =
      para.spans.length == 1 && _isWhollyOneBlank(para.spans.first.content);
  if (para.listMarker != null &&
      para.listMarker!.isNotEmpty &&
      !wholeParaIsBlank) {
    _paraHasListMarker = true;
    final bool rtl = para.direction == "RTL";

    // 🌟 مدلِ hanging-indent وُرد: IndentLeft = جایی که خطوطِ wrap‌شده می‌نشینند،
    // IndentFirstLine = افستِ منفیِ خطِ اول (مارکر) نسبت به IndentLeft.
    // نکته‌ی مهم: Word عرضِ مارکر را به همین مقدار محدود نمی‌کند — اگر شماره از
    // این تنگنا بزرگ‌تر باشد، Word اجازه‌ی overflow می‌دهد، نه clip. پس اینجا هم
    // حداقلِ عرضِ قابل‌خواندن (۱۶px) را تضمین می‌کنیم تا رقم هیچ‌وقت گم نشود؛
    // این همان چیزی بود که در دورِ قبل باعثِ ناپدید شدنِ کاملِ شماره شد
    // (IndentLeft واقعیِ Word برای برخی لیست‌ها فقط ~۱۰px بود).
    final double indentLeft = para.indentLeft ?? 0.0;
    final double hanging = -(para.indentFirstLine ?? 0.0);
    final double rawMarkerWidth = hanging > 0 ? hanging : 18.0;

    // 🌟 به‌جای تکیه بر overflow:visible (که رفتارش داخلِ SizedBoxِ تنگ همیشه
    // قابل‌اتکا نیست)، عرضِ واقعیِ متنِ مارکر را با TextPainter اندازه می‌گیریم و
    // جعبه را دقیقاً به همان اندازه (+ کمی حاشیه) می‌سازیم — این تضمین می‌کند
    // که رقم هیچ‌وقت به هیچ دلیلی clip/ناپدید نشود.
    const TextStyle _markerStyle = TextStyle(height: 1.4, fontSize: 14);
    final TextPainter _tp = TextPainter(
      text: TextSpan(text: para.listMarker!, style: _markerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final double markerWidth = (_tp.width + 4.0).clamp(
      rawMarkerWidth.clamp(16.0, 60.0),
      80.0,
    );
    final double outerLeft = (indentLeft - markerWidth).clamp(0.0, 999.0);

    paragraphContent = Padding(
      padding: EdgeInsets.only(
        left: rtl ? 0 : outerLeft,
        right: rtl ? outerLeft : 0,
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
              style: _markerStyle,
            ),
          ),
          const SizedBox(width: 4),
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
  // 🌟 اگر پاراگراف مارکرِ لیست دارد، تورفتگی همان‌جا (مدلِ hanging-indent) اعمال
  // شده؛ اینجا دوباره اعمال نمی‌شود وگرنه دوبرابر می‌شود.
  double leftMargin =
      (!_paraHasListMarker && para.indentLeft != null && para.indentLeft! > 0)
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
  Map<String, AudioLocation> audioFirstOccurrence = const {},
  int? audioPageNumber,
  int? audioParaIndex,
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
  // 🐞 درخواستِ کاربر: جدولِ FigureTable هیچ‌وقت نباید بوردر نشان دهد،
  // حتی اگرچه strategy آن هم "horizontalScroll" است (همان چیزی که
  // isBorderedTable را true می‌کند و در جاهای دیگر — مسیرِ رندرِ Table
  // widget، منطقِ tableWidthPercent — هنوز لازم است true بماند). پس اینجا
  // یک فلگِ جدا می‌سازیم و فقط تصمیمِ نمایشِ بوردر را از آن مستثنی می‌کنیم.
  final bool isFigureTable = rawStyle.contains("figuretable");
  // 🐞 OutsideTable: فقط بوردرِ دورتادورِ کلِ جدول باید دیده شود، نه خطوطِ
  // داخلیِ بینِ سلول‌ها/ردیف‌ها. چون مکانیزمِ فعلیِ showBorders یک TableBorder
  // به هر ردیف (که خودش یک Table جداست) می‌دهد — یعنی هر ردیف جعبه‌ی خودش
  // را می‌کشد، نه فقط بیرونیِ کل — اینجا رسمِ بوردرِ per-row/per-cell را
  // برایش خاموش می‌کنیم و پایین‌تر (بعد از ساختِ کاملِ tableContainer) یک
  // Border.all بیرونی دورِ کلِ جدول می‌کشیم.
  final bool isOutsideTable = rawStyle.contains("outsidetable");
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
      tableSpan.borderWidth ??
      ((isBorderedTable && !isFigureTable) ? 1.0 : 0.5);
  Color defaultBorderColor =
      _hexToColor(tableSpan.borders?.color) ??
      ((isBorderedTable && !isFigureTable)
          ? Colors.black
          : Colors.grey.shade400);

  final bool showBorders =
      !hideBorders &&
      !isFigureTable &&
      !isOutsideTable &&
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

  // 🐞 رفع باگِ «فقط عکس ریسپانسیو می‌شود، زیرنویس نه»: قبلاً این اسکن فقط
  // پایین‌تر (نزدیکِ wrap‌کردنِ tableContainer) انجام می‌شد، یعنی بعد از
  // اینکه محتوای سلول‌ها (cellContent) از قبل ساخته شده بودند. مشکل این
  // بود که Columnِ داخلِ هر سلول crossAxisAlignment: start داشت، یعنی هر
  // پاراگراف (عکس، زیرنویس) فقط به‌اندازه‌ی نیازِ خودش عرض می‌گرفت، نه به
  // اندازه‌ی کلِ سلول — پس زیرنویس، حتی وقتی سلول به‌اندازه‌ی عکس عریض
  // می‌شد، باز هم جمع‌وجورِ خودش می‌ماند و بصری هم‌راستا با عکس نبود. حالا
  // این اسکن را زودتر انجام می‌دهیم تا موقعِ ساختِ cellContent هم در
  // دسترس باشد.
  //
  // 🐞 رفع دورِ دومِ همین باگ: با خودِ page_0008.json معلوم شد زیرنویس واقعاً
  // یک پاراگرافِ واحد است (سه آیکونِ رنگی + سه برچسبِ متنی، همه inline)، نه
  // چند پاراگراف — پس مشکل از تعدادِ پاراگراف نبود. مشکل این بود که عرضِ
  // لازمِ جدول را فقط از رویِ عرضِ عکسِ نمودار (۴۱۶px) حساب می‌کردیم، در
  // حالی‌که عرضِ طبیعیِ خودِ زیرنویس (۳ آیکون + ۳ برچسبِ متنی + فاصله‌ها،
  // یک‌جا) می‌تواند از عرضِ خودِ عکس هم بیشتر باشد — پس ۴۱۶px برای یک‌خط‌
  // نشدنِ زیرنویس کافی نبود. حالا عرضِ طبیعیِ یک‌خطِ هر پاراگراف را هم
  // می‌سنجیم (آیکون‌ها از رویِ imageWidth، متن‌ها با TextPainter و همان
  // قاعده‌ی تبدیلِ sz:/fn: که رندرِ واقعی استفاده می‌کند) و بیشینه‌ی همه‌ی
  // پاراگراف‌ها را ملاکِ عرضِ جدول قرار می‌دهیم — این‌طوری چه محرکِ عرض،
  // عکسِ نمودار باشد چه خودِ زیرنویس، جدول به‌اندازه‌ی کافی عریض می‌شود.
  double measureParagraphNaturalWidth(ParagraphData p) {
    double width = 0;
    for (final s in p.spans) {
      if (s.type == "image" && s.imageWidth != null) {
        width += s.imageWidth!.toDouble();
      } else if (s.type == "text" && (s.content ?? '').isNotEmpty) {
        double fontSize = 14.0;
        String? fontFamily;
        for (final marker in s.markers) {
          if (marker.startsWith("sz:")) {
            final parsed = double.tryParse(marker.substring(3));
            if (parsed != null) fontSize = parsed / 2;
          } else if (marker.startsWith("fn:")) {
            fontFamily = mapFontFamily(marker.substring(3));
          }
        }
        final tp = TextPainter(
          text: TextSpan(
            text: s.content,
            style: TextStyle(fontSize: fontSize, fontFamily: fontFamily),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        width += tp.width;
      }
    }
    return width;
  }

  double maxEmbeddedImageWidth = 0;
  double maxParagraphNaturalWidth = 0;
  for (final row in tableSpan.tableRows) {
    for (final cell in row.cells) {
      for (final p in cell.paragraphs) {
        final paraWidth = measureParagraphNaturalWidth(p);
        if (paraWidth > maxParagraphNaturalWidth) {
          maxParagraphNaturalWidth = paraWidth;
        }
        for (final s in p.spans) {
          if (s.type == "image" &&
              s.imageWidth != null &&
              s.imageWidth! > maxEmbeddedImageWidth) {
            maxEmbeddedImageWidth = s.imageWidth!.toDouble();
          }
        }
      }
    }
  }
  final double widestContentWidth =
      (maxParagraphNaturalWidth > 0 ? maxParagraphNaturalWidth + 24 : 0) >
          maxEmbeddedImageWidth
      ? maxParagraphNaturalWidth + 24
      : maxEmbeddedImageWidth;
  // 🐞 همان محدودسازیِ «فقط برای استایل‌های خاص»: stretch کردنِ محتوای سلول
  // هم فقط وقتی معنا دارد که خودِ جدول قرار است اسکرولِ افقی بگیرد
  // (strategy=="horizontalScroll")، وگرنه برای جدول‌های معمولی که هیچ‌وقت
  // عریض‌تر نمی‌شوند، این stretch اثرِ عملیِ مفیدی ندارد و بهتر است رفتارِ
  // پیش‌فرض (start) دست‌نخورده بماند.
  final bool stretchCellsToImage =
      strategy == "horizontalScroll" && widestContentWidth > canvasWidth;

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
    // 🐞 رفع باگِ «بوردرِ پایینیِ ضخیم‌تر»: این تقویت فقط برای جداولِ
    // چندردیفه معنا دارد (جداکردنِ ردیفِ اول از بقیه، مثلِ سرستونِ جدول)؛
    // برای جدولِ تک‌ردیفه/تک‌سلولی (مثلِ جعبه‌ی TIP صفحه‌ی ۸) هیچ ردیفِ
    // بعدی‌ای برای جدا شدن وجود ندارد، ولی چون rowIndex==0 همیشه true بود،
    // بی‌دلیل بوردرِ پایین را ۲.۲ برابر می‌کرد.
    if (rowIndex == 0 &&
        tableSpan.tableRows.length > 1 &&
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
            audioFirstOccurrence: audioFirstOccurrence, // 🐞 اضافه شد
            audioPageNumber: audioPageNumber, // 🐞 اضافه شد
            audioParaIndex: audioParaIndex, // 🐞 اضافه شد
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
          crossAxisAlignment: stretchCellsToImage
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
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
      if (isLargeScreen ||
          isBorderedTable ||
          isImageRow ||
          isNestedTable ||
          showBorders ||
          isOutsideTable) {
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

  // 🐞 رفع باگِ «جدول به محتوای بعدی چسبیده»: قبلاً جدولِ تودرتو
  // (isNestedTable، مثلِ FigureTable که همیشه داخلِ سلولِ جدولِ بیرونیِ
  // تمرین است) فقط ۲px فاصله‌ی بالا داشت و اصلاً فاصله‌ی پایین نداشت — برای
  // یک جدولِ تودرتوی کوچکِ معمولی شاید قابلِ‌قبول بود، ولی برای
  // FigureTable/OutsideTable که خودشان یک شکلِ کاملند، خیلی چسبیده به‌نظر
  // می‌رسید. حالا فاصله‌ی پایینِ معقولی هم می‌گیرند؛ اگر جدول قرار است
  // اسکرولِ افقی هم بگیرد، کمی فاصله‌ی بیشتر می‌دهیم تا نوارِ اسکرول
  // (پایین‌تر) جا برای نفس‌کشیدن داشته باشد و روی بوردرِ جدول لَم ندهد.
  final bool willScrollHorizontally = strategy == "horizontalScroll";
  final double nestedBottomMargin = willScrollHorizontally ? 14.0 : 10.0;

  // 🌟 اصلاح نهایی: حذف پارامتر border از کانتینر بیرونی برای جلوگیری از تداخل و دابل‌بوردر شدن سایدها
  Widget tableContainer = Container(
    margin: isNestedTable
        ? EdgeInsets.only(top: 2.0, bottom: nestedBottomMargin)
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

  // 🐞 OutsideTable: چون رسمِ بوردرِ per-row/per-cell برایش بالاتر خاموش
  // شد (showBorders=false)، اینجا یک‌بار دورِ کلِ tableContainer (که همه‌ی
  // ردیف‌ها را در بر دارد) یک Border.all می‌کشیم — یعنی فقط بوردرِ بیرونی،
  // بدونِ خطوطِ داخلی. این wrap قبل از منطقِ اسکرولِ افقیِ زیر انجام می‌شود
  // تا بوردر با محتوا اسکرول شود (فقط در ابتدا/انتهای واقعیِ جدول دیده شود).
  if (isOutsideTable && !hideBorders) {
    tableContainer = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: defaultBorderColor,
          width: defaultBorderWidth,
        ),
      ),
      child: tableContainer,
    );
  }

  // 🐞 رفع بکلاگِ «اسکرول افقی خودکار برای جدول عریض در صفحه‌ی باریک»: اگر
  // جدول آن‌قدر ستون دارد که فشرده‌کردنِ همه در canvasWidth ناخوانا می‌شود
  // (هر ستون فقط چند پیکسل جا دارد)، به‌جای فشردن‌شان با FlexColumnWidth،
  // خودِ tableContainer را با یک عرضِ عریض‌تر (حداقلِ خواناییِ هر ستون ×
  // تعدادِ ستون‌ها) رندر می‌کنیم و داخل یک اسکرولِ افقی می‌گذاریم؛ چون همه‌ی
  // ردیف‌ها همین یک columnWidths نسبی را دارند، تناسبِ ستون‌ها بین ردیف‌ها
  // حفظ می‌ماند.
  // 🐞 رفع باگِ «اسکرولِ افقیِ بیش‌ازحد فراگیر»: قبلاً وقتی tableWidthPercent
  // ست نشده بود هم (فارغ از strategy) این‌جا فعال می‌شد — یعنی هر جدولِ
  // ساده‌ای که فقط TableWidthPercent نداشت هم اسکرولِ افقی می‌گرفت، که خیلی
  // بیشتر از نیاز بود. حالا فقط به فلگِ صریحِ strategy=="horizontalScroll"
  // متکی است؛ سمتِ C# (ResponsiveLowering.cs) این فلگ را فقط برای
  // استایل‌های خاصِ FigureTable و HBTable ست می‌کند، نه به‌عنوانِ پیش‌فرضِ
  // هر جدولِ ناشناخته‌ای.
  final bool explicitHorizontalScroll = strategy == "horizontalScroll";
  if (!applyColumnStack && explicitHorizontalScroll) {
    int maxColumnCount = 0;
    for (final row in tableSpan.tableRows) {
      if (row.cells.length > maxColumnCount) maxColumnCount = row.cells.length;
    }
    // 🐞 widestContentWidth بالاتر (قبل از حلقه‌ی ساختِ سلول‌ها) یک‌بار
    // محاسبه شده — همان‌جا هم برای stretch‌کردنِ محتوای سلول استفاده شد،
    // اینجا دوباره اسکن نمی‌کنیم، همان مقدار (بیشینه‌ی عرضِ عکس یا عرضِ
    // طبیعیِ یک‌خطِ هر پاراگراف، هرکدام بیشتر بود) را برای عرضِ لازم به کار
    // می‌بریم.
    const double minReadableColumnWidth = 90.0;
    final double columnHeuristicWidth = maxColumnCount * minReadableColumnWidth;
    final double neededWidth = columnHeuristicWidth > widestContentWidth
        ? columnHeuristicWidth
        : widestContentWidth;
    final bool manyColumnsNeedRoom =
        maxColumnCount > 1 && columnHeuristicWidth > canvasWidth;
    final bool embeddedImageNeedsRoom = widestContentWidth > canvasWidth;
    if ((manyColumnsNeedRoom || embeddedImageNeedsRoom) &&
        neededWidth > canvasWidth) {
      final double renderWidth = neededWidth.clamp(
        canvasWidth,
        canvasWidth * 3,
      );
      // 🐞 رفع کرش «Scrollbar's ScrollController has no ScrollPosition
      // attached»: بدون controllerِ صریح، Scrollbar به PrimaryScrollController
      // برمی‌گردد که به این SingleChildScrollViewِ افقیِ تودرتو وصل نیست.
      final ScrollController hCtrl = ScrollController();
      tableContainer = Scrollbar(
        controller: hCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hCtrl,
          scrollDirection: Axis.horizontal,
          // 🐞 رفع باگِ «نوارِ اسکرول داخلِ جدول افتاده»: بدونِ این فاصله،
          // نوارِ اسکرولِ افقی درست روی لبه‌ی پایینیِ بوردرِ جدول لَم
          // می‌دهد و به‌نظر می‌رسد داخلِ خودِ جدول جا گرفته. این ۱۴px
          // فاصله‌ی پایین، جدول و نوارِ اسکرول را از هم جدا نگه می‌دارد.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: SizedBox(width: renderWidth, child: tableContainer),
          ),
        ),
      );
    }
  }

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
  Map<String, AudioLocation> audioFirstOccurrence = const {},
  int? audioPageNumber,
  int? audioParaIndex,
  KeyClaim? keyClaim, // 🐞 مشترک بین همه‌ی اسپن‌های همین پاراگراف
}) {
  double fontSize = 14.0;
  String? fontFamily;
  for (var marker in span.markers) {
    if (marker.startsWith("sz:")) {
      double? parsedSize = double.tryParse(marker.substring(3));
      if (parsedSize != null) fontSize = parsedSize / 2;
    } else if (marker.startsWith("fn:")) {
      fontFamily = mapFontFamily(marker.substring(3));
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
    // 🌟 فاصله‌ی خطوط از Word؛ اما اگر همین span پس‌زمینه‌ی رنگی دارد، حداقلِ
    // ۱٫۴ اعمال می‌شود تا رنگِ خطوطِ پشتِ‌هم به هم نچسبند (وگرنه Word با تک‌فاصله
    // خطوط را طوری می‌چسباند که پس‌زمینه‌ها به هم می‌رسند).
    height: (!isInlineBorder && _hexToColor(span.fillColor) != null)
        ? (para.lineSpacing ?? 1.3).clamp(1.4, 3.0)
        : (para.lineSpacing ?? 1.3),
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
  // 🌟 اگر این span فقط یک توکنِ کوتاهِ رنگی است (مثلِ جای‌خالی‌های "___" یا یک
  // کلمه‌ی تکی هایلایت‌شده، بدون فاصله)، آن را به‌جای TextStyle.backgroundColor
  // (که جعبه‌ی رنگ را دقیقاً به اندازه‌ی «خط» می‌کشد و بین خطوطِ متوالی هیچ فاصله‌ای
  // نمی‌گذارد) با یک Container+padding عمودی رسم می‌کنیم — این تنها راهی است که در
  // فلاتر واقعاً بینِ پس‌زمینه‌ی خطوطِ پشتِ‌هم فاصله‌ی دیداری ایجاد می‌کند.
  final String _content = (span.content ?? "").trim();
  final bool _isSafeHighlightToken =
      !isInlineBorder &&
      _hexToColor(span.fillColor) != null &&
      _content.isNotEmpty &&
      _content.length <= 20 &&
      !_content.contains(' ') &&
      (span.innerSpans.isEmpty);

  if (isAudioLink) {
    interactiveSpans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineAudioLink(
          fileName: span.url!.replaceFirst("audio:", ""),
          text: span.content ?? "",
          baseColor: interactiveColor,
          playlist: pageAudioPlaylist,
          firstOccurrence: audioFirstOccurrence,
          pageNumber: audioPageNumber,
          paraIndex: audioParaIndex,
        ),
      ),
    );
  } else if (_isSafeHighlightToken) {
    interactiveSpans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: _hexToColor(span.fillColor),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            span.content ?? "",
            style: baseStyle.copyWith(backgroundColor: null),
          ),
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
      listMarker: _isWhollyOneBlank(span.content) ? para.listMarker : null,
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
  double? explicitWidth, // 🐞 برای تصاویر عریض که در اسکرول افقی رندر می‌شوند
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

  final double? logicalWidth = explicitWidth;
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

// 🐞 برای قابلیتِ «پلی‌لیستِ کتاب»: هر فایلِ صوتیِ یکتا در کتاب، به همراهِ
// همه‌ی موقعیت‌هایی (صفحه+پاراگراف) که در آن‌ها ظاهر شده — چون یک فایل
// می‌تواند در چند تمرین/جای مختلفِ کتاب استفاده شده باشد، ولی باید فقط
// یک‌بار در لیستِ پخش بیاید.
class BookAudioEntry {
  final String resolvedPath;
  final String fileName;
  final List<AudioLocation> occurrences;
  BookAudioEntry({
    required this.resolvedPath,
    required this.fileName,
    required this.occurrences,
  });
}

// یک اسکنِ یک‌باره از تمامِ صفحاتِ کتاب برای جمع‌آوریِ پلی‌لیستِ کتاب‌محور.
// چون این کار روی کلِ کتاب است (نه فقط یک صفحه)، فراخوان (ReadingCanvasScreen)
// باید نتیجه‌اش را کش کند و به‌ازای هر rebuild دوباره صدا نزند.
List<BookAudioEntry> buildBookAudioPlaylist(
  List<PageData> pages,
  BookModel? activeBook, {
  // 🐞 شاخصِ از‌قبل‌محاسبه‌شده (AudioLinksIndex در index.json، سمتِ C#).
  // اگر داده شود و خالی نباشد، پلی‌لیست مستقیم از رویِ همین ساخته می‌شود
  // — بدونِ نیاز به گشتنِ محتوای هیچ صفحه‌ای، که دقیقاً همان چیزی است که
  // لودِ تنبل/صفحه‌به‌صفحه (PagedBookStore) به آن نیاز دارد. اگر داده
  // نشود یا خالی باشد (کتابی که هنوز با ابزارِ جدیدِ C# استخراج نشده)، به
  // همان اسکنِ زنده‌ی قبلی برمی‌گردیم.
  List<AudioLinkEntry>? precomputedIndex,
}) {
  final Map<String, BookAudioEntry> byPath = {};
  final List<String> order = [];

  void addOccurrence(
    String resolved,
    String fileName,
    int pageNumber,
    int paraIndex,
  ) {
    BookAudioEntry? entry = byPath[resolved];
    if (entry == null) {
      entry = BookAudioEntry(
        resolvedPath: resolved,
        fileName: fileName,
        occurrences: [],
      );
      byPath[resolved] = entry;
      order.add(resolved);
    }
    entry.occurrences.add(
      AudioLocation(pageNumber: pageNumber, paraIndex: paraIndex),
    );
  }

  if (precomputedIndex != null && precomputedIndex.isNotEmpty) {
    for (final entry in precomputedIndex) {
      final resolved = InlineAudioLink.resolveAudioPath(
        entry.fileName,
        activeBook,
      );
      addOccurrence(
        resolved,
        entry.fileName,
        entry.pageNumber,
        entry.paraIndex,
      );
    }
    return order.map((k) => byPath[k]!).toList();
  }

  // 🐞 رفع باگِ «پلی‌لیست فقط یک فایل نشان می‌دهد»: قبلاً فقط اسپن‌های
  // سطحِ‌بالای خودِ پاراگراف چک می‌شد؛ چون اکثرِ تمرین‌های این کتاب داخلِ
  // یک جدول‌اند (BorderedTable/NormalTable/...)، دکمه‌های صوتیِ داخلِ
  // سلول‌های جدول اصلاً دیده نمی‌شدند. حالا اگر اسپن از نوعِ «table» باشد،
  // به‌صورتِ بازگشتی داخلِ سلول‌هایش (و جدول‌های تودرتوی احتمالیِ داخلِ
  // همان سلول‌ها) هم می‌گردد — ولی همیشه pageNumber/paraIndex همان
  // پاراگرافِ بیرونی را گزارش می‌دهد (نه اندیسِ داخلیِ سلول)، چون این دقیقاً
  // همان قراردادی است که هنگامِ رندر هم برای audioPageNumber/audioParaIndex
  // استفاده می‌شود — در غیرِ این صورت هدفِ پرش معتبر نبود.
  void scanSpans(List<SpanData> spans, int pageNumber, int topParaIndex) {
    for (final s in spans) {
      if (s.url != null && s.url!.startsWith("audio:")) {
        final fileName = s.url!.replaceFirst("audio:", "");
        if (fileName.isNotEmpty) {
          final resolved = InlineAudioLink.resolveAudioPath(
            fileName,
            activeBook,
          );
          addOccurrence(resolved, fileName, pageNumber, topParaIndex);
        }
      }
      if (s.type == "table") {
        for (final row in s.tableRows) {
          for (final cell in row.cells) {
            for (final p in cell.paragraphs) {
              scanSpans(p.spans, pageNumber, topParaIndex);
            }
          }
        }
      }
    }
  }

  for (final page in pages) {
    for (int pIndex = 0; pIndex < page.paragraphs.length; pIndex++) {
      scanSpans(page.paragraphs[pIndex].spans, page.pageNumber, pIndex);
    }
  }

  return order.map((k) => byPath[k]!).toList();
}

// اولین وقوعِ هر فایل، برای رفتارِ sequential (دکمه‌های قبلی/بعدی و خودِ
// لیستِ پخش) — همان چیزی که AudioPlayerNotifier.playFile وقتی
// explicitLocation پاس داده نشود استفاده می‌کند.
Map<String, AudioLocation> bookAudioFirstOccurrence(
  List<BookAudioEntry> entries,
) {
  return {for (final e in entries) e.resolvedPath: e.occurrences.first};
}

class InlineAudioLink extends ConsumerWidget {
  final String fileName;
  final String text;
  final Color baseColor;
  // 🌟 پلی‌لیستِ همه‌ی فایل‌های صوتیِ کتاب (مسیرهای resolve‌شده)، تا
  // دکمه‌های بعدی/قبلی در پلیر واقعاً چیزی برای رفتن داشته باشند. قبلاً هر
  // لینک هنگام پخش فقط خودش را به‌عنوان یک پلی‌لیستِ تک‌عضوی می‌فرستاد، پس
  // دکمه‌ی بعدی/قبلی همیشه در انتهای لیست بود و کاری نمی‌کرد.
  final List<String> playlist;
  // 🐞 اولین وقوعِ هر فایل در کتاب — همراهِ پلی‌لیست به پلیر پاس داده
  // می‌شود تا وقتی از طریقِ قبلی/بعدی به این فایل رسیدیم، دکمه‌ی «برو به
  // متن» بداند به کجا برود.
  final Map<String, AudioLocation> firstOccurrence;
  // 🐞 موقعیتِ خودِ همین دکمه در کتاب (صفحه + اندیسِ پاراگراف) — وقتی خودِ
  // همین دکمه تپ شود، این دقیقاً همان جایی است که «برو به متن» باید به آن
  // برگردد، نه لزوماً اولین وقوعِ فایل.
  final int? pageNumber;
  final int? paraIndex;

  const InlineAudioLink({
    super.key,
    required this.fileName,
    required this.text,
    required this.baseColor,
    this.playlist = const [],
    this.firstOccurrence = const {},
    this.pageNumber,
    this.paraIndex,
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
          final AudioLocation? thisLocation =
              (pageNumber != null && paraIndex != null)
              ? AudioLocation(pageNumber: pageNumber!, paraIndex: paraIndex!)
              : null;
          ref
              .read(audioPlayerProvider.notifier)
              .playFile(
                targetPath,
                newPlaylist: effectivePlaylist,
                newFirstOccurrence: firstOccurrence,
                // 🐞 خودِ همین دکمه تپ شده → این دقیقاً وقوعِ موردنظرِ
                // کاربر است، نه صرفاً اولین وقوعِ فایل.
                explicitLocation: thisLocation,
              );
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
