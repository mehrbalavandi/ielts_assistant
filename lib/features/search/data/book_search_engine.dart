import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;
import 'package:flutter/services.dart'
    show rootBundle, BackgroundIsolateBinaryMessenger;
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/core/text/document_text_utils.dart';
import 'package:ielts_assistant/features/reader/data/document_loader.dart';

// 🐞 وقتی چند نتیجه‌ی جستجو از یک تراکِ صوتیِ واحد می‌آیند (مثلاً کلمه‌ای
// دوبار در همان اسکریپت آمده)، باید همه‌شان با هم هایلایت شوند — نه فقط
// همانی که رویش تپ/پرش کرده‌ایم. این تابع، از رویِ کلِ نتایجِ یک
// SearchSession، تمام StartMsهای مربوط به یک تراکِ مشخص را جمع می‌کند.
Set<int> matchedStartMsForTrack(List<dynamic> results, String audioTrackName) {
  final Set<int> out = {};
  for (final r in results) {
    if (r is SearchResult &&
        r.audioTrackName == audioTrackName &&
        r.matchedStartMs != null) {
      out.add(r.matchedStartMs!);
    }
  }
  return out;
}

class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final int paraIndex;
  final int occurrenceIndex;
  final ParagraphData paragraph;
  final String matchedExcerpt;
  final String query;
  final int
  hiddenMatchCount; // 🌟 اگر >۱، یعنی چند occurrence داخلِ همین یک جای‌خالی گروه شده‌اند
  // 🐞 برای نتایجِ داخلِ اسکریپتِ صوتی: اگر غیرِخالی باشد، یعنی این نتیجه
  // از یک ترانسکریپتِ صوتی آمده، نه یک صفحه‌ی معمولی — به‌جای اسکرول به
  // صفحه، باید پلیرِ همین تراک باز و به matchedStartMs seek شود (دقیقاً
  // همان رفتاری که آیکونِ چشم برای متنِ مخفی دارد، ولی این‌بار هدف آیکونِ
  // پخش است).
  final String? audioTrackName;
  final int? matchedStartMs;
  // 🐞 اگر این نتیجه، نتیجه‌ی گروه‌بندی‌شده‌ی چند وقوع در همین تراک باشد
  // (کلمه‌ی جستجوشده بیش از یک‌بار در همین فایلِ صوتی آمده)، همه‌ی
  // StartMsهایشان این‌جا جمع می‌شوند — برای این‌که هایلایتِ نتیجه‌ی جستجو
  // در متنِ اسکریپت، همه‌شان را با هم نشان بدهد، نه فقط اولی را.
  final List<int>? audioMatchTimestamps;

  SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.paraIndex,
    required this.occurrenceIndex,
    required this.paragraph,
    required this.matchedExcerpt,
    required this.query,
    this.hiddenMatchCount = 1,
    this.audioTrackName,
    this.matchedStartMs,
    this.audioMatchTimestamps,
  });
}

// یک occurrence خام، قبل از گروه‌بندی: کدام occurrence-index سراسری است، در کجای
// متنِ تمیز افتاده، و داخلِ کدام بازه‌ی {blk} (اگر داخلِ هیچ‌کدام نبود: ‑۱)
class _RawOcc {
  final int occurrence;
  final int matchIndex;
  final int blkIndex;
  _RawOcc(this.occurrence, this.matchIndex, this.blkIndex);
}

// بازه‌های خامِ {blk}...{/blk} در متنِ خامِ پاراگراف (برای تشخیصِ اینکه یک
// occurrence داخلِ کدام جای‌خالی افتاده)
List<List<int>> _findBlkRanges(String rawText) {
  final ranges = <List<int>>[];
  int searchFrom = 0;
  while (true) {
    final openIdx = rawText.indexOf('{blk}', searchFrom);
    if (openIdx == -1) break;
    final closeIdx = rawText.indexOf('{/blk}', openIdx + 5);
    if (closeIdx == -1) break;
    ranges.add([openIdx, closeIdx]);
    searchFrom = closeIdx + 6;
  }
  return ranges;
}

