import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

// final Map<String, String> emojiMap = {
//   "💪": "isBold",
//   "⬜️": "isBlank",
//   "↪️": "isItalic",
//   "📏": "isUnderline",
//   "🚫": "isLineThrough",
//   "✨": "isHighlight",
// };
final Map<String, String> markerMap = {
  "{b}": "isBold",
  "{/b}": "isBold",
  "{i}": "isItalic",
  "{/i}": "isItalic",
  "{u}": "isUnderline",
  "{/u}": "isUnderline",
  "{s}": "isLineThrough",
  "{/s}": "isLineThrough",
  "{h}": "isHighlight",
  "{/h}": "isHighlight",
  "{blk}": "isBlank",
  "{/blk}": "isBlank",
};

// final List<Map<String, String>> markers = [
//   {"start": "{b}", "end": "{/b}", "flag": "isBold"},
//   {"start": "{i}", "end": "{/i}", "flag": "isItalic"},
//   {"start": "{u}", "end": "{/u}", "flag": "isUnderline"},
//   {"start": "{s}", "end": "{/s}", "flag": "isLineThrough"},
//   {"start": "{h}", "end": "{/h}", "flag": "isHighlight"},
//   {"start": "{blk}", "end": "{/blk}", "flag": "isBlank"},
// ];
class Marker {
  final String kind;
  final String start;
  final String end;
  Marker(this.kind, this.start, this.end);
}

final markers = <Marker>[
  Marker("bold", "{b}", "{/b}"),
  Marker("italic", "{i}", "{/i}"),
  Marker("underline", "{u}", "{/u}"),
  Marker("strike", "{s}", "{/s}"),
  Marker("highlight", "{h}", "{/h}"),
  Marker("blank", "{blk}", "{/blk}"),
  Marker("highlightgreen", "{clg}", "{/clg}"),
  Marker("highlightred", "{clr}", "{/clr}"),
];

class MarkerHit {
  final Marker marker;
  final int index;
  MarkerHit(this.marker, this.index);
}

class PositionedItemEnglish {
  final TextSegmentEnglish item;
  final int start;
  final int end; // exclusive
  PositionedItemEnglish(this.item, this.start, this.end);
}

class PositionedItemPersian {
  final TextSegmentPersian item;
  final int start;
  final int end; // exclusive
  PositionedItemPersian(this.item, this.start, this.end);
}

class RawBlock {
  final int start;
  final int end;
  final String text;
  final String? flag;

  RawBlock({
    required this.start,
    required this.end,
    required this.text,
    this.flag,
  });
}

class MarkerParser {
  static List<PositionedItemEnglish> getPositionMapEnglish(
    List<TextSegmentEnglish> items,
  ) {
    List<PositionedItemEnglish> out = [];
    int cursor = 0;

    for (var it in items) {
      int len = it.text.length;
      out.add(PositionedItemEnglish(it, cursor, cursor + len));
      cursor += len;
    }

    return out;
  }

  static List<PositionedItemPersian> getPositionMapPersian(
    List<TextSegmentPersian> items,
  ) {
    List<PositionedItemPersian> out = [];
    int cursor = 0;

    for (var it in items) {
      int len = it.text.length;
      out.add(PositionedItemPersian(it, cursor, cursor + len));
      cursor += len;
    }

    return out;
  }

  static List<RawBlock> getRawBlocks(String fullText) {
    final List<RawBlock> blocks = [];

    final markerPattern = RegExp(
      r'(\{b\}|\{i\}|\{u\}|\{s\}|\{h\}|\{blk\})([\s\S]*?)(\{\/b\}|\{\/i\}|\{\/u\}|\{\/s\}|\{\/h\}|\{\/blk\})',
    );

    final markerToFlag = {
      "{b}": "isBold",
      "{i}": "isItalic",
      "{u}": "isUnderline",
      "{s}": "isLineThrough",
      "{h}": "isHighlight",
      "{blk}": "isBlank",
    };

    int lastEnd = 0;

    for (final match in markerPattern.allMatches(fullText)) {
      final startMarker = match.group(1)!;
      final innerText = match.group(2)!;
      final start = match.start;
      final end = match.end;
      final flag = markerToFlag[startMarker];

      // ۱) اگر قبل از بلوک marker متن عادی بود → به‌عنوان یک RawBlock مستقل
      if (start > lastEnd) {
        final normalText = fullText.substring(lastEnd, start);
        blocks.add(RawBlock(start: lastEnd, end: start, text: normalText));
      }

      // ۲) بلوک marker پیدا شده
      blocks.add(RawBlock(start: start, end: end, text: innerText, flag: flag));

      lastEnd = end;
    }

    // ۳) اگر بعد از آخرین بلوک marker متن باقی مانده بود
    if (lastEnd < fullText.length) {
      blocks.add(
        RawBlock(
          start: lastEnd,
          end: fullText.length,
          text: fullText.substring(lastEnd),
        ),
      );
    }
    // for (int i = 0; i < blocks.length; i++) {
    //   debugPrint('block (${i + 1}): ${blocks[i].text.split('\n').join(' # ')}');
    // }

    return blocks;
  }

