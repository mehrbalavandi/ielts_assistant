import 'dart:convert';
import 'package:flutter/foundation.dart'; // برای تابع compute
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

// مدل نگهداری نتیجه جستجو
class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final String matchedExcerpt; // تیکه‌ای از متن برای نمایش در لیست نتایج

  SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
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
  static Future<List<SearchResult>> searchAllBooks(
    String query,
    List<BookModel> availableBooks,
  ) async {
    if (query.trim().length < 3)
      return []; // برای بهینه‌سازی، کلمات زیر 3 حرف را نمی‌گردیم

    // ۱. خواندن متن فایل‌ها در ترد اصلی
    List<Map<String, dynamic>> booksData = [];
    for (var book in availableBooks) {
      final jsonStr = await rootBundle.loadString(book.jsonAssetPath);
      booksData.add({'id': book.id, 'title': book.title, 'jsonStr': jsonStr});
    }

    // ۲. ارسال داده‌ها به ایزوله (پردازش در پس‌زمینه بدون فریز شدن صفحه)
    return await compute(_searchInIsolate, SearchRequest(query, booksData));
  }
}

// 🌟 این تابع کاملاً در یک Thread مجزا اجرا می‌شود
List<SearchResult> _searchInIsolate(SearchRequest request) {
  List<SearchResult> results = [];
  String lowerQuery = request.query.toLowerCase();

  for (var bookData in request.booksData) {
    String bookId = bookData['id'];
    String bookTitle = bookData['title'];

    // پارس کردن JSON در پس‌زمینه
    List<dynamic> jsonList = jsonDecode(bookData['jsonStr']);
    List<PageData> pages = jsonList.map((e) => PageData.fromJson(e)).toList();

    for (var page in pages) {
      for (var para in page.paragraphs) {
        // تجمیع اسپَن‌ها به یک متن خام و پیوسته
        String rawText = para.spans.map((s) => s.content).join('');

        if (rawText.toLowerCase().contains(lowerQuery)) {
          // پیدا کردن جایگاه کلمه و استخراج ۳۰ کاراکتر قبل و بعد برای نمایش
          int matchIndex = rawText.toLowerCase().indexOf(lowerQuery);
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
              matchedExcerpt: excerpt,
            ),
          );
        }
      }
    }
  }
  return results;
}
