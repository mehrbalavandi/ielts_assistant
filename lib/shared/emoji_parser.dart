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

class PositionedItem {
  final TextSegmentEnglish item;
  final int start;
  final int end; // exclusive
  PositionedItem(this.item, this.start, this.end);
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

MarkerHit? findNextStart(String raw, int from) {
  MarkerHit? best;

  for (var m in markers) {
    final idx = raw.indexOf(m.start, from);
    if (idx >= 0) {
      if (best == null || idx < best.index) {
        best = MarkerHit(m, idx);
      }
    }
  }

  return best;
}

String stripMarkers(String input) {
  return input.replaceAll(RegExp(r'\{\/?(b|i|u|s|h|blk|clg|clr)\}'), '');
}

int computeCleanPosition(String raw, int rawIndex) {
  int cleanPos = 0;
  int i = 0;

  while (i < rawIndex && i < raw.length) {
    final match = RegExp(
      r'^\{\/?(b|i|u|s|h|blk|clg|clr)\}',
    ).matchAsPrefix(raw.substring(i));
    if (match != null) {
      i += match.group(0)!.length;
    } else {
      i++;
      cleanPos++;
    }
  }

  return cleanPos;
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

List<RawBlock> splitRawTextEnglish(String fullText) {
  final List<RawBlock> blocks = [];

  final markerPattern = RegExp(
    r'(\{b\}|\{i\}|\{u\}|\{s\}|\{h\}|\{blk\})([\s\S]*?)(\{\/b\}|\{\/i\}|\{\/u\}|\{\/s\}|\{\/h\}|\{\/blk\})',
  );

  int lastEnd = 0;

  final markerToFlag = {
    "{b}": "isBold",
    "{i}": "isItalic",
    "{u}": "isUnderline",
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

List<TextSegmentEnglish> buildStructuredItemsEnglish(
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
        if (p.item.text.contains('cousin')) {
          String itemText = p.item.text;
        }
        // اگر بلاک دارای marker باشد → استایل بلاک اعمال شود
        if (block.flag != null) {
          merged = applyFlag(merged, block.flag!);
        }
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
      isUnderline: block.flag == 'isUnderline',
      isLineThrough: block.flag == 'isLineThrough',
      isHighlight: block.flag == 'isHighlight',
      isBlank: block.flag == 'isBlank',
      */
    );
    if (subItems.isNotEmpty) {
      blockSegment = blockSegment.copyWith(subItems: subItems);
    }
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
    if (block.flag == 'isHighlight') {
      blockSegment = blockSegment.copyWith(isHighlight: true);
    }
    if (block.flag == 'isBlank') {
      blockSegment = blockSegment.copyWith(isBlank: true);
    }
    output.add(blockSegment);
  }

  return output;
}

//
/*
List<TextSegmentEnglish> parseStyledText(
  String raw, {
  TextSegmentEnglish? parentStyle,
}) {
  List<TextSegmentEnglish> result = [];

  // inherited base
  final baseStyle =
      parentStyle ?? TextSegmentEnglish(text: "", isInteractive: false);

  int i = 0;

  while (i < raw.length) {
    final hit = findNextStart(raw, i);

    // no more tags → plain tail text
    if (hit == null) {
      result.add(baseStyle.copyWith(text: raw.substring(i), subItems: []));
      break;
    }

    // plain text before tag
    if (hit.index > i) {
      result.add(
        baseStyle.copyWith(text: raw.substring(i, hit.index), subItems: []),
      );
    }

    // find end tag
    final endIndex = raw.indexOf(
      hit.marker.end,
      hit.index + hit.marker.start.length,
    );
    if (endIndex < 0) break; // invalid tag

    final inner = raw.substring(hit.index + hit.marker.start.length, endIndex);

    // inherited + update style
    final updated = baseStyle.copyWith(
      isBold:
          (baseStyle.isBold != null && baseStyle.isBold == true) ||
          hit.marker.kind == "bold",
      isItalic:
          baseStyle.isItalic != null && baseStyle.isItalic == true ||
          hit.marker.kind == "italic",
      isUnderline:
          (baseStyle.isUnderline != null && baseStyle.isUnderline == true) ||
          hit.marker.kind == "underline",
      isLineThrough:
          (baseStyle.isLineThrough != null &&
              baseStyle.isLineThrough == true) ||
          hit.marker.kind == "strike",
      isHighlight:
          (baseStyle.isHighlight != null && baseStyle.isHighlight == true) ||
          hit.marker.kind == "highlight",
    );

    // recursive parse
    final children = parseStyledText(inner, parentStyle: updated);

    // add block node
    result.add(updated.copyWith(text: "", subItems: children));

    i = endIndex + hit.marker.end.length;
  }

  return result;
}

List<int> buildMapping(String raw) {
  List<int> map = [];
  int cleanPos = 0;

  int i = 0;
  while (i < raw.length) {
    final match = RegExp(
      r'^\{\/?(b|i|u|s|h|blk|clg|clr)\}',
    ).matchAsPrefix(raw.substring(i));
    if (match != null) {
      i += match.group(0)!.length;
      continue;
    }

    map.add(cleanPos);
    cleanPos++;
    i++;
  }

  return map; // map[rawIndex] = cleanIndex
}

List<TextSegmentEnglish> buildStructuredItemsEnglishNew(
  String raw,
  List<TextSegmentEnglish> interactiveItems,
) {
  final styled = parseStyledText(raw);

  final map = buildMapping(raw);

  bool isInsideInteractive(int cleanPos) {
    for (var item in interactiveItems) {
      final rawPos = raw.indexOf(item.text);
      if (rawPos < 0) continue;
      if (map[rawPos] == cleanPos) return true;
    }
    return false;
  }

  TextSegmentEnglish applyInteractive(TextSegmentEnglish item, int cleanPos) {
    if (item.text.isNotEmpty && isInsideInteractive(cleanPos)) {
      return item.copyWith(isInteractive: true);
    }
    return item;
  }

  int walk(List<TextSegmentEnglish> list, int cleanPos) {
    for (int i = 0; i < list.length; i++) {
      final node = list[i];
      if (node.subItems != null && node.subItems!.isNotEmpty) {
        cleanPos = walk(node.subItems!, cleanPos);
      } else {
        final newNode = applyInteractive(node, cleanPos);
        list[i] = newNode;
        cleanPos += node.text.length;
      }
    }
    return cleanPos;
  }

  walk(styled, 0);

  return styled;
}
*/
//
TextSegmentEnglish applyFlag(TextSegmentEnglish item, String flag) {
  var subSegment = TextSegmentEnglish(
    text: item.text,
    isInteractive: item.isInteractive,

    // isBold: flag == "isBold" ? true : item.isBold,
    // isItalic: flag == "isItalic" ? true : item.isItalic,
    // isUnderline: flag == "isUnderline" ? true : item.isUnderline,
    // isLineThrough: flag == "isLineThrough" ? true : item.isLineThrough,
    // isHighlight: flag == "isHighlight" ? true : item.isHighlight,
    // isBlank: flag == "isBlank" ? true : item.isBlank,
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
  if (flag == 'isHighlight') {
    subSegment = subSegment.copyWith(isHighlight: true);
  } else if (item.isHighlight != null) {
    subSegment = subSegment.copyWith(isHighlight: item.isHighlight);
  }
  if (flag == 'isBlank') {
    subSegment = subSegment.copyWith(isBlank: true);
  } else if (item.isBlank != null) {
    subSegment = subSegment.copyWith(isBlank: item.isBlank);
  }
  return subSegment;
}
