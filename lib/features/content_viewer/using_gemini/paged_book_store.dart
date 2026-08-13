import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';

// 🐞 روانیِ اسکرول — تصحیحِ یک اشتباهِ خودم: راه‌حلِ دورِ قبل (`Isolate.run` به
// ازای هر صفحه) نتیجه‌ی معکوس داد و کاربر با تست تأیید کرد — «کتاب دیرتر لود
// می‌شود» و «تا همه‌ی صفحات یک‌بار اسکرول نخورند روان نمی‌شود». علتش این است:
// `Isolate.run` برایِ *هر* فراخوانی یک ایزوله‌ی کاملاً تازه اسپاون می‌کند و در
// پایان آن را از بین می‌برد؛ این اسپاون/تخریب خودش ده‌ها میلی‌ثانیه هزینه دارد
// — که برای یک کتابِ پرصفحه، به‌ازای *هر تک‌صفحه* پرداخت می‌شد و مجموعاً از
// همان jsonDecodeِ رویِ ترِدِ اصلی که می‌خواستیم رفعش کنیم، کندتر شد (و اولین
// عبورِ هر صفحه، که تا امروز هم قفل داشت، حالا حتی سنگین‌تر شده بود).
//
// راهِ درست: یک ایزوله‌یِ *دائمی* که فقط یک‌بار (اولین باری که به یک صفحه نیاز
// داریم) بالا می‌آید، هزینه‌ی اسپاون فقط همان یک‌بار پرداخت می‌شود، و بعد از آن
// هر صفحه فقط با یک پیام سبک (SendPort/ReceivePort — نه اسپاونِ ایزوله‌ی
// جدید) درخواست می‌شود. این هم ترِدِ UI را در حینِ jsonDecode آزاد نگه می‌دارد
// (هدفِ اصلی) و هم سربارِ اسپاونِ تکراری را حذف می‌کند.
class _DecodeWorker {
  Isolate? _isolate;
  SendPort? _commandPort;
  Future<SendPort>? _starting;

  Future<SendPort> _ensureStarted() {
    final existing = _commandPort;
    if (existing != null) return Future.value(existing);
    return _starting ??= _start();
  }

  Future<SendPort> _start() async {
    final ReceivePort initPort = ReceivePort();
    _isolate = await Isolate.spawn(_decodeWorkerMain, initPort.sendPort);
    final SendPort commandPort = await initPort.first as SendPort;
    initPort.close();
    _commandPort = commandPort;
    return commandPort;
  }

  // path=null یعنی raw از قبل خوانده شده (asset باندل‌شده)؛ در غیرِ این صورت
  // خودِ ایزوله‌ی worker فایل را از دیسک می‌خواند (باز هم دورِ ترِدِ UI).
  Future<Map<String, dynamic>> decode({String? path, String? raw}) async {
    try {
      final SendPort cmd = await _ensureStarted();
      final ReceivePort replyPort = ReceivePort();
      cmd.send(<dynamic>[replyPort.sendPort, path, raw]);
      final dynamic result = await replyPort.first;
      replyPort.close();
      if (result is String && result.startsWith(_workerErrorPrefix)) {
        throw Exception(result.substring(_workerErrorPrefix.length));
      }
      return result as Map<String, dynamic>;
    } catch (_) {
      // 🐞 فال‌بکِ ایمنی: اگر ایزوله به هر دلیلی (پلتفرم/سندباکس) شکست
      // بخورد، به دیکدِ همگامِ رویِ ترِدِ اصلی برمی‌گردیم — کندتر ولی کتاب
      // هیچ‌وقت کامل نمی‌شکند.
      final String content = path != null
          ? await File(path).readAsString()
          : raw!;
      return jsonDecode(content) as Map<String, dynamic>;
    }
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _starting = null;
  }
}

const String _workerErrorPrefix = '__DECODE_ERROR__:';

// نقطه‌ی ورودِ ایزوله‌ی worker — باید سطحِ‌بالا/استاتیک باشد. یک بار اجرا
// می‌شود و برای همیشه به درخواست‌ها گوش می‌دهد (نه یک‌بار-مصرف مثلِ
// Isolate.run).
void _decodeWorkerMain(SendPort mainSendPort) {
  final ReceivePort commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);
  commandPort.listen((dynamic message) {
    final List<dynamic> req = message as List<dynamic>;
    final SendPort replyTo = req[0] as SendPort;
    final String? path = req[1] as String?;
    final String? raw = req[2] as String?;
    try {
      final String content = path != null
          ? File(path).readAsStringSync()
          : raw!;
      replyTo.send(jsonDecode(content));
    } catch (e) {
      replyTo.send('$_workerErrorPrefix$e');
    }
  });
}