  static List<TextSegmentEnglish> getStructuredItemsEnglish(
    List<RawBlock> blocks,
    List<PositionedItemEnglish> positioned,
  ) {
    List<TextSegmentEnglish> output = [];
    for (var block in blocks) {
      List<TextSegmentEnglish> children = [];
      for (var p in positioned) {
        bool isBold = p.item.isBold != null && p.item.isBold == true;
        if (p.start >= block.start && p.end <= block.end) {
          TextSegmentEnglish merged = p.item;
          merged = merged.copyWith(isBold: isBold);
          if (block.flag != null) {
            merged = applyFlagEnglish(merged, block.flag!);
          }
          children.add(merged);
        } else if (p.start < block.start &&
            (p.end > block.start && p.end <= block.end)) {
          TextSegmentEnglish merged = p.item;
          merged = merged.copyWith(
            text: p.item.text.substring(block.start - p.start),
            isBold: isBold,
          );
          if (block.flag != null) {
            merged = applyFlagEnglish(merged, block.flag!);
          }
          children.add(merged);
        } else if ((p.start >= block.start && p.start < block.end) &&
            p.end > block.end) {
          TextSegmentEnglish merged = p.item;
          merged = merged.copyWith(
            text: p.item.text.substring(
              0,
              p.item.text.length - (p.end - block.end),
            ),
            isBold: isBold,
          );
          if (block.flag != null) {
            merged = applyFlagEnglish(merged, block.flag!);
          }
          children.add(merged);
        }
      }
      var blockSegment = TextSegmentEnglish(
        text: block.text,
        isInteractive: false,
      );
      if (block.flag == 'isBold') {
        blockSegment = blockSegment.copyWith(isBold: true);
      }
      if (block.flag == 'isItalic') {
        blockSegment = blockSegment.copyWith(isItalic: true);
      }
      if (block.flag == 'isUnderline') {
        blockSegment = blockSegment.copyWith(isUnderline: true);
      }
      if (block.flag == 'isLineThrough') {
        blockSegment = blockSegment.copyWith(isLineThrough: true);
      }
      if (block.flag == 'highlightColor') {
        blockSegment = blockSegment.copyWith(highlightColor: 'highlightColor');
      }
      if (block.flag == 'isBlank') {
        blockSegment = blockSegment.copyWith(isBlank: true);
      }
      if (children.isNotEmpty) {
        blockSegment = blockSegment.copyWith(children: children);
      }
      output.add(blockSegment);
    }

    return output;
  }

  static List<TextSegmentPersian> getStructuredItemsPersian(
    List<RawBlock> blocks,
    List<PositionedItemPersian> positioned,
  ) {
    List<TextSegmentPersian> output = [];
    for (var block in blocks) {
      List<TextSegmentPersian> children = [];
      for (var p in positioned) {
        bool isBold = p.item.isBold != null && p.item.isBold == true;
        if (p.start >= block.start && p.end <= block.end) {
          TextSegmentPersian merged = p.item;
          merged = merged.copyWith(isBold: isBold);
          if (block.flag != null) {
            merged = applyFlagPersian(merged, block.flag!);
          }
          children.add(merged);
        } else if (p.start < block.start &&
            (p.end > block.start && p.end <= block.end)) {
          TextSegmentPersian merged = p.item;
          merged = merged.copyWith(
            text: p.item.text.substring(block.start - p.start),
            isBold: isBold,
          );
          if (block.flag != null) {
            merged = applyFlagPersian(merged, block.flag!);
          }
          children.add(merged);
        } else if ((p.start >= block.start && p.start < block.end) &&
            p.end > block.end) {
          TextSegmentPersian merged = p.item;
          merged = merged.copyWith(
            text: p.item.text.substring(
              0,
              p.item.text.length - (p.end - block.end),
            ),
            isBold: isBold,
          );
          if (block.flag != null) {
            merged = applyFlagPersian(merged, block.flag!);
          }
          children.add(merged);
        }
      }
      var blockSegment = TextSegmentPersian(text: block.text);
      if (block.flag == 'isBold') {
        blockSegment = blockSegment.copyWith(isBold: true);
      }
      if (block.flag == 'isItalic') {
        blockSegment = blockSegment.copyWith(isItalic: true);
      }
      if (block.flag == 'isUnderline') {
        blockSegment = blockSegment.copyWith(isUnderline: true);
      }
      if (block.flag == 'isLineThrough') {
        blockSegment = blockSegment.copyWith(isLineThrough: true);
      }
      if (block.flag == 'highlightColor') {
        blockSegment = blockSegment.copyWith(highlightColor: 'highlightColor');
      }
      if (block.flag == 'isBlank') {
        blockSegment = blockSegment.copyWith(isBlank: true);
      }
      if (children.isNotEmpty) {
        blockSegment = blockSegment.copyWith(children: children);
      }
      output.add(blockSegment);
    }

    return output;
  }

