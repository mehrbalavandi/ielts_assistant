import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class DocumentLoader {
  static Future<List<PageData>> loadBookFromJson(String path) async {
    String jsonString = '';

    // 🌟 بررسی هوشمند: فایل در حافظه گوشی است یا دارایی برنامه (assets)؟
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

    List<dynamic> jsonList = jsonDecode(jsonString);
    List<PageData> allPages = [];

    for (var pageJson in jsonList) {
      allPages.add(PageData.fromJson(pageJson));
    }
    return allPages;
  }
}
