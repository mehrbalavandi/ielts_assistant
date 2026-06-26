// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

// class DocumentLoader {
//   static Future<List<PageData>> loadBookFromJson(String path) async {
//     String jsonString = '';

//     // 🌟 بررسی هوشمند: فایل در حافظه گوشی است یا دارایی برنامه (assets)؟
//     if (path.startsWith('assets/')) {
//       jsonString = await rootBundle.loadString(path);
//     } else {
//       final file = File(path);
//       if (await file.exists()) {
//         jsonString = await file.readAsString();
//       } else {
//         throw Exception("فایل در حافظه گوشی یافت نشد: $path");
//       }
//     }

//     List<dynamic> jsonList = jsonDecode(jsonString);
//     List<PageData> allPages = [];

//     for (var pageJson in jsonList) {
//       allPages.add(PageData.fromJson(pageJson));
//     }
//     return allPages;
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

// 🌟 کلاس جدید برای نگه داشتن همزمان کتاب و اسکریپت‌ها
class BookContent {
  final List<PageData> pages;
  final List<ParagraphData> audioScripts;

  BookContent({required this.pages, required this.audioScripts});
}

class DocumentLoader {
  static Future<BookContent> loadBookFromJson(String path) async {
    String jsonString = '';

    if (path.startsWith('assets/')) {
      jsonString = await rootBundle.loadString(path);
    } else {
      final file = File(path);
      if (await file.exists()) {
        jsonString = await file.readAsString();
      } else {
        throw Exception("فایل در حافظه گوشی یافت نشد: $path");
      }
    }

    var decoded = jsonDecode(jsonString);

    // 🌟 بررسی هوشمند ساختار JSON
    if (decoded is Map<String, dynamic>) {
      // فرمت جدید (دارای فیلد pages و audioScripts)
      List<PageData> allPages =
          (decoded['Pages'] as List?)
              ?.map((e) => PageData.fromJson(e))
              .toList() ??
          [];

      List<ParagraphData> scripts =
          (decoded['AudioScripts'] as List?)
              ?.map((e) => ParagraphData.fromJson(e))
              .toList() ??
          [];

      return BookContent(pages: allPages, audioScripts: scripts);
    } else if (decoded is List) {
      // پشتیبانی از فرمت قدیمی (آرایه مستقیم از صفحات)
      List<PageData> allPages = decoded
          .map((e) => PageData.fromJson(e))
          .toList();
      return BookContent(pages: allPages, audioScripts: []);
    }

    throw Exception("فرمت JSON نامعتبر است.");
  }
}
