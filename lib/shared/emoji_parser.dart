import 'package:ielts_assistant/shared/models/content_models.dart';

// final Map<String, String> emojiMap = {
//   "💪": "isBold",
//   "⬜️": "isBlank",
//   "↪️": "isItalic",
//   "📏": "isUnderLine",
//   "🚫": "isLineThrough",
//   "✨": "isHighlight",
// };
final Map<String, String> markerMap = {
  "{b}": "isBold",
  "{/b}": "isBold",
  "{i}": "isItalic",
  "{/i}": "isItalic",
  "{u}": "isUnderLine",
  "{/u}": "isUnderLine",
  "{s}": "isLineThrough",
  "{/s}": "isLineThrough",
  "{h}": "isHighlight",
  "{/h}": "isHighlight",
  "{blk}": "isBlank",
  "{/blk}": "isBlank",
};
final List<Map<String, String>> markers = [
  {"start": "{b}", "end": "{/b}", "flag": "isBold"},
  {"start": "{i}", "end": "{/i}", "flag": "isItalic"},
  {"start": "{u}", "end": "{/u}", "flag": "isUnderLine"},
  {"start": "{s}", "end": "{/s}", "flag": "isLineThrough"},
  {"start": "{h}", "end": "{/h}", "flag": "isHighlight"},
  {"start": "{blk}", "end": "{/blk}", "flag": "isBlank"},
];

class PositionedItem {
  final TextSegmentEnglish item;
  final int start;
  final int end; // exclusive
  PositionedItem(this.item, this.start, this.end);
}

List<PositionedItem> buildPositionMap(List<TextSegmentEnglish> items) {
  List<PositionedItem> out = [];
  int cursor = 0;

  for (var it in items) {
    int len = it.text.length;
    out.add(PositionedItem(it, cursor, cursor + len));
    cursor += len;
  }

  return out;
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

List<RawBlock> splitRawText(String fullText) {
  final List<RawBlock> blocks = [];

  final markerPattern = RegExp(
    r'(\{b\}|\{i\}|\{u\}|\{s\}|\{h\}|\{blk\})([\s\S]*?)(\{\/b\}|\{\/i\}|\{\/u\}|\{\/s\}|\{\/h\}|\{\/blk\})',
  );

  int lastEnd = 0;

  final markerToFlag = {
    "{b}": "isBold",
    "{i}": "isItalic",
    "{u}": "isUnderLine",
    "{s}": "isLineThrough",
    "{h}": "isHighlight",
    "{blk}": "isBlank",
  };
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

  return blocks;
}

List<TextSegmentEnglish> buildStructuredItems(
  List<RawBlock> blocks,
  List<PositionedItem> positioned,
) {
  List<TextSegmentEnglish> output = [];

  for (var block in blocks) {
    List<TextSegmentEnglish> subItems = [];

    for (var p in positioned) {
      bool inside = (p.start >= block.start && p.end <= block.end);
      // (p.start >= block.start && p.start < block.end) ||
      // (p.end > block.start && p.end <= block.end) ||
      // (p.start <= block.start && p.end >= block.end);

      if (inside) {
        TextSegmentEnglish merged = p.item;
        // اگر بلاک دارای marker باشد → استایل بلاک اعمال شود
        if (block.flag != null) merged = applyFlag(merged, block.flag!);
        subItems.add(merged);
      }
    }
    var blockSegment = TextSegmentEnglish(
      text: block.text,
      isInteractive: false,
      // hasSubItems: subItems.isEmpty ? null : true,
      // subItems: subItems.isEmpty ? null : subItems,
      // استایل خود بلاک اگر marker دارد
      /*
      isBold: block.flag == 'isBold',
      isItalic: block.flag == 'isItalic',
      isUnderLine: block.flag == 'isUnderLine',
      isLineThrough: block.flag == 'isLineThrough',
      isHighlight: block.flag == 'isHighlight',
      isBlank: block.flag == 'isBlank',
      */
    );
    if (subItems.isNotEmpty) {
      blockSegment.hasSubItems = true;
      blockSegment.subItems = subItems;
    }
    if (block.flag == 'isBold') {
      blockSegment.isBold = true;
    }
    if (block.flag == 'isItalic') {
      blockSegment.isItalic = true;
    }
    if (block.flag == 'isUnderLine') {
      blockSegment.isUnderLine = true;
    }
    if (block.flag == 'isLineThrough') {
      blockSegment.isLineThrough = true;
    }
    if (block.flag == 'isHighlight') {
      blockSegment.isHighlight = true;
    }
    if (block.flag == 'isBlank') {
      blockSegment.isBlank = true;
    }
    output.add(blockSegment);
  }

  return output;
}

TextSegmentEnglish applyFlag(TextSegmentEnglish item, String flag) {
  var subSegment = TextSegmentEnglish(
    text: item.text,
    isInteractive: item.isInteractive,

    // isBold: flag == "isBold" ? true : item.isBold,
    // isItalic: flag == "isItalic" ? true : item.isItalic,
    // isUnderLine: flag == "isUnderLine" ? true : item.isUnderLine,
    // isLineThrough: flag == "isLineThrough" ? true : item.isLineThrough,
    // isHighlight: flag == "isHighlight" ? true : item.isHighlight,
    // isBlank: flag == "isBlank" ? true : item.isBlank,
    translation: item.translation,
    explanation: item.explanation,
    pronounce: item.pronounce,
    cerfLevel: item.cerfLevel, // translation, explanation, etc.
  );
  if (flag == 'isBold') {
    subSegment.isBold = true;
  } else if (item.isBold != null) {
    subSegment.isBold = item.isBold;
  }
  if (flag == 'isItalic') {
    subSegment.isItalic = true;
  } else if (item.isItalic != null) {
    subSegment.isItalic = item.isItalic;
  }
  if (flag == 'isUnderLine') {
    subSegment.isUnderLine = true;
  } else if (item.isUnderLine != null) {
    subSegment.isUnderLine = item.isUnderLine;
  }
  if (flag == 'isLineThrough') {
    subSegment.isLineThrough = true;
  } else if (item.isLineThrough != null) {
    subSegment.isLineThrough = item.isLineThrough;
  }
  if (flag == 'isHighlight') {
    subSegment.isHighlight = true;
  } else if (item.isHighlight != null) {
    subSegment.isHighlight = item.isHighlight;
  }
  if (flag == 'isBlank') {
    subSegment.isBlank = true;
  } else if (item.isBlank != null) {
    subSegment.isBlank = item.isBlank;
  }
  return subSegment;
}
