import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class DocumentLoader {
  static Future<List<ParagraphData>> loadBookFromJson() async {
    // خواندن فایل متنی از Assets
    String jsonString = await rootBundle.loadString('assets/data/book.json');

    // تبدیل به لیست داینامیک
    List<dynamic> jsonList = jsonDecode(jsonString);

    List<ParagraphData> allParagraphs = [];

    // پیمایش صفحات و استخراج پاراگراف‌ها
    for (var pageJson in jsonList) {
      PageData page = PageData.fromJson(pageJson);
      allParagraphs.addAll(page.paragraphs);
    }

    return allParagraphs;
  }
}
