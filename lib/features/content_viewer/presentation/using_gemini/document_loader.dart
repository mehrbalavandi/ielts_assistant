import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class DocumentLoader {
  // 🌟 دریافت مسیر فایل به عنوان پارامتر ورودی
  static Future<List<PageData>> loadBookFromJson(String assetPath) async {
    String jsonString = await rootBundle.loadString(assetPath);
    List<dynamic> jsonList = jsonDecode(jsonString);
    List<PageData> allPages = [];

    for (var pageJson in jsonList) {
      allPages.add(PageData.fromJson(pageJson));
    }
    return allPages;
  }
}
