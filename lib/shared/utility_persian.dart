import 'package:flutter/material.dart';

class UtilityPersian {
  // 1: ساخت یک نمونه استاتیک خصوصی از خود کلاس
  static final UtilityPersian _instance = UtilityPersian._internal();

  // 2: کانستراکتور خصوصی (برای جلوگیری از new کردن)
  UtilityPersian._internal();

  // 3: دسترسی عمومی به نمونه Singleton
  factory UtilityPersian() {
    return _instance;
  }

  //[۰۱۲۳۴۵۶۷۸۹][٠١٢٣٤٥٦٧٨٩]
  String repairNumberAndChars(String input) {
    String outPut = input.replaceAll('۰', '0');
    outPut = outPut.replaceAll('٠', '0');

    outPut = outPut.replaceAll('۱', '1');
    outPut = outPut.replaceAll('١', '1');

    outPut = outPut.replaceAll('۲', '2');
    outPut = outPut.replaceAll('٢', '2');

    outPut = outPut.replaceAll('۳', '3');
    outPut = outPut.replaceAll('٣', '3');

    outPut = outPut.replaceAll('۴', '4');
    outPut = outPut.replaceAll('٤', '4');

    outPut = outPut.replaceAll('۵', '5');
    outPut = outPut.replaceAll('٥', '5');

    outPut = outPut.replaceAll('۶', '6');
    outPut = outPut.replaceAll('٦', '6');

    outPut = outPut.replaceAll('۷', '7');
    outPut = outPut.replaceAll('٧', '7');

    outPut = outPut.replaceAll('۸', '8');
    outPut = outPut.replaceAll('٨', '8');

    outPut = outPut.replaceAll('۹', '9');
    outPut = outPut.replaceAll('٩', '9');
    outPut = outPut.replaceAll('ي', 'ی');
    outPut = outPut.replaceAll('ئ', 'ی');
    outPut = outPut.replaceAll('ك', 'ک');
    outPut = outPut.replaceAll('ﮑ', 'ک');
    outPut = outPut.replaceAll('ﮐ', 'ک');
    outPut = outPut.replaceAll('ﮏ', 'ک');
    return outPut;
  }

  // final persianRegex = RegExp(r'[\u0600-\u06FF&&[^\u06F0-\u06F9]]+');
  List<TextSpan> buildMixedTextSpans(
    String text, {
    required TextStyle persianStyle,
    required TextStyle normalStyle,
  }) {
    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Regex برای تشخیص توالی حروف فارسی (بدون اعداد)
    final persianLettersRegex = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+',
      unicode: true,
    );

    for (final match in persianLettersRegex.allMatches(text)) {
      final matchedText = match.group(0)!;

      // بررسی کنید که آیا شامل عدد فارسی است
      final hasPersianNumber = RegExp(
        r'[\u06F0-\u06F9]',
        unicode: true,
      ).hasMatch(matchedText);

      // اگر شامل عدد فارسی است، آن را به بخش‌های کوچکتر تقسیم کنید
      if (hasPersianNumber) {
        final parts = <String>[];
        final tempSpans = <TextSpan>[];
        int partStart = 0;

        for (int i = 0; i < matchedText.length; i++) {
          final char = matchedText[i];
          final isPersianNumber = RegExp(
            r'[\u06F0-\u06F9]',
            unicode: true,
          ).hasMatch(char);

          if (isPersianNumber) {
            if (partStart < i) {
              parts.add(matchedText.substring(partStart, i));
            }
            parts.add(char);
            partStart = i + 1;
          }
        }

        if (partStart < matchedText.length) {
          parts.add(matchedText.substring(partStart));
        }

        // قبل از بخش فارسی، متن غیرفارسی را اضافه کنید
        if (match.start > lastIndex) {
          spans.add(
            TextSpan(
              text: text.substring(lastIndex, match.start),
              style: normalStyle,
            ),
          );
        }

        // هر بخش را با استایل مناسب اضافه کنید
        for (final part in parts) {
          final isPersianPart =
              RegExp(
                r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
                unicode: true,
              ).hasMatch(part) &&
              !RegExp(r'^[\u06F0-\u06F9]+$', unicode: true).hasMatch(part);

          spans.add(
            TextSpan(
              text: part,
              style: isPersianPart ? persianStyle : normalStyle,
            ),
          );
        }

        lastIndex = match.end;
      } else {
        // اگر عدد فارسی ندارد، کل بخش را با استایل فارسی نمایش دهید
        if (match.start > lastIndex) {
          spans.add(
            TextSpan(
              text: text.substring(lastIndex, match.start),
              style: normalStyle,
            ),
          );
        }

        spans.add(TextSpan(text: matchedText, style: persianStyle));

        lastIndex = match.end;
      }
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: normalStyle));
    }

    return spans;
  }
}
