import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class ParsingState {
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  bool isStrikethrough = false;
  bool isBlank = false;
  // شما می‌توانید رنگ‌های هایلایت را هم اینجا اضافه کنید
}

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

  static List<InlineSpan> parseWithGlobalSearch({
    required String textWithMarkers,
    required TextStyle baseStyle,
    required List<SearchRange> globalMatches,
    required int segmentOffset,
    GestureRecognizer? recognizer,
  }) {
    // ریجکس برای یافتن اولین لایه از مارکرها
    final regex = RegExp(r'\{(b|i|u|s|blk|hclr)\}(.*?)\{/\1\}', dotAll: true);
    List<InlineSpan> spans = [];
    int lastIndex = 0;
    int currentLocalPlainOffset = 0;

    // تابع کمکی برای مدیریت متن‌های ساده و اعمال هایلایت جستجو
    void addPlainChunksWithHighlight(String plainText, TextStyle style) {
      spans.addAll(
        _applyGlobalHighlight(
          plainText,
          style,
          globalMatches,
          segmentOffset + currentLocalPlainOffset,
          recognizer: recognizer,
        ),
      );
      currentLocalPlainOffset += plainText.length;
    }

    final matches = regex.allMatches(textWithMarkers);

    for (final match in matches) {
      // ۱. بخش قبل از شروع مارکر (متن ساده)
      if (match.start > lastIndex) {
        String leadingText = textWithMarkers.substring(lastIndex, match.start);
        addPlainChunksWithHighlight(leadingText, baseStyle);
      }

      // ۲. پردازش محتوای داخل مارکر (ممکن است خودش شامل مارکر باشد)
      String tag = match.group(1)!;
      String innerContent = match.group(2)!;
      TextStyle innerStyle = applyMarkerStyle(tag, baseStyle);

      // --- نکته کلیدی: فراخوانی بازگشتی (Recursion) ---
      // اگر داخل innerContent هنوز علامت { وجود دارد، دوباره پارس کن
      if (innerContent.contains('{')) {
        spans.addAll(
          parseWithGlobalSearch(
            textWithMarkers: innerContent,
            baseStyle: innerStyle,
            globalMatches: globalMatches,
            segmentOffset: segmentOffset + currentLocalPlainOffset,
            recognizer: recognizer,
          ),
        );
        // آپدیت کردن آفست بر اساس متن خالصِ محتوای داخلی
        currentLocalPlainOffset += innerContent
            .replaceAll(RegExp(r'\{.*?\}'), '')
            .length;
      } else {
        // اگر مارکر تو در تو نداشت، مستقیماً اضافه کن
        addPlainChunksWithHighlight(innerContent, innerStyle);
      }

      lastIndex = match.end;
    }

    // ۳. بخش باقی‌مانده بعد از آخرین مارکر
    if (lastIndex < textWithMarkers.length) {
      addPlainChunksWithHighlight(
        textWithMarkers.substring(lastIndex),
        baseStyle,
      );
    }

    return spans;
  }

  static List<InlineSpan> parseWithGlobalSearchPersian({
    required String textWithMarkers,
    required TextStyle baseStyle,
    required List<SearchRange> globalMatches,
    required int segmentOffset,
  }) {
    final regex = RegExp(r'\{(b|i|u|s|blk|hclr)\}(.*?)\{/\1\}', dotAll: true);
    List<InlineSpan> spans = [];
    int lastIndex = 0;
    int currentLocalPlainOffset = 0;

    // تابع داخلی برای اعمال هایلایت و نگاشت ایندکس
    void processChunk(String plainText, TextStyle style) {
      spans.addAll(
        _applyGlobalHighlight(
          plainText,
          style,
          globalMatches,
          segmentOffset + currentLocalPlainOffset,
        ),
      );
      currentLocalPlainOffset += plainText.length;
    }

    final matches = regex.allMatches(textWithMarkers);
    for (final match in matches) {
      if (match.start > lastIndex) {
        processChunk(
          textWithMarkers.substring(lastIndex, match.start),
          baseStyle,
        );
      }

      String tag = match.group(1)!;
      String content = match.group(2)!;
      TextStyle innerStyle = applyMarkerStyle(tag, baseStyle);

      processChunk(content, innerStyle);
      lastIndex = match.end;
    }

    if (lastIndex < textWithMarkers.length) {
      processChunk(textWithMarkers.substring(lastIndex), baseStyle);
    }

    return spans;
  }

  static List<InlineSpan> _applyGlobalHighlight(
    String text,
    TextStyle style,
    List<SearchRange> globalMatches,
    int localStartInGlobal, {
    GestureRecognizer? recognizer,
  }) {
    if (globalMatches.isEmpty) {
      return [TextSpan(text: text, style: style, recognizer: recognizer)];
    }

    List<InlineSpan> spans = [];
    int localEndInGlobal = localStartInGlobal + text.length;
    int lastProcessedIndex = 0;

    for (var match in globalMatches) {
      int highlightStart = max(localStartInGlobal, match.start);
      int highlightEnd = min(localEndInGlobal, match.end);

      if (highlightStart < highlightEnd) {
        // متن قبل از هایلایت
        if (highlightStart > localStartInGlobal + lastProcessedIndex) {
          spans.add(
            TextSpan(
              text: text.substring(
                lastProcessedIndex,
                highlightStart - localStartInGlobal,
              ),
              style: style,
              recognizer: recognizer,
            ),
          );
        }
        // بخش هایلایت شده
        spans.add(
          TextSpan(
            text: text.substring(
              highlightStart - localStartInGlobal,
              highlightEnd - localStartInGlobal,
            ),
            style: style.copyWith(
              backgroundColor: Colors.yellowAccent,
              color: Colors.black,
            ),
            recognizer: recognizer,
          ),
        );
        lastProcessedIndex = highlightEnd - localStartInGlobal;
      }
    }

    if (lastProcessedIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastProcessedIndex),
          style: style,
          recognizer: recognizer,
        ),
      );
    }
    return spans.isEmpty
        ? [TextSpan(text: text, style: style, recognizer: recognizer)]
        : spans;
  }

  //! جدید
  static List<InlineSpan> parseLinear({
    required String text,
    required TextStyle baseStyle,
    required ParsingState state, // وضعیت فعلی که از سگمنت قبلی آمده
    required List<SearchRange> globalMatches,
    required int segmentOffset,
    GestureRecognizer? recognizer,
  }) {
    List<InlineSpan> spans = [];
    // ریجکس برای یافتن هر نوع تگ باز یا بسته: {b} یا {/b}
    final tagRegex = RegExp(r'\{/?(b|i|u|s|blk|hclr)\}');
    int lastIndex = 0;
    int currentLocalOffset = 0;

    void addChunk(String plainText) {
      if (plainText.isEmpty) return;

      // اعمال استایل‌های فعال فعلی بر اساس وضعیت State
      TextStyle currentStyle = baseStyle.copyWith(
        fontWeight: state.isBold ? FontWeight.bold : null,
        fontStyle: state.isItalic ? FontStyle.italic : null,
        decoration: TextDecoration.combine([
          if (state.isUnderline) TextDecoration.underline,
          if (state.isStrikethrough) TextDecoration.lineThrough,
        ]),
        backgroundColor: state.isBlank ? Colors.grey[300] : null,
      );

      spans.addAll(
        _applyGlobalHighlight(
          plainText,
          currentStyle,
          globalMatches,
          segmentOffset + currentLocalOffset,
          recognizer: recognizer,
        ),
      );
      currentLocalOffset += plainText.length;
    }

    final matches = tagRegex.allMatches(text);

    for (final match in matches) {
      // ۱. متن قبل از تگ را با استایل فعلی اضافه کن
      addChunk(text.substring(lastIndex, match.start));

      // ۲. وضعیت استایل را بر اساس تگ پیدا شده تغییر بده
      String tag = match.group(0)!;
      if (tag == '{b}')
        state.isBold = true;
      else if (tag == '{/b}')
        state.isBold = false;
      else if (tag == '{i}')
        state.isItalic = true;
      else if (tag == '{/i}')
        state.isItalic = false;
      else if (tag == '{u}')
        state.isUnderline = true;
      else if (tag == '{/u}')
        state.isUnderline = false;
      else if (tag == '{blk}')
        state.isBlank = true;
      else if (tag == '{/blk}')
        state.isBlank = false;

      lastIndex = match.end;
    }

    // ۳. متن باقی‌مانده بعد از آخرین تگ
    addChunk(text.substring(lastIndex));

    return spans;
  }
}
