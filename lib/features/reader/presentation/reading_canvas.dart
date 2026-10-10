// 🔊 🎧 ▶ ▶️
// ignore_for_file: unused_local_variable, unused_import

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// 🌟 برای زومِ دسکتاپ: PointerScrollEvent از gestures و HardwareKeyboard/
// LogicalKeyboardKey از services می‌آیند. هیچ‌کدام در showـلیستِ صادراتیِ
// material نیستند، پس باید صریح import شوند.
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:float_column/float_column.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/reader/data/paged_book_store.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/text_render_engine.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/core/text/document_text_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/audio/presentation/audio_player_bar.dart';
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

class ReadingCanvas extends ConsumerStatefulWidget {
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
  const ReadingCanvas({
    super.key,
    required this.pagedBookStore,
    required this.audioScripts,
    this.precomputedAudioLinksIndex = const [],
  });

  @override
  ConsumerState<ReadingCanvas> createState() {
    return _ReadingCanvasState();
  }
}

class _ReadingCanvasState extends ConsumerState<ReadingCanvas> {
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

  // 🐞 قبلاً «زوم» فقط یعنی بزرگ‌تر از ۱۰۰٪. حالا که کوچک‌نماییِ زیرِ ۱۰۰٪ هم
  // ممکن است، این گتر باید هر انحرافی از اندازه‌ی اصلی را زوم بداند — وگرنه
  // در حالتِ کوچک‌شده دکمه‌ی «بازگشت به اندازه اصلی» ظاهر نمی‌شد.
  bool get _isZoomed => (_currentScale - 1.0).abs() > 0.02;

  /// فقط بزرگ‌نمایی. pan معنایش وقتی است که محتوا از کادر بزرگ‌تر شده باشد؛
  /// در حالتِ کوچک‌شده چیزی برای جابه‌جا کردن نیست.
  bool get _isZoomedIn => _currentScale > 1.02;
  bool get _isPinching => _pointerCount >= 2;

  // ── زوم روی دسکتاپ (ویندوز/لینوکس/مک) ────────────────────────────────
  // روی موبایل زوم با pinch انجام می‌شود و این بخش عملاً بی‌اثر است.
  // 🐞 ریشه‌ی «دکمه‌ی کوچک‌نمایی کار نمی‌کند»: کفِ زوم ۱.۰ بود، یعنی در
  // اندازه‌ی اصلی هیچ‌جایی برای کوچک‌تر شدن وجود نداشت و دکمه درست‌کار ولی
  // غیرفعال می‌ماند. روی موبایل همان کفِ ۱.۰ منطقی است (کوچک‌کردنِ متن روی
  // صفحه‌ی کوچک فقط ناخوانا می‌شود)، ولی روی دسکتاپ که صفحه بزرگ است،
  // کوچک‌نمایی برای دیدنِ کلِ صفحه یک خواسته‌ی طبیعی است.
  static const double _kDesktopMinZoom = 0.5;
  static const double _kMaxZoom = 3.5;

  double get _minZoom => _isDesktop ? _kDesktopMinZoom : 1.0;
  static const double _kZoomStep = 1.25; // برای دکمه‌ها و Ctrl +/-
  static const double _kWheelZoomStep =
      1.12; // ریزتر، چون چرخ تیک‌های زیاد می‌زند

  /// کلیدِ ویجتِ Listener — برای گرفتنِ اندازه‌ی واقعیِ ناحیه‌ی نمایش هنگام
  /// محدودکردنِ جابه‌جایی بعد از زوم.
  final GlobalKey _viewerKey = GlobalKey();

  /// آیا Ctrl (یا Cmd روی مک) همین حالا نگه داشته شده است؟
  bool _ctrlHeld = false;

