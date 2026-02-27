import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class MarkerParser {
  static TextStyle applyMarkerStyle(String tag, TextStyle currentStyle) {
    switch (tag) {
      case 'b':
        return currentStyle.copyWith(fontWeight: FontWeight.bold);
      case 'i':
        return currentStyle.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        return currentStyle.copyWith(decoration: TextDecoration.underline);
      case 's':
        return currentStyle.copyWith(decoration: TextDecoration.lineThrough);
      case 'blk':
        // return currentStyle.copyWith(
        //   color: Colors.transparent,
        //   backgroundColor: Colors.grey[300],
        // );
        return currentStyle;
      case 'hclr':
        return currentStyle.copyWith(backgroundColor: Colors.yellowAccent);
      default:
        return currentStyle;
    }
  }

  static List<InlineSpan> parseToSpans(
    String text,
    TextStyle incomingStyle,
    String searchQuery,
    TextSegmentEnglish originalSegment,
    GestureRecognizer? recognizer, // آرگومان جدید
  ) {
    final regex = RegExp(r'\{(b|i|u|s|blk|hclr)\}(.*?)\{/\1\}', dotAll: true);
    List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.addAll(
          _applySearchHighlight(
            text.substring(lastIndex, match.start),
            incomingStyle,
            searchQuery,
            recognizer, // پاس دادن به هایلایتر
          ),
        );
      }

      String tag = match.group(1)!;
      String content = match.group(2)!;
      TextStyle innerStyle = applyMarkerStyle(tag, incomingStyle);

      // بازگشت با حفظ Recognizer
      spans.add(
        TextSpan(
          children: parseToSpans(
            content,
            innerStyle,
            searchQuery,
            originalSegment,
            recognizer,
          ),
          recognizer: recognizer, // اعمال رکاگنایزر به بخش مارکر زده شده
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.addAll(
        _applySearchHighlight(
          text.substring(lastIndex),
          incomingStyle,
          searchQuery,
          recognizer, // پاس دادن به هایلایتر
        ),
      );
    }

    return spans;
  }

  static List<InlineSpan> _applySearchHighlight(
    String text,
    TextStyle style,
    String query,
    GestureRecognizer? recognizer,
  ) {
    // ۱. اگر جستجو خالی است یا کلمه در متن نیست، کل متن را با استایل و رکاگنایزر برگردان
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return [
        TextSpan(
          text: text,
          style: style,
          recognizer: recognizer, // حفظ قابلیت کلیک
        ),
      ];
    }

    List<InlineSpan> spans = [];
    // استفاده از RegExp برای یافتن تمام موارد مطابقت (Case-insensitive)
    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    int lastIndex = 0;

    for (var match in matches) {
      // ۲. اضافه کردن بخش قبل از کلمه پیدا شده
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: style,
            recognizer: recognizer, // حفظ قابلیت کلیک
          ),
        );
      }

      // ۳. اضافه کردن خود کلمه پیدا شده با استایل هایلایت
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: style.copyWith(
            backgroundColor: Colors.yellowAccent, // رنگ هایلایت جستجو
            color: Colors.black, // خوانایی بهتر روی پس‌زمینه زرد
          ),
          recognizer: recognizer, // حتی بخش هایلایت شده هم باید قابل کلیک باشد
        ),
      );

      lastIndex = match.end;
    }

    // ۴. اضافه کردن باقی‌مانده متن بعد از آخرین مطابقت
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: style,
          recognizer: recognizer, // حفظ قابلیت کلیک
        ),
      );
    }

    return spans;
  }
}
