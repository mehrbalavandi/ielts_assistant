import 'package:ielts_assistant/shared/models/content_models.dart';

final Map<String, String> emojiMap = {
  "💪": "isBold",
  "⬜️": "isBlank",
  "↪️": "isItalic",
  "📏": "isUnderLine",
  "🚫": "isLineThrough",
  "✨": "isHighlight",
};

class RawBlock {
  String text;
  String? flag; // null = normal text

  RawBlock(this.text, {this.flag});
}

List<RawBlock> splitRawText(String raw) {
  List<RawBlock> blocks = [];

  // marker با و بدون FE0F
  final marker = r'(💪|⬜️|⬜|↪️|↪|📏|🚫|✨)';
  // الگوی درست: marker + متن + همان marker
  // final pattern = RegExp('$marker(.+?)\\1', dotAll: true);

  final pattern = RegExp(r'\{(b|i|u|s|h|blk)\}(.+?)\{/\1\}', dotAll: true);
  int lastEnd = 0;

  for (final match in pattern.allMatches(raw)) {
    final start = match.start;
    final end = match.end;

    // متن عادی قبل از بلاک
    if (start > lastEnd) {
      blocks.add(RawBlock(raw.substring(lastEnd, start)));
    }

    final startMarker = match.group(1)!; // marker
    final inner = match.group(2)!; // متن داخل marker

    final flag = emojiMap[startMarker]; // این‌بار قطعاً درست مقدار دارد

    blocks.add(RawBlock(inner, flag: flag));

    lastEnd = end;
  }

  // باقی‌مانده متن بدون استایل
  if (lastEnd < raw.length) {
    blocks.add(RawBlock(raw.substring(lastEnd)));
  }

  return blocks;
}

/// تشخیص طول marker واقعی (برای حالات با FE0F یا بدون FE0F)
int startMarkerExtraLength(String fullMatch, String inner) {
  return fullMatch.length - inner.length - 1;
}

List<TextSegmentEnglish> buildStructuredItems(
  List<RawBlock> blocks,
  List<TextSegmentEnglish> originalItems,
) {
  List<TextSegmentEnglish> result = [];

  for (var block in blocks) {
    if (block.flag == null) {
      // normal text block
      result.add(TextSegmentEnglish(text: block.text, isInteractive: false));
    } else {
      // styled block
      List<TextSegmentEnglish> innerItems = [];

      for (var item in originalItems) {
        if (block.text.contains(item.text)) {
          innerItems.add(applyFlag(item, block.flag!));
        }
      }

      result.add(
        TextSegmentEnglish(
          text: block.text,
          isInteractive: false,
          subItems: innerItems.isNotEmpty ? innerItems : null,
          isBold: block.flag == "isBold",
          isBlank: block.flag == "isBlank",
          isItalic: block.flag == "isItalic",
          isUnderLine: block.flag == "isUnderLine",
          isLineThrough: block.flag == "isLineThrough",
          isHighlight: block.flag == "isHighlight",
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
    isBlank: flag == "isBlank" ? true : item.isBlank,
    isItalic: flag == "isItalic" ? true : item.isItalic,
    isUnderLine: flag == "isUnderLine" ? true : item.isUnderLine,
    isLineThrough: flag == "isLineThrough" ? true : item.isLineThrough,
    isHighlight: flag == "isHighlight" ? true : item.isHighlight,

    translation: item.translation,
    explanation: item.explanation,
    pronounce: item.pronounce,
    cerfLevel: item.cerfLevel,
  );
}
