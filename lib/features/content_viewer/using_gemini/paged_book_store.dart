import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';

// 🐞 رفع «سقفِ» معماریِ قبلی (نه فقط جنکِ اسکرول):
//
// قبلاً DocumentLoader.loadBookFromJson کل فایل data.json کتاب را یک‌جا
// jsonDecode می‌کرد و یک List<PageData> برای *همه‌ی* صفحات کتاب می‌ساخت که
// تا وقتی کاربر در صفحه بود، کامل در حافظه می‌ماند — چه صفحه‌ی ۱ دیده شود
// چه صفحه‌ی ۹۰۰. یعنی هم زمانِ باز شدنِ کتاب و هم مصرف حافظه با تعداد کل
// صفحات کتاب رشد می‌کرد، مستقل از اینکه کاربر واقعاً چند صفحه را دیده.
//
// این کلاس آن الگو را با یک الگوی استاندارد (دقیقاً همان چیزی که
// اپ‌های کتاب‌خوان حرفه‌ای استفاده می‌کنند) جایگزین می‌کند: «عمر داده» را
// از «عمر ویجت» جدا می‌کند.
//   ۱. فقط یک manifest سبک (شمار صفحات + دیکشنری مشترک کلمات تعاملی +
//      شاخص صوتی) یک‌بار و کامل لود می‌شود — حجمش با تعداد صفحات رشد
//      نمی‌کند.
//   ۲. هر صفحه در یک فایل جدای خودش ذخیره شده و فقط وقتی درخواست شود
//      (getPage) از دیسک خوانده و پارس می‌شود.
//   ۳. صفحاتِ پارس‌شده در یک کش LRU با سقفِ ثابت (maxCachedPages) نگه
//      داشته می‌شوند؛ با رد شدن از سقف، قدیمی‌ترین صفحه‌ی استفاده‌نشده
//      آزاد می‌شود. یعنی مصرف حافظه‌ی این کلاس، مستقل از اندازه‌ی کل
//      کتاب، به یک عدد ثابت محدود می‌ماند.
//
// ساختار مورد انتظار روی دیسک (چه در پوشه‌ی دانلودشده‌ی محلی، چه در
// assets برای نسخه‌ی نمونه/باندل‌شده)، داخل یک پوشه به‌ازای هر کتاب:
//   <bookFolder>/manifest.json
//   <bookFolder>/pages/page_0001.json
//   <bookFolder>/pages/page_0002.json
//   ...
//
// manifest.json:
// {
//   "SchemaVersion": 2,
//   "PageCount": 214,
//   // 🌟 اختیاری: اگر شماره‌ی چاپی صفحات همیشه دقیقاً index+1 نیست (مثلاً
//   // صفحات مقدماتی/فهرست شماره‌گذاری متفاوت دارند)، این آرایه (هم‌طول با
//   // PageCount) شماره‌ی چاپی هر ایندکس را می‌دهد. اگر نباشد، فال‌بکِ
//   // «pageNumber == index+1» استفاده می‌شود. این برای اسکرول به نتیجه‌ی
//   // جستجو لازم است (قبلاً با گشتن در بین همه‌ی PageData های لودشده پیدا
//   // می‌شد؛ حالا دیگر همه‌ی صفحات از قبل لود نیستند).
//   "PageNumbers": [1, 2, 3, ...],
//   // 🌟 لیست تخت و بدون تکرار نام تمام تصاویر استفاده‌شده در کل کتاب —
//   // برای پیش‌بارگذاریِ تصاویر بدون نیاز به لود کردن محتوای هر صفحه.
//   "ImageIndex": ["p12_img1.png", "p45_img2.png", ...],
//   "Interactives": [ ...دقیقاً همان آرایه‌ی InteractiveWord فعلی... ],
//   "AudioIndex": [
//     {
//       "PageNumber": 12,
//       "Paragraph": { ...یک آبجکت کامل Paragraph همان فرمتِ فعلی... }
//     },
//     ...
//   ]
// }
//
// هر pages/page_XXXX.json دقیقاً همان چیزی است که امروز یک عضو از آرایه‌ی
// "Pages" در data.json فعلی است — یعنی { "PageNumber": N, "Paragraphs": [...] }
// — هیچ تغییری در ساختار داخلیِ خودِ صفحه لازم نیست، چون PageData.fromJson
// از قبل پارامترهای sharedInteractives/sharedPattern/sharedByText را
// می‌پذیرد.
class PagedBookStore {
  final BookModel book;

