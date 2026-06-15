import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final int paraIndex;
  final int occurrenceIndex; // 🌟 نگهداری شماره تکرار در یک پاراگراف
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

  static Future<List<SearchResult>> searchAllBooks(
    String query,
    List<BookModel> availableBooks,
  ) async {
    String safeQuery = query.trim().toLowerCase();
    if (safeQuery.length < 3) return [];

    List<Map<String, dynamic>> booksData = [];
    for (var book in availableBooks) {
      if (!_jsonCache.containsKey(book.id)) {
        try {
          _jsonCache[book.id] = await rootBundle.loadString(book.jsonAssetPath);
        } catch (e) {
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
    List<dynamic> jsonList = jsonDecode(bookData['jsonStr']);
    List<PageData> pages = jsonList.map((e) => PageData.fromJson(e)).toList();

    for (var page in pages) {
      for (int pIndex = 0; pIndex < page.paragraphs.length; pIndex++) {
        var para = page.paragraphs[pIndex];
        String rawText = _extractFullText(para);
        String normalizedText = _normalizeText(rawText);

        int occurrence = 0; // شمارنده تکرارها در این پاراگراف
        int matchIndex = normalizedText.indexOf(lowerQuery);

        // 🌟 حلقه while برای استخراج تمامیِ موارد یافت‌شده (حتی داخل یک جدول)
        while (matchIndex != -1) {
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
              paraIndex: pIndex,
              occurrenceIndex: occurrence, // ذخیره شماره این کلمه
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