  static List<InlineSpan> parseWithGlobalSearch({
    required String textWithMarkers,
    required TextStyle textStyle,
    required List<SearchRange> globalMatches,
    required int globalOffset,
    GestureRecognizer? recognizer,
  }) {
    // ریجکس برای یافتن اولین لایه از مارکرها
    final regexMarkers = RegExp(
      r'\{(b|i|u|s|blk|hclr)\}(.*?)\{/\1\}',
      dotAll: true,
    );
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
          globalOffset + currentLocalPlainOffset,
          recognizer: recognizer,
        ),
      );
      currentLocalPlainOffset += plainText.length;
    }

    final matchesMarkers = regexMarkers.allMatches(textWithMarkers);

    for (final match in matchesMarkers) {
      // ۱. بخش قبل از شروع مارکر (متن ساده)
      if (match.start > lastIndex) {
        String leadingText = textWithMarkers.substring(lastIndex, match.start);
        addPlainChunksWithHighlight(leadingText, textStyle);
      }

      // ۲. پردازش محتوای داخل مارکر (ممکن است خودش شامل مارکر باشد)
      String tag = match.group(1)!;
      String innerContent = match.group(2)!;
      TextStyle innerStyle = applyMarkerStyle(tag, textStyle);

      // --- نکته کلیدی: فراخوانی بازگشتی (Recursion) ---
      // اگر داخل innerContent هنوز علامت { وجود دارد، دوباره پارس کن
      if (innerContent.contains('{')) {
        spans.addAll(
          parseWithGlobalSearch(
            textWithMarkers: innerContent,
            textStyle: innerStyle,
            globalMatches: globalMatches,
            globalOffset: globalOffset + currentLocalPlainOffset,
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
        textStyle,
      );
    }

    return spans;
  }

  static List<InlineSpan> _applyGlobalHighlight(
    String plainText,
    TextStyle style,
    List<SearchRange> globalMatches,
    int localStartInGlobal, {
    GestureRecognizer? recognizer,
  }) {
    if (globalMatches.isEmpty || plainText.isEmpty) {
      return [TextSpan(text: plainText, style: style, recognizer: recognizer)];
    }
    List<InlineSpan> spans = [];
    int localEndInGlobal = localStartInGlobal + plainText.length;
    // debugPrint('locals is: $localStartInGlobal,  $localEndInGlobal');
    // موقعیت فعلی ما در مقیاس متن کل (Global)
    int currentIndex = localStartInGlobal;

    for (var match in globalMatches) {
      // اگر این تطابق کلا قبل از سگمنت فعلی است، از آن عبور کن
      if (match.end <= localStartInGlobal) continue;

      // اگر این تطابق کلا بعد از سگمنت فعلی است، حلقه را بشکن (چون فرض بر این است که تطابق‌ها به ترتیب هستند)
      if (match.start >= localEndInGlobal) break;

      // محاسبه ابتدا و انتهای بخش هایلایت در داخل این سگمنت
      int highlightStart = max(currentIndex, match.start);
      int highlightEnd = min(localEndInGlobal, match.end);

      // ۱. استخراج متن معمولی (هایلایت نشده) قبل از کلمه پیدا شده
      if (highlightStart > currentIndex) {
        spans.add(
          TextSpan(
            text: plainText.substring(
              currentIndex - localStartInGlobal,
              highlightStart - localStartInGlobal,
            ),
            style: style,
            recognizer: recognizer,
          ),
        );
      }

      // ۲. استخراج بخش هایلایت شده
      if (highlightStart < highlightEnd) {
        spans.add(
          TextSpan(
            text: plainText.substring(
              highlightStart - localStartInGlobal,
              highlightEnd - localStartInGlobal,
            ),
            style: style.copyWith(
              backgroundColor: Colors.yellowAccent,
              // color: Colors.black, // برای خوانایی بهتر روی پس‌زمینه زرد
            ),
            recognizer: recognizer,
          ),
        );
        // آپدیت کردن نشانگر موقعیت به انتهای بخش هایلایت شده
        currentIndex = highlightEnd;
      }
    }

    // ۳. افزودن باقی‌مانده متن سگمنت (اگر بعد از آخرین هایلایت، متنی باقی مانده باشد)
    if (currentIndex < localEndInGlobal) {
      spans.add(
        TextSpan(
          text: plainText.substring(currentIndex - localStartInGlobal),
          style: style,
          recognizer: recognizer,
        ),
      );
    }

    return spans.isEmpty
        ? [TextSpan(text: plainText, style: style, recognizer: recognizer)]
        : spans;
  }

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

  static TextSegmentEnglish applyFlagEnglish(
    TextSegmentEnglish item,
    String flag,
  ) {
    var subSegment = TextSegmentEnglish(
      text: item.text,
      isInteractive: item.isInteractive,
      translation: item.translation,
      explanation: item.explanation,
      pronounce: item.pronounce,
      cerfLevel: item.cerfLevel, // translation, explanation, etc.
    );
    if (flag == 'isBold') {
      subSegment = subSegment.copyWith(isBold: true);
    } else if (item.isBold != null) {
      subSegment = subSegment.copyWith(isBold: item.isBold);
    }
    if (flag == 'isItalic') {
      subSegment = subSegment.copyWith(isItalic: true);
    } else if (item.isItalic != null) {
      subSegment = subSegment.copyWith(isItalic: item.isItalic);
    }
    if (flag == 'isUnderline') {
      subSegment = subSegment.copyWith(isUnderline: true);
    } else if (item.isUnderline != null) {
      subSegment = subSegment.copyWith(isUnderline: item.isUnderline);
    }
    if (flag == 'isLineThrough') {
      subSegment = subSegment.copyWith(isLineThrough: true);
    } else if (item.isLineThrough != null) {
      subSegment = subSegment.copyWith(isLineThrough: item.isLineThrough);
    }
    if (flag == 'highlightColor') {
      subSegment = subSegment.copyWith(highlightColor: 'highlightColor');
    } else if (item.highlightColor != null) {
      subSegment = subSegment.copyWith(highlightColor: item.highlightColor);
    }
    if (flag == 'isBlank') {
      subSegment = subSegment.copyWith(isBlank: true);
    } else if (item.isBlank != null) {
      subSegment = subSegment.copyWith(isBlank: item.isBlank);
    }
    return subSegment;
  }

  static TextSegmentPersian applyFlagPersian(
    TextSegmentPersian item,
    String flag,
  ) {
    var subSegment = TextSegmentPersian(
      text: item.text,
      translation: item.translation,
      explanation: item.explanation,
    );
    if (flag == 'isBold') {
      subSegment = subSegment.copyWith(isBold: true);
    } else if (item.isBold != null) {
      subSegment = subSegment.copyWith(isBold: item.isBold);
    }
    if (flag == 'isItalic') {
      subSegment = subSegment.copyWith(isItalic: true);
    } else if (item.isItalic != null) {
      subSegment = subSegment.copyWith(isItalic: item.isItalic);
    }
    if (flag == 'isUnderline') {
      subSegment = subSegment.copyWith(isUnderline: true);
    } else if (item.isUnderline != null) {
      subSegment = subSegment.copyWith(isUnderline: item.isUnderline);
    }
    if (flag == 'isLineThrough') {
      subSegment = subSegment.copyWith(isLineThrough: true);
    } else if (item.isLineThrough != null) {
      subSegment = subSegment.copyWith(isLineThrough: item.isLineThrough);
    }
    if (flag == 'highlightColor') {
      subSegment = subSegment.copyWith(highlightColor: 'highlightColor');
    } else if (item.highlightColor != null) {
      subSegment = subSegment.copyWith(highlightColor: item.highlightColor);
    }
    if (flag == 'isBlank') {
      subSegment = subSegment.copyWith(isBlank: true);
    } else if (item.isBlank != null) {
      subSegment = subSegment.copyWith(isBlank: item.isBlank);
    }
    return subSegment;
  }
}
