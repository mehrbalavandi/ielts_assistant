import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;
import 'package:flutter/services.dart'
    show rootBundle, BackgroundIsolateBinaryMessenger;
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/search_text_utils.dart';

class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final int paraIndex;
  final int occurrenceIndex;
  final ParagraphData paragraph;
  final String matchedExcerpt;
  final String query;

  SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.paraIndex,
    required this.occurrenceIndex,
    required this.paragraph,
    required this.matchedExcerpt,
    required this.query,
  });
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

class CrossBookSearchEngine {
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

  commandPort.listen((message) async {
    if (message is! _SearchRequest) return;
    try {
      final results = await _performSearch(
        message.query,
        message.books,
        pagesCache,
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

  String jsonStr;
  final file = File(book['activeJsonPath']!);
  if (await file.exists()) {
    jsonStr = await file.readAsString();
  } else {
    jsonStr = await rootBundle.loadString(book['jsonAssetPath']!);
  }

  var decoded = jsonDecode(jsonStr);
  List<PageData> pages = [];
  if (decoded is Map<String, dynamic>) {
    var pagesList = decoded['Pages'] ?? decoded['pages'];
    pages =
        (pagesList as List?)?.map((e) => PageData.fromJson(e)).toList() ?? [];
  } else if (decoded is List) {
    pages = decoded.map((e) => PageData.fromJson(e)).toList();
  }

  cache[id] = pages;
  return pages;
}

Future<List<SearchResult>> _performSearch(
  String query,
  List<Map<String, String>> books,
  Map<String, List<PageData>> cache,
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

        int occurrence = 0;
        int matchIndex = normalizedText.indexOf(lowerQuery);
        while (matchIndex != -1) {
          int cleanStartIdx = (matchIndex - 30).clamp(
            0,
            mapper.cleanText.length,
          );
          int cleanEndIdx = (matchIndex + lowerQuery.length + 30).clamp(
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
              occurrenceIndex: occurrence,
              paragraph: para,
              matchedExcerpt: excerpt,
              query: query,
            ),
          );

          occurrence++;
          matchIndex = normalizedText.indexOf(
            lowerQuery,
            matchIndex + lowerQuery.length,
          );
        }
      }
    }
  }
  return results;
}

String _extractFullText(ParagraphData para) => extractFullText(para);

String _normalizeText(String text) => normalizeText(text);