  /// دکمه‌های ‎+/−‎ فقط روی دسکتاپ معنا دارند؛ روی موبایل pinch هست و
  /// شلوغ‌کردنِ صفحه ارزشی ندارد.
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
  //
  // 🐞 «روی ویندوز بعد از زوم، اسکرولِ افقی ممکن نیست»: قبلاً این‌جا
  // `if (!_isPinching) return;` بود، یعنی _currentScale *فقط* با pinchِ دو
  // انگشتی به‌روز می‌شد. روی اندروید زوم همیشه pinch است، ولی روی ویندوز زوم از
  // Ctrl+چرخ، دکمه‌های ‎+/−‎ و Ctrl+/− (یعنی _zoomBy) می‌آید — پس _currentScale
  // روی ۱ می‌ماند، _isZoomedIn=false و در نتیجه panEnabledِ InteractiveViewer
  // خاموش می‌ماند (دکمه‌ی «بازگشت به اندازه‌ی اصلی» هم ظاهر نمی‌شد).
  // گارد لازم نبود: جابه‌جاییِ افقیِ IV فقط translation را عوض می‌کند و اسکیل
  // ثابت می‌ماند، پس شرطِ پایین (تغییرِ اسکیل > ۰.۰۰۵) خودش جلوی setStateِ
  // اضافه را می‌گیرد؛ اسکرولِ عمودیِ معمولی هم اصلاً به این کنترلر دست نمی‌زند.
  void _onTransformChanged() {
    final s = _transformationController.value.getMaxScaleOnAxis();
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  /// میان‌برهای زومِ دسکتاپ + دنبال‌کردنِ وضعیتِ Ctrl.
  /// خروجی true یعنی «کلید مصرف شد». فقط برای همان سه میان‌بر true
  /// برمی‌گردانیم تا هیچ کلیدِ دیگری (تایپ در جستجو، دیالوگ‌ها) دست نخورد.
  bool _handleKeyEvent(KeyEvent event) {
    final bool ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (ctrl != _ctrlHeld && mounted) {
      setState(() => _ctrlHeld = ctrl);
    }

    if (!ctrl || event is! KeyDownEvent) return false;

    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _zoomBy(_kZoomStep);
      return true;
    }
    if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(1 / _kZoomStep);
      return true;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      _resetZoom();
      return true;
    }
    return false;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    if (mounted) setState(() => _currentScale = 1.0);
  }

  /// زومِ برنامه‌ای حولِ یک نقطه‌ی کانونی (محلِ نشانگرِ ماوس، یا مرکزِ صفحه
  /// وقتی از دکمه/میان‌بر می‌آید).
  ///
  /// چرا دستی و نه از خودِ InteractiveViewer: چرخِ ماوس در IV عمداً با
  /// scaleFactor بسیار بزرگ خنثی شده (وگرنه بی‌آنکه بخواهیم، هم‌زمان با
  /// اسکرول زوم می‌کرد). پس زومِ خواسته‌شده را این‌جا خودمان روی همان
  /// transformationController اعمال می‌کنیم — یعنی pinch و این مسیر روی یک
  /// حالتِ مشترک کار می‌کنند و با هم ناسازگار نمی‌شوند.
  void _zoomBy(double factor, {Offset? focalPoint}) {
    final RenderObject? ro = _viewerKey.currentContext?.findRenderObject();
    final Size viewport = (ro is RenderBox && ro.hasSize)
        ? ro.size
        : MediaQuery.of(context).size;

    final Offset focal =
        focalPoint ?? Offset(viewport.width / 2, viewport.height / 2);

    final Matrix4 current = _transformationController.value;
    final double currentScale = current.getMaxScaleOnAxis();
    final double target = (currentScale * factor).clamp(_minZoom, _kMaxZoom);
    final double applied = target / currentScale;
    if ((applied - 1.0).abs() < 0.0001) return;

    // 🌟 عبور از ۱۰۰٪ دقیقاً روی ۱۰۰٪ بایستد: بدونِ این، پله‌های ۱.۲۵ هیچ‌وقت
    // سرِ راست به اندازه‌ی اصلی نمی‌رسند و کاربر مجبور می‌شد دکمه‌ی ریست را
    // بزند تا «۱۰۰٪» را ببیند.
    if ((target - 1.0).abs() < 0.02) {
      _resetZoom();
      return;
    }

    // M' = T(focal) · S(applied) · T(-focal) · M
    // یعنی نقطه‌ای که زیرِ نشانگر است، دقیقاً همان‌جا می‌ماند.
    final Matrix4 next = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(applied)
      ..translate(-focal.dx, -focal.dy);
    final Matrix4 result = next * current;

    final double newScale = result.getMaxScaleOnAxis();

    // 🐞 محدودکردنِ جابه‌جایی: InteractiveViewer فقط حرکت‌های *خودش* را
    // داخلِ کادر نگه می‌دارد؛ چون این‌جا مستقیم روی کنترلر می‌نویسیم، بدونِ
    // این کلمپ زوم روی لبه‌ی صفحه می‌توانست فضای خالی کنارِ محتوا باز کند.
    if (newScale > 1.0) {
      final translation = result.getTranslation();
      result.setTranslationRaw(
        translation.x.clamp(viewport.width * (1 - newScale), 0.0),
        translation.y.clamp(viewport.height * (1 - newScale), 0.0),
        0.0,
      );
    } else {
      // 🐞 مسیرِ کوچک‌نمایی نمی‌تواند از همان کلمپ استفاده کند: با scale<1
      // مقدارِ viewport.width*(1-scale) *مثبت* است و از حدِ بالا (۰) بزرگ‌تر
      // می‌شود — و clamp در دارت با lower > upper خطا پرتاب می‌کند. این‌جا
      // اصلاً محدودیتی لازم نیست: محتوا از کادر کوچک‌تر شده، فقط افقی
      // وسط‌چین و عمودی از بالا می‌چسبانیمش.
      result.setTranslationRaw(viewport.width * (1 - newScale) / 2, 0.0, 0.0);
    }

    _transformationController.value = result;
  }

  /// 🌟 جابه‌جاییِ افقیِ صفحه‌ی زوم‌شده با چرخِ ماوس (Shift+چرخ، چرخِ افقی
  /// یا اسکرولِ کناریِ تاچ‌پد) — قراردادِ رایجِ دسکتاپ. با ماوس هم می‌شود
  /// صفحه را کشید (pan داخلِ خودِ InteractiveViewer)، ولی چرخ راحت‌تر است.
  /// dx مثبت یعنی محتوا به راست می‌رود. محدوده همان کلمپِ _zoomBy است تا
  /// هیچ‌وقت فضای خالی کنارِ صفحه باز نشود.
  void _panHorizontallyBy(double dx) {
    final RenderObject? ro = _viewerKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final double viewportWidth = ro.size.width;

    final Matrix4 m = _transformationController.value.clone();
    final double s = m.getMaxScaleOnAxis();
    if (s <= 1.0) return;

    final t = m.getTranslation();
    final double nx = (t.x + dx).clamp(viewportWidth * (1 - s), 0.0);
    if ((nx - t.x).abs() < 0.01) return;
    m.setTranslationRaw(nx, t.y, t.z);
    _transformationController.value = m;
  }

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);
    // 🌟 هندلرِ سراسریِ صفحه‌کلید: هم وضعیتِ Ctrl را دنبال می‌کند (برای
    // Ctrl+چرخ) و هم میان‌برهای Ctrl + / − / 0 را اجرا می‌کند. سراسری است
    // چون به فوکوسِ ویجت وابسته نباشد.
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

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
      // 🐞 دیگر «ایندکس + ۱» نیست: استخراج‌کننده می‌تواند شماره‌گذاری را از
      // عددِ دلخواه شروع کند، پس شماره‌ی واقعیِ صفحه از index.json خوانده
      // می‌شود. فالبکِ index+1 برای کتاب‌های قدیمی رفتارِ قبلی را نگه می‌دارد.
      final newPage =
          widget.pagedBookStore.pageNumberForIndex(topItem.index) ??
          (topItem.index + 1);
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
      // 🐞 از ۱۲۰۰ به ۲۵۰۰ رفت: با مکثِ کوتاه، نشان دیگر بلافاصله کم‌رنگ
      // نمی‌شود، پس در خواندنِ عادی (اسکرول، مکث، اسکرول) مدام حالت عوض
      // نمی‌کند.
      _badgeTimer = Timer(const Duration(milliseconds: 2500), () {
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
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  // 🌟 دیالوگِ «رفتن به صفحه» (مثل PDF‌خوان‌ها)
  Future<void> _openJumpToPageDialog() async {
    final total = widget.pagedBookStore.pageCount;
    final int firstPage = widget.pagedBookStore.firstPageNumber;
    final int lastPage = widget.pagedBookStore.lastPageNumber;
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
              hintText: 'شماره‌ای بین $firstPage تا $lastPage',
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

    // 🐞 قبلاً مستقیم `n - 1` به‌عنوانِ ایندکس استفاده می‌شد، که فقط وقتی
    // درست است که صفحات از ۱ شروع شوند. حالا شماره → ایندکس از همان نگاشتی
    // خوانده می‌شود که جستجو هم از آن استفاده می‌کند.
    final int targetIndex =
        (n == null ? null : widget.pagedBookStore.indexForPageNumber(n)) ??
        ((n != null && n >= 1 && n <= total) ? n - 1 : -1);

    if (targetIndex >= 0 &&
        targetIndex < total &&
        _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: targetIndex,
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
          // 🌟 روی دسکتاپ pinch وجود ندارد، پس دکمه‌های صریحِ بزرگ‌نمایی/
          // کوچک‌نمایی لازم‌اند. روی موبایل نمایش داده نمی‌شوند.
          if (_isDesktop) ...[
            FloatingActionButton.small(
              heroTag: 'zoomIn',
              onPressed: _currentScale >= _kMaxZoom - 0.01
                  ? null
                  : () => _zoomBy(_kZoomStep),
              backgroundColor: Colors.black.withOpacity(0.55),
              elevation: 3,
              tooltip: 'بزرگ‌نمایی (Ctrl و +، یا Ctrl و چرخِ ماوس)',
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'zoomOut',
              onPressed: _currentScale <= _minZoom + 0.01
                  ? null
                  : () => _zoomBy(1 / _kZoomStep),
              backgroundColor: Colors.black.withOpacity(0.55),
              elevation: 3,
              tooltip: 'کوچک‌نمایی (Ctrl و −)',
              child: const Icon(Icons.remove, color: Colors.white),
            ),
            const SizedBox(height: 8),
          ],
          if (_isZoomed)
            FloatingActionButton.small(
              heroTag: 'zoomReset',
              onPressed: _resetZoom,
              backgroundColor: Colors.orange,
              elevation: 4,
              tooltip: 'بازگشت به اندازه اصلی (Ctrl و ۰)',
              child: const Icon(Icons.zoom_out_map, color: Colors.white),
            ),
          const SizedBox(height: 8),
          // 🌟 نشانِ شماره‌ی صفحه؛ ضربه روی آن دیالوگِ «رفتن به صفحه» را باز
          // می‌کند.
          //
          // 🐞 دو ایرادِ گزارش‌شده این‌جا اصلاح شد:
          // ۱) «چشمک‌زدن»: قبلاً بینِ opacity صفر و یک می‌رفت، پس با هر مکثِ
          //    کوتاهِ کاربر کامل محو و دوباره ظاهر می‌شد. حالا همیشه دیده
          //    می‌شود و فقط بینِ «کم‌رنگ» و «پررنگ» جابه‌جا می‌شود — با
          //    ترنزیشنِ کندتر (۴۰۰ms و easeOutCubic) که چشم را نمی‌زند.
          //    IgnorePointer هم حذف شد، چون حالا همیشه قابلِ لمس است.
          // ۲) ظاهر: FloatingActionButton.extended برای یک نشانِ اطلاعاتی
          //    زیادی سنگین بود. حالا یک چیپِ قرصی‌شکلِ نیمه‌شفاف با حاشیه‌ی
          //    نازک است که رویِ هر رنگِ صفحه می‌نشیند.
          //
          // 🌟 و برچسب: عدد دوم دیگر «تعدادِ کل صفحات» نیست بلکه شماره‌ی
          // آخرین صفحه است — چون استخراج‌کننده می‌تواند شماره‌گذاری را از
          // عددِ دلخواه شروع کند و «صفحه ۲۰ از ۱۲» بی‌معنی می‌شد.
          AnimatedOpacity(
            opacity: _showPageBadge ? 1.0 : 0.62,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.black.withOpacity(0.62),
              elevation: 2,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openJumpToPageDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'صفحه $_currentPage از ${widget.pagedBookStore.lastPageNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
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
                key: _viewerKey,
                // 🌟 Ctrl + چرخِ ماوس = زوم (قراردادِ رایجِ دسکتاپ). بدونِ
                // Ctrl هیچ کاری نمی‌کنیم و چرخ فقط اسکرول می‌کند.
                onPointerSignal: (e) {
                  if (e is! PointerScrollEvent) return;
                  if (_ctrlHeld) {
                    if (e.scrollDelta.dy == 0) return;
                    _zoomBy(
                      e.scrollDelta.dy < 0
                          ? _kWheelZoomStep
                          : 1 / _kWheelZoomStep,
                      focalPoint: e.localPosition,
                    );
                    return;
                  }
                  // 🌟 صفحه‌ی زوم‌شده: Shift+چرخ یا چرخ/تاچ‌پدِ افقی = جابه‌جاییِ
                  // افقی. از طریقِ pointerSignalResolver ثبت می‌شود تا اگر
                  // نشانگر روی یک جدول/عکسِ اسکرول‌شونده‌ی افقی است که هنوز جا
                  // برای حرکت دارد، اول همان اسکرول شود (Scrollableِ داخلی زودتر
                  // ثبت می‌کند و برنده است) و فقط وقتی به لبه رسید، صفحه جابه‌جا
                  // شود. لیستِ عمودی با Shift خودش dx را می‌خواند (صفر) و ثبت
                  // نمی‌کند، پس با این تداخل ندارد.
                  if (!_isZoomedIn) return;
                  final bool shift = HardwareKeyboard.instance.isShiftPressed;
                  final double dx = e.scrollDelta.dx != 0
                      ? e.scrollDelta.dx
                      : (shift ? e.scrollDelta.dy : 0.0);
                  if (dx == 0) return;
                  GestureBinding.instance.pointerSignalResolver.register(
                    e,
                    (_) => _panHorizontallyBy(-dx),
                  );
                },
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
                  panEnabled: _isZoomedIn,
                  panAxis: PanAxis.horizontal,
                  // scale همیشه فعال — pinch را در هر لحظه تشخیص می‌دهد
                  scaleEnabled: true,
                  // 🐞 رفعِ «اسکرول به بالا اول زوم می‌کند»: InteractiveViewer
                  // چرخِ ماوس را هم به‌عنوانِ زوم می‌گیرد
                  // (scaleChange = exp(-scrollDelta.dy / scaleFactor)) و این کار
                  // را مستقل از لیستِ زیرش انجام می‌دهد — پس هر دو با هم واکنش
                  // نشان می‌دادند. رو به پایین چون زوم را کم می‌کند و اسکیل
                  // از قبل روی minScale=1 است، هیچ اثری دیده نمی‌شد؛ رو به بالا
                  // ولی تا maxScale زوم می‌کرد و تازه بعدش اسکرول دیده می‌شد.
                  // با یک scaleFactor بسیار بزرگ، سهمِ هر تیکِ چرخ در زوم
                  // عملاً صفر می‌شود (exp(-100/1e9) ≈ 1) و چرخ فقط اسکرول
                  // می‌کند. مهم: این پارامتر *فقط* روی چرخِ ماوس اثر دارد، پس
                  // pinch با دو انگشت و زومِ ترک‌پد دست‌نخورده باقی می‌مانند.
                  scaleFactor: 1e9,
                  minScale: _minZoom,
                  maxScale: _kMaxZoom,
                  clipBehavior: Clip.hardEdge,

                  // وقتی کاربر انگشتان را برمی‌دارد:
                  // اگر scale ≈ 1 بود → ریست کامل transform
                  onInteractionEnd: (_) {
                    final s = _transformationController.value
                        .getMaxScaleOnAxis();
                    // 🐞 قبلاً «s <= 1.02» بود، یعنی هر نتیجه‌ی کوچک‌نمایی
                    // (که همیشه زیرِ ۱ است) بلافاصله به ۱۰۰٪ پرت می‌شد.
                    // حالا فقط وقتی ریست می‌کنیم که کاربر عملاً *روی* اندازه‌ی
                    // اصلی ایستاده باشد.
                    if ((s - 1.0).abs() <= 0.02) {
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

                              // 🐞 نکته‌ی ظریف: Listenerِ ما بالای لیست است،
                              // پس اگر لیست بتواند اسکرول کند، Ctrl+چرخ
                              // هم‌زمان زوم *و* اسکرول می‌کرد. وقتی Ctrl
                              // نگه داشته شده اسکرول را می‌بندیم؛ آن‌وقت
                              // Scrollable اصلاً رویدادِ چرخ را برنمی‌دارد
                              // و فقط زوم می‌ماند.
                              physics: (_isPinching || _ctrlHeld)
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
              child: AudioPlayerBar(
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
  // ReadingCanvas پاس داده می‌شود تا یک‌بار برای کل کتاب محاسبه شود،
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
  // مشکل: هر setState در ReadingCanvas (تغییر _pointerCount، zoom، ...)
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
    // پلی‌لیست از سطحِ ReadingCanvas (که کلِ کتاب را می‌بیند، نه فقط
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
  if (normalized.contains("segoepr")) {
    return "Segoepr";
  }
  if (normalized.contains("comic")) {
    return "Comic";
  }
  return "Source Sans 3";
}

// 🐞 رنگِ بوردری که *خودِ سند* تعریف کرده، همان‌طور که Word رسمش می‌کند. در Word
// رنگِ «auto» (یا نبودنِ w:color) برای بوردر یعنی مشکی، و صفحه‌ی مطالعه هم
// همیشه روشن است. اکسترکتورِ قدیمی «auto» را null می‌نوشت و این‌جا خاکستریِ
// روشن کشیده می‌شد، پس بوردرهای مشکیِ سند در اپ کم‌رنگ دیده می‌شدند (Mindset 3:
// ۱۱۵ جدولِ CommonTable). اکسترکتورِ جدید کلمه‌ی "auto" را صریح می‌نویسد
// (نه "000000"، تا جایی که تمِ تیره دارد — پنجره‌ی متنِ مخفی — بتواند آن را
// به رنگِ متن ببرد)؛ هر دو حالت (null در JSONِ قدیمی و "auto" در جدید) این‌جا
// مشکی می‌شوند، پس استخراجِ مجدد لازم نیست.
// ⚠️ فقط برای بوردری که شیءِ BorderDetail دارد (یعنی از سند آمده). جایی که
// اپ خودش بوردرِ پیش‌فرض می‌کشد (مثلاً جعبه‌ی CompactTableی که سند بوردری
// برایش تعریف نکرده) null برمی‌گرداند تا همان رنگِ پیش‌فرضِ قبلی بماند.
Color? _docBorderColor(BorderDetail? border) =>
    border == null ? null : (_hexToColor(border.color) ?? Colors.black);

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

/// 🌟 محتوای غنیِ جای‌خالی (مودالِ آیکونِ چشم) با *همان* رندرِ صفحه.
///
/// درخواستِ کاربر: هر چیزی که در حالتِ عادی نشان داده می‌شود — جدول، عکس، لیست،
/// رنگ، بوردر، … — باید در جوابِ مخفی هم بی‌محدودیت قابلِ نمایش باشد. مودال قبلاً
/// فقط اسپن‌های متنیِ تخت (innerSpans) را می‌شناخت. حالا وقتی اکسترکتور
/// `HiddenParagraphs` فرستاده، هر پاراگراف دقیقاً با `_buildParagraph` (همان تابعی
/// که صفحه را می‌سازد) رندر می‌شود؛ پس هر قابلیتی که صفحه دارد یا بعداً پیدا
/// کند، خودبه‌خود در مودال هم هست.
///
/// [width] عرضِ واقعیِ ناحیه‌ی محتوای مودال است (جدول‌ها و عکس‌ها بر همین
/// اساس جا می‌شوند). مقیاسِ فونتِ سیستم مثلِ صفحه‌ی مطالعه خنثی می‌شود تا
/// اندازه‌گیری‌های جدول (که با noScaling انجام می‌شوند) با رندر یکی باشند.
Widget buildHiddenRichContent(
  BuildContext context,
  List<ParagraphData> paragraphs,
  double width, {
  List<InteractiveWord> interactives = const [],
}) {
  final BookModel? activeBook = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(activeBookProvider);
  final double screenWidth = MediaQuery.of(context).size.width;

  // کلماتِ دیکشنری: هم آن‌هایی که به پاراگرافِ والد چسبیده (شاملِ متنِ مخفی)
  // و هم آن‌هایی که document_loader به خودِ پاراگراف‌های مخفی داده است.
  final Map<String, InteractiveWord> byText = {
    for (final w in interactives) w.exactText: w,
    for (final p in paragraphs)
      for (final w in p.interactives) w.exactText: w,
  };
  final List<InteractiveWord> allInteractives = byText.values.toList();

  // 🐞 حذفِ تورفتگیِ پایه‌ی جواب (همان قاعده‌ی مودالِ متنی، Mindset 2 ص۴۹ تمرین
  // ۱۱): در مودال متنِ سؤال نیست، پس تورفتگی‌ای که جواب را زیرِ سؤال می‌نشاند
  // معنایی ندارد. «چپ‌ترین نقطه»ی هر پاراگراف = IndentLeft + (تورفتگیِ خطِ اول
  // اگر منفی/آویزان است) — یعنی جای شماره‌ی لیست هم حساب می‌شود؛ کمترینِ آن
  // بینِ پاراگراف‌ها از IndentLeftِ همه کم می‌شود. نتیجه: جواب از لبه شروع
  // می‌شود، ولی تورفتگی‌های نسبی (زیربند، تورفتگیِ آویزانِ لیستِ شماره‌دار که
  // خطوطِ دومش زیرِ متن می‌آیند) دست‌نخورده می‌مانند. جدول‌ها و پاراگراف‌های
  // داخلِ سلول‌ها لمس نمی‌شوند.
  double leftmost(ParagraphData p) {
    final double left = p.indentLeft ?? 0;
    final double first = p.indentFirstLine ?? 0;
    return left + (first < 0 ? first : 0);
  }

  final List<double> leftmosts = [
    for (final p in paragraphs)
      if (p.spans.any((s) => s.type != "table" && s.type != "layout"))
        leftmost(p),
  ];
  final double baseIndent = leftmosts.isEmpty
      ? 0
      : leftmosts.reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
  final List<ParagraphData> normalized = baseIndent <= 0.5
      ? paragraphs
      : [
          for (final p in paragraphs)
            (p.indentLeft ?? 0) > 0
                ? p.copyWith(
                    indentLeft: ((p.indentLeft ?? 0.0) - baseIndent).clamp(
                      0.0,
                      double.infinity,
                    ),
                  )
                : p,
        ];

  return MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < normalized.length; i++)
          _buildParagraph(
            normalized[i],
            width,
            screenWidth,
            context,
            prevPara: i > 0 ? normalized[i - 1] : null,
            nextPara: i < normalized.length - 1 ? normalized[i + 1] : null,
            activeBook: activeBook,
            pageInteractives: allInteractives,
            keyClaim: KeyClaim(),
          ),
      ],
    ),
  );
}

Widget _buildParagraph(
  ParagraphData para,
  double canvasWidth,
  double screenWidth,
  BuildContext context, {
  bool isImageCell = false,
  bool isInsideTableCell = false,
  // 🐞 CommonTable: عکس‌های داخلِ سلول با ابعادِ طبیعیِ سند (verbatim) رندر
  // شوند تا ابعادِ قطعی داشته باشند و زیرِ intrinsicHeight جمع نشوند/خالی
  // نمانند (به‌ویژه سلولِ فقط‌عکس بدونِ متن).
  bool verbatimCellImage = false,
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
  // 🐞 پاراگرافِ «فقط‌شماره»ی لیست (Mindset 2 ص۵۳ تمرینِ ۰۶: ستونِ اولِ جدول فقط
  // شماره‌ی خودکارِ ۱ تا ۶ دارد): متن ندارد ولی Word شماره‌اش را نشان می‌دهد،
  // پس نباید مثلِ پاراگرافِ خالی کنار گذاشته شود. اکسترکتور برایش یک اسپنِ
  // متنیِ خالی با فونت/اندازه‌ی واقعی می‌فرستد؛ مسیرِ عادیِ لیست (پایین‌تر)
  // شماره را در کادرش می‌کشد و محتوای خالی ارتفاعی نمی‌گیرد.
  final bool markerOnlyListItem =
      para.listMarker != null && para.listMarker!.trim().isNotEmpty;
  if (!markerOnlyListItem &&
      (para.spans.isEmpty ||
          (para.spans.length == 1 &&
              para.spans.first.type == "text" &&
              (para.spans.first.content == "\n" ||
                  (para.spans.first.content).trim().isEmpty)))) {
    return const SizedBox.shrink();
  }

  mapOffset ??= MapOffset();
  keyClaim ??= KeyClaim();

  List<Object> blockElements = [];
  List<InlineSpan> currentInlineSpans = [];
  // 🐞 پیش‌فرض از left به start عوض شد: وقتی سند هیچ هم‌ترازی‌ای تعیین نکرده،
  // ورد از جهتِ خودِ پاراگراف پیروی می‌کند — یعنی پاراگرافِ RTL راست‌چین است،
  // نه چپ‌چین. Directionality (پایین‌تر، از para.direction) این را حل می‌کند.
  // "S"/"E" مقادیرِ تازه‌ی سی‌شارپ برای start/end هستند (که در ورد نسبت به
  // جهتِ پاراگراف‌اند، نه چپ/راستِ مطلق)؛ "L"/"R"/"C"/"J" مثلِ قبل کار
  // می‌کنند، پس JSONهای قدیمی بدونِ استخراجِ مجدد هم درست می‌مانند.
  TextAlign textAlign = TextAlign.start;
  if (para.alignment == "L") textAlign = TextAlign.left;
  if (para.alignment == "C") textAlign = TextAlign.center;
  if (para.alignment == "R") textAlign = TextAlign.right;
  if (para.alignment == "J") textAlign = TextAlign.justify;
  if (para.alignment == "S") textAlign = TextAlign.start;
  if (para.alignment == "E") textAlign = TextAlign.end;

  // 🌟 همان هم‌ترازی برای بلاک‌های غیرمتنی (عکسِ مستقل) — تا عکس هم دقیقاً
  // همان‌جایی بنشیند که در سند نشسته بود. اگر سند هم‌ترازی تعیین نکرده
  // باشد (alignment == null) عمداً همان رفتارِ قبلی (وسط‌چین) نگه داشته
  // می‌شود، تا کتاب‌های قبلاً استخراج‌شده ناگهان تغییرِ ظاهر ندهند.
  final Alignment? standaloneBlockAlign = switch (para.alignment) {
    "C" => Alignment.center,
    "R" => Alignment.centerRight,
    "L" => Alignment.centerLeft,
    "J" => Alignment.centerLeft,
    "S" =>
      para.direction == "RTL" ? Alignment.centerRight : Alignment.centerLeft,
    "E" =>
      para.direction == "RTL" ? Alignment.centerLeft : Alignment.centerRight,
    _ => null,
  };

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

          // 🐞 در سلولِ CommonTable عکس را عیناً با ابعادِ سند رندر می‌کنیم.
          // دادنِ عرض *و* ارتفاعِ صریح یعنی عکس فوراً (حتی پیش از لود) همان
          // فضا را می‌گیرد، پس در پاسِ اندازه‌گیریِ intrinsicHeight ارتفاعِ
          // درست دارد و سلولِ فقط‌عکس دیگر خالی/جمع‌شده نمی‌شود.
          double? cellImgW = imageExplicitWidth;
          double? cellImgH;
          if (verbatimCellImage &&
              span.imageWidth != null &&
              span.imageWidth! > 0) {
            cellImgW = span.imageWidth!.toDouble();
            cellImgH = (span.imageHeight != null && span.imageHeight! > 0)
                ? span.imageHeight!.toDouble()
                : null;
          }

          Widget standaloneImage = _buildLocalImage(
            imagePath,
            isMobile: !isLargeScreen,
            screenWidth: screenWidth,
            isImageCell: isImageCell,
            activeBook: activeBook,
            context: context,
            explicitWidth: cellImgW,
            explicitHeight: cellImgH,
          );
          if (imageNeedsHScroll) {
            // 🐞 رفع کرش «Scrollbar's ScrollController has no ScrollPosition
            // attached»: بدون controllerِ صریح، Scrollbar سعی می‌کند از
            // PrimaryScrollController استفاده کند که به این
            // SingleChildScrollViewِ افقیِ تودرتو وصل نیست (آن یکی معمولاً
            // به اسکرولِ عمودیِ کلِ صفحه وصل است). با یک ScrollController
            // مشترک بین خودِ Scrollbar و SingleChildScrollView این مشکل
            // رفع می‌شود.
            standaloneImage = _HScrollBox(
              // 🐞 همان فیکسِ فاصله: تا نوارِ اسکرول روی لبه‌ی پایینیِ
              // خودِ عکس لَم ندهد.
              child: Padding(
                // فقط روی دسکتاپ اسکرول‌بار هست و این فاصله برای آن است؛ روی
                // موبایل اسکرول‌بار نیست، پس فضای خالیِ اضافه هم نباید باشد.
                padding: EdgeInsets.only(
                  bottom: _isDesktopPlatform ? 14.0 : 0.0,
                ),
                child: standaloneImage,
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
                        : Align(
                            alignment: standaloneBlockAlign ?? Alignment.center,
                            child: standaloneImage,
                          ))
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
      // 🐞 رفعِ باگِ «صفحه‌ی کاملاً خالی»: ResponsiveLowering در سی‌شارپ
      // نوعِ اسپنِ ColumnStackTable را از "table" به "layout" تغییر می‌دهد،
      // ولی این‌جا فقط "text"/"image"/"table" شناخته می‌شدند — یعنی چنین
      // اسپنی بی‌صدا نادیده گرفته می‌شد و اگر تنها اسپنِ صفحه بود (مثلِ
      // صفحه‌ی ۲۹)، کلِ صفحه خالی نمایش داده می‌شد. ربطی به تودرتو‌بودن یا
      // نبودنِ جدول نداشت.
      // خودِ _buildTable از قبل چیدمانِ ستونی/استکی را کامل پشتیبانی می‌کند
      // (isColumnStack روی strategy=="stack" و layoutReflow=="stack" — که هر
      // دو در همین JSON هستند)، پس فقط کافی است "layout" هم به همان مسیر
      // هدایت شود، نه اینکه رندرکننده‌ی موازیِ جدیدی نوشته شود.
    } else if (span.type == "table" || span.type == "layout") {
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
      // پاراگرافِ «فقط‌شماره»ی لیست هیچ بلاکی ندارد؛ جعبه‌ی خالی امن‌تر از
      // FloatColumnِ بی‌فرزند است (ارتفاعِ ردیف را خودِ شماره تعیین می‌کند).
      child: blockElements.isEmpty
          ? const SizedBox.shrink()
          : FloatColumn(
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
      para.keepListMarkerVisible != true &&
      para.spans.length == 1 &&
      _isWhollyOneBlank(para.spans.first.content);
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
    // 🐞 رفع باگِ «نشانگرِ لیست با متنِ بعدش هم‌ترازِ عمودی نیست»: مارکر قبلاً
    // fontSize هاردکدِ ۱۴ و height ۱.۴ داشت، ولی متنِ پاراگراف اندازه‌ی خودش
    // (مثلاً sz:23 → ۱۱.۵) و height خودش (para.lineSpacing) را دارد. اختلافِ
    // اندازه/ارتفاعِ خطْ باعث می‌شد baseline‌ها روی هم نیفتند (Word شماره را
    // با همان اندازه‌ی متن می‌کشد، پس هم‌تراز است). حالا اندازه‌ی مارکر را از
    // اولین اسپنِ متنیِ همین پاراگراف (اولین sz: که پیدا شود) و ارتفاعِ خط را
    // برابرِ متن می‌گیریم؛ با CrossAxisAlignment.start این یعنی هم‌ترازیِ دقیق.
    double markerFontSize = 14.0;
    String? markerFontFamily; // 🐞 fontFamily مارکر را هم از متن می‌گیریم
    for (final s in para.spans) {
      if (s.type != "text") continue;
      final szMarker = s.markers.firstWhere(
        (m) => m.startsWith("sz:"),
        orElse: () => "",
      );
      if (szMarker.isNotEmpty) {
        final parsed = double.tryParse(szMarker.substring(3));
        if (parsed != null) markerFontSize = parsed / 2;
      }
      final fnMarker = s.markers.firstWhere(
        (m) => m.startsWith("fn:"),
        orElse: () => "",
      );
      if (fnMarker.isNotEmpty) {
        markerFontFamily = mapFontFamily(fnMarker.substring(3));
      }
      break; // فقط اولین اسپنِ متنی
    }
    // 🐞 رفع باگِ «شماره‌ی لیست بولد نمی‌شود» (ادامه): بولد بودن داده‌محور است
    // (para.listMarkerBold)، ولی چون قبلاً fontFamily ست نمی‌شد، مارکر از فونتِ
    // ambient ارث می‌برد که ممکن است بولدِ واقعی نداشته باشد؛ حالا همان فونتِ
    // متن (که بولدش کار می‌کند) را می‌گذاریم تا مارکر هم دقیقاً مثلِ متن بولد شود.
    // 🐞 Mindset 2 ص۵۳ تمرینِ ۰۶ (شماره‌ی بولد، regular دیده می‌شد): پاراگرافِ
    // «فقط‌شماره» در JSONهای فعلی هیچ اسپنی ندارد، پس fontFamily نال می‌ماند و
    // شماره با فونتِ سیستمیِ گوشی کشیده می‌شد. فونتِ سیستمیِ بعضی گوشی‌ها (مثلاً
    // شیائومی) متغیر (variable) است و FontWeight.bold در فلاتر محورِ وزنِ آن را
    // جابه‌جا نمی‌کند؛ نتیجه: شماره‌ی regular. حالا در نبودِ اسپن، فونتِ پیش‌فرضِ
    // کتاب (همان پیش‌فرضِ mapFontFamily) استفاده می‌شود که وزنِ بولدِ واقعی دارد.
    markerFontFamily ??= mapFontFamily('');
    final TextStyle _markerStyle = TextStyle(
      height: para.lineSpacing ?? 1.3,
      fontSize: markerFontSize,
      fontFamily: markerFontFamily,
      fontWeight: para.listMarkerBold ? FontWeight.bold : FontWeight.normal,
      // 🐞 رنگِ نشانگرِ خودکارِ لیست از سندخوانده می‌شود (rPrِ سطحِ numbering).
      // اگر تعریف نشده باشد null می‌ماند و رنگِ پیش‌فرضِ تمِ متن اعمال می‌شود —
      // پس روی لیست‌های بی‌رنگ هیچ تغییری نمی‌دهد.
      color: _hexToColor(para.listMarkerColor),
    );
    final TextPainter _tp = TextPainter(
      text: TextSpan(text: para.listMarker!, style: _markerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    // 🐞 پس‌زمینه/کادرِ شماره (قاعده‌ی Word: سطحِ numbering ← نشانه‌ی پایانِ
    // پاراگراف ← استایلِ کاراکتریِ آن). مثلاً Mindset 2 ص۱۱۷: شماره‌ی سفید داخلِ
    // کادرِ آبی. کادر فقط دورِ خودِ شماره است، نه کلِ پهنای تورفتگی.
    final Color? _markerFill = _hexToColor(para.listMarkerFill);
    final BorderDetail? _markerBdr = para.listMarkerBorder;
    final bool _markerBoxed = _markerFill != null || _markerBdr != null;
    final double _markerBdrW = _markerBdr != null
        ? (_markerBdr.width ?? 1.0)
        : 0.0;
    const double _markerBoxPadH = 2.0;
    final double _markerBoxExtra = _markerBoxed
        ? 2 * (_markerBoxPadH + _markerBdrW)
        : 0.0;
    final double markerWidth = (_tp.width + 4.0 + _markerBoxExtra).clamp(
      rawMarkerWidth.clamp(16.0, 60.0),
      80.0,
    );
    final double outerLeft = (indentLeft - markerWidth).clamp(0.0, 999.0);

    // 🐞 فقط آیتم‌هایی که آیکونِ چشمِ متنِ مخفی دارند به هم‌ترازیِ baseline
    // نیاز دارند (بقیه با start درست‌اند). یک اسکنِ ارزانِ رشته‌ای — در برابرِ
    // پاسِ layoutِ اضافی که baseline تحمیل می‌کند، عملاً رایگان است.
    final bool _paraHasBlankIcon = para.spans.any(
      (s) => s.type == "text" && (s.content ?? '').contains('{blk}'),
    );

    paragraphContent = Padding(
      padding: EdgeInsets.only(
        left: rtl ? 0 : outerLeft,
        right: rtl ? outerLeft : 0,
      ),
      child: Row(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        // 🐞 رفع نهاییِ ناهم‌ترازیِ نشانگرِ لیست: علتِ واقعی این بود که وقتی
        // متنِ آیتم شاملِ آیکونِ چشمِ متنِ مخفی است، آن WidgetSpan (ارتفاعِ
        // ~۲۴px، بسیار بلندتر از خطِ ~۱۵px) خطِ اولِ محتوا را باد می‌کند و متن
        // را پایین‌تر می‌بَرد، در حالی که ستونِ مارکر (start) بالا می‌ماند —
        // برای همین بدونِ آیکون هم‌تراز بود و با آیکون نه. راهِ درست: هم‌ترازیِ
        // بر اساسِ baseline نه top.
        //
        // 🐞 روانیِ اسکرول (تأییدشده با پروفایلِ DevTools): این baseline رایگان
        // نیست. CrossAxisAlignment.baseline مجبور می‌کند Row از هر فرزند
        // baseline بپرسد، و برای RenderFloatColumn یعنی یک پاسِ layoutِ اضافیِ
        // کاملِ همان پاراگراف (در تریس: صدها RenderFloatColumn.getDryBaseline و
        // RenderConstrainedBox.getDryBaseline — تنها رویدادهای سنگینِ ترِد UI).
        // چون ناهم‌ترازی *فقط* وقتی رخ می‌دهد که آیکونِ چشم در متن باشد، این
        // مسیرِ گران را هم فقط برای همان آیتم‌ها روشن می‌کنیم؛ بقیه (اکثریتِ
        // قاطع) به هم‌ترازیِ ارزانِ start برمی‌گردند که قبلاً هم برایشان درست بود.
        crossAxisAlignment: _paraHasBlankIcon
            ? CrossAxisAlignment.baseline
            : CrossAxisAlignment.start,
        textBaseline: _paraHasBlankIcon ? TextBaseline.alphabetic : null,
        children: [
          SizedBox(
            width: markerWidth,
            child: _markerBoxed
                // 🐞 شماره‌ی کادردار/رنگی: جعبه به اندازه‌ی خودِ شماره، در ابتدای
                // خط (مثلِ چپ‌چینیِ حالتِ عادی).
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _markerBoxPadH,
                        ),
                        decoration: BoxDecoration(
                          color: _markerFill,
                          border: _markerBdr != null
                              ? Border.all(
                                  color:
                                      _docBorderColor(_markerBdr) ??
                                      Colors.black,
                                  width: _markerBdrW,
                                )
                              : null,
                        ),
                        child: Text(para.listMarker!, style: _markerStyle),
                      ),
                    ],
                  )
                : Text(
                    para.listMarker!,
                    // 🐞 Word شماره‌ی لیست را در موقعیتِ (left−hanging) *چپ‌چین*
                    // می‌گذارد؛ راست‌چینِ قبلی شماره را ته جعبه می‌بُرد و لیست تورفته
                    // دیده می‌شد (مثلِ ۱،۲ ص۱۵ که کاربر flush می‌خواست). حالا چپ‌چین:
                    // مارکرِ سطحِ پایه روی لبه‌ی چپ (flush) و سطوحِ عمیق‌تر تورفته.
                    textAlign: rtl ? TextAlign.right : TextAlign.left,
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
        _docBorderColor(para.borders) ?? Colors.grey.shade600;
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

  // 🐞 روانیِ اسکرول (داده‌محور، از تریسِ Track Widget Builds): اولین ساختِ هر
  // صفحه ~۲۰۳ RenderPadding و ~۹۱ RenderDecoratedBox و ~۹۳ RenderFlex می‌سازد.
  // بخشی از این‌ها بی‌اثرند (paddingِ صفر، decorationِ خالی، Columnِ تک‌فرزند) و
  // فقط هزینه‌ی build+layout اضافه می‌کنند بدونِ هیچ اثرِ بصری. اگر هر چهار
  // margin صفر باشد اصلاً Padding نمی‌سازیم.
  if (topMargin == 0 &&
      bottomMargin == 0 &&
      leftMargin == 0 &&
      rightMargin == 0) {
    return paragraphContent;
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

// 🐞 CommonTable AutoFit: در Word حاشیه‌ی پیش‌فرضِ سلول ~۵.۷۶pt هر طرف است و
// حالا padding افقیِ سلولِ CommonTable هم به همان مقدار کم شده تا ناحیه‌ی متن
// دقیقاً برابرِ Word شود. باقی‌مانده‌ی اختلاف صرفاً از پهن‌تر بودنِ متریکِ متنِ
// فلاتر نسبت به Word است؛ این safety آن را جبران می‌کند تا محتوایی که در سند
// با «AutoFit to contents» یک‌خطی است، در فلاتر هم یک‌خطی بماند. (کاربر با
// padding=۸px و safety=۲۲ به نتیجه رسیده بود؛ با paddingِ کم‌شده همان فضای
// مؤثر تقریباً با ۱۸ بازتولید می‌شود. در صورتِ نیاز قابلِ تنظیم است.)
const double _kNaturalColSafetyPx = 18.0;

// 🐞 روانیِ اسکرول: قبلاً در سه جای مسیرِ رندر، داخلِ خودِ build یک
// `ScrollController()` ساخته می‌شد. build ممکن است بارها اجرا شود، پس هر بار
// یک کنترلرِ تازه ساخته می‌شد که هیچ‌وقت dispose نمی‌شد (نشتیِ حافظه) و
// Scrollbar در هر فریم دوباره attach/detach می‌کرد. این ویجتِ کوچک کنترلر را
// یک‌بار می‌سازد و در dispose آزاد می‌کند.
class _HScrollBox extends StatefulWidget {
  const _HScrollBox({required this.child});
  final Widget child;

  @override
  State<_HScrollBox> createState() => _HScrollBoxState();
}

/// آیا برنامه روی دسکتاپ (ویندوز/لینوکس/مک) اجرا می‌شود؟ کاربرِ ماوس به
/// اسکرول‌بار عادت دارد و بدونِ آن نمی‌تواند با کشیدن اسکرول کند؛ روی
/// موبایل/تبلت اسکرول با انگشت است و نشانه‌ی بصری کافی است.
bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// 🌟 درخواستِ کاربر: روی اندروید و iOS اسکرول‌بارِ افقی نشان داده نشود؛ به‌جایش
/// خودِ ناحیه طوری دیده شود که کاربر بفهمد «این‌جا ادامه دارد و افقی اسکرول
/// می‌شود». الگوی آشنای اپ‌های موبایل (جدول‌های iOS، کاروسل‌ها) به کار رفته:
///
/// ۱) **سایه‌ی لبه:** در هر طرفی که محتوای پنهان هست، یک سایه‌ی محوِ باریک روی
///    لبه می‌افتد؛ یعنی محتوا «زیرِ لبه» ادامه دارد. با اسکرول به‌روز می‌شود: در
///    ابتدا فقط راست، وسطِ راه هر دو طرف، در انتها فقط چپ.
/// ۲) **دکمه‌ی فلش:** یک دایره‌ی کوچک با فلشِ › روی لبه‌ی راست، که تا اولین
///    اسکرولِ کاربر دیده می‌شود. با یک لمس، ناحیه حدودِ ۸۰٪ عرضش جلو می‌رود؛
///    یعنی هم راهنماست و هم برای کسی که سوایپ را امتحان نکرده کار می‌کند. بعد
///    از اولین اسکرول محو می‌شود و فقط سایه‌ها می‌مانند تا شلوغ نشود.
///
/// روی دسکتاپ اسکرول‌بار مثلِ قبل همیشه دیده می‌شود (ماوس بدونِ آن کشیدن
/// ندارد) و سایه‌های لبه هم کنارش هستند. فلش روی دسکتاپ هم کمک می‌کند.
///
/// (🐞 تاریخچه: قبلاً در سه جای مسیرِ رندر، داخلِ خودِ build یک
/// `ScrollController()` ساخته می‌شد که هیچ‌وقت dispose نمی‌شد. این ویجت کنترلر
/// را یک‌بار می‌سازد و در dispose آزاد می‌کند.)
class _HScrollBoxState extends State<_HScrollBox> {
  final ScrollController _ctrl = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _userHasScrolled = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_updateEdges);
    // ابعادِ محتوا فقط بعد از اولین layout معلوم است.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateEdges);
    _ctrl.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!mounted || !_ctrl.hasClients) return;
    final ScrollPosition p = _ctrl.position;
    if (!p.hasContentDimensions) return;
    final bool left = p.pixels > p.minScrollExtent + 1;
    final bool right = p.pixels < p.maxScrollExtent - 1;
    final bool scrolled = _userHasScrolled || p.pixels > 4;
    if (left != _canScrollLeft ||
        right != _canScrollRight ||
        scrolled != _userHasScrolled) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
        _userHasScrolled = scrolled;
      });
    }
  }

  void _nudgeForward() {
    if (!_ctrl.hasClients) return;
    final ScrollPosition p = _ctrl.position;
    final double target = (p.pixels + p.viewportDimension * 0.8).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _edgeShade({required bool left, required bool visible}) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: const [Color(0x2E000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = _isDesktopPlatform;

    Widget scroller = SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      child: widget.child,
    );
    if (desktop) {
      // رفع کرش «Scrollbar's ScrollController has no ScrollPosition
      // attached»: کنترلرِ صریح، مشترک بینِ Scrollbar و ScrollView.
      scroller = Scrollbar(
        controller: _ctrl,
        thumbVisibility: true,
        child: scroller,
      );
    } else {
      // هیچ اسکرول‌باری روی موبایل؛ حتی اسکرول‌بارِ خودکارِ ScrollBehavior.
      scroller = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: scroller,
      );
    }

    final bool showHint = _canScrollRight && !_userHasScrolled;

    // تغییرِ ابعاد (چرخشِ گوشی، لودِ عکس) هم لبه‌ها را دوباره حساب کند.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
        return false;
      },
      child: Stack(
        children: [
          scroller,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _edgeShade(left: true, visible: _canScrollLeft),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _edgeShade(left: false, visible: _canScrollRight),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: desktop ? 12 : 0, // بالای اسکرول‌بارِ دسکتاپ
            child: Center(
              child: IgnorePointer(
                ignoring: !showHint,
                child: AnimatedOpacity(
                  opacity: showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: Colors.black38,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _nudgeForward,
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Colors.black54,
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
    );
  }
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
  // 🐞 برای جعبه‌های کوچکِ تک‌سلولی (مثلِ شماره‌ی تمرین) که باید بوردر
  // داشته باشند ولی هرگز کش نیایند/اسکرول نگیرند — کاملاً جدا از
  // isBorderedTable نگه داشته می‌شود تا هیچ‌کدام از رفتارهای مرتبط با
  // horizontalScroll/tableWidthPercent رویش اثر نگذارد.
  final bool isCompactTable = rawStyle.contains("compacttable");
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
  // 🐞 اصلاحِ برداشتِ قبلی (تصحیحِ کاربر) دربارهٔ MultiColumnTable:
  // «متنِ چندستونی» در صفحهٔ باریک نباید به چند جدولِ تک‌ستونهٔ *جدا از هم*
  // (هرکدام با بوردرِ خودش) تبدیل شود. رفتارِ درست این است که متنِ همهٔ
  // ستون‌ها پشتِ‌سرِ هم به یکدیگر الحاق شود و همگی داخلِ *یک* جدولِ
  // تک‌ستونهٔ بوردردار قرار بگیرند — یعنی فقط یک کادر، دورِ کلِ متن.
  // (رفتارِ صفحهٔ عریض تغییری نمی‌کند: همهٔ ستون‌ها کنارِ هم داخلِ یک جدول
  // با BorderMode="outer" و بدونِ خطوطِ داخلی.)
  // تشخیص: اول فیلدِ declarative (LayoutReflow=="merge" که سی‌شارپ برای
  // استخراج‌های جدید می‌فرستد)، بعد فال‌بکِ نامِ استایل تا کتاب‌هایی که
  // قبلاً با LayoutReflow=="stack" استخراج شده‌اند هم بدونِ استخراجِ مجدد
  // درست رندر شوند.
  // 🌟 استایلِ تازه‌ی FlowTable: به‌جای گریدِ ستون‌ثابت، محتوایِ سلول‌ها مثلِ
  // «چیپ» کنارِ هم چیده می‌شوند و هر وقت جا کم آمد به خطِ بعد می‌روند.
  // چرا لازم شد: جدولِ «Is it big or / How many bedrooms / ...» در سند یک
  // ردیفِ ساده از عبارت‌هایِ رنگی است، ولی با WidthMode="equal" هر ستون
  // یک‌چهارمِ عرضِ ظرف را می‌گرفت (فاصله‌هایِ عظیم) و با "natural" مجموعِ
  // عرض‌ها از ظرف بیرون می‌زد. حالتِ جریانی هیچ‌کدام را ندارد: نه عرضِ
  // تحمیلی، نه سرریز.
  final bool applyWrapFlow = strategy == "wrap";

  final bool isMultiColumnMerge =
      tableSpan.layoutReflow == "merge" ||
      rawStyle.contains("multicolumntable");
  final bool isColumnStack =
      strategy == "stack" ||
      tableSpan.layoutReflow == "stack" ||
      isMultiColumnMerge ||
      rawStyle.contains("columnstack");
  final bool isDotted =
      strategy == "collapseToCards" ||
      borderVal == "dotted" ||
      rawStyle.contains("dottedtable");

  // 🐞 درخواستِ کاربر: بوردرهای «پیوسته» باید دیده شوند. قبلاً بعضی
  // استایل‌ها (ColumnStackTable و TableGrid) بی‌قید‌و‌شرط بوردرشان مخفی
  // می‌شد، حتی وقتی خودِ سندِ Word یک بوردرِ واقعیِ single/double با عرض و
  // رنگِ مشخص تعیین کرده بود (مثلِ جدولِ صفحه‌ی ۲۹ با Val:"single").
  // این تابع فقط سبک‌های نقطه‌چین/خط‌چین (و none/nil) را «غیرِپیوسته»
  // می‌شمارد؛ هر چیزِ دیگری پیوسته است و باید رسم شود.
  bool isSolidBorderStyle(String? val) {
    if (val == null || val.isEmpty) return false;
    final v = val.toLowerCase();
    if (v == "none" || v == "nil") return false;
    // dotted, dashed, dotDash, dashSmallGap, dashDotStroked و ...
    if (v.contains("dot") || v.contains("dash")) return false;
    return true;
  }

  // 🐞 CommonTable: یک ضلعِ بوردر را عیناً از دادهٔ همان سلول می‌سازد. اگر
  // ضلع تعریف‌نشده یا none/nil باشد → BorderSide.none. عرض به point است و
  // چون اپ ۱pt→۱px رندر می‌کند مستقیماً همان عدد px است. بوردرِ نقطه‌چین/
  // خط‌چینِ سند چون فلاتر BorderSide نقطه‌چین ندارد، به‌صورتِ خطِ پیوسته‌ی
  // نازک تقریب زده می‌شود (نه حذف) تا وفادار به سند بماند.
  BorderSide cellSideFrom(BorderDetail? d) {
    if (d == null) return BorderSide.none;
    final v = (d.val ?? "").toLowerCase();
    if (v.isEmpty || v == "none" || v == "nil") return BorderSide.none;
    final double w = d.width ?? 0.5;
    return BorderSide(
      color: _docBorderColor(d)!, // d این‌جا null نیست؛ «auto» → مشکی
      width: w <= 0 ? 0.5 : w,
    );
  }

  // 🐞 collapse بوردرها (رفعِ «همه بوردرها هم‌ضخامت دیده می‌شوند»): اگر هر
  // سلول هر ۴ ضلعش را بکشد، لبه‌های مشترکِ داخلی از دو سلولِ مجاور دوبل
  // می‌شوند (۱.۰+۱.۰≈۲.۰) و کنتراستِ ضخامت با لبه‌ی بالای ۲.۲ گم می‌شود. مثلِ
  // مدلِ collapsed در Word/HTML، هر لبه را فقط یک سلول «مالک» می‌کشد: راست و
  // پایینِ هر سلول همیشه، ولی بالا فقط در ردیفِ اول و چپ فقط در ستونِ اول.
  // این‌طور هر خطِ داخلی یک‌بار کشیده می‌شود و ضخامت‌های واقعیِ سند (مثلِ
  // بالای ضخیمِ سرستون) دقیق دیده می‌شوند.
  Border? cellBorderFrom(CellBorders? b, bool isFirstRow, bool isFirstCol) {
    if (b == null) return null;
    return Border(
      top: isFirstRow ? cellSideFrom(b.top) : BorderSide.none,
      left: isFirstCol ? cellSideFrom(b.left) : BorderSide.none,
      right: cellSideFrom(b.right),
      bottom: cellSideFrom(b.bottom),
    );
  }

  // بوردرِ پیوسته یا در سطحِ خودِ جدول تعریف شده، یا (وقتی جدول سطحِ خودش
  // را ندارد) در سطحِ سلول‌ها — هر دو را می‌پذیریم.
  // 🐞 قانونِ درست (اصلاحِ کاربر): بوردر فقط وقتی مخفی شود که *غیر solid* باشد
  // (dashed/dotted/none)، فارغ از کم‌رنگ بودن. ColumnStackTableِ ص۱۵ در سند
  // بوردرِ dashed دارد (که حالا C# درست به‌صورتِ "dashed" می‌فرستد، نه "single")
  // پس isSolidBorderStyle=false → مخفی؛ ولی جدولی با بوردرِ solid (سطحِ جدول یا
  // سلول) نشان داده می‌شود.
  final bool hasSolidBorder =
      isSolidBorderStyle(borderVal) ||
      tableSpan.tableRows.any(
        (row) => row.cells.any(
          (cell) =>
              isSolidBorderStyle(cell.borders?.top?.val) ||
              isSolidBorderStyle(cell.borders?.bottom?.val) ||
              isSolidBorderStyle(cell.borders?.left?.val) ||
              isSolidBorderStyle(cell.borders?.right?.val),
        ),
      );
  final bool hideBorders =
      (isDotted || isColumnStack || rawStyle.contains("tablegrid")) &&
      !hasSolidBorder;
  final bool applyColumnStack = isColumnStack && !isLargeScreen;

  double defaultBorderWidth =
      tableSpan.borders?.width ??
      ((isBorderedTable || isCompactTable) && !isFigureTable ? 1.0 : 0.5);
  // 🐞 بوردرِ سطحِ جدولی که از سند آمده همیشه Width دارد (اکسترکتور sz را
  // می‌خواند)؛ بوردرِ پیش‌فرضی که ResponsiveLowering برای بعضی استایل‌ها
  // می‌سازد Width ندارد. پس «Width دارد ولی رنگ ندارد» یعنی «auto»ِ سند در
  // JSONِ قدیمی → مشکی، مثلِ Word. پیش‌فرضِ خودِ اپ (خاکستری) دست‌نخورده است.
  // اکسترکتورِ جدید «auto» را صریحاً با همین کلمه می‌نویسد.
  final bool tableBorderFromDoc =
      tableSpan.borders?.width != null ||
      (tableSpan.borders?.color ?? "").toLowerCase() == "auto";
  Color defaultBorderColor =
      _hexToColor(tableSpan.borders?.color) ??
      ((tableBorderFromDoc ||
              ((isBorderedTable || isCompactTable) && !isFigureTable))
          ? Colors.black
          : Colors.grey.shade400);

  final bool showBorders =
      !hideBorders &&
      !isFigureTable &&
      !isOutsideTable &&
      (isBorderedTable ||
          isCompactTable ||
          tableSpan.hasBorders == "true" ||
          (borderVal != null &&
              borderVal != "none" &&
              borderVal != "nil" &&
              borderVal != "dotted"));

  // 🐞 مدلِ صریحِ جدید: اول از فیلدهای BorderMode/WidthMode (که سی‌شارپ
  // برایِ کتاب‌هایِ تازه‌استخراج‌شده ست می‌کند) استفاده می‌شود؛ اگر خالی
  // بودند (کتابِ قدیمی)، از همان پرچم‌های قبلیِ مبتنی‌بر نامِ استایل
  // (بالا) نتیجه‌گیری می‌شود — یعنی هیچ کتابِ قدیمی‌ای رفتارش عوض نمی‌شود.
  //
  // 🐞 NormalTable — بوردرِ هر سلول عیناً مثلِ سند (رنگ، ضخامت، و پنهان/پیدا
  // بودنِ هر یک از چهار ضلع): قبلاً BorderMode="all" بود، یعنی یک TableBorderِ
  // یکنواخت برای کلِ ردیف — هر چهار ضلع همیشه کشیده می‌شد. ولی بیشترِ
  // NormalTableهای کتاب فقط بخشی از اضلاع را دارند (مثلاً فقط خطِ رنگیِ بالا،
  // یا بالای ضخیم + پایینِ نازک بدونِ دو طرف)، پس جعبه‌ی کامل غلط بود. سی‌شارپ
  // حالا برای NormalTable مقدارِ "cell" می‌فرستد؛ این‌جا کتاب‌هایی هم که قبلاً
  // با "all" استخراج شده‌اند بدونِ استخراجِ مجدد به "cell" ارتقا داده می‌شوند —
  // ولی فقط وقتی دست‌کم یک سلول داده‌ی بوردرِ خودش را دارد (وگرنه بوردرِ
  // جدول فقط از استایل آمده و "cell" چیزی نمی‌کشید، پس همان "all" می‌ماند).
  final bool isNormalTable = rawStyle.contains("normaltable");
  bool anyCellHasBorderData() => tableSpan.tableRows.any(
    (row) => row.cells.any(
      (c) =>
          c.borders?.top != null ||
          c.borders?.bottom != null ||
          c.borders?.left != null ||
          c.borders?.right != null,
    ),
  );
  final String resolvedBorderMode =
      (isNormalTable && tableSpan.borderMode == "all" && anyCellHasBorderData())
      ? "cell"
      : (tableSpan.borderMode ??
            (isOutsideTable
                ? "outer"
                : (hideBorders ? "none" : (showBorders ? "all" : "none"))));
  // 🐞 BorderMode="cell" از اول برای CommonTable ساخته شد و چند رفتارِ دیگرِ
  // «وفاداری به هندسه‌ی سند» هم به آن گره خورده بود: paddingِ افقیِ ۵.۷۶ و
  // رندرِ عکسِ داخلِ سلول با ابعادِ عینیِ سند. درخواستِ کاربر برای NormalTable
  // فقط بوردرهاست، پس آن دو رفتار برای NormalTable اعمال نمی‌شوند و چیدمانش
  // (padding و عکس‌ها) دقیقاً مثلِ قبل می‌ماند. بوردرِ per-cell، هم‌ارتفاع‌شدنِ
  // سلول‌های یک ردیف (تا خطوط تا پایینِ ردیف برسند) و vAlign برایش فعال‌اند.
  final bool cellGeometryFromDoc =
      resolvedBorderMode == "cell" && !isNormalTable;
  final String resolvedWidthMode =
      tableSpan.widthMode ??
      (isCompactTable
          ? "content"
          : (isOutsideTable
                ? "proportional"
                : ((isBorderedTable && !isFigureTable) ? "fill" : "equal")));

  // 🐞 بازنویسیِ کامل: به‌جای این‌که ماشین‌آلاتِ کاملِ Table/TableRow/
  // TableCell/columnWidths را مجبور کنیم مثلِ یک جعبهٔ ساده‌ی بوردردار
  // رفتار کند (که در چند تلاشِ قبلی، هربار به یک شکلِ جدید خراب می‌شد —
  // جمع‌شدنِ کامل، کش‌آمدنِ کاملِ عرضِ صفحه، ...)، برایِ WidthMode="content"
  // اصلاً وارد آن مسیر نمی‌شویم. چنین جدولی طبقِ تعریف همیشه تک‌سلولی
  // است (برایِ نشان‌هایِ کوچک مثلِ شماره‌ی تمرین) — پس مستقیم محتوایِ همان
  // یک سلول را (با همان _buildParagraph که سلول‌هایِ عادی هم استفاده
  // می‌کنند) در یک Containerِ بوردردار می‌گذاریم؛ این Container خودش،
  // دقیقاً مثلِ یک پاراگرافِ معمولیِ بوردردار (بدونِ هیچ جدولی)، طبیعتاً به
  // اندازه‌ی محتوایش می‌ماند — همان رفتاری که تمرینِ ۰۲ (بدونِ جدول، فقط
  // بوردرِ مستقیم رویِ پاراگراف) از اول درست داشت.
  if (resolvedWidthMode == "content") {
    final singleCell =
        tableSpan.tableRows.isNotEmpty &&
            tableSpan.tableRows.first.cells.isNotEmpty
        ? tableSpan.tableRows.first.cells.first
        : null;
    if (singleCell == null) return const SizedBox.shrink();

    // 🐞 پیدا شد: _buildParagraph متن را داخلِ WrappableText (از پکیجِ
    // float_column، برایِ پاراگراف‌هایِ عادیِ عریض که ممکن است دورِ عکس
    // بپیچند) می‌گذارد — این ویجت برایِ محاسبه‌ی چیدمانِ wrap/float به
    // عرضِ دردسترس حساس است، مستقل از این‌که متنِ داخلش چقدر کوتاه
    // است. برایِ این موردِ ساده (متنِ تک‌خطیِ یک نشان)، کاملاً از
    // _buildParagraph/WrappableText صرف‌نظر می‌شود؛ مستقیم با همان
    // توابعِ سطحِ‌پایینِ TextRenderEngine که ویوئرِ ترانسکریپتِ صوتی هم
    // موفق استفاده می‌کند، رندر می‌شود.
    final List<InlineSpan> richSpans = [];
    for (final para in singleCell.paragraphs) {
      for (final span in para.spans) {
        if (span.type != "text") continue;
        final TextStyle baseStyle = TextRenderEngine.applySpanStyle(
          const TextStyle(color: Colors.black87, fontSize: 14, height: 1.3),
          span,
          false, // isDarkTheme
        );
        String? fontFamily;
        double? fontSize;
        for (final marker in span.markers) {
          if (marker.startsWith("fn:")) {
            fontFamily = mapFontFamily(marker.substring(3));
          } else if (marker.startsWith("sz:")) {
            final parsed = double.tryParse(marker.substring(3));
            if (parsed != null) fontSize = parsed / 2;
          }
        }
        richSpans.add(
          TextSpan(
            text: span.content,
            style: baseStyle.copyWith(
              fontFamily: fontFamily,
              fontSize: fontSize,
            ),
          ),
        );
      }
    }
    if (richSpans.isEmpty) return const SizedBox.shrink();

    Alignment tableAlign = Alignment.centerLeft;
    if (tableSpan.tableAlignment == "center") tableAlign = Alignment.center;
    if (tableSpan.tableAlignment == "right") {
      tableAlign = Alignment.centerRight;
    }

    // 🐞 UnconstrainedBox (تلاشِ قبلی) در عمل باعثِ خطای واقعیِ overflow
    // شد (RenderConstraintsTransformBox overflowed) — یعنی در حداقل یک
    // موقعیتِ واقعی، عرضِ واقعاً دردسترسِ آن سلول از چیزی که «۰۱» لازم
    // دارد کمتر است، و اصرار بر اندازه‌ی طبیعی فقط یک خطای رندر تولید
    // می‌کند، نه یک ظاهرِ قابلِ‌قبول. FittedBox با BoxFit.scaleDown راهِ
    // امنِ فلاتر برایِ همین سناریوست: هروقت جا کافی بود (حالتِ رایج،
    // منطبق با سند)، دقیقاً با اندازه‌ی طبیعی رندر می‌شود؛ فقط وقتی
    // واقعاً جا نیست، کلِ جعبه (با بوردرش، متناسب) کمی کوچک می‌شود —
    // هیچ‌وقت overflow نمی‌دهد و هیچ‌وقت هم بدونِ بوردر رها نمی‌شود.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: tableAlign,
      child: Container(
        padding: EdgeInsets.only(
          top: singleCell.paddingTop ?? 4.0,
          bottom: singleCell.paddingBottom ?? 4.0,
          left: singleCell.paddingLeft ?? 8.0,
          right: singleCell.paddingRight ?? 8.0,
        ),
        decoration: BoxDecoration(
          color: _hexToColor(singleCell.fillColor),
          border: (resolvedBorderMode == "none")
              ? null
              : Border.all(
                  color: defaultBorderColor,
                  width: defaultBorderWidth,
                ),
        ),
        child: Text.rich(
          TextSpan(children: richSpans),
          softWrap: false,
          textAlign:
              (tableSpan.tableAlignment == "center" ||
                  tableSpan.tableAlignment == "right")
              ? TextAlign.center
              : TextAlign.left,
        ),
      ),
    );
  }

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
        // 🐞 همان سبکِ ارثیِ رندر (letterSpacingِ تم، …) — بدونِ آن اندازه کمی
        // کمتر از واقعیت بود و آخرین کلمه‌ی چیپ‌های FlowTable گاهی به خطِ دوم
        // می‌افتاد. noScaling مثلِ صفحه‌ی مطالعه.
        final tp = TextPainter(
          text: TextSpan(
            text: s.content,
            style: DefaultTextStyle.of(context).style.merge(
              TextStyle(
                fontSize: fontSize,
                fontFamily: fontFamily,
                fontWeight: s.markers.contains("b")
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontStyle: s.markers.contains("i")
                    ? FontStyle.italic
                    : FontStyle.normal,
                letterSpacing: s.letterSpacing,
              ),
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        width += tp.width;
      }
    }
    return width;
  }

  double maxEmbeddedImageWidth = 0;
  double maxParagraphNaturalWidth = 0;
  // 🐞 برای جدول‌های چندستونی (مثلاً یک جدولِ واژگان با ۵-۶ ستونِ کوتاه
  // کنارِ هم)، «پهن‌ترین یک سلولِ کلِ جدول» معیارِ درستی برای «عرضِ لازم»
  // نیست — چون همه‌ی ستون‌ها کنارِ هم قرار می‌گیرند، عرضِ واقعاً لازم
  // نزدیک به مجموعِ پهن‌ترینِ هر ستون است، نه فقط پهن‌ترینِ یک سلول در
  // کلِ جدول. این Map پهن‌ترین محتوای هر ستون (بر اساسِ اندیسِ سلول در
  // هر ردیف) را جدا نگه می‌دارد.
  final Map<int, double> perColumnWidestContent = {};

  // 🐞 روانیِ اسکرول — علتِ «تا همه‌ی صفحات یک‌بار دیده نشوند روان نمی‌شود»:
  // حلقه‌ی زیر برای *هر جدول* روی تک‌تکِ اسپن‌های هر سلول یک
  // TextPainter.layout() اجرا می‌کند. layout واقعاً متن را shape می‌کند
  // (کارِ سنگینِ Skia)، و یک صفحه با چند جدولِ چندسلولی به‌راحتی صدها بار
  // این کار را در همان فریمی انجام می‌دهد که کاربر دارد به آن صفحه می‌رسد —
  // یعنی دقیقاً همان قفلِ «اولین عبور». بعد از اولین ساخت، صفحه به‌خاطرِ
  // AutomaticKeepAlive + _cachedWidgets زنده می‌ماند و دیگر تکرار نمی‌شود؛
  // برای همین «بعد از یک‌بار اسکرولِ کامل» روان می‌شد.
  //
  // نکته‌ی کلیدی: خروجیِ این اندازه‌گیری فقط در حالت‌های horizontalScroll و
  // proportional مصرف می‌شود، و در حالتِ natural فقط به‌عنوانِ *فال‌بک* وقتی
  // widthPt نداریم. ولی از وقتی Responsivelowering هر استایلِ ناشناخته را
  // CommonTable (natural + widthPtِ معتبر) می‌کند، اکثریتِ جدول‌ها این
  // اندازه‌گیری را انجام می‌دادند و بعد دور می‌ریختند. این گاردِ ارزان
  // (فقط چند مقایسه‌ی عددی، بدونِ TextPainter) آن کارِ بی‌مصرف را حذف می‌کند.
  bool everyCellHasWidthPt = tableSpan.tableRows.isNotEmpty;
  for (final row in tableSpan.tableRows) {
    for (final cell in row.cells) {
      final w = cell.widthPt;
      if (w == null || w <= 0) {
        everyCellHasWidthPt = false;
        break;
      }
    }
    if (!everyCellHasWidthPt) break;
  }
  final bool measurementUnused =
      resolvedWidthMode == "natural" &&
      everyCellHasWidthPt &&
      strategy != "horizontalScroll" &&
      !isBorderedTable &&
      !isOutsideTable;

  if (!measurementUnused) {
    for (final row in tableSpan.tableRows) {
      for (int ci = 0; ci < row.cells.length; ci++) {
        final cell = row.cells[ci];
        double thisColumnWidth = 0;
        for (final p in cell.paragraphs) {
          final paraWidth = measureParagraphNaturalWidth(p);
          if (paraWidth > maxParagraphNaturalWidth) {
            maxParagraphNaturalWidth = paraWidth;
          }
          if (paraWidth > thisColumnWidth) thisColumnWidth = paraWidth;
          for (final s in p.spans) {
            if (s.type == "image" &&
                s.imageWidth != null &&
                s.imageWidth! > maxEmbeddedImageWidth) {
              maxEmbeddedImageWidth = s.imageWidth!.toDouble();
            }
          }
        }
        if (thisColumnWidth > (perColumnWidestContent[ci] ?? 0)) {
          perColumnWidestContent[ci] = thisColumnWidth;
        }
      }
    }
  }
  final double sumOfColumnWidestContent =
      perColumnWidestContent.values.fold(0.0, (a, b) => a + b) +
      (perColumnWidestContent.length * 24);
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

  // 🐞 ریشه‌ی «جدولی که در Word سرریز نیست ولی در فلاتر سرریز می‌کند»:
  // در حالتِ natural هر ستون WidthPtِ سند را می‌گرفت *به‌علاوه‌ی*
  // _kNaturalColSafetyPx. یعنی عرضِ کلِ جدول به‌اندازه‌ی (تعدادِ ستون × ۱۸)
  // از سند پهن‌تر می‌شد — برای یک جدولِ ۴ستونی ۷۲ پیکسل. اگر جدول در Word
  // تقریباً کلِ عرضِ متن را پر کرده باشد، همین اضافه آن را سرریز می‌کند.
  //
  // safety حذف نشد چون کارِ مفیدی می‌کند (متریکِ متنِ فلاتر کمی پهن‌تر از
  // Word است و بدونِ آن، محتوایی که در سند یک‌خطی است ممکن است دو خط شود).
  // به‌جایش *تطبیقی* شد: اگر جدول با safety جا نمی‌شود ولی با عرضِ خودِ سند
  // جا می‌شود، فقط همان مقدارِ فضایِ باقی‌مانده بینِ ستون‌ها پخش می‌شود و در
  // بدترین حالت به صفر می‌رسد — یعنی هندسه دقیقاً همان سند. اگر جا بود،
  // رفتارِ سخاوتمندانه‌ی قبلی دست‌نخورده می‌ماند.
  double naturalPerColSafety = _kNaturalColSafetyPx;
  if (resolvedWidthMode == "natural") {
    double widestDocRowWidth = 0;
    int widestDocRowCols = 0;
    for (final row in tableSpan.tableRows) {
      double rowW = 0;
      int cols = 0;
      for (final c in row.cells) {
        final w = c.widthPt;
        if (w != null && w > 0) {
          rowW += w;
          cols++;
        }
      }
      if (rowW > widestDocRowWidth) {
        widestDocRowWidth = rowW;
        widestDocRowCols = cols;
      }
    }
    if (widestDocRowCols > 0 &&
        widestDocRowWidth + widestDocRowCols * _kNaturalColSafetyPx >
            canvasWidth) {
      final double spare = canvasWidth - widestDocRowWidth;
      // 🐞 اگر جدول حتی با عرضِ دقیقِ سند هم جا نمی‌شود (spare≤0)، به‌هرحال
      // اسکرولِ افقی یا کوچک‌شدنِ یکنواخت می‌گیرد؛ صفرکردنِ safety در این
      // حالت هیچ کمکی به جاشدن نمی‌کند و فقط باعث می‌شد کلماتی که در Word
      // یک‌خطی‌اند در فلاتر به خطِ دوم بروند. پس safety کامل می‌ماند.
      naturalPerColSafety = spare > 0
          ? (spare / widestDocRowCols)
          : _kNaturalColSafetyPx;
      if (naturalPerColSafety > _kNaturalColSafetyPx) {
        naturalPerColSafety = _kNaturalColSafetyPx;
      }
    }
  }

  // 🐞 دومین ریشه‌ی سرریز، و بدترش چون کران ندارد: عرضِ ستون و عرضِ
  // SizedBoxِ دورِ جدول با *دو فرمولِ متفاوت* حساب می‌شدند. ستونی که
  // widthPt نداشت، در columnWidths عرضِ اندازه‌گیری‌شده‌ی محتوا می‌گرفت ولی
  // در مجموعِ عرضِ جدول صفر شمرده می‌شد — پس جدول همیشه از ظرفش پهن‌تر
  // می‌شد. حالا هر دو از همین یک تابع می‌خوانند و نمی‌توانند واگرا شوند.
  double naturalColumnPx(TableCellData c, int ci) {
    final double? wpt = c.widthPt;
    return (wpt != null && wpt > 0)
        ? wpt + naturalPerColSafety
        : ((perColumnWidestContent[ci] ?? 60) + 24);
  }

  // 🐞 CommonTable تک‌ردیفه روی صفحه‌ی باریک (جدولِ پیشوندهای ص۵: post- ،
  // for-/fore- ، ... ، under-): قبلاً وقتی جدول جا نمی‌شد، ستون‌ها کورکورانه
  // به نسبتِ عرضِ سند جمع می‌شدند. ولی یک کلمه‌ی بی‌فاصله قابلِ شکستن نیست؛
  // پس «under-» از ستونش بیرون می‌زد و فلاتر «for-/fore-» را سرِ خط‌تیره‌ها
  // می‌شکست — در حالی‌که در Word هر دو یک‌خطی‌اند.
  //
  // این تابع کمینه‌ی عرضی را می‌دهد که سلول بدونِ شکستنِ هیچ کلمه‌ای لازم
  // دارد: پهن‌ترین «توکنِ» سلول — متنِ بینِ دو فاصله‌ی سفید، نه بینِ هر نقطه‌ی
  // مجازِ شکستنِ فلاتر (که بعد از خط‌تیره و اسلش هم می‌شکند) — به‌علاوه‌ی
  // تورفتگی، padding و بوردرِ همان سلول. اندازه‌گیری با همان فونت/اندازه/
  // ضخامتی است که رندرِ واقعی استفاده می‌کند (مقیاسِ فونتِ سیستم در صفحه‌ی
  // مطالعه خنثی شده، پس این‌جا هم noScaling).
  //
  // ⚡ عمداً lazy است: فقط داخلِ LayoutBuilder، فقط برای جدولِ *تک‌ردیفه*، و
  // فقط یک‌بار برای هر جدول (singleRowFloors) — یعنی چند TextPainter برای
  // سلول‌های همان یک ردیف. گاردِ measurementUnused برای بقیه‌ی جدول‌ها
  // دست‌نخورده می‌ماند.
  final RegExp breakingSpace = RegExp(r'[ \t\r\n\u2000-\u200A\u3000]');

  // 🐞 کلمه با وجودِ کف باز هم می‌شکست (Mindset 2 ص۵۱: «technolog|y»): متنِ
  // سلول داخلِ FloatColumn با `DefaultTextStyle.of(context).style` ترکیب و رندر
  // می‌شود، و هر ویژگی‌ای که خودِ اسپن تعیین نکرده از تمِ اپ ارث می‌رسد —
  // مهم‌ترینش letterSpacing=0.25ِ bodyMediumِ متریال ۳ (ThemeData() پیش‌فرض).
  // اندازه‌گیری قبلاً با یک TextStyleِ خام بود و این فاصله را نمی‌دید؛ برای
  // «technology» (۱۰ حرف) حدودِ ۲.۵px کم می‌آمد، بیشتر از حاشیه‌ی ۲pxِ کف. حالا
  // پایه‌ی اندازه‌گیری دقیقاً همان سبکِ ارثیِ رندر است.
  final TextStyle inheritedTextStyle = DefaultTextStyle.of(context).style;

  TextStyle measureStyleFor(SpanData s) {
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
    final bool subOrSup =
        s.markers.contains("sub") || s.markers.contains("sup");
    return inheritedTextStyle.merge(TextStyle(
      fontSize: subOrSup ? fontSize * 0.75 : fontSize,
      fontFamily: fontFamily,
      fontWeight: s.markers.contains("b") ? FontWeight.bold : FontWeight.normal,
      fontStyle: s.markers.contains("i") ? FontStyle.italic : FontStyle.normal,
      letterSpacing: s.letterSpacing, // null → همان فاصله‌ی ارثیِ تم
    ));
  }

  // عرضِ دکمه‌ی آیکونِ چشم (InteractiveBlankWord): margin ۴+۴، padding ۱۰+۱۰ و
  // آیکونِ ۱۶. متنِ مخفیِ داخلش در صفحه دیده نمی‌شود، پس به‌جای آن همین عرض
  // حساب می‌شود.
  const double kBlankIconWidth = 44.0;
  final RegExp blankRe = RegExp(r'\{blk\}.*?\{/blk\}', dotAll: true);

  // فضایی که شماره‌ی لیست می‌گیرد — دقیقاً همان فرمولِ _buildParagraph
  // (کادرِ ثابت‌عرضِ شماره + ۴ فاصله + بیرون‌زدگیِ تورفتگی).
  double listMarkerLead(ParagraphData p) {
    double fontSize = 14.0;
    String? fontFamily;
    for (final s in p.spans) {
      if (s.type != "text") continue;
      for (final m in s.markers) {
        if (m.startsWith("sz:")) {
          final parsed = double.tryParse(m.substring(3));
          if (parsed != null) fontSize = parsed / 2;
        } else if (m.startsWith("fn:")) {
          fontFamily = mapFontFamily(m.substring(3));
        }
      }
      break; // فقط اولین اسپنِ متنی، مثلِ رندر
    }
    final tp = TextPainter(
      text: TextSpan(
        text: p.listMarker,
        // Text(...)ِ شماره هم با DefaultTextStyle ترکیب می‌شود.
        style: inheritedTextStyle.merge(
          TextStyle(
            fontSize: fontSize,
            // 🐞 همان fallbackِ رندر: پاراگرافِ بی‌اسپن → فونتِ پیش‌فرضِ کتاب
            fontFamily: fontFamily ?? mapFontFamily(''),
            fontWeight: p.listMarkerBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final double hanging = -(p.indentFirstLine ?? 0.0);
    final double raw = hanging > 0 ? hanging : 18.0;
    // 🐞 همان فضای اضافه‌ی کادر/پس‌زمینه‌ی شماره که رندر می‌گیرد
    final bool boxed =
        _hexToColor(p.listMarkerFill) != null || p.listMarkerBorder != null;
    final double boxExtra = boxed
        ? 2 * (2.0 + (p.listMarkerBorder?.width ?? 0.0))
        : 0.0;
    final double markerWidth = (tp.width + 4.0 + boxExtra).clamp(
      raw.clamp(16.0, 60.0),
      80.0,
    );
    tp.dispose();
    final double outerLeft = ((p.indentLeft ?? 0.0) - markerWidth).clamp(
      0.0,
      999.0,
    );
    return outerLeft + markerWidth + 4.0;
  }

  double measurePieces(List<TextSpan> pieces) {
    final tp = TextPainter(
      text: TextSpan(children: pieces),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final double w = tp.width;
    tp.dispose();
    return w;
  }

  // 🐞 حداقلِ عرضِ لازمِ یک سلول بدونِ شکستنِ هیچ کلمه و بدونِ روی‌هم‌افتادن:
  // پهن‌ترین «کلمه» (متنِ بینِ دو فاصله‌ی سفید) + فضای شماره‌ی لیست یا
  // تورفتگی + padding و بوردرِ سلول.
  // - آیکونِ چشم ({blk}…{/blk}) با عرضِ واقعیِ دکمه حساب می‌شود، نه متنِ مخفی.
  //   (Mindset 2 ص۵۱ تمرینِ ۰۱: شماره‌ی «1:» روی آیکونِ چشم می‌افتاد.)
  // - شماره‌ی لیست با همان فرمولِ رندر حساب می‌شود.
  // - عکس کف نمی‌گذارد؛ قابلِ کوچک‌شدن است.
  // ⚡ برای هر پاراگراف فقط ۵ کلمه‌ی بلندتر (از نظرِ تعدادِ حروف) با TextPainter
  // اندازه گرفته می‌شود، نه همه‌ی کلمات؛ سلول‌های پرمتن هزینه‌ی زیادی نمی‌سازند.
  double cellNoBreakWidth(TableCellData c, int ci, bool isFirstRow) {
    double widest = 0;
    for (final p in c.paragraphs) {
      final bool wholeParaIsBlank =
          p.keepListMarkerVisible != true &&
          p.spans.length == 1 &&
          _isWhollyOneBlank(p.spans.first.content);
      double lead =
          (p.listMarker != null && p.listMarker!.isNotEmpty && !wholeParaIsBlank)
          ? listMarkerLead(p)
          : ((p.indentLeft ?? 0) > 0 ? p.indentLeft! : 0.0);
      lead += (p.indentRight ?? 0) > 0 ? p.indentRight! : 0.0;
      // 🐞 تورفتگیِ مثبتِ خطِ اول یک WidgetSpanِ ثابت‌عرض در ابتدای خط است
      // (_buildParagraph)؛ اولین کلمه باید کنارش جا شود.
      if (!(p.listMarker != null && p.listMarker!.isNotEmpty) &&
          (p.indentFirstLine ?? 0) > 0) {
        lead += p.indentFirstLine!;
      }

      final List<List<TextSpan>> tokens = [];
      final List<int> tokenChars = [];
      List<TextSpan> pieces = [];
      int chars = 0;
      double fixedWidest = 0;

      void flush() {
        if (pieces.isEmpty) return;
        tokens.add(pieces);
        tokenChars.add(chars);
        pieces = [];
        chars = 0;
      }

      void addText(String text, TextStyle style) {
        final List<String> parts = text.split(breakingSpace);
        for (int k = 0; k < parts.length; k++) {
          if (k > 0) flush();
          if (parts[k].isNotEmpty) {
            pieces.add(TextSpan(text: parts[k], style: style));
            chars += parts[k].length;
          }
        }
      }

      void addSpan(SpanData s) {
        // جای‌خالی قبل از innerSpans بررسی می‌شود: محتوای مخفی در innerSpans
        // است ولی در صفحه فقط دکمه‌ی چشم دیده می‌شود.
        if (s.type == "text" && s.content.contains("{blk}")) {
          final TextStyle style = measureStyleFor(s);
          int last = 0;
          for (final m in blankRe.allMatches(s.content)) {
            if (m.start > last) {
              addText(s.content.substring(last, m.start), style);
            }
            flush();
            if (kBlankIconWidth > fixedWidest) fixedWidest = kBlankIconWidth;
            last = m.end;
          }
          if (last < s.content.length) {
            addText(
              s.content
                  .substring(last)
                  .replaceAll("{blk}", "")
                  .replaceAll("{/blk}", ""),
              style,
            );
          }
          return;
        }
        if (s.innerSpans.isNotEmpty) {
          for (final inner in s.innerSpans) {
            addSpan(inner);
          }
          return;
        }
        if (s.type == "image") {
          // عکس قابلِ کوچک‌شدن است (با حفظِ نسبت، در _buildLocalImage)، پس کف
          // نمی‌گذارد؛ وگرنه یک جدولِ تک‌عکسی روی گوشی بی‌دلیل اسکرول می‌گرفت.
          flush();
          return;
        }
        if (s.type != "text" || s.content.isEmpty) return;
        // کادرِ دورِ متن (مثلِ شماره‌ی تمرینِ «01» که از CompactTable آمده) یک
        // WidgetSpanِ نشکستنی است: داخلِ سلول padding/margin ندارد، پس عرضش
        // متن + دو برابرِ ضخامتِ بوردر است.
        final String borderFlag = (s.hasBorders ?? "").toLowerCase().trim();
        final bool inlineBox =
            s.borders != null || borderFlag == "true" || borderFlag == "1";
        if (inlineBox && s.content.trim().length <= 24) {
          flush();
          final double w =
              measurePieces([
                TextSpan(text: s.content.trim(), style: measureStyleFor(s)),
              ]) +
              2 * (s.borders?.width ?? 1.2);
          if (w > fixedWidest) fixedWidest = w;
          return;
        }
        // 🐞 لینکِ صوتی یک ویجتِ نشکستنی است (InlineAudioLink): margin ۴ +
        // padding ۸+۸ + بوردرِ ۱+۱ + آیکونِ ۲۲ + فاصله‌ی ۸ + متن (۱۴، w600،
        // فاصله‌ی حروفِ ۰.۵).
        if (s.url != null && s.url!.startsWith("audio:")) {
          flush();
          final double w =
              measurePieces([
                TextSpan(
                  text: s.content,
                  style: inheritedTextStyle.merge(
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]) +
              4.0 + 16.0 + 2.0 + 22.0 + 8.0;
          if (w > fixedWidest) fixedWidest = w;
          return;
        }
        // 🐞 توکنِ کوتاهِ رنگی (همان شرطِ _isSafeHighlightToken در رندر) به‌صورتِ
        // WidgetSpan با padding افقیِ ۲+۲ کشیده می‌شود: نشکستنی و ۴px پهن‌تر.
        final String trimmedContent = s.content.trim();
        if (!inlineBox &&
            _hexToColor(s.fillColor) != null &&
            trimmedContent.isNotEmpty &&
            trimmedContent.length <= 20 &&
            !trimmedContent.contains(' ')) {
          flush();
          final double w =
              measurePieces([
                TextSpan(text: s.content, style: measureStyleFor(s)),
              ]) +
              4.0;
          if (w > fixedWidest) fixedWidest = w;
          return;
        }
        addText(s.content, measureStyleFor(s));
      }

      for (final s in p.spans) {
        addSpan(s);
      }
      flush();

      final List<int> order = List<int>.generate(tokens.length, (i) => i)
        ..sort((a, b) => tokenChars[b].compareTo(tokenChars[a]));
      double paraWidest = fixedWidest;
      for (final i in order.take(5)) {
        final double w = measurePieces(tokens[i]);
        if (w > paraWidest) paraWidest = w;
      }
      if (paraWidest + lead > widest) widest = paraWidest + lead;
    }

    final bool imageOnly =
        c.paragraphs.any((p) => p.spans.any((s) => s.type == "image")) &&
        !c.paragraphs.any(
          (p) => p.spans.any(
            (s) => s.type == "text" && s.content.trim().isNotEmpty,
          ),
        );
    final double hpad = cellGeometryFromDoc ? 5.76 : 8.0;
    final double pad = imageOnly
        ? 4.0
        : (c.paddingLeft ?? hpad) + (c.paddingRight ?? hpad);
    final Border? b = (resolvedBorderMode == "cell")
        ? cellBorderFrom(c.borders, isFirstRow, ci == 0)
        : null;
    final double border = (b?.left.width ?? 0) + (b?.right.width ?? 0);
    // ‎+2‎ برای گردکردنِ زیرپیکسلیِ Table؛ بدونِ آن گاهی همان توکنِ مرزی
    // باز هم می‌شکند.
    return widest + pad + border + 2.0;
  }

  // ⚡ سقفِ ارزانِ کفِ یک سلول، بدونِ TextPainter: طولانی‌ترین کلمه (به حرف) ×
  // (اندازه‌ی فونت + فاصله‌ی حروف) — هیچ حرفِ لاتینی پهن‌تر از ۱.۰۵em نیست — +
  // تورفتگی + padding + بوردر. اگر همین سقف در عرضِ ستون جا شود، سلول قطعاً
  // نمی‌شکند و اندازه‌گیریِ دقیق لازم نیست؛ پس جدول‌های جادار تقریباً هیچ
  // هزینه‌ای نمی‌دهند. برای سلول‌های پیچیده (شماره‌ی لیست، آیکونِ چشم، کادرِ
  // متن، لینکِ صوتی، توکنِ رنگی) null برمی‌گرداند یعنی «حتماً اندازه بگیر».
  double? cellNoBreakUpperBound(TableCellData c, int ci, bool isFirstRow) {
    double widest = 0;
    for (final p in c.paragraphs) {
      if (p.listMarker != null && p.listMarker!.isNotEmpty) return null;
      final StringBuffer text = StringBuffer();
      double fs = 0;
      double ls = 0.25; // letterSpacingِ تمِ متریال ۳ (bodyMedium)
      void scan(SpanData s) {
        if (s.innerSpans.isNotEmpty && !s.content.contains("{blk}")) {
          for (final inner in s.innerSpans) {
            scan(inner);
          }
          return;
        }
        if (s.type != "text") {
          text.write(' ');
          return;
        }
        final String flag = (s.hasBorders ?? "").toLowerCase().trim();
        if (s.content.contains("{blk}") ||
            s.borders != null ||
            flag == "true" ||
            flag == "1" ||
            (s.url != null && s.url!.startsWith("audio:")) ||
            _hexToColor(s.fillColor) != null) {
          fs = -1; // پیچیده
          return;
        }
        double size = 14.0;
        for (final m in s.markers) {
          if (m.startsWith("sz:")) {
            final parsed = double.tryParse(m.substring(3));
            if (parsed != null) size = parsed / 2;
          }
        }
        if (size > fs && fs >= 0) fs = size;
        if ((s.letterSpacing ?? 0) > ls) ls = s.letterSpacing!;
        text.write(s.content);
      }

      for (final s in p.spans) {
        scan(s);
        if (fs < 0) return null;
      }
      int longest = 0;
      for (final t in text.toString().split(breakingSpace)) {
        if (t.length > longest) longest = t.length;
      }
      double lead = (p.indentLeft ?? 0) > 0 ? p.indentLeft! : 0.0;
      lead += (p.indentRight ?? 0) > 0 ? p.indentRight! : 0.0;
      lead += (p.indentFirstLine ?? 0) > 0 ? p.indentFirstLine! : 0.0;
      final double w = longest * (fs * 1.05 + ls) + lead;
      if (w > widest) widest = w;
    }
    final double hpad = cellGeometryFromDoc ? 5.76 : 8.0;
    final double pad = (c.paddingLeft ?? hpad) + (c.paddingRight ?? hpad);
    final Border? b = (resolvedBorderMode == "cell")
        ? cellBorderFrom(c.borders, isFirstRow, ci == 0)
        : null;
    final double border = (b?.left.width ?? 0) + (b?.right.width ?? 0);
    return widest + pad + border + 2.0;
  }

  // کفِ بدونِ‌شکستنِ یک سلول برای مقایسه با عرضِ [available]: اگر سقفِ ارزان جا
  // شود همان سقف (محافظه‌کارانه و بی‌هزینه)، وگرنه اندازه‌گیریِ دقیق.
  double cellFloorAgainst(
    TableCellData c,
    int ci,
    bool isFirstRow,
    double available,
  ) {
    final double? bound = cellNoBreakUpperBound(c, ci, isFirstRow);
    if (bound != null && bound <= available + 0.5) return bound;
    return cellNoBreakWidth(c, ci, isFirstRow);
  }

  // 🐞 Mindset 2 ص۵۷ تمرین‌های ۰۳ و ۰۴: CommonTableِ چندردیفه فقط WidthPtِ سند
  // + safety می‌گرفت و هیچ کفی نداشت؛ پس با وجودِ اسکرولِ افقی، کلمه‌های بلند
  // («extraordinary»، «uncomfortable») وسطشان می‌شکستند. حالا همان کفِ جدولِ
  // تک‌ردیفه این‌جا هم هست، با شبکه‌ی مشترکِ ستون‌ها تا ردیف‌ها هم‌تراز بمانند
  // (حتی با سلولِ ادغامی، مثلِ سرستونِ «Newspapers» روی دو ستون).
  List<List<double>>? computeMultiRowNaturalWidths() {
    final rows = tableSpan.tableRows;
    final List<List<double>> base = [
      for (final row in rows)
        [
          for (int ci = 0; ci < row.cells.length; ci++)
            naturalColumnPx(row.cells[ci], ci),
        ],
    ];
    bool violated = false;
    final List<List<double>> floors = [];
    for (int r = 0; r < rows.length; r++) {
      final List<double> f = [];
      for (int ci = 0; ci < rows[r].cells.length; ci++) {
        final double v = cellFloorAgainst(
          rows[r].cells[ci],
          ci,
          r == 0,
          base[r][ci],
        );
        if (v > base[r][ci] + 0.5) violated = true;
        f.add(v);
      }
      floors.add(f);
    }
    if (!violated) return null;
    return _solveColumnGrid(
      docW: [
        for (final row in rows) [for (final c in row.cells) c.widthPt],
      ],
      base: base,
      floor: floors,
    );
  }


  // 🌟 برای جدولِ تک‌ردیفه، ارجاعِ نقشه‌ی عرضِ ستون‌ها را نگه می‌داریم تا
  // پایین‌تر — وقتی عرضِ واقعیِ ظرف را از LayoutBuilder گرفتیم — بتوانیم
  // ستون‌ها را جمع کنیم. Table نقشه را در زمانِ layout می‌خواند، پس این
  // تغییرِ متأخر به آن می‌رسد.
  Map<int, TableColumnWidth>? singleRowColumnWidths;
  // کفِ بدونِ‌شکستنِ ستون‌های جدولِ تک‌ردیفه — مستقل از عرضِ ظرف است، پس یک‌بار
  // (در اولین اجرای LayoutBuilder) اندازه گرفته و برای اجراهای بعدی نگه داشته
  // می‌شود.
  List<double>? singleRowFloors;
  // 🐞 عرضِ کف‌دارِ ستون‌های جدولِ چندردیفه‌ی natural — یک‌بار محاسبه می‌شود (مستقل
  // از عرضِ ظرف). null یعنی هیچ سلولی کمبود نداشت و هندسه‌ی قبلی دست نمی‌خورد.
  bool multiRowFloorsDone = false;
  List<List<double>>? multiRowWidths;
  // 🐞 نقشه‌ی عرضِ ستون‌های هر ردیف که از مسیرِ Table رندر می‌شود (به‌ترتیبِ
  // ردیف‌ها) — برای «کفِ عرضِ ستون» در جدول‌های درصدی (پایین‌تر).
  final List<Map<int, TableColumnWidth>> tablePathColumnWidths = [];
  // 🐞 نقشه‌ی عرضِ ستونِ *هر* ردیف به‌ترتیبِ اندیسِ ردیف (برای کفِ عرضِ ستون در
  // جدول‌های چندردیفه و جدول‌های دارای سلولِ ادغامی — _solveColumnGrid).
  final List<Map<int, TableColumnWidth>> allRowColumnWidths = [];

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
    allRowColumnWidths.add(columnWidths);
    if (tableSpan.tableRows.length == 1) singleRowColumnWidths = columnWidths;

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

        // 🐞 ضلعی که در سند وجود دارد ولی رنگش «auto» است (یا در JSONِ قدیمی
        // null) قبلاً یا نادیده گرفته می‌شد یا به defaultBorderColor (که برای
        // اکثرِ استایل‌ها خاکستری است) می‌افتاد؛ مثلِ Word باید مشکی باشد.
        if (cb.bottom != null) currentBottomColor = _docBorderColor(cb.bottom)!;
        if (cb.top != null) currentTopColor = _docBorderColor(cb.top)!;
        if (cb.left != null) currentLeftColor = _docBorderColor(cb.left)!;
        if (cb.right != null) currentRightColor = _docBorderColor(cb.right)!;
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
            verbatimCellImage: cellGeometryFromDoc, // 🐞 CommonTable (نه NormalTable)
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

      // 🐞 راهِ اصولیِ AutoFit (به‌جای تکیه‌ی صرف بر safetyِ عرضِ ستون): در
      // Word حاشیه‌ی پیش‌فرضِ سلول ۰.۰۸in=۵.۷۶pt هر طرف است؛ برای CommonTable
      // (که وفادار به سند است) padding افقی را به همان مقدار می‌گذاریم تا
      // ناحیه‌ی متن دقیقاً برابرِ Word شود. بقیه‌ی جدول‌ها ۸px پیشینِ خود را
      // نگه می‌دارند.
      final double _hpad = cellGeometryFromDoc ? 5.76 : 8.0;
      EdgeInsetsGeometry cellPadding = isImageCell
          ? const EdgeInsets.all(2.0)
          : EdgeInsets.only(
              top: cell.paddingTop ?? 4.0,
              bottom: cell.paddingBottom ?? 4.0,
              left: cell.paddingLeft ?? _hpad,
              right: cell.paddingRight ?? _hpad,
            );

      // 🐞 روانیِ اسکرول: هر دو تا حذفِ بی‌اثر — (۱) اگر سلول نه رنگِ پس‌زمینه
      // دارد نه بوردر، decoration را null می‌گذاریم تا RenderDecoratedBox اصلاً
      // ساخته نشود (تریس ~۹۱ عدد از این‌ها در هر صفحه نشان می‌داد). (۲) اگر
      // سلول فقط یک پاراگراف دارد، Columnِ تک‌فرزند حذف می‌شود (RenderFlexِ
      // کم‌تر). هیچ‌کدام اثرِ بصری ندارند.
      final Color? _cellFill = _hexToColor(cell.fillColor);
      // در حالتِ جریانی هر سلول یک جعبه‌ی مستقل است و کنارِ سلولِ بعدی
      // نمی‌چسبد، پس منطقِ collapse (که عمداً بوردرِ بالا/چپ را جز در ردیف و
      // ستونِ اول حذف می‌کند تا خط‌ها دوتایی نشوند) این‌جا غلط است و باید
      // هر چهار ضلع کشیده شود.
      final Border? _cellBorder = (resolvedBorderMode == "cell")
          ? (applyWrapFlow
                ? cellBorderFrom(cell.borders, true, true)
                : cellBorderFrom(cell.borders, rowIndex == 0, i == 0))
          : null;
      final Widget _cellInner = cellParagraphs.length == 1
          ? cellParagraphs.first
          : Column(
              crossAxisAlignment: stretchCellsToImage
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: cellParagraphs,
            );

      // 🐞 هم‌ترازیِ عمودیِ سلول در حالتِ BorderMode="cell" (CommonTable و
      // هر جدولِ ناشناخته‌ای که به default می‌افتد) اصلاً اعمال نمی‌شد: آن
      // مسیر به‌جای getVAlign از TableCellVerticalAlignment.intrinsicHeight
      // استفاده می‌کند (که برای هم‌ارتفاع‌کردنِ سلول‌های یک ردیف لازم است و
      // نمی‌شود حذفش کرد)، ولی intrinsicHeight فقط سلول را تا ارتفاعِ ردیف
      // کِش می‌دهد و محتوا را همیشه بالا می‌گذارد. حالا خودِ محتوا داخلِ آن
      // سلولِ کش‌آمده هم‌تراز می‌شود.
      // SizedBox(width: infinity) عمدی است: Align به فرزندش constraintهای
      // شُل می‌دهد و بدونِ آن، محتوا ممکن بود به عرضِ خودش جمع شود و
      // هم‌ترازیِ افقیِ متن (textAlign) بی‌اثر به‌نظر برسد.
      // بقیه‌ی حالت‌ها دست‌نخورده‌اند چون همان بالا با getVAlign(cell.vAlign)
      // به‌صورتِ نیتیو روی خودِ TableCell اعمال می‌شوند.
      final String? _cellVAlign = cell.vAlign;
      Widget _cellAlignedInner = _cellInner;
      // !applyWrapFlow عمدی است: SizedBox(width: infinity) داخلِ Wrap —
      // که constraintهای شُل می‌دهد — یعنی عرضِ بی‌نهایت.
      if (!applyWrapFlow &&
          resolvedBorderMode == "cell" &&
          (_cellVAlign == "center" || _cellVAlign == "bottom")) {
        _cellAlignedInner = Align(
          alignment: _cellVAlign == "center"
              ? Alignment.center
              : Alignment.bottomCenter,
          child: SizedBox(width: double.infinity, child: _cellInner),
        );
      }

      Widget cellContent = Container(
        padding: cellPadding,
        decoration: (_cellFill != null || _cellBorder != null)
            ? BoxDecoration(color: _cellFill, border: _cellBorder)
            : null,
        child: _cellAlignedInner,
      );

      // 🐞 چرا در FlowTable فقط سلولِ اول دیده می‌شد: ویجتِ پاراگرافِ داخلِ
      // سلول هر عرضی که به آن بدهند را کامل می‌گیرد (shrink-wrap نمی‌کند).
      // Wrap به فرزندانش constraintِ شُل می‌دهد، پس چیپِ اول کلِ عرضِ خط را
      // برمی‌داشت و بقیه به خط‌های بعد رانده و از کادر بیرون می‌افتادند.
      // چون Wrap برخلافِ Table عرضِ ستون ندارد که جلوی این را بگیرد، عرضِ
      // هر چیپ باید صریح تعیین شود.
      //
      // ConstrainedBox و نه SizedBox: این فقط سقف می‌گذارد. اگر ظرف از این
      // باریک‌تر باشد (سلولِ تودرتو روی گوشی) چیپ کوچک‌تر می‌شود و متنش
      // wrap می‌کند، به‌جای اینکه سرریز کند.
      if (applyWrapFlow) {
        double chipContentWidth = 0;
        for (final p in cell.paragraphs) {
          final double w = measureParagraphNaturalWidth(p);
          if (w > chipContentWidth) chipContentWidth = w;
        }
        // ⚠️ cellPadding از نوع EdgeInsetsGeometry است و ‎.horizontal‎ ندارد،
        // پس همان دو مقداری که بالاتر ساختندش دوباره جمع می‌شوند. عرضِ
        // بوردر هم باید حساب شود، چون ConstrainedBox سقف را روی جعبه‌ی
        // بیرونیِ Container می‌گذارد، نه روی محتوا.
        final double chipHPad = isImageCell
            ? 4.0
            : ((cell.paddingLeft ?? _hpad) + (cell.paddingRight ?? _hpad));
        final double chipBorder =
            (_cellBorder?.left.width ?? 0) + (_cellBorder?.right.width ?? 0);
        // ‎+2‎ برای خطاهای گردکردنِ اندازه‌گیریِ متن؛ بدونِ آن گاهی آخرین
        // کلمه بی‌دلیل به خطِ دوم می‌افتد.
        final double chipWidth = chipContentWidth + chipHPad + chipBorder + 2.0;
        cellContent = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: chipWidth < 24.0 ? 24.0 : chipWidth,
          ),
          child: cellContent,
        );
      }

      cellWidgets.add(cellContent);

      if (resolvedWidthMode == "natural") {
        // 🐞 CommonTable: هر ستون دقیقاً عرضِ مطلقِ سند را می‌گیرد (WidthPt،
        // که ۱pt=۱px است). اگر سلولی عرضِ صریح نداشت، به عرضِ اندازه‌گیری‌شده‌ی
        // محتوا برمی‌گردیم تا ستون جمع نشود.
        columnWidths[i] = FixedColumnWidth(naturalColumnPx(cell, i));
      } else if (cell.widthPercent != null && cell.widthPercent! > 0) {
        // 🐞 حفظِ محتوا بدونِ بریدن/اسکرولِ بی‌جا: ستونِ باریکِ برچسب (WidthPt
        // کوچک — مثلِ ستونِ Examiner/Candidateِ ص۴۳) روی صفحه‌ی باریک سهمِ
        // درصدی‌اش از عرضِ محتوایش (یک کلمه‌ی بی‌فاصله) کمتر می‌شد و سرریز
        // می‌کرد. حالا اگر ستون باریک است *و* حداقل یک ستونِ پهن (متنِ شکنا)
        // هم در ردیف هست، این ستون را با عرضِ مطلقِ سند (WidthPt+safety، که Word
        // محتوا را در آن جا داده) ثابت می‌کنیم و ستون‌های پهن flex می‌مانند و
        // بقیه‌ی عرض را پر می‌کنند (متن wrap می‌شود). اگر ستونِ پهنی نبود
        // (جدولِ یکنواختِ باریک) همه flex می‌مانند تا عرض را پر کنند و چیزی
        // سرریز نکند. جدولِ بدنه (ستونِ محتوایِ پهن) هم دست‌نخورده flex می‌ماند.
        final double? wpt = cell.widthPt;
        final bool hasWideColumn = row.cells.any(
          (c) => c.widthPt == null || (c.widthPt ?? 0) > 120,
        );
        if (wpt != null && wpt > 0 && wpt <= 120 && hasWideColumn) {
          columnWidths[i] = FixedColumnWidth(wpt + _kNaturalColSafetyPx);
        } else {
          columnWidths[i] = FlexColumnWidth(cell.widthPercent!);
        }
      } else {
        // 🐞 اندازه‌گیریِ واقعیِ عرضِ محتوایِ همین ستون (نه یک پرچمِ Intrinsic
        // شکننده) — perColumnWidestContent همان چیزی است که بالاترِ همین
        // تابع، برایِ محاسبه‌ی عرضِ لازمِ OutsideTable هم استفاده شد؛
        // این‌جا دوباره اندازه‌گیری نمی‌کنیم، همان مقدار را می‌خوانیم.
        final double measuredColumnWidth =
            (perColumnWidestContent[i] ?? 0) + 24;
        switch (resolvedWidthMode) {
          case "content":
            // 🐞 IntrinsicColumnWidth قبلاً باعثِ جمع‌شدنِ کاملِ جدول به
            // نزدیکِ صفر می‌شد (احتمالاً چون یکی از ویجت‌های داخلِ سلول
            // عرضِ intrinsic را درست گزارش نمی‌دهد) — با این‌که خودِ متن
            // هنوز با اندازه‌ی طبیعی‌اش رندر می‌شد، یعنی از جعبه‌ی
            // جمع‌شده بیرون می‌زد. FixedColumnWidth با یک عددِ دقیق و
            // اندازه‌گیری‌شده، این مشکل را کاملاً کنار می‌گذارد.
            columnWidths[i] = FixedColumnWidth(
              measuredColumnWidth > 0 ? measuredColumnWidth : 24,
            );
            break;
          case "proportional":
            // 🐞 FlexColumnWidth یک وزن است، نه لزوماً بینِ ۰ و ۱ — با
            // پاس‌دادنِ همان عددِ اندازه‌گیری‌شده به‌عنوانِ وزن، ستونی که
            // محتوایش پهن‌تر است سهمِ بیشتری از عرضِ دردسترس می‌گیرد،
            // به‌جای تقسیمِ کورکورانه‌ی مساوی (که باعثِ له‌شدنِ متنِ
            // ستون‌های پهن‌تر می‌شد، حتی وقتی عرضِ کلی کافی بود).
            columnWidths[i] = FlexColumnWidth(
              measuredColumnWidth > 0 ? measuredColumnWidth : 1,
            );
            break;
          default:
            columnWidths[i] = const FlexColumnWidth(1);
        }
      }
    }

    if (applyWrapFlow) {
      // هر ردیفِ سند یک Wrap. spacing/runSpacing عمداً کوچک‌اند: کلِ شکایتِ
      // کاربر از فاصله‌های بزرگ بود، و در این حالت هیچ عرضِ اضافه‌ای هم
      // تحمیل نمی‌شود، پس فاصله فقط همین دو عدد است.
      rowWidgets.add(
        Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: cellWidgets,
        ),
      );
    } else if (applyColumnStack) {
      allGridCells.add(cellWidgets);
    } else {
      if (isLargeScreen ||
          isBorderedTable ||
          isImageRow ||
          isNestedTable ||
          showBorders ||
          isOutsideTable ||
          resolvedBorderMode == "cell" || // 🐞 CommonTable همیشه گرید
          resolvedWidthMode == "natural") {
        List<Widget> tableCellWidgets = [];
        for (int i = 0; i < cellWidgets.length; i++) {
          tableCellWidgets.add(
            TableCell(
              // 🐞 پاسخِ نکتهٔ کاربر: در CommonTable اگر یک سلول wrap شده و
              // بلندتر از بقیه شود، همه‌ی سلول‌های همان ردیف باید هم‌ارتفاعِ آن
              // شوند و بوردر/پس‌زمینه‌شان تا پایینِ ردیف پُر شود. مقدارِ
              // intrinsicHeight دقیقاً این کار را می‌کند: در محاسبه‌ی ارتفاعِ
              // ردیف با layoutِ واقعی شرکت می‌کند (نه intrinsic، پس با
              // FloatColumnِ محتوایِ سلول که ابعادِ intrinsic نمی‌دهد سازگار
              // است) و سپس هر سلول را تا ارتفاعِ ردیف کش می‌دهد. برایِ بقیه‌ی
              // استایل‌ها همان رفتارِ قبلی (getVAlign) حفظ می‌شود.
              verticalAlignment: resolvedBorderMode == "cell"
                  ? TableCellVerticalAlignment.intrinsicHeight
                  : getVAlign(row.cells[i].vAlign),
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

        // 🐞 بوردرِ هر ردیف حالا بر اساسِ resolvedBorderMode تصمیم‌گیری
        // می‌شود، نه فقط یک روشن/خاموشِ ساده (showBorders). "outer" هنوز
        // با همان مکانیزمِ قبلی (پایین‌تر، بعدِ ساختِ کاملِ جدول، یک
        // Border.all دورِ کل کشیده می‌شود) کار می‌کند — این‌جا برایش هیچ
        // بوردرِ per-row رسم نمی‌شود. "inner"/"firstRowOuter" مستقیماً
        // این‌جا محاسبه می‌شوند.
        final bool isLastRow = rowIndex == tableSpan.tableRows.length - 1;
        TableBorder resolvedTableBorder;
        switch (resolvedBorderMode) {
          case "all":
            resolvedTableBorder = TableBorder(
              // 🌟 خط بالایی کل جدول فقط و فقط توسط ردیف اول رسم می‌شود
              top: rowIndex == 0 ? topSide : BorderSide.none,
              bottom: bottomSide,
              left: leftSide,
              right: rightSide,
              verticalInside: insideVSide,
            );
            break;
          case "inner":
            // 🐞 فقط خطوطِ داخلی: بینِ ستون‌ها (هر ردیف) و بینِ ردیف‌ها —
            // بجز زیرِ آخرین ردیف، که آن مرزِ بیرونی است، نه داخلی؛ و بدونِ
            // top/left/right (که همیشه مرزِ بیرونی‌اند).
            resolvedTableBorder = TableBorder(
              bottom: isLastRow ? BorderSide.none : bottomSide,
              verticalInside: insideVSide,
            );
            break;
          case "firstRowOuter":
            // 🐞 بوردرِ دورِ کلِ جدول + یک خط زیرِ ردیفِ اول (جداکننده‌ی
            // سرستون از بدنه)، بدونِ خطوطِ داخلیِ دیگر.
            resolvedTableBorder = TableBorder(
              top: rowIndex == 0 ? topSide : BorderSide.none,
              bottom: (rowIndex == 0 || isLastRow)
                  ? bottomSide
                  : BorderSide.none,
              left: leftSide,
              right: rightSide,
            );
            break;
          case "outerThickFirstRow":
            // 🐞 HeaderOutsideTable: بوردرِ بیرونیِ کامل توسطِ wrapِ پایین‌تر
            // (Border.all) کشیده می‌شود؛ این‌جا فقط یک خطِ *ضخیم‌تر* زیرِ ردیفِ
            // اول به‌عنوانِ جداکننده‌ی سرستون می‌کشیم (وقتی جدول بیش از یک ردیف
            // دارد). بقیه‌ی ردیف‌ها هیچ خطی نمی‌گیرند — مثلِ OutsideTable.
            if (rowIndex == 0 && tableSpan.tableRows.length > 1) {
              resolvedTableBorder = TableBorder(
                bottom: BorderSide(
                  color: currentBottomColor,
                  width:
                      (currentBottomWidth <= 0
                          ? defaultBorderWidth
                          : currentBottomWidth) *
                      2.5,
                ),
              );
            } else {
              resolvedTableBorder = const TableBorder.symmetric();
            }
            break;
          case "outer":
          case "none":
          default:
            resolvedTableBorder = const TableBorder.symmetric();
        }

        tablePathColumnWidths.add(columnWidths);
        rowWidgets.add(
          Table(
            columnWidths: columnWidths,
            border: resolvedTableBorder,
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
    // 🐞 حالتِ merge (MultiColumnTable): محتوایِ همهٔ ستون‌ها — به ترتیبِ
    // ستونی (اولْ کلِ ستونِ ۱، بعد کلِ ستونِ ۲ و ...) که همان ترتیبِ خواندنِ
    // متنِ چندستونی است — در یک لیستِ واحد جمع می‌شود و در پایانِ حلقه
    // به‌صورتِ *یک* ستونِ یکپارچه اضافه می‌گردد. بوردرِ دورِ آن را
    // borderWrapsWholeTable (پایین‌تر) می‌کشد، پس این‌جا نه بوردرِ per-column
    // می‌خواهیم نه فاصلهٔ بینِ ستون‌ها.
    final List<Widget> mergedColumnCells = [];
    for (int colIndex = 0; colIndex < maxCols; colIndex++) {
      List<Widget> columnCells = [];
      for (int rowIndex = 0; rowIndex < allGridCells.length; rowIndex++) {
        if (colIndex < allGridCells[rowIndex].length) {
          columnCells.add(allGridCells[rowIndex][colIndex]);
        }
      }
      if (isMultiColumnMerge) {
        mergedColumnCells.addAll(columnCells);
        continue;
      }
      rowWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          // 🐞 مسیرِ دوم که از قلم افتاده بود: در حالتِ استکی (صفحه‌ی باریک)
          // سلول‌ها اصلاً از مسیرِ Table با resolvedTableBorder رد نمی‌شوند،
          // پس هر ستون به‌صورتِ یک Columnِ ساده و کاملاً بی‌بوردر رندر
          // می‌شد — یعنی فیکسِ قبلی فقط در صفحه‌ی عریض اثر داشت. حالا وقتی
          // قرار است بوردر دیده شود، هر ستونِ استک‌شده جعبه‌ی بوردردارِ خودش
          // را می‌گیرد (معادلِ طبیعیِ ستون‌های بوردردارِ Word بعد از عمودی‌شدن).
          decoration: (resolvedBorderMode != "none" && !hideBorders)
              ? BoxDecoration(
                  border: Border.all(
                    color: defaultBorderColor,
                    width: defaultBorderWidth,
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columnCells,
          ),
        ),
      );
    }
    if (isMultiColumnMerge && mergedColumnCells.isNotEmpty) {
      rowWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: mergedColumnCells,
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
  // فاصله‌ی اضافه فقط برای جای اسکرول‌بار است، که حالا فقط روی دسکتاپ هست.
  final double nestedBottomMargin =
      (willScrollHorizontally && _isDesktopPlatform) ? 14.0 : 10.0;

  // 🐞 پیدا شد — علتِ «فاصله‌ی اضافه زیرِ ردیفِ آخر، داخلِ بوردر»: در فلاتر
  // margin یک Container بیرونِ decorationِ *خودش* است، ولی وقتی این
  // Container داخلِ یک Containerِ دیگر با بوردر پیچیده می‌شود (کارِ بلاکِ
  // زیر برایِ BorderMode="outer")، آن margin عملاً داخلِ بوردرِ بیرونی
  // می‌افتد. یعنی همان ۱۴px فاصله‌ی پایین (که برایِ جدایِ نگه‌داشتنِ نوارِ
  // اسکرول از جدول گذاشته شده) و ۲px بالا، به‌جایِ بیرونِ کادر، *داخلِ*
  // کادر رسم می‌شدند — دقیقاً همان فضایِ خالیِ نامتقارنِ زیرِ ردیفِ آخر.
  // راهِ حل: وقتی بوردرِ بیرونی اعمال می‌شود، margin از کانتینرِ داخلی
  // برداشته و به خودِ کانتینرِ بوردردار داده می‌شود تا بوردر دقیقاً دورِ
  // ردیف‌ها بچسبد و فاصله بیرونِ آن بماند.
  final EdgeInsets tableOuterMargin = isNestedTable
      ? EdgeInsets.only(top: 2.0, bottom: nestedBottomMargin)
      : const EdgeInsets.symmetric(vertical: 12.0);
  // 🐞 در حالتِ استکیِ معمولی (ColumnStackTable روی صفحهٔ باریک) هر ستون
  // خودش جعبهٔ بوردردارِ مستقل می‌گیرد، پس این wrapِ بیرونی نباید اجرا شود —
  // وگرنه یک کادرِ اضافه هم دورِ کلِ ستون‌های از‌قبل‌کادردار کشیده می‌شد.
  // 🐞 "outerThickFirstRow" (استایلِ HeaderOutsideTable) هم مثلِ "outer" یک
  // بوردرِ بیرونیِ کامل (شاملِ بالای جدول) دورِ کلِ جدول می‌خواهد؛ خطِ ضخیمِ
  // زیرِ ردیفِ اول جداگانه در سوییچِ per-row رسم می‌شود.
  // 🐞 استثنا: در حالتِ merge (MultiColumnTable روی صفحهٔ باریک) دقیقاً
  // برعکس است — همهٔ ستون‌ها در یک ستونِ یکپارچه ادغام شده‌اند و *هیچ*
  // بوردرِ per-columnی ندارند، پس همین wrapِ بیرونی است که تنها کادرِ
  // دورِ کلِ متن را می‌کشد و باید فعال بماند.
  final bool borderWrapsWholeTable =
      (resolvedBorderMode == "outer" ||
          resolvedBorderMode == "outerThickFirstRow") &&
      !hideBorders &&
      (!applyColumnStack || isMultiColumnMerge);

  // 🌟 اصلاح نهایی: حذف پارامتر border از کانتینر بیرونی برای جلوگیری از تداخل و دابل‌بوردر شدن سایدها
  Widget tableContainer = Container(
    margin: borderWrapsWholeTable ? EdgeInsets.zero : tableOuterMargin,
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
  if (borderWrapsWholeTable) {
    tableContainer = Container(
      margin: tableOuterMargin,
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
  // 🐞 برای کفِ عرضِ ستون (پایینِ تابع): جدولِ پیش از پیچیدن در اسکرولِ افقی، و
  // عرضی که این مسیر برایش حدس زد (اگر پیچیده شد).
  final Widget tableBeforeHScroll = tableContainer;
  double? hScrollRenderWidth;
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
    // 🐞 برای OutsideTable، «پهن‌ترین یک سلول» (widestContentWidth) کافی
    // نیست — یک جدولِ واژگانِ چندستونی (مثلِ جدولِ کلماتِ این تمرین) عرضِ
    // واقعی‌اش نزدیک به مجموعِ پهن‌ترینِ هر ستون است، چون همه‌ی ستون‌ها
    // کنارِ هم قرار می‌گیرند. sumOfColumnWidestContent همین را می‌دهد؛
    // هرکدام از این دو معیار (تکی یا مجموع) بیشتر بود همان استفاده
    // می‌شود.
    final double outsideTableContentWidth =
        (sumOfColumnWidestContent > widestContentWidth
            ? sumOfColumnWidestContent
            : widestContentWidth) *
        1.08;
    // 🐞 ضریبِ ۱.۰۸: اندازه‌گیریِ TextPainter هیچ‌وقت دقیقاً برابرِ عرضِ
    // واقعیِ رندرشده در سلول نیست (رُندکردنِ فاصله‌گذاریِ حروف/کلمات و
    // این‌جور جزئیات) — بدونِ این حاشیه‌ی امن، در برخی عرض‌هایِ صفحه
    // (نه همه)، محاسبه‌ی «کافی است» درست از آب درمی‌آمد ولی رندرِ واقعی
    // چند پیکسل بیشتر لازم داشت، و ستون‌ها به‌جایِ گرفتنِ اسکرولِ افقی
    // (که کاربر می‌خواهد)، له/wrap می‌شدند.
    final double neededWidth = isOutsideTable
        ? outsideTableContentWidth
        : (columnHeuristicWidth > widestContentWidth
              ? columnHeuristicWidth
              : widestContentWidth);
    // 🐞 رفع باگِ «OutsideTable عریض‌تر از سند + فاصله‌ی اضافه در انتهای
    // ردیفِ آخر»: قبلاً همین فرضِ «هر ستون حداقل ۹۰px» برای OutsideTable
    // هم اعمال می‌شد — یعنی حتی وقتی محتوای واقعیِ ستون‌ها خیلی باریک‌تر
    // بود، جدول به‌خاطرِ همین فرض کش می‌آمد (بیشتر از چیزی که واقعاً لازم
    // داشت)، و چون بوردرِ بیرونی هم با همین عرضِ اجباری کشیده می‌شود، هم
    // بوردر با سند نمی‌خواند هم انتهای هر ردیف فضای خالیِ اضافه داشت.
    // برای OutsideTable، فقط بر اساسِ محتوایِ واقعاً اندازه‌گیری‌شده
    // (outsideTableContentWidth، نه یک فرضِ ثابتِ به‌ازایِ هر ستون) عریض
    // می‌شود.
    final bool manyColumnsNeedRoom =
        !isOutsideTable &&
        maxColumnCount > 1 &&
        columnHeuristicWidth > canvasWidth;
    final bool embeddedImageNeedsRoom = isOutsideTable
        ? outsideTableContentWidth > canvasWidth
        : widestContentWidth > canvasWidth;
    if ((manyColumnsNeedRoom || embeddedImageNeedsRoom) &&
        neededWidth > canvasWidth) {
      final double renderWidth = neededWidth.clamp(
        canvasWidth,
        canvasWidth * 3,
      );
      hScrollRenderWidth = renderWidth;
      // 🐞 رفع کرش «Scrollbar's ScrollController has no ScrollPosition
      // attached»: بدون controllerِ صریح، Scrollbar به PrimaryScrollController
      // برمی‌گردد که به این SingleChildScrollViewِ افقیِ تودرتو وصل نیست.
      tableContainer = _HScrollBox(
        // 🐞 این‌جا قبلاً یک Padding(bottom: 14) بود تا نوارِ اسکرول روی
        // لبه‌ی پایینیِ بوردرِ جدول لَم ندهد. ولی بعد از فیکسِ قبلی (که
        // marginِ ۱۴پیکسلیِ جدول را از داخلِ بوردر به بیرونش منتقل کرد)،
        // همان margin — که خودش داخلِ همین ناحیه‌ی اسکرول است — دقیقاً
        // همین جدایی را فراهم می‌کند. پس این Padding تکراری شده بود و
        // ۱۴+۱۴=۲۸ پیکسل فاصله می‌ساخت؛ حذف شد تا فقط همان ۱۴ بماند.
        child: SizedBox(width: renderWidth, child: tableContainer),
      );
    }
  }

  // 🐞 CommonTable (WidthMode="natural"): تصمیمِ اسکرولِ افقی داده‌محور و
  // قطعی است — مجموعِ عرضِ مطلقِ ستون‌ها (WidthPt، ۱pt=۱px) را با عرضِ
  // دستگاه مقایسه می‌کنیم. اگر بزرگ‌تر بود، جدول با عرضِ طبیعی‌اش داخلِ اسکرولِ
  // افقی می‌رود (ستون‌ها له نمی‌شوند)؛ اگر جا می‌شد، با همان عرضِ طبیعی و
  // چپ‌چین رندر می‌شود (کش نمی‌آید، عیناً مثلِ سند). این‌جا نه حدسِ محتوا لازم
  // است نه حاشیه‌ی امن — عددِ واقعیِ سند را داریم.
  if (resolvedWidthMode == "natural") {
    // دقیقاً همان naturalColumnPx که عرضِ ستون‌ها را ساخت — تا عرضِ
    // SizedBox هیچ‌وقت از عرضِ واقعیِ Table کمتر نشود.
    double naturalTableWidth = 0;
    for (final row in tableSpan.tableRows) {
      double rowW = 0;
      for (int ci = 0; ci < row.cells.length; ci++) {
        rowW += naturalColumnPx(row.cells[ci], ci);
      }
      if (rowW > naturalTableWidth) naturalTableWidth = rowW;
    }

    if (naturalTableWidth > 0) {
      // 🐞 تصمیمِ scroll/fit را با عرضِ *واقعیِ در دسترس* می‌گیریم نه canvasWidthِ
      // بیرونی. جدولِ تودرتو (مثلِ Societies تمرین۷ ص۳۷ داخلِ ستونِ چپِ چیدمانِ
      // دو ستونی) canvasWidth را از کلِ صفحه می‌گرفت و روی نمایشگرِ عریض با عرضِ
      // طبیعی رندر می‌شد و از ستونش بیرون می‌زد (می‌رفت زیرِ TIP). با LayoutBuilder
      // عرضِ همان سلول را می‌گیریم: اگر جا نشد، داخلِ خودش اسکرولِ افقی می‌گیرد؛
      // اگر جا شد، با عرضِ طبیعی. دیگر هیچ‌وقت از ظرفش سرریز نمی‌کند.
      return LayoutBuilder(
        builder: (context, constraints) {
          final double avail = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : canvasWidth;
          // 🌟 درخواستِ کاربر: وقتی جدول فقط یک ردیف دارد، عرضِ ستون‌ها هیچ
          // نقشی در هم‌ترازیِ بینِ ردیف‌ها ندارد؛ پس به‌جای اسکرول، ستون‌ها
          // جمع می‌شوند تا داخلِ ظرف جا شوند و متن wrap شود.
          //
          // 🐞 اصلاح (جدولِ پیشوندهای ص۵: post- ، for-/fore- ، ... ، under-):
          // قبلاً ستون‌ها کورکورانه به نسبتِ سند جمع می‌شدند؛ «under-» از
          // ستونش بیرون می‌زد و «for-/fore-» سرِ خط‌تیره به خطِ دوم می‌رفت،
          // در حالی‌که در Word هر دو یک‌خطی‌اند. حالا هر ستون یک «کف» دارد
          // (cellNoBreakWidth: پهن‌ترین کلمه‌ی سلول + padding + بوردر، با
          // متریکِ واقعیِ فلاتر) و هیچ ستونی هرگز از کفش باریک‌تر نمی‌شود:
          //  ۱) max(عرضِ سند، کف) جا شد → همان؛ یک‌خطی، عیناً مثلِ Word.
          //     (این حالت هم لازم بود: safetyِ تطبیقی نزدیکِ مرزِ جاشدن به
          //     صفر می‌رسد و چون متریکِ فلاتر کمی از Word پهن‌تر است، مثلاً
          //     «under-» در عرضِ دقیقِ سند جا نمی‌شد.)
          //  ۲) فقط کف‌ها جا شدند → هر ستون کفش را می‌گیرد و باقیِ عرض به
          //     نسبتِ «کمبودِ» هر ستون پخش می‌شود؛ سلولِ تک‌کلمه‌ای نمی‌شکند و
          //     سلولِ جمله‌ای فقط سرِ فاصله‌ها wrap می‌شود.
          //  ۳) حتی کف‌ها جا نشدند → جمع‌کردن بدونِ شکستنِ کلمه ممکن نیست؛
          //     جدول با هندسه‌ی خودِ سند رندر می‌شود (گوشی: اسکرولِ افقی؛
          //     نمایشگرِ عریض: کوچک‌شدنِ یکنواخت) — مثلِ جدولِ چندردیفه.
          //
          // ⚠️ singleRowColumnWidths بینِ اجراهای LayoutBuilder (مثلاً بعد از
          // چرخشِ گوشی) مشترک است، پس در هر اجرا *همه‌ی* ستون‌ها از نو مقدار
          // می‌گیرند و چیزی از اجرای قبلی باقی نمی‌ماند.
          double tableWidth = naturalTableWidth;
          if (tableSpan.tableRows.length == 1 &&
              singleRowColumnWidths != null &&
              tableSpan.tableRows.first.cells.isNotEmpty) {
            final cells = tableSpan.tableRows.first.cells;
            final List<double> floors = singleRowFloors ??= [
              for (int ci = 0; ci < cells.length; ci++)
                cellNoBreakWidth(cells[ci], ci, true),
            ];
            final List<double> naturals = [
              for (int ci = 0; ci < cells.length; ci++)
                naturalColumnPx(cells[ci], ci),
            ];
            final List<double> safeNaturals = [
              for (int ci = 0; ci < cells.length; ci++)
                math.max(naturals[ci], floors[ci]),
            ];
            final double sumSafe = safeNaturals.fold(0.0, (a, b) => a + b);
            final double sumFloors = floors.fold(0.0, (a, b) => a + b);

            if (sumSafe <= avail + 0.5) {
              // ۱) یک‌خطی با عرضِ سند
              for (int ci = 0; ci < cells.length; ci++) {
                singleRowColumnWidths![ci] = FixedColumnWidth(safeNaturals[ci]);
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: sumSafe, child: tableContainer),
              );
            }

            if (sumFloors <= avail + 0.5) {
              // ۲) جمع‌شده تا عرضِ ظرف، بدونِ شکستنِ هیچ کلمه‌ای
              final List<double> deficits = [
                for (int ci = 0; ci < cells.length; ci++)
                  safeNaturals[ci] - floors[ci], // همیشه ≥ ۰
              ];
              final double sumDeficits = deficits.fold(0.0, (a, b) => a + b);
              final double extra = math.max(0.0, avail - sumFloors);
              double fittedWidth = 0;
              for (int ci = 0; ci < cells.length; ci++) {
                final double share = sumDeficits > 0
                    ? extra * deficits[ci] / sumDeficits
                    : extra / cells.length;
                final double w = floors[ci] + share;
                singleRowColumnWidths![ci] = FixedColumnWidth(w);
                fittedWidth += w;
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: math.min(fittedWidth, avail),
                  child: tableContainer,
                ),
              );
            }

            // ۳) هندسه‌ی خودِ سند (WidthPt بدونِ safety) + کف؛ این‌جا کفِ
            // اندازه‌گیری‌شده جای safetyِ حدسی را می‌گیرد، پس ستون‌ها بی‌دلیل
            // از Word پهن‌تر نمی‌شوند.
            tableWidth = 0;
            for (int ci = 0; ci < cells.length; ci++) {
              final double? wpt = cells[ci].widthPt;
              final double docW = (wpt != null && wpt > 0) ? wpt : naturals[ci];
              final double w = math.max(docW, floors[ci]);
              singleRowColumnWidths![ci] = FixedColumnWidth(w);
              tableWidth += w;
            }
          }
          // 🐞 جدولِ چندردیفه: هیچ ستونی از کفِ بدونِ‌شکستنِ سلول‌هایش باریک‌تر
          // نمی‌شود (computeMultiRowNaturalWidths). اگر کف‌ها جدول را از ظرف
          // پهن‌تر کنند، همان اسکرولِ افقی/کوچک‌شدنِ یکنواختِ پایین اعمال می‌شود.
          if (tableSpan.tableRows.length > 1 &&
              allRowColumnWidths.length == tableSpan.tableRows.length) {
            if (!multiRowFloorsDone) {
              multiRowFloorsDone = true;
              multiRowWidths = computeMultiRowNaturalWidths();
            }
            final List<List<double>>? widths = multiRowWidths;
            if (widths != null) {
              double widestRow = 0;
              for (int r = 0; r < widths.length; r++) {
                double rowW = 0;
                for (int c = 0; c < widths[r].length; c++) {
                  allRowColumnWidths[r][c] = FixedColumnWidth(widths[r][c]);
                  rowW += widths[r][c];
                }
                if (rowW > widestRow) widestRow = rowW;
              }
              tableWidth = widestRow;
            }
          }
          if (tableWidth > avail + 0.5) {
            // 🐞 وقتی جدول از عرضِ در دسترس بزرگ‌تر است:
            // - نمایشگرِ عریض → shrink-to-fit: کلِ جدول (متن هم) یکنواخت کوچک
            //   می‌شود تا کامل جا شود (روی صفحه‌ی بزرگ رزولوشن هست و جاشدن بهتر
            //   از اسکرول است). FittedBox با scaleDown فقط کوچک می‌کند نه بزرگ.
            // - نمایشگرِ باریک (گوشی) → اسکرولِ افقی، چون کوچک‌کردن متن را
            //   ناخوانا می‌کند (کاربر قبلاً squish/shrink روی گوشی را نمی‌خواست).
            if (isLargeScreen) {
              return Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: tableWidth, child: tableContainer),
                ),
              );
            }
            return _HScrollBox(
              child: SizedBox(width: tableWidth, child: tableContainer),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: tableWidth, child: tableContainer),
          );
        },
      );
    }
  }

  // 🐞 کفِ عرضِ ستون برای جدول‌های درصدی (DottedTable، NormalTable، …) —
  // Mindset 2 ص۵۱ تمرینِ ۰۱: ستون‌ها فقط با درصدِ سند (FlexColumnWidth) تقسیم
  // می‌شدند، بی‌توجه به محتوا. روی صفحه‌ی باریک ستونِ ۷.۸٪ حدودِ ۲۳px می‌شد ولی
  // «1:» + آیکونِ چشم ~۸۰px لازم دارد، پس روی هم می‌افتادند؛ و «technology» در
  // ستونِ A جا نمی‌شد و فلاتر وسطِ کلمه می‌شکست («technolog|y»).
  //
  // همان قاعده‌ی CommonTable: هیچ ستونی از کفِ خودش (cellNoBreakWidth) باریک‌تر
  // نمی‌شود.
  //  - اگر سهمِ درصدیِ همه‌ی ستون‌ها از کفشان بیشتر است → دقیقاً رفتارِ قبلی
  //    (هیچ تغییری؛ صفحه‌های عریض و جدول‌های جاداری که مشکلی نداشتند دست
  //    نمی‌خورند).
  //  - اگر مجموعِ کف‌ها جا می‌شود → ستون‌های کم‌جا کفشان را می‌گیرند و بقیه‌ی
  //    عرض به نسبتِ درصدهای سند بینِ ستون‌های دیگر پخش می‌شود.
  //  - اگر حتی کف‌ها هم جا نمی‌شوند → جدول با مجموعِ کف‌ها افقی اسکرول می‌شود
  //    (روی موبایل با سایه‌ی لبه و فلش، بدونِ اسکرول‌بار).
  // فقط وقتی همه‌ی ردیف‌ها از مسیرِ Table رد شده‌اند، تعدادِ ستون‌ها یکسان است،
  // سلولِ ادغامی (colspan) نیست و همه‌ی ستون‌ها Flex هستند؛ جدول‌های
  // horizontalScroll/Bordered/Outside مسیرهای خودشان را دارند.
  final List<TableRowData> guardRows = tableSpan.tableRows;
  final int guardCols = guardRows.isEmpty ? 0 : guardRows.first.cells.length;
  final bool floorGuardEligible =
      resolvedWidthMode != "natural" &&
      resolvedWidthMode != "content" &&
      !applyWrapFlow &&
      !applyColumnStack &&
      !explicitHorizontalScroll &&
      !isBorderedTable &&
      !isOutsideTable &&
      guardCols > 1 &&
      tablePathColumnWidths.length == guardRows.length &&
      guardRows.every(
        (r) =>
            r.cells.length == guardCols &&
            r.cells.every((c) => (c.colSpan ?? 1) <= 1 && (c.gridSpan ?? 1) <= 1),
      ) &&
      tablePathColumnWidths.every(
        (m) => List<int>.generate(
          guardCols,
          (i) => i,
        ).every((i) => m[i] is FlexColumnWidth),
      );

  if (floorGuardEligible) {
    final List<double> weights = [
      for (int ci = 0; ci < guardCols; ci++)
        (tablePathColumnWidths.first[ci] as FlexColumnWidth).value,
    ];
    final double weightSum = weights.fold(0.0, (a, b) => a + b);
    // کفِ هر ستون فقط وقتی لازم شد و فقط یک‌بار اندازه گرفته می‌شود.
    final Map<int, double> floorCache = {};
    double columnFloor(int ci) => floorCache.putIfAbsent(ci, () {
      double f = 0;
      for (int ri = 0; ri < guardRows.length; ri++) {
        final double w = cellNoBreakWidth(guardRows[ri].cells[ci], ci, ri == 0);
        if (w > f) f = w;
      }
      return f;
    });
    final Widget guardedTable = tableContainer;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : canvasWidth;
        // ⚠️ نقشه‌ها بینِ اجراها مشترک‌اند (مثلاً چرخشِ گوشی) → اول به درصدهای سند.
        for (final m in tablePathColumnWidths) {
          for (int ci = 0; ci < guardCols; ci++) {
            m[ci] = FlexColumnWidth(weights[ci]);
          }
        }
        if (weightSum <= 0) return guardedTable;

        final List<double> share = [
          for (int ci = 0; ci < guardCols; ci++) avail * weights[ci] / weightSum,
        ];
        // ستونِ پهن (≥۱۶۰px) عملاً هیچ‌وقت کمبود ندارد؛ اندازه‌گیری‌اش لازم نیست.
        final List<double> floors = [
          for (int ci = 0; ci < guardCols; ci++)
            share[ci] >= 160 ? 0.0 : columnFloor(ci),
        ];
        bool violated = false;
        for (int ci = 0; ci < guardCols; ci++) {
          if (share[ci] + 0.5 < floors[ci]) violated = true;
        }
        if (!violated) return guardedTable; // رفتارِ قبلی، بی‌تغییر

        final double floorSum = floors.fold(0.0, (a, b) => a + b);
        final List<double> widths;
        if (floorSum <= avail + 0.5) {
          // «پرکردنِ آب»: ستون‌هایی که سهمشان از کفشان کمتر است کف را می‌گیرند،
          // باقیِ عرض به نسبتِ درصدها بینِ بقیه؛ تا وقتی ستونِ تازه‌ای زیرِ کف نرود.
          final Set<int> pinned = {};
          List<double> w = List<double>.from(share);
          for (int iter = 0; iter < guardCols; iter++) {
            double pinnedSum = 0;
            double freeWeight = 0;
            for (int ci = 0; ci < guardCols; ci++) {
              if (pinned.contains(ci)) {
                pinnedSum += floors[ci];
              } else {
                freeWeight += weights[ci];
              }
            }
            final double remaining = avail - pinnedSum;
            bool changed = false;
            for (int ci = 0; ci < guardCols; ci++) {
              if (pinned.contains(ci)) {
                w[ci] = floors[ci];
                continue;
              }
              w[ci] = freeWeight > 0 ? remaining * weights[ci] / freeWeight : 0;
              if (w[ci] + 0.5 < floors[ci]) {
                pinned.add(ci);
                changed = true;
              }
            }
            if (!changed) break;
          }
          widths = w;
        } else {
          widths = floors;
        }

        for (final m in tablePathColumnWidths) {
          for (int ci = 0; ci < guardCols; ci++) {
            m[ci] = FixedColumnWidth(widths[ci]);
          }
        }
        final double total = widths.fold(0.0, (a, b) => a + b);
        if (total > avail + 0.5) {
          return _HScrollBox(
            child: SizedBox(width: total, child: guardedTable),
          );
        }
        return SizedBox(width: avail, child: guardedTable);
      },
    );
  }

  // عرضی که مسیرِ پیش‌فرضِ پایین به خودِ جدول می‌دهد (null = همه‌ی عرضِ ظرف)؛
  // کفِ عرضِ ستون (gridGuard) با همین عرض مقایسه می‌کند.
  double? defaultTableWidth = hScrollRenderWidth;
  Widget defaultResult = tableContainer;
  if (isBorderedTable && tableSpan.tableWidthPercent != null) {
    if (isLargeScreen) {
      Alignment tableAlign = Alignment.centerLeft;
      if (tableSpan.tableAlignment == "center") tableAlign = Alignment.center;
      if (tableSpan.tableAlignment == "right") {
        tableAlign = Alignment.centerRight;
      }
      defaultTableWidth ??= canvasWidth * (tableSpan.tableWidthPercent! / 100);
      defaultResult = Align(
        alignment: tableAlign,
        child: SizedBox(
          width: canvasWidth * (tableSpan.tableWidthPercent! / 100),
          child: tableContainer,
        ),
      );
    } else {
      if (tableSpan.tableWidthPercent! < 40) {
        defaultTableWidth ??= canvasWidth * 0.6;
        defaultResult = Align(
          alignment: Alignment.center,
          child: SizedBox(width: canvasWidth * 0.6, child: tableContainer),
        );
      }
    }
  }

  // 🐞 همان کف برای همه‌ی جدول‌های درصدی‌ای که مسیرِ بالا نمی‌پذیرد: سلولِ ادغامی
  // (ColSpan)، ردیف‌هایی با تعدادِ سلولِ متفاوت، ستون‌های ثابت‌عرضِ کنارِ ستون‌های
  // Flex (قاعده‌ی «ستونِ برچسبِ باریک»)، و جدول‌های Bordered/Outside/Figure (حتی
  // وقتی مسیرِ horizontalScroll با یک عرضِ حدسی در اسکرول پیچیده‌شان). این‌ها
  // قبلاً هیچ کفی نداشتند.
  // با _solveColumnGrid: ستون‌ها هم‌تراز می‌مانند، هیچ سلولی از کفش باریک‌تر
  // نمی‌شود و اضافه‌عرض تا جای ممکن از فضای اضافیِ ستون‌های دیگر گرفته می‌شود؛
  // اگر جا نشد، اسکرولِ افقی. اگر هیچ سلولی کمبود نداشت، رفتارِ قبلی بی‌تغییر.
  final bool gridGuardEligible =
      !floorGuardEligible &&
      resolvedWidthMode != "natural" &&
      resolvedWidthMode != "content" &&
      !applyWrapFlow &&
      !applyColumnStack &&
      guardRows.isNotEmpty &&
      tablePathColumnWidths.length == guardRows.length &&
      allRowColumnWidths.length == guardRows.length &&
      guardRows.any((r) => r.cells.length > 1) &&
      List<int>.generate(guardRows.length, (i) => i).every(
        (r) =>
            allRowColumnWidths[r].length == guardRows[r].cells.length &&
            allRowColumnWidths[r].values.every(
              (v) => v is FixedColumnWidth || v is FlexColumnWidth,
            ),
      );

  if (gridGuardEligible) {
    // جدولِ خام (پیش از پیچیدن در اسکرولِ حدسیِ horizontalScroll)؛ اگر کمبودی
    // نبود، دقیقاً همان نتیجه‌ی پیش‌فرض (defaultResult) برمی‌گردد.
    final Widget guardedTable = tableBeforeHScroll;
    // نقشه‌ها بینِ اجراهای LayoutBuilder مشترک‌اند؛ هر اجرا از نسخه‌ی اصلی شروع می‌کند.
    final List<Map<int, TableColumnWidth>> originals = [
      for (final m in allRowColumnWidths) Map<int, TableColumnWidth>.of(m),
    ];
    final bool allPt = guardRows.every(
      (r) => r.cells.every((c) => (c.widthPt ?? 0) > 0),
    );
    final List<List<double?>> docW = [
      for (final r in guardRows)
        [for (final c in r.cells) allPt ? c.widthPt : c.widthPercent],
    ];
    final Map<int, double> exactFloors = {};
    double exactFloor(int r, int ci) => exactFloors.putIfAbsent(
      r * 1000 + ci,
      () => cellNoBreakWidth(guardRows[r].cells[ci], ci, r == 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : canvasWidth;
        for (int r = 0; r < guardRows.length; r++) {
          allRowColumnWidths[r]
            ..clear()
            ..addAll(originals[r]);
        }
        // عرضی که مسیرِ پیش‌فرض واقعاً به جدول می‌دهد.
        final double tableAvail = defaultTableWidth ?? avail;
        // عرضِ فعلیِ هر سلول، همان‌طور که Table حساب می‌کند: ثابت‌ها عرضِ خودشان،
        // Flexها سهمشان از باقیِ عرض.
        final List<List<double>> base = [];
        for (int r = 0; r < guardRows.length; r++) {
          double fixedSum = 0, flexSum = 0;
          for (final v in originals[r].values) {
            if (v is FixedColumnWidth) fixedSum += v.value;
            if (v is FlexColumnWidth) flexSum += v.value;
          }
          final double free = math.max(0.0, tableAvail - fixedSum);
          base.add([
            for (int ci = 0; ci < guardRows[r].cells.length; ci++)
              () {
                final TableColumnWidth v = originals[r][ci]!;
                if (v is FixedColumnWidth) return v.value;
                final double f = (v as FlexColumnWidth).value;
                return flexSum > 0 ? free * f / flexSum : 0.0;
              }(),
          ]);
        }
        bool violated = false;
        for (int r = 0; r < guardRows.length && !violated; r++) {
          for (int ci = 0; ci < guardRows[r].cells.length; ci++) {
            final double? bound = cellNoBreakUpperBound(
              guardRows[r].cells[ci],
              ci,
              r == 0,
            );
            if (bound != null && bound <= base[r][ci] + 0.5) continue;
            if (exactFloor(r, ci) > base[r][ci] + 0.5) {
              violated = true;
              break;
            }
          }
        }
        if (!violated) return defaultResult; // رفتارِ قبلی، بی‌تغییر

        final List<List<double>> floors = [
          for (int r = 0; r < guardRows.length; r++)
            [
              for (int ci = 0; ci < guardRows[r].cells.length; ci++)
                exactFloor(r, ci),
            ],
        ];
        final List<List<double>> widths = _solveColumnGrid(
          docW: docW,
          base: base,
          floor: floors,
          maxTotal: tableAvail,
        );
        double total = 0;
        for (int r = 0; r < widths.length; r++) {
          double rowW = 0;
          for (int ci = 0; ci < widths[r].length; ci++) {
            allRowColumnWidths[r][ci] = FixedColumnWidth(widths[r][ci]);
            rowW += widths[r][ci];
          }
          if (rowW > total) total = rowW;
        }
        if (total > avail + 0.5) {
          return _HScrollBox(
            child: SizedBox(width: total, child: guardedTable),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: total, child: guardedTable),
        );
      },
    );
  }

  return defaultResult;
}

/// 🐞 حلِ «کفِ عرضِ ستون» برای هر جدولی که ردیف‌هایش جدا رندر می‌شوند (هر ردیف
/// یک Table با نقشه‌ی ستونِ خودش)، حتی با سلولِ ادغامی (ColSpan) یا ردیف‌هایی
/// با تعدادِ سلولِ متفاوت. Mindset 2 ص۵۷: در جدول‌های چندردیفه هیچ کفی اعمال
/// نمی‌شد و «extraordin|ary» با وجودِ اسکرولِ افقی می‌شکست.
///
/// روش: از هندسه‌ی خودِ سند ([docW]، عرضِ هر سلول) مرزهای عمودیِ مشترکِ همه‌ی
/// ردیف‌ها ساخته می‌شود (یک «شبکه»). هر سلول یک بازه از ستون‌های شبکه است. عرضِ
/// پایه‌ی هر ستونِ شبکه از عرضِ فعلیِ سلول‌ها ([base]) می‌آید؛ بعد هر سلولی که
/// از کفش ([floor]) باریک‌تر است، کمبودش بینِ ستون‌های همان بازه (به نسبتِ عرضِ
/// سند) پخش می‌شود — اول سلول‌های تک‌ستونه، بعد ادغامی‌ها. چون همه‌ی ردیف‌ها از
/// همین شبکه می‌خوانند، ستون‌های ردیف‌ها هم‌تراز می‌مانند.
///
/// اگر [maxTotal] داده شود (جدول‌های درصدی)، اضافه‌عرض تا جای ممکن از «فضای
/// اضافیِ» ستون‌های دیگر (عرض منهای کفِ خودشان) گرفته می‌شود تا جدول در ظرف
/// جا شود؛ اگر نشد، جدول با همین عرض اسکرولِ افقی می‌گیرد.
///
/// اگر هندسه‌ی سند ناقص باشد (سلولی بدونِ عرض)، هر ردیف مستقل:
/// عرض = بیشینه‌ی (پایه، کف).
List<List<double>> _solveColumnGrid({
  required List<List<double?>> docW,
  required List<List<double>> base,
  required List<List<double>> floor,
  double? maxTotal,
}) {
  final int nRows = base.length;
  bool gridOk = nRows > 0;
  for (final row in docW) {
    for (final d in row) {
      if (d == null || d <= 0) gridOk = false;
    }
  }
  if (!gridOk) {
    return [
      for (int r = 0; r < nRows; r++)
        [
          for (int c = 0; c < base[r].length; c++)
            math.max(base[r][c], floor[r][c]),
        ],
    ];
  }

  // ۱) مرزهای شبکه (با رواداریِ ۱pt برای گردکردن‌های Word)
  final List<double> raw = [0.0];
  final List<List<double>> starts = [];
  final List<List<double>> ends = [];
  for (int r = 0; r < nRows; r++) {
    double x = 0;
    final List<double> st = [];
    final List<double> en = [];
    for (final d in docW[r]) {
      st.add(x);
      x += d!;
      en.add(x);
      raw.add(x);
    }
    starts.add(st);
    ends.add(en);
  }
  raw.sort();
  final List<double> bounds = [];
  for (final x in raw) {
    if (bounds.isEmpty || x - bounds.last > 1.0) bounds.add(x);
  }
  int idx(double x) {
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < bounds.length; i++) {
      final double d = (bounds[i] - x).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  final int k = math.max(1, bounds.length - 1);
  final List<double> gridDoc = [
    for (int i = 0; i < k; i++)
      i + 1 < bounds.length ? (bounds[i + 1] - bounds[i]) : 1.0,
  ];
  final List<List<int>> cs = [];
  final List<List<int>> ce = [];
  for (int r = 0; r < nRows; r++) {
    final List<int> a = [];
    final List<int> b = [];
    for (int c = 0; c < docW[r].length; c++) {
      int s0 = idx(starts[r][c]);
      int e0 = idx(ends[r][c]);
      if (s0 >= k) s0 = k - 1;
      if (e0 <= s0) e0 = s0 + 1;
      if (e0 > k) e0 = k;
      a.add(s0);
      b.add(e0);
    }
    cs.add(a);
    ce.add(b);
  }
  double spanDoc(int s0, int e0) {
    double t = 0;
    for (int i = s0; i < e0; i++) {
      t += gridDoc[i];
    }
    return t <= 0 ? 1.0 : t;
  }

  // ۲) عرضِ پایه‌ی هر ستونِ شبکه: بیشینه‌ی برآوردِ سلول‌هایی که از آن می‌گذرند
  final List<double> w = List<double>.filled(k, 0.0);
  for (int r = 0; r < nRows; r++) {
    for (int c = 0; c < base[r].length; c++) {
      final double sd = spanDoc(cs[r][c], ce[r][c]);
      for (int i = cs[r][c]; i < ce[r][c]; i++) {
        final double est = base[r][c] * gridDoc[i] / sd;
        if (est > w[i]) w[i] = est;
      }
    }
  }

  // ۳) اعمالِ کف‌ها: اول سلول‌های باریک‌تر (کم‌ستون‌تر)
  final List<List<int>> order = [
    for (int r = 0; r < nRows; r++)
      for (int c = 0; c < base[r].length; c++) [r, c],
  ]..sort((x, y) =>
      (ce[x[0]][x[1]] - cs[x[0]][x[1]]).compareTo(ce[y[0]][y[1]] - cs[y[0]][y[1]]));
  void enforce() {
    for (final rc in order) {
      final int r = rc[0], c = rc[1];
      double sum = 0;
      for (int i = cs[r][c]; i < ce[r][c]; i++) {
        sum += w[i];
      }
      final double deficit = floor[r][c] - sum;
      if (deficit > 0.01) {
        final double sd = spanDoc(cs[r][c], ce[r][c]);
        for (int i = cs[r][c]; i < ce[r][c]; i++) {
          w[i] += deficit * gridDoc[i] / sd;
        }
      }
    }
  }

  enforce();

  // ۴) جمع‌کردن تا عرضِ ظرف (فقط جدول‌های درصدی)، بدونِ رفتن زیرِ هیچ کفی
  if (maxTotal != null) {
    final List<double> minW = List<double>.filled(k, 0.0);
    for (int r = 0; r < nRows; r++) {
      for (int c = 0; c < base[r].length; c++) {
        if (ce[r][c] - cs[r][c] == 1 && floor[r][c] > minW[cs[r][c]]) {
          minW[cs[r][c]] = floor[r][c];
        }
      }
    }
    for (int iter = 0; iter < 4; iter++) {
      final double total = w.fold(0.0, (a, b) => a + b);
      if (total <= maxTotal + 0.5) break;
      double sumSlack = 0;
      for (int i = 0; i < k; i++) {
        sumSlack += math.max(0.0, w[i] - minW[i]);
      }
      if (sumSlack <= 0.5) break;
      final double cut = math.min(total - maxTotal, sumSlack);
      for (int i = 0; i < k; i++) {
        final double slack = math.max(0.0, w[i] - minW[i]);
        w[i] -= cut * slack / sumSlack;
      }
      enforce(); // سلول‌های ادغامی دوباره کفشان را بگیرند
    }
  }

  return [
    for (int r = 0; r < nRows; r++)
      [
        for (int c = 0; c < base[r].length; c++)
          () {
            double t = 0;
            for (int i = cs[r][c]; i < ce[r][c]; i++) {
              t += w[i];
            }
            return t;
          }(),
      ],
  ];
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

  // 🐞 مارکرهای جدیدِ متن: خط‌خورده (s) و زیرنویس/بالانویس (sub/sup).
  // sub/sup در فلاتر معادلِ مستقیم ندارند: اندازه را کوچک می‌کنیم و با
  // fontFeatures از فونت رقمِ sub/sup می‌خواهیم (اگر فونت پشتیبانی نکند فقط
  // کوچک می‌ماند، خراب نمی‌شود). چند decoration با combine جمع می‌شوند.
  final bool _mStrike = span.markers.contains("s");
  final bool _mSub = span.markers.contains("sub");
  final bool _mSup = span.markers.contains("sup");
  final List<TextDecoration> _mDecos = [
    if (span.markers.contains("u")) TextDecoration.underline,
    if (_mStrike) TextDecoration.lineThrough,
  ];

  TextStyle baseStyle = TextStyle(
    fontSize: (_mSub || _mSup) ? fontSize * 0.75 : fontSize,
    // 🌟 'smcp' برای w:smallCaps؛ می‌تواند با بالا/زیرنویس جمع شود.
    fontFeatures: <FontFeature>[
      if (_mSup) const FontFeature('sups'),
      if (_mSub) const FontFeature('subs'),
      if (span.markers.contains("smallcaps")) const FontFeature('smcp'),
    ],
    // 🌟 فاصله‌ی بینِ حروف از ورد
    letterSpacing: span.letterSpacing,
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
    decoration: _mDecos.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(_mDecos),
    // 🌟 نوع/ضخامت/رنگِ زیرخط از ورد. همان helperهای TextRenderEngine
    // استفاده می‌شوند تا این مسیر و مسیرِ applySpanStyle از هم واگرا نشوند.
    decorationStyle: span.markers.contains("u")
        ? TextRenderEngine.decorationStyleFromWord(span.underlineStyle)
        : null,
    decorationColor: span.markers.contains("u")
        ? TextRenderEngine.hexToColor(span.underlineColor)
        : null,
    decorationThickness: span.markers.contains("u")
        ? span.underlineThickness
        : null,
  );

  List<InlineSpan> interactiveSpans = [];
  // 🌟 اگر این span فقط یک توکنِ کوتاهِ رنگی است (مثلِ جای‌خالی‌های "___" یا یک
  // کلمه‌ی تکی هایلایت‌شده، بدون فاصله)، آن را به‌جای TextStyle.backgroundColor
  // (که جعبه‌ی رنگ را دقیقاً به اندازه‌ی «خط» می‌کشد و بین خطوطِ متوالی هیچ فاصله‌ای
  // نمی‌گذارد) با یک Container+padding عمودی رسم می‌کنیم — این تنها راهی است که در
  // فلاتر واقعاً بینِ پس‌زمینه‌ی خطوطِ پشتِ‌هم فاصله‌ی دیداری ایجاد می‌کند.
  final String _content = (span.content ?? "").trim();
  final RegExp blankRegex = RegExp(r'\{blk\}(.*?)\{/blk\}', dotAll: true);
  final matches = blankRegex.allMatches(_content);
  final bool isBlankSpan = blankRegex.allMatches(_content).isNotEmpty;
  final bool _isSafeHighlightToken =
      !isInlineBorder &&
      _hexToColor(span.fillColor) != null &&
      _content.isNotEmpty &&
      _content.length <= 20 &&
      !_content.contains(' ') &&
      (span.innerSpans.isEmpty) &&
      !isBlankSpan;

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
      hiddenParagraphs: span.hiddenParagraphs, // 🌟 جدول/عکسِ داخلِ جوابِ مخفی
      // 🐞 مارکرهای جدید (s/sub/sup): خودِ مارکرهای این اسپن هم رد می‌شوند تا
      // مودال/بنرِ متنِ مخفی بداند چه چیزی از قبل داخلِ baseStyle اعمال شده و
      // بتواند آن را برای متنِ آشکارشده و شماره‌ی لیست خنثی کند.
      blankParentMarkers: span.markers,
      exactMatchKey: isInlineBorder ? null : exactMatchKey,
      // 🌟 وقتی محتوا قرار است داخل باکسِ border در یک Text.rich تودرتو
      // بنشیند (خط ۱۶۵۹ به بعد)، کلید را نمی‌دهیم تا WidgetSpanِ دومی
      // ساخته نشود. برای همه‌ی حالت‌های دیگر (آیکون چشم، جای‌خالی،
      // لینک صوتی، کلمه‌ی معمولی) کلید واقعی داده می‌شود و دقتِ
      // کلمه‌به‌کلمه‌ی قبلی برمی‌گردد.
      interactivesPattern: interactivesPattern,
      interactivesByText: interactivesByText,
      sharedKeyClaim: keyClaim, // 🐞 رفع کرش: claim مشترکِ سطح پاراگراف
      // 🐞 صفحه ۵ تمرین ۱۸: مارکرِ لیست فقط وقتی به مودالِ جای‌خالی پیش‌چسب
      // شود که *کلِ پاراگراف* یک بلاکِ مخفی باشد (یعنی خودِ خط پنهان است و
      // شماره در متنِ بیرون دیده نمی‌شود). برای جای‌خالیِ inline داخلِ آیتمِ
      // لیست (مثلِ «Paragraph A {blk}ii{/blk}» که شماره‌اش بیرون دیده می‌شود)
      // نباید «1:» به «ii» چسبانده شود؛ مودال باید فقط «ii» را نشان دهد.
      // قبلاً شرط روی خودِ span بود، نه پاراگراف، و همین باعثِ «1: ii» می‌شد.
      listMarker:
          (para.keepListMarkerVisible != true &&
              para.spans.length == 1 &&
              _isWhollyOneBlank(para.spans.first.content))
          ? para.listMarker
          : null,
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
              color: _docBorderColor(span.borders) ?? Colors.grey.shade600,
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
  double?
  explicitHeight, // 🐞 CommonTable: ارتفاعِ صریح تا سلولِ فقط‌عکس جمع نشود
}) {
  final String baseImageName = imageName.split('/').last;
  String fallbackPath = 'assets/data/testbook/images/$baseImageName';
  File? localFile;

  // 🌟 هوشمندی: خواندن از فایل آفلاین
  if (activeBook != null && activeBook.activeJsonPath.isNotEmpty) {
    final bookFolderPath = File(activeBook.activeJsonPath).parent.path;
    // 🐞 درخواستِ کاربر: تصاویر در زیرپوشه‌ی images/ ذخیره می‌شوند. اول آن‌جا،
    // سپس fallback به ریشه برای کتاب‌های قدیمیِ صافْ‌ذخیره‌شده.
    final subFolderFile = File('$bookFolderPath/images/$baseImageName');
    final flatFile = File('$bookFolderPath/$baseImageName');

    if (subFolderFile.existsSync()) {
      localFile = subFolderFile;
    } else if (flatFile.existsSync()) {
      localFile = flatFile;
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

  // 🐞 فضای خالیِ بزرگ بالا و پایینِ عکس (نمودارِ ص۸ داخلِ CommonTable): قبلاً
  // برای عکسِ سلولِ CommonTable هم عرض و هم ارتفاعِ سند (۶۰۵×۴۸۲) *جداگانه* به
  // Image داده می‌شد. وقتی جا کمتر از ۶۰۵ بود، عرض جمع می‌شد ولی ارتفاعِ جعبه
  // همان ۴۸۲ می‌ماند؛ BoxFit.contain عکسِ کوچک‌شده را وسطِ آن جعبه‌ی بلند
  // می‌گذاشت و دو نوارِ خالیِ هم‌اندازه بالا و پایینش می‌ماند (روی گوشی هر کدام
  // ~۱۰۰px). حالا وقتی هر دو بعد معلوم‌اند، فقط *نسبتِ* ابعاد ثابت است:
  // عرض = کمترینِ «عرضِ سند» و «جای موجود»، و ارتفاع همیشه از همان عرض و نسبت
  // به دست می‌آید. هدفِ اصلیِ ارتفاعِ صریح هم حفظ می‌شود: AspectRatio حتی پیش
  // از لودِ عکس ارتفاعِ درست را (هم در layout و هم در پاسِ intrinsicHeightِ
  // سلول‌های CommonTable) گزارش می‌دهد، پس سلولِ فقط‌عکس جمع نمی‌شود.
  final bool keepAspect =
      logicalWidth != null &&
      logicalWidth > 0 &&
      explicitHeight != null &&
      explicitHeight > 0;

  Widget image = localFile != null
      ? Image.file(
          localFile,
          fit: BoxFit.contain,
          width: keepAspect ? null : logicalWidth,
          height: keepAspect ? null : explicitHeight,
          cacheWidth: cacheWidth, // 🌟 اضافه شد
          errorBuilder: (context, error, stackTrace) => _errorImage(imageName),
        )
      : Image.asset(
          fallbackPath,
          fit: BoxFit.contain,
          width: keepAspect ? null : logicalWidth,
          height: keepAspect ? null : explicitHeight,
          cacheWidth: cacheWidth, // 🌟 اضافه شد
          errorBuilder: (context, error, stackTrace) => _errorImage(imageName),
        );

  if (keepAspect) {
    image = ConstrainedBox(
      // «!» لازم است: Dart متغیرِ nullable را از طریقِ یک boolِ جدا promote نمی‌کند.
      constraints: BoxConstraints(maxWidth: logicalWidth!),
      child: AspectRatio(
        aspectRatio: logicalWidth / explicitHeight!,
        child: image,
      ),
    );
  }

  return Padding(
    padding: EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 4.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(isImageCell ? 0 : 6),
      child: image,
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
// چون این کار روی کلِ کتاب است (نه فقط یک صفحه)، فراخوان (ReadingCanvas)
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
      // 🐞 "layout" هم پیمایش شود، وگرنه لینک‌های صوتیِ داخلِ
      // ColumnStackTable پیدا نمی‌شوند.
      if (s.type == "table" || s.type == "layout") {
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
      // fileName ممکن است خودش شاملِ مسیرِ زیرپوشه باشد یا فقط نامِ فایل؛
      // فقط نامِ پایه را برمی‌داریم تا مسیرها را خودمان بسازیم.
      final baseName = fileName.split('/').last;
      String targetPath = 'assets/data/audio/$baseName';
      if (activeBook != null && activeBook.activeJsonPath.isNotEmpty) {
        final bookFolderPath = File(activeBook.activeJsonPath).parent.path;
        // 🐞 درخواستِ کاربر: صوت‌ها در زیرپوشه‌ی audio/ ذخیره می‌شوند. اول
        // آن‌جا را می‌جوییم؛ اگر نبود (کتابِ قدیمی که صافْ‌ذخیره شده) به ریشه
        // fallback می‌کنیم تا دانلودهای قبلی نشکنند.
        final subFolderFile = File('$bookFolderPath/audio/$baseName');
        final flatFile = File('$bookFolderPath/$baseName');
        if (subFolderFile.existsSync()) {
          targetPath = subFolderFile.path;
        } else if (flatFile.existsSync()) {
          targetPath = flatFile.path;
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