  // 🌟 سقفِ تعداد صفحاتی که هم‌زمان به‌صورت PageData پارس‌شده در حافظه
  // می‌مانند. برای کتاب‌های «چند صد صفحه‌ای» این پروژه، ۶۰ صفحه (خیلی
  // بیشتر از چیزی که در یک لحظه دیده می‌شود) حاشیه‌ی امنِ کافی برای
  // اسکرولِ رفت‌وبرگشتی می‌دهد بدون اینکه حافظه هیچ‌وقت با اندازه‌ی کل
  // کتاب رشد کند.
  final int maxCachedPages;

  PagedBookStore({required this.book, this.maxCachedPages = 60});

  // ── وضعیت منیفست (یک‌بار لود می‌شود، کوچک است، برای همیشه می‌ماند) ──────
  bool _manifestLoaded = false;
  Completer<void>? _manifestLoading;
  int _pageCount = 0;
  List<InteractiveWord> _sharedInteractives = const [];
  RegExp? _sharedPattern;
  Map<String, InteractiveWord> _sharedByText = const {};
  List<ParagraphData> _audioScripts = const [];
  Map<int, int> _pageNumberToIndex = const {};
  List<String> _imageNames = const [];

  int get pageCount => _pageCount;
  List<ParagraphData> get audioScripts => _audioScripts;
  List<String> get imageNames => _imageNames;
  bool get isManifestLoaded => _manifestLoaded;

  // 🌟 معادلِ widget.documentPages.indexWhere((p) => p.pageNumber == n) در
  // نسخه‌ی قبلی — اما بدون نیاز به لود بودنِ همه‌ی صفحات. برای اسکرول به
  // نتیجه‌ی جستجو (که فقط pageNumber را می‌داند، نه ایندکس لیست) استفاده
  // می‌شود. اگر پیدا نشود null برمی‌گرداند (دقیقاً معادلِ -1 قبلی).
  int? indexForPageNumber(int pageNumber) => _pageNumberToIndex[pageNumber];

  // ── مسیر فعال پوشه‌ی این کتاب (دانلودشده یا asset) ───────────────────
  // 🌟 عمداً هیچ فیلد جدیدی به BookModel اضافه نشده. از همان
  // BookModel.activeJsonPath موجود (که خودِ آن از قبل منطق سه‌مرحله‌ای
  // خرید‌شده→نمونه→فال‌بک را دارد) استفاده می‌کنیم:
  //   • حالت محلی (دانلودشده): فایلِ ردیاب نسخه (data.json/sample.json)
  //     هنوز داخل پوشه‌ی کتاب می‌نشیند؛ پوشه‌ی کتاب همان پوشه‌ی والدِ این
  //     فایل است — دقیقاً همان قراردادی که _resolveLocalImageFile در
  //     reading_canvas_screen.dart از قبل برای پیدا کردن تصاویر استفاده
  //     می‌کند، پس هیچ تغییری در سیستم دانلود/نسخه‌بندی لازم نیست.
  //   • حالت asset/باندل‌شده: به‌جای assets/data/<id>.json تخت، هر کتاب
  //     زیرپوشه‌ی مخصوص خودش می‌گیرد: assets/data/<id>/ (باید در
  //     pubspec.yaml هم به‌همین شکل ثبت شود).
  bool get _isLocal => book.isJsonDownloaded || book.isSampleDownloaded;

  String get _bookFolderPath {
    if (_isLocal) {
      return File(book.activeJsonPath).parent.path;
    }
    return 'assets/data/${book.id}';
  }

  Future<String> _readAsset(String relativePath) {
    final path = '$_bookFolderPath/$relativePath';
    if (_isLocal) {
      return File(path).readAsString();
    }
    return rootBundle.loadString(path);
  }

