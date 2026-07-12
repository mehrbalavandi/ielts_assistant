import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';

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

class SearchRequest {
  final String query;
  final List<Map<String, dynamic>> booksData;
  SearchRequest(this.query, this.booksData);
}

class CrossBookSearchEngine {
  static final Map<String, String> _jsonCache = {};
  // 🌟 به‌جای رشته‌ی خام JSON، حالا خودِ List<PageData> پارس‌شده کش می‌شود
  static final Map<String, List<PageData>> _pagesCache = {};

  static Future<List<PageData>> _getParsedPages(BookModel book) async {
    final cached = _pagesCache[book.id];
    if (cached != null)
      return cached; // 🌟 از دومین جستجو به بعد، فقط همین خط اجرا می‌شود

    String jsonStr;
    try {
      final file = File(book.activeJsonPath);
      jsonStr = await file.exists()
          ? await file.readAsString()
          : await rootBundle.loadString(book.jsonAssetPath);
    } catch (e) {
      debugPrint("خطا در لود دیتای جستجو برای کتاب ${book.id}: $e");
      return [];
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

    _pagesCache[book.id] = pages; // 🌟 فقط همین یک‌بار پارس و ذخیره می‌شود
    return pages;
  }

  static Future<List<SearchResult>> searchAllBooks(
    String query,
    List<BookModel> availableBooks,
  ) async {
    String safeQuery = query.trim();
    if (safeQuery.length < 3) return [];
    String lowerQuery = _normalizeText(safeQuery);

    List<SearchResult> results = [];
    for (var book in availableBooks) {
      final pages = await _getParsedPages(
        book,
      ); // 🌟 اولین بار: پارس. بعدها: از کش
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
                bookId: book.id,
                bookTitle: book.title,
                pageNumber: page.pageNumber,
                paraIndex: pIndex,
                occurrenceIndex: occurrence,
                paragraph: para,
                matchedExcerpt: excerpt,
                query: safeQuery,
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
    // 🌟 دیگر compute()/ایزوله لازم نیست: بخش سنگین (پارس‌کردن) فقط یک‌بار
    // انجام می‌شود و در کش می‌ماند؛ خودِ اسکن متن روی داده‌ی آماده، برای
    // دیتای سبک، آن‌قدر سریع است که نیازی به بردن آن به ترد جدا نیست.
    // اگر بعداً حجم کتاب‌ها خیلی بزرگ شد، همین حلقه را می‌شود داخل یک
    // ایزوله‌ی دائمی (persistent isolate، نه compute) نگه داشت.
  }

  static Future<List<SearchResult>> searchAllBooks0(
    String query,
    List<BookModel> availableBooks,
  ) async {
    String safeQuery = query.trim().toLowerCase();
    if (safeQuery.length < 3) return [];

    List<Map<String, dynamic>> booksData = [];
    for (var book in availableBooks) {
      if (!_jsonCache.containsKey(book.id)) {
        try {
          final file = File(book.activeJsonPath);
          if (await file.exists()) {
            _jsonCache[book.id] = await file.readAsString();
          } else {
            _jsonCache[book.id] = await rootBundle.loadString(
              book.jsonAssetPath,
            );
          }
        } catch (e) {
          debugPrint("خطا در لود دیتای جستجو برای کتاب ${book.id}: $e");
          continue;
        }
      }
      booksData.add({
        'id': book.id,
        'title': book.title,
        'jsonStr': _jsonCache[book.id],
      });
    }
    return await compute(_searchInIsolate, SearchRequest(safeQuery, booksData));
  }
}

List<SearchResult> _searchInIsolate(SearchRequest request) {
  List<SearchResult> results = [];
  String lowerQuery = _normalizeText(request.query);

  for (var bookData in request.booksData) {
    String bookId = bookData['id'];
    String bookTitle = bookData['title'];

    var decoded = jsonDecode(bookData['jsonStr']);
    List<PageData> pages = [];

    if (decoded is Map<String, dynamic>) {
      // 🌟 پشتیبانی همزمان از کلید با حروف بزرگ و کوچک برای جلوگیری از کرش موتور جستجو
      var pagesList = decoded['Pages'] ?? decoded['pages'];
      pages =
          (pagesList as List?)?.map((e) => PageData.fromJson(e)).toList() ?? [];
    } else if (decoded is List) {
      pages = decoded.map((e) => PageData.fromJson(e)).toList();
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
              bookId: bookId,
              bookTitle: bookTitle,
              pageNumber: page.pageNumber,
              paraIndex: pIndex,
              occurrenceIndex: occurrence,
              paragraph: para,
              matchedExcerpt: excerpt,
              query: request.query,
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

String _extractFullText(ParagraphData para) {
  StringBuffer sb = StringBuffer();
  for (var span in para.spans) {
    if (span.type == "text" && span.content != null)
      sb.write(span.content);
    else if (span.type == "table" && span.tableRows != null) {
      for (var row in span.tableRows!) {
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
