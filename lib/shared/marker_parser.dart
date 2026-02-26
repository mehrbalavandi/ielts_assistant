import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class AdvancedMarkerParser {
  static TextStyle getStyleForMarker(String tag, TextStyle currentStyle) {
    switch (tag) {
      case 'b':
        return currentStyle.copyWith(fontWeight: FontWeight.bold);
      case 'i':
        return currentStyle.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        return currentStyle.copyWith(
          decoration: TextDecoration.combine([
            currentStyle.decoration ?? TextDecoration.none,
            TextDecoration.underline,
          ]),
        );
      case 's':
        return currentStyle.copyWith(
          decoration: TextDecoration.combine([
            currentStyle.decoration ?? TextDecoration.none,
            TextDecoration.lineThrough,
          ]),
        );
      case 'h':
        return currentStyle.copyWith(backgroundColor: Colors.yellowAccent);
      case 'clg':
        return currentStyle.copyWith(backgroundColor: Colors.greenAccent);
      case 'clr':
        return currentStyle.copyWith(backgroundColor: Colors.redAccent);
      case 'blk':
        return currentStyle.copyWith(
          color: Colors.blueGrey[900],
          backgroundColor: Colors.grey[300],
          fontFamily: 'Courier',
        );
      default:
        return currentStyle;
    }
  }

  static List<InlineSpan> parse(
    String text,
    TextStyle baseStyle,
    String searchQuery,
    TextSegmentEnglish originalSegment,
  ) {
    List<InlineSpan> spans = [];
    // رگکس اصلاح شده برای شناسایی تمام تگ‌های شما
    final regex = RegExp(
      r'\{(b|i|u|s|h|blk|clg|clr)\}(.*?)\{/\1\}',
      dotAll: true,
    );
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        // اعمال هایلایت جستجو روی متن ساده قبل از مارکر
        spans.addAll(
          _applySearchHighlight(
            text.substring(lastIndex, match.start),
            searchQuery,
            baseStyle,
          ),
        );
      }

      String tag = match.group(1)!;
      String content = match.group(2)!;
      TextStyle innerStyle = getStyleForMarker(tag, baseStyle);

      // فراخوانی بازگشتی برای هندل کردن استایل‌های تو در تو
      spans.add(
        TextSpan(
          children: parse(content, innerStyle, searchQuery, originalSegment),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.addAll(
        _applySearchHighlight(
          text.substring(lastIndex),
          searchQuery,
          baseStyle,
        ),
      );
    }

    return spans;
  }

  static List<InlineSpan> _applySearchHighlight(
    String text,
    String query,
    TextStyle currentStyle,
  ) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: text, style: currentStyle)];
    }

    List<InlineSpan> spans = [];
    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    int lastIndex = 0;

    for (var match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: currentStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: currentStyle.copyWith(
            backgroundColor: Colors.orange[300],
            color: Colors.black,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: currentStyle));
    }
    return spans;
  }
}
