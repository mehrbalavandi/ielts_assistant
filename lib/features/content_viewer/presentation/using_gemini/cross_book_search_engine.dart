import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

// مدل نگهداری نتیجه جستجو
class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final ParagraphData paragraph;
  final String matchedExcerpt;

  SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.paragraph,
    required this.matchedExcerpt,
  });
}

// مدلی برای ارسال داده‌ها به ایزوله
class SearchRequest {
  final String query;
  final List<Map<String, dynamic>> booksData;
  SearchRequest(this.query, this.booksData);
}

class CrossBookSearchEngine {
  // 🌟 ۱. کش کردن فایل‌های JSON در مموری برای جلوگیری از I/O Bottleneck و سرعت نور در جستجو
  static final Map<String, String> _jsonCache = {};

  static Future<List<SearchResult>> searchAllBooks(
    String query,
    List<BookModel> availableBooks,
  ) async {
    // حذف فواصل اضافی و حروف کوچک
    String safeQuery = query.trim().toLowerCase();
    if (safeQuery.length < 3) return [];

    List<Map<String, dynamic>> booksData = [];

    for (var book in availableBooks) {
      // اگر فایل قبلاً خوانده نشده بود، بخوان و در کش ذخیره کن
      if (!_jsonCache.containsKey(book.id)) {
        try {
          _jsonCache[book.id] = await rootBundle.loadString(book.jsonAssetPath);
        } catch (e) {
          debugPrint("خطا در خواندن فایل کتاب ${book.title}: $e");
          continue; // اگر مسیر فایل اشتباه بود، از این کتاب عبور کن
        }
      }

      booksData.add({
        'id': book.id,
        'title': book.title,
        'jsonStr': _jsonCache[book.id],
      });
    }

    // ارسال به ایزوله برای پردازش سنگین
    return await compute(_searchInIsolate, SearchRequest(safeQuery, booksData));
  }
}

// ============================================================================
// توابع پردازش در پس‌زمینه (Isolate)
// ============================================================================

List<SearchResult> _searchInIsolate(SearchRequest request) {
  List<SearchResult> results = [];
  String lowerQuery = _normalizeText(request.query);

  for (var bookData in request.booksData) {
    String bookId = bookData['id'];
    String bookTitle = bookData['title'];

    // پارس کردن JSON
    List<dynamic> jsonList = jsonDecode(bookData['jsonStr']);
    List<PageData> pages = jsonList.map((e) => PageData.fromJson(e)).toList();

    for (var page in pages) {
      for (var para in page.paragraphs) {
        // 🌟 ۲. استخراج دقیق و عمیق تمام متون (حتی داخل جداول)
        String rawText = _extractFullText(para);
        String normalizedText = _normalizeText(rawText);

        if (normalizedText.contains(lowerQuery)) {
          // پیدا کردن جایگاه کلمه و استخراج ۳۰ کاراکتر قبل و بعد برای نمایش
          int matchIndex = normalizedText.indexOf(lowerQuery);
          int startIdx = (matchIndex - 30).clamp(0, rawText.length);
          int endIdx = (matchIndex + lowerQuery.length + 30).clamp(
            0,
            rawText.length,
          );

          String excerpt =
              "... ${rawText.substring(startIdx, endIdx).trim()} ...";

          results.add(
            SearchResult(
              bookId: bookId,
              bookTitle: bookTitle,
              pageNumber: page.pageNumber,
              paragraph: para,
              matchedExcerpt: excerpt,
            ),
          );
        }
      }
    }
  }
  return results;
}

// 🌟 ۳. تابع استخراج بازگشتی متن (برای پشتیبانی از متون داخل جدول)
String _extractFullText(ParagraphData para) {
  StringBuffer sb = StringBuffer();
  for (var span in para.spans) {
    if (span.type == "text" && span.content != null) {
      sb.write(span.content);
    }
    // اگر کلمه داخل جدول بود، باید پاراگراف‌های جدول را هم استخراج کنیم
    else if (span.type == "table" && span.tableRows != null) {
      for (var row in span.tableRows!) {
        for (var cell in row.cells) {
          for (var cellPara in cell.paragraphs) {
            sb.write(_extractFullText(cellPara));
            sb.write(" "); // فاصله بین متون جدول
          }
        }
      }
    }
  }
  return sb.toString();
}

// 🌟 ۴. تابع نرمال‌سازی حروف برای جلوگیری از خطای کیبوردهای مختلف
String _normalizeText(String text) {
  return text
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('\u200c', ' '); // تبدیل نیم‌فاصله به فاصله کامل
}