int _blkIndexForRawPos(List<List<int>> blkRanges, int rawPos) {
  for (int i = 0; i < blkRanges.length; i++) {
    if (rawPos >= blkRanges[i][0] && rawPos < blkRanges[i][1]) return i;
  }
  return -1;
}

// ---------- پیام‌های رفت‌وبرگشت با ایزوله‌ی دائمی ----------

class _SearchRequest {
  final int requestId;
  final String query;
  final List<Map<String, String>> books;
  _SearchRequest(this.requestId, this.query, this.books);
}

class _SearchResponse {
  final int requestId;
  final List<SearchResult> results;
  final String? error;
  _SearchResponse(this.requestId, this.results, [this.error]);
}

class _IsolateInit {
  final SendPort mainSendPort;
  final RootIsolateToken rootToken;
  _IsolateInit(this.mainSendPort, this.rootToken);
}

// ---------- سرویس اصلی (روی ترد UI) ----------

class BookSearchEngine {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static final ReceivePort _receivePort = ReceivePort();
  static Completer<void>? _readyCompleter;
  static int _requestCounter = 0;
  static int _latestRequestId = 0;
  static final Map<int, Completer<List<SearchResult>>> _pending = {};

  static Future<void> _ensureIsolateReady() async {
    if (_sendPort != null) return;
    if (_readyCompleter != null) return _readyCompleter!.future;
    _readyCompleter = Completer<void>();

    // 🌟 توکن ایزوله‌ی اصلی — بدون این، rootBundle.loadString داخل
    // ایزوله‌ی جدید کار نمی‌کند (چون بارگذاری asset از کانال پلتفرم رد می‌شود)
    final rootToken = RootIsolateToken.instance!;

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateInit(_receivePort.sendPort, rootToken),
    );

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message; // هندشیک اولیه
        _readyCompleter?.complete();
      } else if (message is _SearchResponse) {
        final completer = _pending.remove(message.requestId);
        if (completer == null) return;
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete(message.results);
        }
      }
    });

    return _readyCompleter!.future;
  }

  static Future<List<SearchResult>> searchAllBooks(
    String query,
    List<BookModel> availableBooks,
  ) async {
    String safeQuery = query.trim();
    if (safeQuery.length < 3) return [];

    await _ensureIsolateReady();

    final requestId = ++_requestCounter;
    _latestRequestId =
        requestId; // 🌟 برای نادیده‌گرفتن پاسخ‌های قدیمی/دورریخته
    final completer = Completer<List<SearchResult>>();
    _pending[requestId] = completer;

    _sendPort!.send(
      _SearchRequest(
        requestId,
        safeQuery,
        availableBooks
            .map(
              (b) => {
                'id': b.id,
                'title': b.title,
                'activeJsonPath': b.activeJsonPath,
                'jsonAssetPath': b.jsonAssetPath,
              },
            )
            .toList(),
      ),
    );

    final result = await completer.future;
    if (requestId != _latestRequestId)
      return []; // جستجوی جدیدتری از این دیرتر شروع شده
    return result;
  }
}

// ---------- نقطه‌ی ورود ایزوله‌ی دائمی (اینجا کل کار سنگین انجام می‌شود) ----------

