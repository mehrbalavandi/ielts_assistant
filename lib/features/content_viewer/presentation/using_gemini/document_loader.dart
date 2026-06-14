import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class DocumentLoader {
  // 🌟 اصلاح خروجی متد به List<PageData> جهت پشتیبانی از شماره صفحات جداگانه
  static Future<List<PageData>> loadBookFromJson() async {
    // خواندن فایل متنی از Assets
    String jsonString = await rootBundle.loadString('assets/data/book_3.json');

    // تبدیل به لیست داینامیک
    List<dynamic> jsonList = jsonDecode(jsonString);

    List<PageData> allPages = [];

    // پیمایش صفحات و مپ کردن مستقیم به مدل PageData
    for (var pageJson in jsonList) {
      PageData page = PageData.fromJson(pageJson);
      allPages.add(page);
    }

    return allPages;
  }
}
