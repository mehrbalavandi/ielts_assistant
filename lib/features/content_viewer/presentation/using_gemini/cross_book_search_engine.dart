import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class SearchResult {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final int paraIndex; // 🌟 ایندکس دقیق پاراگراف اضافه شد
  final ParagraphData paragraph;
  final String matchedExcerpt;
  final String query;

  SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.paraIndex, // 🌟
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

        if (normalizedText.contains(lowerQuery)) {
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
              paraIndex: pIndex, // 🌟 ذخیره جایگاه دقیق
              paragraph: para,
              matchedExcerpt: excerpt,
              query: request.query,
            ),
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
            sb.write(" ");
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