void _isolateEntryPoint(_IsolateInit init) {
  BackgroundIsolateBinaryMessenger.ensureInitialized(init.rootToken);

  final ReceivePort commandPort = ReceivePort();
  init.mainSendPort.send(commandPort.sendPort);

  // 🌟 این کش هرگز از این ایزوله خارج نمی‌شود؛ برخلاف compute() قبلی،
  // این ایزوله زنده می‌ماند، پس این Map هم بین جستجوهای پی‌درپی می‌ماند
  final Map<String, List<PageData>> pagesCache = {};
  // 🐞 برای جستجو در اسکریپت‌های صوتی: کشِ جداگانه، همان الگو.
  final Map<String, List<AudioScriptTrack>> audioScriptsCache = {};

  commandPort.listen((message) async {
    if (message is! _SearchRequest) return;
    try {
      final results = await _performSearch(
        message.query,
        message.books,
        pagesCache,
        audioScriptsCache,
      );
      init.mainSendPort.send(_SearchResponse(message.requestId, results));
    } catch (e) {
      init.mainSendPort.send(
        _SearchResponse(message.requestId, [], e.toString()),
      );
    }
  });
}

Future<List<PageData>> _loadAndParsePages(
  Map<String, String> book,
  Map<String, List<PageData>> cache,
) async {
  final id = book['id']!;
  final cached = cache[id];
  if (cached != null)
    return cached; // 🌟 از دومین بار به بعد برای همین کتاب، فقط همین خط اجرا می‌شود

  final indexPath = book['activeJsonPath']!;
  final assetPath = book['jsonAssetPath']!;

  final bool fromFile = await File(indexPath).exists();
  final String indexStr = fromFile
      ? await File(indexPath).readAsString()
      : await rootBundle.loadString(assetPath);

  final decoded = jsonDecode(indexStr);
  List<PageData> pages = [];

  if (decoded is List) {
    // ساختار قدیمِ آرایه‌ی صفحات
    pages = decoded.map((e) => PageData.fromJson(e)).toList();
  } else if (decoded is Map<String, dynamic>) {
    final pagesList = (decoded['Pages'] ?? decoded['pages']) as List? ?? [];

    // 🌟 آیا این یک index.json است؟ (هر آیتمِ Pages فقط مانیفست است: {n, file, version})
    final bool isIndex =
        pagesList.isNotEmpty &&
        pagesList.first is Map &&
        ((pagesList.first as Map).containsKey('file') ||
            (pagesList.first as Map).containsKey('File'));

    if (isIndex) {
      // فایلِ هر صفحه را جدا و نسبت به پوشه‌ی همان index بخوان — دقیقاً مثل DocumentLoader
      final String basePath = fromFile ? indexPath : assetPath;
      final String baseDir = basePath.contains('/')
          ? basePath.substring(0, basePath.lastIndexOf('/'))
          : '';
      for (final e in pagesList) {
        final String rel = (e['file'] ?? e['File']) as String;
        final String full = baseDir.isEmpty ? rel : '$baseDir/$rel';
        final String pageStr = fromFile
            ? await File(full).readAsString()
            : await rootBundle.loadString(full);
        pages.add(
          PageData.fromJson(jsonDecode(pageStr) as Map<String, dynamic>),
        );
      }
    } else {
      // ساختارِ تک‌فایلی: {Pages:[full pages], ...}
      pages = pagesList.map((e) => PageData.fromJson(e)).toList();
    }
  }

  cache[id] = pages;
  return pages;
}

// 🐞 برای جستجو در اسکریپت‌های صوتی: همان الگویِ کش/لودِ pagesِ بالا، ولی
// برای AudioScriptTrackها. مستقیم از DocumentLoader.loadAudioScripts
// استفاده می‌شود (همان منطقی که PagedBookStore هم برای resolve کردنِ
// اشاره‌گرهای AudioScripts در index.json به کار می‌برد) تا منطقِ resolve
// دوباره این‌جا تکرار نشود.
Future<List<AudioScriptTrack>> _loadAndParseAudioScripts(
  Map<String, String> book,
  Map<String, List<AudioScriptTrack>> cache,
) async {
  final id = book['id']!;
  final cached = cache[id];
  if (cached != null) return cached;

  final indexPath = book['activeJsonPath']!;
  final assetPath = book['jsonAssetPath']!;
  final bool fromFile = await File(indexPath).exists();
  final String path = fromFile ? indexPath : assetPath;

  List<AudioScriptTrack> tracks;
  try {
    tracks = await DocumentLoader.loadAudioScripts(path);
  } catch (_) {
    tracks = const [];
  }

  cache[id] = tracks;
  return tracks;
}

