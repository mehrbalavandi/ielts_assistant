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

class RawBlock {
  final String text;
  final String? flag;
  RawBlock(this.text, {this.flag});
}

List<RawBlock> splitRawText(String raw) {
  List<RawBlock> blocks = [];

  // ساخت الگوی regex از همه marker ها
  final pattern = RegExp(
    r'(\{b\}|\{i\}|\{u\}|\{s\}|\{h\}|\{blk\})(.+?)(\{\/b\}|\{\/i\}|\{\/u\}|\{\/s\}|\{\/h\}|\{\/blk\})',
    dotAll: true,
  );

  int lastEnd = 0;

  for (final match in pattern.allMatches(raw)) {
    final start = match.start;
    final end = match.end;

    // بخش عادی قبل از بلاک
    if (start > lastEnd) {
      blocks.add(RawBlock(raw.substring(lastEnd, start)));
    }

    final startMarker = match.group(1)!; // {b}
    final innerText = match.group(2)!; // داخل بلاک
    final endMarker = match.group(3)!; // {/b}

    // پیدا کردن flag مربوطه
    final flag = markerMap[startMarker];

    blocks.add(RawBlock(innerText, flag: flag));

    lastEnd = end;
  }

  // بخش پایانی متن
  if (lastEnd < raw.length) {
    blocks.add(RawBlock(raw.substring(lastEnd)));
  }

  return blocks;
}

List<TextSegmentEnglish> buildStructuredItems(
  List<RawBlock> blocks,
  List<TextSegmentEnglish> originalItems,
) {
  List<TextSegmentEnglish> result = [];

  for (var block in blocks) {
    if (block.flag == null) {
      // متن عادی
      result.add(TextSegmentEnglish(text: block.text, isInteractive: false));
    } else {
      // بلاک دارای استایل
      List<TextSegmentEnglish> sub = [];

      for (var item in originalItems) {
        if (block.text.contains(item.text)) {
          sub.add(applyFlag(item, block.flag!));
        }
      }

      result.add(
        TextSegmentEnglish(
          text: block.text,
          isInteractive: false,
          subItems: sub.isNotEmpty ? sub : null,
          isBold: block.flag == "isBold",
          isItalic: block.flag == "isItalic",
          isUnderLine: block.flag == "isUnderLine",
          isLineThrough: block.flag == "isLineThrough",
          isHighlight: block.flag == "isHighlight",
          isBlank: block.flag == "isBlank",
        ),
      );
    }
  }

  return result;
}

TextSegmentEnglish applyFlag(TextSegmentEnglish item, String flag) {
  return TextSegmentEnglish(
    text: item.text,
    isInteractive: item.isInteractive,
    isBold: flag == "isBold" ? true : item.isBold,
    isItalic: flag == "isItalic" ? true : item.isItalic,
    isUnderLine: flag == "isUnderLine" ? true : item.isUnderLine,
    isLineThrough: flag == "isLineThrough" ? true : item.isLineThrough,
    isHighlight: flag == "isHighlight" ? true : item.isHighlight,
    isBlank: flag == "isBlank" ? true : item.isBlank,

    translation: item.translation,
    explanation: item.explanation,
    pronounce: item.pronounce,
    cerfLevel: item.cerfLevel,
  );
}