// قبلاً DocumentLoader.loadBookFromJson کل فایل data.json کتاب را یک‌جا
// jsonDecode می‌کرد و یک List<PageData> برای *همه‌ی* صفحات کتاب می‌ساخت که
// تا وقتی کاربر در صفحه بود، کامل در حافظه می‌ماند — چه صفحه‌ی ۱ دیده شود
// چه صفحه‌ی ۹۰۰. یعنی هم زمانِ باز شدنِ کتاب و هم مصرف حافظه با تعداد کل
// صفحات کتاب رشد می‌کرد، مستقل از اینکه کاربر واقعاً چند صفحه را دیده.
//
// این کلاس آن الگو را با یک الگوی استاندارد (دقیقاً همان چیزی که
// اپ‌های کتاب‌خوان حرفه‌ای استفاده می‌کنند) جایگزین می‌کند: «عمر داده» را
// از «عمر ویجت» جدا می‌کند.
//   ۱. فقط یک منیفستِ سبک (شمار صفحات + دیکشنری مشترک کلمات تعاملی +
//      اسکریپت‌های صوتی + شاخصِ لینک‌های صوتی) یک‌بار و کامل لود می‌شود —
//      حجمش با تعداد صفحات رشد نمی‌کند.
//   ۲. هر صفحه در یک فایل جدای خودش ذخیره شده و فقط وقتی درخواست شود
//      (getPage) از دیسک خوانده و پارس می‌شود.
//   ۳. صفحاتِ پارس‌شده در یک کش LRU با سقفِ ثابت (maxCachedPages) نگه
//      داشته می‌شوند؛ با رد شدن از سقف، قدیمی‌ترین صفحه‌ی استفاده‌نشده
//      آزاد می‌شود. یعنی مصرف حافظه‌ی این کلاس، مستقل از اندازه‌ی کل
//      کتاب، به یک عدد ثابت محدود می‌ماند.
//
// 🐞 رفع باگِ نسخه‌ی قبلی: این کلاس قبلاً منتظرِ یک «manifest.json» با
// فیلدهای PageCount/PageNumbers/ImageIndex/AudioIndex بود — ولی
// BookOutputWriter.cs (ابزارِ سی‌شارپ) هیچ‌وقت چنین فایلی ننوشته و
// نمی‌نویسد؛ خروجیِ واقعیِ آن همیشه «index.json» با این شکل بوده:
//   { SchemaVersion, BookVersion, Pages:[{N,File,Version}],
//     Interactives:[...], AudioScripts:[{AudioTrackName,Paragraphs}],
//     AudioLinksIndex:[{PageNumber,ParaIndex,FileName}] }
// یعنی این کلاس عملاً همیشه به فال‌بکِ «فرمتِ قدیمِ تک‌فایلی» می‌افتاد (و
// حتی آن فال‌بک هم چون Pagesِ index.json را «پاراگرافِ کاملِ هر صفحه»
// فرض می‌کرد نه «مسیرِ فایلِ هر صفحه»، برای خودِ همین فرمتِ رایج هم درست
// کار نمی‌کرد). حالا مستقیماً همان index.jsonِ واقعی را می‌خواند.
//
// 🐞 AudioLinksIndex تازه اضافه شده: قبلاً ساختنِ پلی‌لیستِ کتاب
// (buildBookAudioPlaylist در reading_canvas_screen.dart) مجبور بود محتوایِ
// *همه‌ی* صفحاتِ لودشده را زنده بگردد — دقیقاً همان چیزی که این کلاس
// می‌خواست جلویش را بگیرد. حالا این شاخص از قبل در index.json آماده است
// و buildBookAudioPlaylist می‌تواند از رویِ همین (بدونِ لودِ محتوای هیچ
// صفحه‌ای) پلی‌لیست بسازد.
//
// ساختار مورد انتظار روی دیسک (چه در پوشه‌ی دانلودشده‌ی محلی، چه در
// assets برای نسخه‌ی نمونه/باندل‌شده)، داخل یک پوشه به‌ازای هر کتاب:
//   <bookFolder>/index.json
//   <bookFolder>/pages/page_0001.json
//   <bookFolder>/pages/page_0002.json
//   ...
//
// هر pages/page_XXXX.json دقیقاً همان چیزی است که در C#، BookOutputWriter
// برای هر صفحه جدا نوشته — { "PageNumber": N, "Paragraphs": [...] } — هیچ
// تغییری در ساختار داخلیِ خودِ صفحه لازم نیست، چون PageData.fromJson از
// قبل پارامترهای sharedInteractives/sharedPattern/sharedByText را
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

  // 🐞 یک ایزوله‌ی دائمی به‌ازای هر PagedBookStore (یعنی هر کتابِ بازشده) —
  // نه به‌ازای هر صفحه. اولین getPage آن را بالا می‌آورد؛ بقیه‌ی صفحات
  // فقط پیام رد و بدل می‌کنند.
  final _DecodeWorker _decodeWorker = _DecodeWorker();

  // ── وضعیت منیفست (یک‌بار لود می‌شود، کوچک است، برای همیشه می‌ماند) ──────
  bool _manifestLoaded = false;
  Completer<void>? _manifestLoading;
  int _pageCount = 0;
  List<InteractiveWord> _sharedInteractives = const [];
  RegExp? _sharedPattern;
  Map<String, InteractiveWord> _sharedByText = const {};
  // 🐞 نوع عوض شد: سطحِ کتاب و گروه‌بندی‌شده‌بر‌اساسِ تراک (یک آیتم به‌ازای
  // هر فایلِ صوتی)، نه فهرستِ تخت پاراگراف‌های تک‌تک مثلِ قبل.
  List<AudioScriptTrack> _audioScripts = const [];
  // 🐞 شاخصِ جدید: کجای متن دکمه‌ی صوتی هست.
  List<AudioLinkEntry> _audioLinksIndex = const [];
  Map<int, int> _pageNumberToIndex = const {};
  // 🌟 عکسِ نگاشتِ بالا. لازم شد چون استخراج‌کننده‌ی سی‌شارپ حالا می‌تواند
  // شماره‌ی صفحه‌ها را از عددِ دلخواهِ کاربر شروع کند (مثلاً ۱۵)، پس دیگر
  // نمی‌شود شماره‌ی صفحه را از رویِ «ایندکس + ۱» حدس زد.
  List<int> _pageNumbers = const [];
  // 🐞 مسیرِ فایلِ هر صفحه، مستقیماً از index.json (فیلدِ File در هر
  // آیتمِ Pages) — دیگر نیازی به فرض‌کردنِ الگویِ نام‌گذاریِ ثابت نیست.
  List<String> _pageFiles = const [];
  // 🐞 index.json فعلاً فیلدِ ImageIndex ندارد (چیزی که این کلاس قبلاً
  // انتظارش را داشت)؛ تا وقتی به BookOutputWriter اضافه نشده، این همیشه
  // خالی می‌ماند — نه کرش، فقط یعنی پیش‌بارگذاریِ تصاویر فعلاً غیرفعال
  // است.
  List<String> _imageNames = const [];

  int get pageCount => _pageCount;
  List<AudioScriptTrack> get audioScripts => _audioScripts;
  List<AudioLinkEntry> get audioLinksIndex => _audioLinksIndex;
  List<String> get imageNames => _imageNames;
  bool get isManifestLoaded => _manifestLoaded;

  // 🌟 معادلِ widget.documentPages.indexWhere((p) => p.pageNumber == n) در
  // نسخه‌ی قبلی — اما بدون نیاز به لود بودنِ همه‌ی صفحات. برای اسکرول به
  // نتیجه‌ی جستجو (که فقط pageNumber را می‌داند، نه ایندکس لیست) استفاده
  // می‌شود. اگر پیدا نشود null برمی‌گرداند (دقیقاً معادلِ -1 قبلی).
  int? indexForPageNumber(int pageNumber) => _pageNumberToIndex[pageNumber];

  /// شماره‌ی صفحه‌ی واقعی (همان که در کتابِ چاپی نوشته شده) برای ایندکسِ
  /// لیست. اگر ایندکس معتبر نباشد null. فراخوان‌ها معمولاً به `index + 1`
  /// فالبک می‌کنند تا کتاب‌های قدیمی هم مثل قبل رفتار کنند.
  int? pageNumberForIndex(int index) =>
      (index >= 0 && index < _pageNumbers.length) ? _pageNumbers[index] : null;

  /// اولین و آخرین شماره‌ی صفحه — برای راهنمای دیالوگِ «رفتن به صفحه».
  int get firstPageNumber => _pageNumbers.isNotEmpty ? _pageNumbers.first : 1;
  int get lastPageNumber =>
      _pageNumbers.isNotEmpty ? _pageNumbers.last : _pageCount;

  // ── مسیر فعال پوشه‌ی این کتاب (دانلودشده یا asset) ───────────────────
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
      Map<String, dynamic>? json;
      try {
        raw = await _readAsset('index.json');
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            _looksLikePagePointerIndex(decoded)) {
          json = decoded;
        }
      } catch (_) {
        json = null;
      }

      if (json == null) {
        // 🐞 دوران گذار/فرمتِ ناشناخته: یا index.json پیدا نشد، یا شکلش با
        // ساختارِ موردِ انتظار (Pages به‌صورتِ مسیرِ فایل) نمی‌خواند —
        // مثلاً یک کتابِ خیلی قدیمی که کل محتوا را یک‌جا دارد. به‌جای
        // کرش، از همان DocumentLoader موجود (که هر سه فرمتِ شناخته‌شده را
        // می‌فهمد) برای بارگذاریِ کاملِ کتاب استفاده می‌کنیم — دقیقاً
        // همان رفتارِ قبلیِ برنامه (کل کتاب یک‌جا)، تا وقتی این کتاب با
        // یک دانلودِ بعدی به فرمتِ جدید مهاجرت کند.
        await _loadViaDocumentLoader();
        _manifestLoaded = true;
        completer.complete();
        return;
      }

      final rawPages = (json['Pages'] as List? ?? []);
      _pageCount = rawPages.length;

      final Map<int, int> pageNumberToIndex = {};
      final List<String> pageFiles = List<String>.filled(rawPages.length, '');
      final List<int> pageNumbers = List<int>.filled(rawPages.length, 0);
      for (int i = 0; i < rawPages.length; i++) {
        final entry = rawPages[i] as Map<String, dynamic>;
        final int n = (entry['N'] as num?)?.toInt() ?? (i + 1);
        final String file = (entry['File'] ?? entry['file'] ?? '') as String;
        pageNumberToIndex[n] = i;
        pageFiles[i] = file;
        pageNumbers[i] = n;
      }
      _pageNumberToIndex = pageNumberToIndex;
      _pageFiles = pageFiles;
      _pageNumbers = pageNumbers;

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

      // 🐞 اسکریپتِ صوتی: index.json فقط یک اشاره‌گر (مثلِ Pages) به هر
      // تراک می‌دهد — چون پاراگراف‌هایش هم مثلِ صفحاتِ سندِ اصلی در یک
      // فایلِ page-likeِ جدا (پوشه‌ی audio_scripts/) نوشته می‌شوند (تا
      // پایپلاینِ ترجمه آن‌ها را هم پردازش کند). هر اشاره‌گر را resolve
      // می‌کنیم.
      final rawAudioScripts = (json['AudioScripts'] as List? ?? []);
      final audioPointers = rawAudioScripts
          .map(
            (e) => AudioScriptTrackPointer.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      final List<AudioScriptTrack> resolvedTracks = [];
      for (final p in audioPointers) {
        if (p.file.isEmpty) continue;
        try {
          final raw = await _readAsset(p.file);
          final pageJson = jsonDecode(raw) as Map<String, dynamic>;
          final rawParagraphs = pageJson['Paragraphs'] as List? ?? [];
          resolvedTracks.add(
            AudioScriptTrack(
              audioTrackName: p.audioTrackName,
              paragraphs: rawParagraphs
                  .map((e) => ParagraphData.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          );
        } catch (_) {
          // یک فایلِ گم‌شده/خراب نباید بقیه‌ی تراک‌ها را متوقف کند
        }
      }
      _audioScripts = resolvedTracks;

      // 🐞 شاخصِ لینک‌های صوتی: هم از قبل در index.json آماده است.
      final rawAudioLinks = (json['AudioLinksIndex'] as List? ?? []);
      _audioLinksIndex = rawAudioLinks
          .map((e) => AudioLinkEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      _imageNames = const [];

      _manifestLoaded = true;
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      _manifestLoading = null;
      rethrow;
    }
  }

  // 🌟 تشخیصِ این‌که آیا Pagesِ این JSON واقعاً «مسیرِ فایلِ هر صفحه» است
  // (فرمتِ فعلیِ index.json) یا چیزِ دیگری — همان قاعده‌ای که
  // DocumentLoader._looksLikeIndex هم برای همین تشخیص استفاده می‌کند.
  bool _looksLikePagePointerIndex(Map<String, dynamic> d) {
    final pages = d['Pages'] as List?;
    if (pages == null || pages.isEmpty) return false;
    final first = pages.first;
    return first is Map &&
        (first.containsKey('File') || first.containsKey('file'));
  }

  // ── فال‌بکِ دوران گذار: هر فرمتِ دیگری، با همان DocumentLoardِ موجود ──
  // 🌟 چون این مسیر کل کتاب را یک‌جا لود می‌کند (نه تنبل)، همه‌ی صفحات
  // مستقیم در _cache قرار می‌گیرند (بدون _evictIfNeeded) تا getPage بعدی
  // صرفاً یک cache hit باشد؛ به‌محض اینکه این کتاب با یک دانلود بعدی به
  // فرمتِ جدید مهاجرت کند (و نمونه‌ی PagedBookStore دوباره ساخته شود)،
  // رفتار تنبل/کم‌حافظه‌ی معمول خودش را پیدا می‌کند.
  Future<void> _loadViaDocumentLoader() async {
    final String path = _isLocal ? book.activeJsonPath : book.jsonAssetPath;

    final pages = await DocumentLoader.loadBookFromJson(path);
    _pageCount = pages.length;
    final Map<int, int> pageNumberToIndex = {};
    final List<int> pageNumbers = List<int>.filled(pages.length, 0);
    _cache.clear();
    for (int i = 0; i < pages.length; i++) {
      _cache[i] = pages[i];
      pageNumberToIndex[pages[i].pageNumber] = i;
      pageNumbers[i] = pages[i].pageNumber;
    }
    _pageNumberToIndex = pageNumberToIndex;
    _pageNumbers = pageNumbers;
    _pageFiles = const []; // این مسیر صفحات را مستقیم لود کرده، دیگر لازم نیست

    try {
      _audioScripts = await DocumentLoader.loadAudioScripts(path);
    } catch (_) {
      _audioScripts = const [];
    }

    try {
      _audioLinksIndex = await DocumentLoader.loadAudioLinksIndex(path);
    } catch (_) {
      _audioLinksIndex = const [];
    }
    // 🐞 اگر این فرمتِ قدیمی اصلاً AudioLinksIndex نداشته باشد (کتابی که
    // هنوز با ابزارِ جدیدِ C# استخراج نشده)، به‌جای پلی‌لیستِ خالی، از
    // رویِ همین صفحاتی که همین الان یک‌جا لود کرده‌ایم می‌سازیمش —
    // دقیقاً همان اسکنِ زنده‌ای که reading_canvas_screen.dart قبلاً
    // همیشه انجام می‌داد، فقط این‌جا هم به‌عنوانِ فال‌بک.
    if (_audioLinksIndex.isEmpty) {
      final List<AudioLinkEntry> derived = [];
      void scanSpans(List<SpanData> spans, int pageNumber, int topParaIndex) {
        for (final s in spans) {
          if (s.url != null && s.url!.startsWith('audio:')) {
            final fileName = s.url!.replaceFirst('audio:', '');
            if (fileName.isNotEmpty) {
              derived.add(
                AudioLinkEntry(
                  pageNumber: pageNumber,
                  paraIndex: topParaIndex,
                  fileName: fileName,
                ),
              );
            }
          }
          // 🐞 "layout" هم پیمایش شود (همان دلیلِ بالا).
          if (s.type == 'table' || s.type == 'layout') {
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
        for (int i = 0; i < page.paragraphs.length; i++) {
          scanSpans(page.paragraphs[i].spans, page.pageNumber, i);
        }
      }
      _audioLinksIndex = derived;
    }

    _imageNames = const [];

    // 🐞 دیکشنریِ کلماتِ تعاملی در این مسیر از قبل داخلِ هر PageData تزریق
    // شده (DocumentLoader خودش این کار را می‌کند)، پس _sharedInteractives/
    // _sharedPattern/_sharedByText این‌جا لازم نیستند — فقط برای مسیرِ
    // تنبل (index.json واقعی) استفاده می‌شوند.
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
    await ensureManifestLoaded();

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

    // 🐞 اگر این کتاب از مسیرِ فال‌بک (_loadViaDocumentLoader) لود شده،
    // همه‌ی صفحات از قبل در _cache هستند و getPage هیچ‌وقت تا این‌جا
    // نمی‌رسد؛ این چک فقط برای ایمنی است.
    if (pageIndex < 0 ||
        pageIndex >= _pageFiles.length ||
        _pageFiles[pageIndex].isEmpty) {
      throw Exception(
        'صفحه‌ای با این ایندکس در index.json پیدا نشد: $pageIndex',
      );
    }

    // 🐞 خواندن + jsonDecode روی همان ایزوله‌ی دائمیِ این کتاب انجام می‌شود
    // (نه یک ایزوله‌ی تازه به‌ازای این صفحه). ترِد UI در حینِ decode آزاد
    // می‌ماند، ولی بدونِ هزینه‌ی اسپاونِ تکراری. فقط PageData.fromJson روی
    // ترِد اصلی می‌ماند، چون به آبجکت‌های مشترکِ همین ایزوله
    // (sharedInteractives/Pattern/ByText) نیاز دارد — سبک‌تر از خودِ پارس.
    final Map<String, dynamic> json = _isLocal
        ? await _decodeWorker.decode(
            path: '$_bookFolderPath/${_pageFiles[pageIndex]}',
          )
        : await _decodeWorker.decode(
            raw: await _readAsset(_pageFiles[pageIndex]),
          );
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
  // 🐞 روانیِ اسکرول: نسخه‌ی قبلی از start تا end پشتِ‌سرِهم و بدونِ وقفه
  // getPage می‌کرد — یعنی تا ۹ صفحه در یک رگبار، و چون هر صفحه هم
  // PageData.fromJsonِ ترِد اصلی دارد، همان لحظه‌ی اسکرول چند فریم می‌پرید.
  // سه تغییر: (۱) ترتیبِ نزدیک‌ترین‌اول (صفحه‌ای که کاربر واقعاً دارد به آن
  // می‌رسد اول آماده می‌شود)، (۲) بعد از هر صفحه‌ی *واقعاً لودشده* یک نوبت به
  // حلقه‌ی رویداد برمی‌گردیم تا کارها بینِ فریم‌ها پخش شود نه در یک فریم،
  // (۳) شماره‌ی نسل: با هر اسکرولِ جدید prewarmِ قبلی خودش را کنار می‌کشد تا
  // چند prewarm هم‌زمان روی هم تلنبار نشوند.
  int _prewarmGeneration = 0;

  Future<void> prewarmAround(int centerIndex, {int radius = 4}) async {
    final gen = ++_prewarmGeneration;
    final start = (centerIndex - radius).clamp(0, _pageCount - 1);
    final end = (centerIndex + radius).clamp(0, _pageCount - 1);

    final List<int> order = [];
    for (int d = 0; d <= radius; d++) {
      final ahead = centerIndex + d;
      if (ahead >= start && ahead <= end) order.add(ahead);
      if (d != 0) {
        final behind = centerIndex - d;
        if (behind >= start && behind <= end) order.add(behind);
      }
    }

    for (final i in order) {
      if (gen != _prewarmGeneration) return; // یک prewarmِ تازه‌تر آمده
      final bool wasCached = _cache.containsKey(i);
      try {
        await getPage(i);
      } catch (_) {
        // یک صفحه‌ی خراب/گم‌شده نباید بقیه‌ی پیش‌بارگذاریِ پنجره را متوقف کند
      }
      // فقط وقتی واقعاً کاری انجام شد نفس بکش؛ برای صفحه‌ی از قبل در کش
      // هیچ هزینه‌ای نداشتیم پس وقفه هم لازم نیست.
      if (!wasCached) await Future<void>.delayed(Duration.zero);
    }
  }

  void clearCache() {
    _cache.clear();
  }

  // 🐞 باید وقتی این PagedBookStore دیگر لازم نیست (مثلاً کاربر کتاب را
  // بست/عوض کرد) صدا زده شود تا ایزوله‌ی دائمی‌اش کشته شود؛ وگرنه هر کتابی
  // که باز شده، یک ایزوله‌ی زنده برای همیشه پشتِ سر می‌گذارد.
  void dispose() {
    _decodeWorker.dispose();
  }
}
