import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TextItem {
  String text;
  bool isInteractive;

  bool? isBold;
  bool? isBlank;
  bool? isItalic;
  bool? isUnderLine;
  bool? isLineThrough;
  bool? isHighlight;

  List<TextItem>? subItems;

  TextItem({
    required this.text,
    required this.isInteractive,
    this.isBold,
    this.isBlank,
    this.isItalic,
    this.isUnderLine,
    this.isLineThrough,
    this.isHighlight,
    this.subItems,
  });

  factory TextItem.fromJson(Map<String, dynamic> json) {
    return TextItem(
      text: json["text"],
      isInteractive: json["isInteractive"],
      isBold: json["isBold"],
      isBlank: json["isBlank"],
      isItalic: json["isItalic"],
      isUnderLine: json["isUnderLine"],
      isLineThrough: json["isLineThrough"],
      isHighlight: json["isHighlight"],
      subItems: json["subItems"] == null
          ? null
          : (json["subItems"] as List)
                .map((e) => TextItem.fromJson(e))
                .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    "text": text,
    "isInteractive": isInteractive,
    if (isBold != null) "isBold": isBold,
    if (isBlank != null) "isBlank": isBlank,
    if (isItalic != null) "isItalic": isItalic,
    if (isUnderLine != null) "isUnderLine": isUnderLine,
    if (isLineThrough != null) "isLineThrough": isLineThrough,
    if (isHighlight != null) "isHighlight": isHighlight,
    if (subItems != null) "subItems": subItems!.map((e) => e.toJson()).toList(),
  };
}

final emojiMap = {
  "💪": "isBold",
  "⬜️": "isBlank",
  "↪️": "isItalic",
  "📏": "isUnderLine",
  "🚫": "isLineThrough",
  "✨": "isHighlight",
};

class EmojiParser {
  List<TextItem> parse(String raw, List<TextItem> originalItems) {
    List<TextItem> result = [];

    int index = 0;
    while (index < raw.length) {
      String char = raw[index];

      // آیا ایموجی شروع یک بخش هست؟
      if (emojiMap.containsKey(char)) {
        String? flag = emojiMap[char];
        int endIndex = raw.indexOf(char, index + 1);

        if (endIndex == -1) {
          result.add(TextItem(text: char, isInteractive: false));
          index++;
          continue;
        }

        String innerText = raw.substring(index + 1, endIndex);

        // جستجو برای subItems
        List<TextItem> sub = [];
        for (var item in originalItems) {
          if (innerText.contains(item.text)) {
            sub.add(_merge(item, flag));
          }
        }

        // ساخت آیتم بخش جدید
        result.add(
          TextItem(
            text: innerText,
            isInteractive: false,
            subItems: sub,
            isBold: flag == "isBold",
            isBlank: flag == "isBlank",
            isItalic: flag == "isItalic",
            isUnderLine: flag == "isUnderLine",
            isLineThrough: flag == "isLineThrough",
            isHighlight: flag == "isHighlight",
          ),
        );

        index = endIndex + 1;
        continue;
      }

      result.add(TextItem(text: char, isInteractive: false));
      index++;
    }

    return result;
  }

  /// ادغام ویژگی قبلی + ویژگی جدید
  TextItem _merge(TextItem item, String? flag) {
    return TextItem(
      text: item.text,
      isInteractive: item.isInteractive,
      isBold: flag == "isBold" ? true : item.isBold,
      isBlank: flag == "isBlank" ? true : item.isBlank,
      isItalic: flag == "isItalic" ? true : item.isItalic,
      isUnderLine: flag == "isUnderLine" ? true : item.isUnderLine,
      isLineThrough: flag == "isLineThrough" ? true : item.isLineThrough,
      isHighlight: flag == "isHighlight" ? true : item.isHighlight,
      subItems: item.subItems,
    );
  }
}

class TextItemToSpan {
  TextSpan build(TextItem item) {
    TextStyle style = TextStyle(
      fontWeight: item.isBold == true ? FontWeight.bold : null,
      fontStyle: item.isItalic == true ? FontStyle.italic : null,
      decoration: TextDecoration.combine([
        if (item.isUnderLine == true) TextDecoration.underline,
        if (item.isLineThrough == true) TextDecoration.lineThrough,
      ]),
      backgroundColor: item.isHighlight == true
          ? Colors.yellow.withOpacity(0.5)
          : null,
    );

    if (item.subItems != null && item.subItems!.isNotEmpty) {
      return TextSpan(
        text: item.text,
        style: style,
        children: item.subItems!.map(build).toList(),
      );
    }

    return TextSpan(
      text: item.text,
      style: style,
      recognizer: item.isInteractive
          ? (TapGestureRecognizer()..onTap = () => print(item.text))
          : null,
    );
  }
}
