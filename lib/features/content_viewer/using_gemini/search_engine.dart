import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';

class SearchEngine {
  /// این متد متن‌های یک پاراگراف را می‌خواند، عبارت جستجو شده را حتی اگر
  /// بین چند اسپن شکسته شده باشد پیدا می‌کند و با هایلایت زرد برمی‌گرداند.
  static List<InlineSpan> highlightSearchQuery(
    ParagraphData para,
    String query,
  ) {
    if (query.isEmpty) {
      // اگر جستجویی در کار نیست، همان متن معمولی را برگردان
      return _buildNormalSpans(para);
    }

    // گام ۱: ساخت متن یکپارچه (Flat Text)
    String fullText = "";
    for (var span in para.spans) {
      if (span.type == "text") {
        fullText += span.content;
      }
    }

    // تبدیل به حروف کوچک برای جستجوی Case-Insensitive
    String lowerFullText = fullText.toLowerCase();
    String lowerQuery = query.toLowerCase();

    // اگر کلمه اصلاً در این پاراگراف نیست، زودتر خارج شو
    if (!lowerFullText.contains(lowerQuery)) {
      return _buildNormalSpans(para);
    }

    // گام ۲: ساخت نقشه بیتی (Boolean Map)
    // یک لیست هم‌اندازه متن می‌سازیم که پیش‌فرض همه فالس هستند
    List<bool> isHighlighted = List.filled(fullText.length, false);

    int matchIndex = lowerFullText.indexOf(lowerQuery);
    while (matchIndex != -1) {
      // کاراکترهای مربوط به کلمه پیدا شده را در نقشه true می‌کنیم
      for (int i = 0; i < query.length; i++) {
        isHighlighted[matchIndex + i] = true;
      }
      // ادامه جستجو برای پیدا کردن تکرارهای بعدی همین کلمه در پاراگراف
      matchIndex = lowerFullText.indexOf(lowerQuery, matchIndex + query.length);
    }

    // گام ۳: بازسازی اسپن‌ها بر اساس نقشه
    List<InlineSpan> finalSpans = [];
    int globalOffset = 0; // نگهدارنده موقعیت ما در متن کل

    for (var span in para.spans) {
      if (span.type != "text") {
        // اگر عکس یا المان دیگری بود، همانطور که هست اضافه‌اش کن
        // finalSpans.add(WidgetSpan(...));
        continue;
      }

      String currentText = span.content;
      if (currentText.isEmpty) continue;

      // وضعیت فعلی: آیا در حال هایلایت کردن هستیم یا نه؟
      bool isCurrentlyHighlighting = isHighlighted[globalOffset];
      String chunk = "";

      for (int i = 0; i < currentText.length; i++) {
        bool charHighlight = isHighlighted[globalOffset + i];

        if (charHighlight == isCurrentlyHighlighting) {
          // تا زمانی که وضعیت تغییر نکرده، کاراکترها را به تکه (Chunk) فعلی اضافه کن
          chunk += currentText[i];
        } else {
          // وضعیت تغییر کرد! (مثلاً از کلمه عادی رسیدیم به شروع کلمه جستجو شده)
          // تکه‌ی قبلی را به لیست نهایی اضافه می‌کنیم
          finalSpans.add(
            _createTextSpan(chunk, isCurrentlyHighlighting, span.markers),
          );

          // ریست کردن برای تکه جدید
          chunk = currentText[i];
          isCurrentlyHighlighting = charHighlight;
        }
      }

      // اضافه کردن تکه‌ی باقی‌مانده در انتهای اسپن فعلی
      if (chunk.isNotEmpty) {
        finalSpans.add(
          _createTextSpan(chunk, isCurrentlyHighlighting, span.markers),
        );
      }

      // حرکت به جلو در نقشه بیتی
      globalOffset += currentText.length;
    }

    return finalSpans;
  }

  // متد کمکی برای ساخت TextSpan با استایل‌های اصلی (مثل بولد بودن) + رنگ جستجو
  static TextSpan _createTextSpan(
    String text,
    bool isHighlighted,
    List<String> markers,
  ) {
    return TextSpan(
      text: text,
      style: TextStyle(
        backgroundColor: isHighlighted
            ? Colors.yellow.shade300
            : Colors.transparent,
        color: isHighlighted
            ? Colors.black
            : null, // برای خوانایی بهتر روی پس‌زمینه زرد
        fontWeight: markers.contains("b") ? FontWeight.bold : FontWeight.normal,
        fontStyle: markers.contains("i") ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }

  // متد کمکی برای رندر عادی پاراگراف (وقتی جستجویی در کار نیست)
  static List<InlineSpan> _buildNormalSpans(ParagraphData para) {
    return para.spans.map((span) {
      if (span.type == "text") {
        return _createTextSpan(span.content, false, span.markers);
      }
      return const TextSpan(text: ""); // برای المان‌های غیرمتنی
    }).toList();
  }
}