  // ── لود منیفست (idempotent؛ فراخوانی‌های هم‌زمان همان یک Future را می‌بینند) ──
  Future<void> ensureManifestLoaded() async {
    if (_manifestLoaded) return;
    if (_manifestLoading != null) return _manifestLoading!.future;

    final completer = Completer<void>();
    _manifestLoading = completer;
    try {
      String raw;
      try {
        raw = await _readAsset('manifest.json');
      } catch (_) {
        // 🐞 دوران گذار: این کتابِ خاص هنوز به فرمت جدید مهاجرت نکرده (کاربر
        // نسخه‌ی جدیدش را دانلود نکرده، یا asset باندل‌شده هنوز به‌روزرسانی
        // نشده). به‌جای کرش/خالی‌نشان‌دادن صفحه، همان فایل قدیمیِ تک‌جایی را
        // می‌خوانیم و از رویش، *فقط برای همین یک کتاب*، یک نسخه‌ی معادل در
        // حافظه می‌سازیم — دقیقاً همان رفتار قبلی (کل کتاب یک‌جا)، تا وقتی
        // که با یک دانلود بعدی به فرمت جدید مهاجرت کند.
        await _loadLegacySingleFileFormat();
        _manifestLoaded = true;
        completer.complete();
        return;
      }
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

      _pageCount = json['PageCount'] as int? ?? 0;

      // 🌟 نگاشت شماره‌ی چاپیِ صفحه → ایندکس در لیست. اگر مولد کتاب این
      // آرایه را نداد، فرض می‌کنیم رایج‌ترین حالت برقرار است: pageNumber
      // همیشه دقیقاً index+1 است.
      final rawPageNumbers = json['PageNumbers'] as List?;
      if (rawPageNumbers != null && rawPageNumbers.length == _pageCount) {
        _pageNumberToIndex = {
          for (int i = 0; i < rawPageNumbers.length; i++)
            (rawPageNumbers[i] as num).toInt(): i,
        };
      } else {
        _pageNumberToIndex = {for (int i = 0; i < _pageCount; i++) (i + 1): i};
      }

      _imageNames = (json['ImageIndex'] as List? ?? [])
          .map((e) => e.toString())
          .toList();

      final interactivesList =
          (json['Interactives'] as List? ?? [])
              .map((e) => InteractiveWord.fromJson(e))
              .toList()
            ..sort((a, b) => b.exactText.length.compareTo(a.exactText.length));
      _sharedInteractives = interactivesList;

      final nonEmptyWords = interactivesList
          .where((w) => w.exactText.isNotEmpty)
          .toList();
      _sharedPattern = nonEmptyWords.isNotEmpty
          ? RegExp(
              nonEmptyWords.map((w) => RegExp.escape(w.exactText)).join('|'),
            )
          : null;
      _sharedByText = {for (final w in nonEmptyWords) w.exactText: w};

      // 🌟 شاخص صوتی: فقط همان پاراگراف‌هایی که واقعاً به یک تکه‌صدا وصل‌اند
      // (startMs/endMs/audioTrackName هر سه ست) — دقیقاً همان چیزی که قبلاً
      // MainBookScreen._extractAudioScripts با اسکن *کل* کتاب می‌ساخت. حالا
      // مولد کتاب (ابزار C#) این لیستِ کوچک را از قبل در manifest می‌گذارد،
      // پس دیگر نیازی به لود کردن همه‌ی صفحات فقط برای ساختن پلی‌لیست نیست.
      final audioList = (json['AudioIndex'] as List? ?? [])
          .map((e) => ParagraphData.fromJson(e['Paragraph'] ?? e))
          .toList();
      _audioScripts = audioList;

      _manifestLoaded = true;
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      _manifestLoading = null;
      rethrow;
    }
  }

  // ── فال‌بکِ دوران گذار: فرمت قدیمِ تک‌فایلی ────────────────────────────
  // 🌟 دقیقاً همان چیزی که قبلاً DocumentLoader.loadBookFromJson انجام
  // می‌داد، فقط اینجا محدود به همین یک نمونه (و فقط وقتی manifest.json
  // پیدا نشود). چون کل کتاب همین‌جا لود شده، همه‌ی صفحات مستقیم در _cache
  // قرار می‌گیرند (بدون _evictIfNeeded) تا getPage بعدی صرفاً یک cache hit
  // باشد؛ به‌محض اینکه این کتاب با یک دانلود بعدی به فرمت جدید مهاجرت کند
  // (و نمونه‌ی PagedBookStore دوباره ساخته شود)، رفتار تنبل/کم‌حافظه‌ی
  // معمول خودش را پیدا می‌کند.
  Future<void> _loadLegacySingleFileFormat() async {
    final String jsonStr = _isLocal
        ? await File(book.activeJsonPath).readAsString()
        : await rootBundle.loadString(book.activeJsonPath);

    final decoded = jsonDecode(jsonStr);
    List<dynamic> rawPages = const [];
    List<dynamic> rawInteractives = const [];
    if (decoded is Map<String, dynamic>) {
      rawPages = (decoded['Pages'] ?? decoded['pages'] ?? []) as List;
      rawInteractives = (decoded['Interactives'] as List?) ?? const [];
    } else if (decoded is List) {
      rawPages = decoded;
    }

    final interactivesList =
        rawInteractives.map((e) => InteractiveWord.fromJson(e)).toList()
          ..sort((a, b) => b.exactText.length.compareTo(a.exactText.length));
    _sharedInteractives = interactivesList;
    final nonEmptyWords = interactivesList
        .where((w) => w.exactText.isNotEmpty)
        .toList();
    _sharedPattern = nonEmptyWords.isNotEmpty
        ? RegExp(nonEmptyWords.map((w) => RegExp.escape(w.exactText)).join('|'))
        : null;
    _sharedByText = {for (final w in nonEmptyWords) w.exactText: w};

    _pageCount = rawPages.length;
    final Map<int, int> pageNumberToIndex = {};
    _cache.clear();
    for (int i = 0; i < rawPages.length; i++) {
      final page = PageData.fromJson(
        rawPages[i] as Map<String, dynamic>,
        sharedInteractives: _sharedInteractives,
        sharedPattern: _sharedPattern,
        sharedByText: _sharedByText,
      );
      _cache[i] = page;
      pageNumberToIndex[page.pageNumber] = i;
    }
    _pageNumberToIndex = pageNumberToIndex;

    final List<ParagraphData> audioScripts = [];
    final List<String> images = [];
    void collectFromParagraphs(List<ParagraphData> paragraphs) {
      for (final p in paragraphs) {
        if (p.startMs != null && p.endMs != null && p.audioTrackName != null) {
          audioScripts.add(p);
        }
        for (final s in p.spans) {
          if (s.type == 'image') {
            final name = s.url ?? s.content;
            if (name.isNotEmpty) images.add(name);
          } else if (s.type == 'table') {
            for (final row in s.tableRows) {
              for (final cell in row.cells) {
                collectFromParagraphs(cell.paragraphs);
              }
            }
          }
        }
      }
    }

    for (final page in _cache.values) {
      collectFromParagraphs(page.paragraphs);
    }
    _audioScripts = audioScripts;
    _imageNames = images;
  }

