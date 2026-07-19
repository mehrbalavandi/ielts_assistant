import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';

/// ابزارِ مشترکِ متنِ جستجو — یک منبعِ واحد که هم موتورِ جستجو (finder) و هم
/// موتورِ رندر (هایلایت) از آن استفاده می‌کنند. چون شمارشِ occurrence و نقشه‌ی
/// هایلایت باید کاملاً هم‌تراز باشند، این سه ابزار نباید در دو فایل کپی شوند.

/// متنِ خام را به متنِ «تمیز» (بدونِ مارکرهای {blk}/{/blk}) تبدیل می‌کند و نگاشتِ
/// اندیسِ تمیز → اندیسِ خام را نگه می‌دارد تا بتوان محلِ تطبیق در متنِ اصلی را یافت.
class TextSearchMapper {
  final String rawText;
  late final String cleanText;
  late final List<int> cleanToRaw;

  TextSearchMapper(this.rawText) {
    StringBuffer clean = StringBuffer();
    cleanToRaw = [];
    int rawIdx = 0;
    while (rawIdx < rawText.length) {
      if (rawText.startsWith('{blk}', rawIdx)) {
        rawIdx += 5;
        continue;
      }
      if (rawText.startsWith('{/blk}', rawIdx)) {
        rawIdx += 6;
        continue;
      }
      clean.write(rawText[rawIdx]);
      cleanToRaw.add(rawIdx);
      rawIdx++;
    }
    cleanText = clean.toString();
  }
}

/// متنِ کاملِ یک پاراگراف را استخراج می‌کند (شاملِ سلول‌های جدول، به‌صورت بازگشتی).
String extractFullText(ParagraphData para) {
  StringBuffer sb = StringBuffer();
  for (var span in para.spans) {
    if (span.type == "text") {
      sb.write(span.content);
    } else if (span.type == "table" && span.tableRows.isNotEmpty) {
      for (var row in span.tableRows) {
        for (var cell in row.cells) {
          for (var cellPara in cell.paragraphs) {
            sb.write(extractFullText(cellPara));
          }
        }
      }
    }
  }
  return sb.toString();
}

/// نرمال‌سازیِ متن برای مقایسه‌ی جستجو: lowercase + یکسان‌سازیِ حروفِ عربی/فارسی
/// + تبدیلِ نیم‌فاصله (ZWNJ) به فاصله.
String normalizeText(String text) {
  return text
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('\u200c', ' ');
}