// 🐞 موقعیتِ خامِ یک تطبیق (rawPos، اندیسِ کاراکتر در متنِ کاملِ پاراگراف)
// را به اسپنی که آن کاراکتر داخلش افتاده resolve می‌کند — تا بشود
// StartMsِ همان اسپن (نه کلِ پاراگراف) را برای seekِ پلیر برداشت. فقط
// اسپن‌های متنیِ سطحِ‌بالا را می‌بیند (اسکریپتِ صوتی جدول ندارد، پس نیازی
// به بازگشتی‌بودن مثلِ extractFullText نیست).
SpanData? _spanAtRawPos(ParagraphData para, int rawPos) {
  int cursor = 0;
  for (final span in para.spans) {
    if (span.type != "text") continue;
    final len = span.content?.length ?? 0;
    if (rawPos >= cursor && rawPos < cursor + len) return span;
    cursor += len;
  }
  return null;
}

Future<List<SearchResult>> _performSearch(
  String query,
  List<Map<String, String>> books,
  Map<String, List<PageData>> cache,
  Map<String, List<AudioScriptTrack>> audioScriptsCache,
) async {
  String lowerQuery = _normalizeText(query);
  List<SearchResult> results = [];

  for (var book in books) {
    List<PageData> pages;
    try {
      pages = await _loadAndParsePages(book, cache);
    } catch (e) {
      continue; // یک کتابِ خراب بقیه را متوقف نکند
    }

    for (var page in pages) {
      for (int pIndex = 0; pIndex < page.paragraphs.length; pIndex++) {
        var para = page.paragraphs[pIndex];
        String rawText = _extractFullText(para);
        TextSearchMapper mapper = TextSearchMapper(rawText);
        String normalizedText = _normalizeText(mapper.cleanText);
        List<List<int>> blkRanges = _findBlkRanges(rawText);

        // 🌟 گام ۱: همه‌ی occurrenceهای این پاراگراف را جمع می‌کنیم، به‌همراهِ
        // اینکه هرکدام داخلِ کدام {blk} افتاده‌اند (اگر هیچ‌کدام: -۱)
        List<_RawOcc> occs = [];
        int occurrence = 0;
        int matchIndex = normalizedText.indexOf(lowerQuery);
        while (matchIndex != -1) {
          final rawPos = mapper.cleanToRaw[matchIndex];
          final blkIdx = _blkIndexForRawPos(blkRanges, rawPos);
          occs.add(_RawOcc(occurrence, matchIndex, blkIdx));
          occurrence++;
          matchIndex = normalizedText.indexOf(
            lowerQuery,
            matchIndex + lowerQuery.length,
          );
        }

        // 🌟 گام ۲: occurrenceهای متوالی که داخلِ همان یک {blk} هستند، فقط یک
        // SearchResult می‌سازند — پس next/prev روی آن‌ها یک‌بار توقف می‌کند،
        // نه یک‌بار به‌ازای هر occurrenceِ پنهان.
        int i = 0;
        while (i < occs.length) {
          final first = occs[i];
          int j = i + 1;
          if (first.blkIndex != -1) {
            while (j < occs.length && occs[j].blkIndex == first.blkIndex) {
              j++;
            }
          }
          final groupSize = j - i;

          int cleanStartIdx = (first.matchIndex - 30).clamp(
            0,
            mapper.cleanText.length,
          );
          int cleanEndIdx = (first.matchIndex + lowerQuery.length + 30).clamp(
            0,
            mapper.cleanText.length,
          );
          String excerpt =
              "... ${mapper.cleanText.substring(cleanStartIdx, cleanEndIdx).trim()} ...";

          results.add(
            SearchResult(
              bookId: book['id']!,
              bookTitle: book['title']!,
              pageNumber: page.pageNumber,
              paraIndex: pIndex,
              // 🌟 اولین occurrenceِ گروه کافی است: چون تمامِ occurrenceهای این
              // گروه داخلِ همان یک blank هستند، این اندیس در blankMap همان
              // blank هم حضور دارد و هایلایتِ فعال درست کار می‌کند.
              occurrenceIndex: first.occurrence,
              paragraph: para,
              matchedExcerpt: excerpt,
              query: query,
              hiddenMatchCount: groupSize,
            ),
          );
          i = j;
        }
      }
    }

    // 🐞 جستجو در اسکریپت‌های صوتیِ همین کتاب هم. برخلافِ نسخه‌ی قبلی (که
    // هر occurrence یک SearchResult جدا می‌ساخت و لیستِ نتایج را شلوغ
    // می‌کرد)، حالا همه‌ی occurrenceهای یک تراک را جمع می‌کنیم و فقط یک
    // SearchResult نماینده‌ی کلِ تراک می‌سازیم — با audioMatchTimestamps
    // شاملِ همه‌ی StartMsها و hiddenMatchCount به‌عنوانِ تعدادِ نمایشی
    // («۲ نتیجه»)، دقیقاً همان الگویی که برایِ گروه‌بندیِ متنِ مخفی از قبل
    // استفاده می‌شد.
    List<AudioScriptTrack> audioTracks;
    try {
      audioTracks = await _loadAndParseAudioScripts(book, audioScriptsCache);
    } catch (e) {
      audioTracks = const [];
    }

    for (var track in audioTracks) {
      final List<int> trackTimestamps = [];
      ParagraphData? firstMatchedPara;
      int firstMatchedParaIndex = -1;
      String firstExcerpt = '';

      for (int pIndex = 0; pIndex < track.paragraphs.length; pIndex++) {
        var para = track.paragraphs[pIndex];
        String rawText = _extractFullText(para);
        TextSearchMapper mapper = TextSearchMapper(rawText);
        String normalizedText = _normalizeText(mapper.cleanText);

        int matchIndex = normalizedText.indexOf(lowerQuery);
        while (matchIndex != -1) {
          final rawPos = mapper.cleanToRaw[matchIndex];
          final matchedSpan = _spanAtRawPos(para, rawPos);
          if (matchedSpan?.startMs != null) {
            trackTimestamps.add(matchedSpan!.startMs!);
          }

          if (firstMatchedPara == null) {
            firstMatchedPara = para;
            firstMatchedParaIndex = pIndex;
            int cleanStartIdx = (matchIndex - 30).clamp(
              0,
              mapper.cleanText.length,
            );
            int cleanEndIdx = (matchIndex + lowerQuery.length + 30).clamp(
              0,
              mapper.cleanText.length,
            );
            firstExcerpt =
                "... ${mapper.cleanText.substring(cleanStartIdx, cleanEndIdx).trim()} ...";
          }

          matchIndex = normalizedText.indexOf(
            lowerQuery,
            matchIndex + lowerQuery.length,
          );
        }
      }

      if (firstMatchedPara != null && trackTimestamps.isNotEmpty) {
        results.add(
          SearchResult(
            bookId: book['id']!,
            bookTitle: book['title']!,
            pageNumber:
                0, // برای نتایجِ صوتی معنایی ندارد؛ audioTrackName مرجع است
            paraIndex: firstMatchedParaIndex,
            occurrenceIndex: 0,
            paragraph: firstMatchedPara,
            matchedExcerpt: firstExcerpt,
            query: query,
            audioTrackName: track.audioTrackName,
            matchedStartMs: trackTimestamps.first,
            audioMatchTimestamps: trackTimestamps,
            hiddenMatchCount: trackTimestamps.length,
          ),
        );
      }
    }
  }
  return results;
}

String _extractFullText(ParagraphData para) => extractFullText(para);

String _normalizeText(String text) => normalizeText(text);