  // ── کش LRU صفحات ────────────────────────────────────────────────────
  // 🌟 LinkedHashMap ترتیب درج را حفظ می‌کند؛ با remove+reinsert روی هر
  // hit، آیتم به انتهای لیست (MRU) منتقل می‌شود، پس همیشه keys.first
  // قدیمی‌ترین (LRU) است — پیاده‌سازی سبک LRU بدون نیاز به پکیج جدید.
  final LinkedHashMap<int, PageData> _cache = LinkedHashMap<int, PageData>();
  final Map<int, Future<PageData>> _inFlight = {};

  // 🌟 اگر صفحه‌ای از قبل در کش باشد (چه لود شده چه هنوز در حالِ لود)،
  // بدون هیچ I/O جدیدی همان را برمی‌گرداند. این هم برای سرعت است و هم
  // برای جلوگیری از خواندن هم‌زمانِ چندبارِ یک فایل وقتی چند ویجت هم‌زمان
  // (مثلاً حین یک جهش بزرگ) همان صفحه را درخواست می‌کنند.
  Future<PageData> getPage(int pageIndex) async {
    final cached = _cache.remove(pageIndex);
    if (cached != null) {
      _cache[pageIndex] = cached; // انتقال به انتهای لیست = MRU
      return cached;
    }

    final inFlight = _inFlight[pageIndex];
    if (inFlight != null) return inFlight;

    final future = _loadPage(pageIndex);
    _inFlight[pageIndex] = future;
    try {
      final page = await future;
      _cache[pageIndex] = page;
      _evictIfNeeded();
      return page;
    } finally {
      _inFlight.remove(pageIndex);
    }
  }

  // 🌟 نسخه‌ی sync: اگر صفحه از قبل در کش باشد فوری برمی‌گرداند، وگرنه
  // null — برای جاهایی که نباید منتظر Future بمانند (مثلاً یک هدرِ ساده).
  PageData? peekPage(int pageIndex) => _cache[pageIndex];

  void _evictIfNeeded() {
    while (_cache.length > maxCachedPages) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
  }

  Future<PageData> _loadPage(int pageIndex) async {
    await ensureManifestLoaded();
    final pageNumber = pageIndex + 1;
    final fileName = 'pages/page_${pageNumber.toString().padLeft(4, '0')}.json';
    final String raw = await _readAsset(fileName);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return PageData.fromJson(
      json,
      sharedInteractives: _sharedInteractives,
      sharedPattern: _sharedPattern,
      sharedByText: _sharedByText,
    );
  }

  // 🌟 برای پیش‌بارگذاریِ «پنجره‌ای» (نه کل کتاب) — مثلاً چند صفحه‌ی
  // جلوتر/عقب‌تر از موقعیت فعلی، پیوسته حین اسکرول. صرفاً getPage را صدا
  // می‌زند تا نتیجه وارد کش شود؛ خطای تک‌صفحه بقیه را متوقف نمی‌کند.
  Future<void> prewarmAround(int centerIndex, {int radius = 4}) async {
    final start = (centerIndex - radius).clamp(0, _pageCount - 1);
    final end = (centerIndex + radius).clamp(0, _pageCount - 1);
    for (int i = start; i <= end; i++) {
      try {
        await getPage(i);
      } catch (_) {
        // یک صفحه‌ی خراب/گم‌شده نباید بقیه‌ی پیش‌بارگذاریِ پنجره را متوقف کند
      }
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
