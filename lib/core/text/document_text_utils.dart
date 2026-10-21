import 'package:ielts_assistant/features/reader/domain/document_models.dart';

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
String extractFullText(ParagraphData para) => _writeFullText(para, StringBuffer(), null);

/// 🌟 S-18: همان متنِ [extractFullText] (همان اندیس‌ها، پس occurrenceها عوض نمی‌شوند) به‌همراهِ
/// جاهایی که پاراگرافِ تازه‌ای از یک سلولِ جدول شروع می‌شود — گزیده‌ی نتیجه‌ی جستجو آن‌جا فاصله
/// می‌گذارد تا «comfortable» و «Sweden» ِ دو سلولِ کنارِ هم «comfortableSweden» نشوند.
({String text, Set<int> breaks}) extractFullTextWithBreaks(ParagraphData para) {
  final Set<int> breaks = {};
  final String text = _writeFullText(para, StringBuffer(), breaks);
  return (text: text, breaks: breaks);
}

String _writeFullText(ParagraphData para, StringBuffer sb, Set<int>? breaks) {
  for (var span in para.spans) {
    if (span.type == "text") {
      sb.write(span.content);
    } else if ((span.type == "table" || span.type == "layout") &&
        span.tableRows.isNotEmpty) {
      // 🐞 "layout" هم باید پیمایش شود: اسپنِ ColumnStackTable در سی‌شارپ
      // نوعش به "layout" تغییر می‌کند ولی ساختارِ ردیف/سلولش همان است —
      // بدونِ این، متنِ داخلِ چنین جدولی اصلاً قابلِ جستجو نبود.
      for (var row in span.tableRows) {
        for (var cell in row.cells) {
          for (var cellPara in cell.paragraphs) {
            breaks?.add(sb.length);
            _writeFullText(cellPara, sb, breaks);
          }
        }
      }
      breaks?.add(sb.length);
    }
  }
  return sb.toString();
}

/// 🌟 S-18: گزیده‌ی یک نتیجه‌ی جستجو و جای عبارتِ یافته‌شده در آن (برای پررنگ کردن).
/// matchStart = -1: جای عبارت معلوم نیست، یا ([hidden]) داخلِ پاسخِ پنهان است و دیده نمی‌شود.
class SearchExcerpt {
  final String text;
  final int matchStart;
  final int matchEnd;
  final bool hidden;
  const SearchExcerpt(this.text, this.matchStart, this.matchEnd, {this.hidden = false});
}

/// 🌟 S-18: گزیده از متنِ خام ([rawText] با {blk}): حدودِ [before]/[after] نویسه‌ی دیدنی دورِ
/// تطبیقِ [rawStart, rawEnd)، با:
/// - فاصله در مرزِ سلول‌ها ([breaks]) و یکی شدنِ فاصله‌ها/خطِ تازه؛
/// - پاسخِ پنهان ({blk}…{/blk}) به‌صورتِ «____» — گزیده‌ی جستجو پاسخِ تمرین را لو نمی‌دهد؛
/// - بریدن در مرزِ کلمه و «…» در دو سر وقتی متن ادامه دارد.
SearchExcerpt buildSearchExcerpt(
  String rawText,
  Set<int> breaks,
  int rawStart,
  int rawEnd, {
  int before = 45,
  int after = 80,
}) {
  bool markerAt(int i) =>
      rawText.startsWith('{blk}', i) || rawText.startsWith('{/blk}', i);

  // پنجره (در نویسه‌های دیدنی).
  int from = rawStart;
  for (int seen = 0; from > 0 && seen < before;) {
    from--;
    if (rawText[from] == '}') {
      final int o = rawText.lastIndexOf('{', from);
      if (o >= 0 && markerAt(o)) {
        from = o;
        continue;
      }
    }
    seen++;
  }
  int to = rawEnd;
  for (int seen = 0; to < rawText.length && seen < after;) {
    if (rawText.startsWith('{blk}', to)) {
      to += 5;
      continue;
    }
    if (rawText.startsWith('{/blk}', to)) {
      to += 6;
      continue;
    }
    to++;
    seen++;
  }

  // داخلِ پاسخِ پنهان شروع می‌شود؟
  bool inBlk = false;
  {
    final int open = rawText.lastIndexOf('{blk}', from == 0 ? 0 : from - 1);
    if (open >= 0 && from > open) {
      final int close = rawText.indexOf('{/blk}', open);
      inBlk = close < 0 || close >= from;
    }
  }

  final StringBuffer out = StringBuffer();
  int mStart = -1;
  int mEnd = -1;
  bool matchHidden = false;
  void space() {
    if (out.isNotEmpty && !out.toString().endsWith(' ')) out.write(' ');
  }

  if (inBlk) out.write('____');
  for (int i = from; i < to;) {
    if (breaks.contains(i) && i != from) space();
    if (i == rawStart) {
      if (inBlk) matchHidden = true;
      mStart = out.length;
    }
    if (rawText.startsWith('{blk}', i)) {
      inBlk = true;
      if (!out.toString().endsWith('____')) out.write('____');
      i += 5;
      continue;
    }
    if (rawText.startsWith('{/blk}', i)) {
      inBlk = false;
      i += 6;
      continue;
    }
    if (!inBlk) {
      final String ch = rawText[i];
      if (ch.trim().isEmpty) {
        space();
      } else {
        out.write(ch);
      }
    } else if (i >= rawStart && i < rawEnd) {
      matchHidden = true;
    }
    i++;
    if (i == rawEnd) mEnd = out.length;
  }
  if (mEnd < 0) mEnd = out.length;

  String text = out.toString();
  // بریدن در مرزِ کلمه.
  int cutStart = 0;
  if (from > 0) {
    final int sp = text.indexOf(' ');
    if (sp >= 0 && sp < 18 && (mStart < 0 || sp < mStart)) cutStart = sp + 1;
  }
  int cutEnd = text.length;
  if (to < rawText.length) {
    final int sp = text.lastIndexOf(' ');
    if (sp > 0 && text.length - sp < 18 && sp >= mEnd) cutEnd = sp;
  }
  text = text.substring(cutStart, cutEnd).trim();
  final int lead = text.isEmpty
      ? 0
      : out.toString().substring(cutStart).indexOf(text[0]);
  final int shift = cutStart + (lead < 0 ? 0 : lead);
  final String pre = from > 0 ? '… ' : '';
  final String post = to < rawText.length ? ' …' : '';
  if (matchHidden || mStart < 0) {
    return SearchExcerpt('$pre$text$post', -1, -1, hidden: matchHidden);
  }
  final int s0 = (mStart - shift).clamp(0, text.length);
  final int e0 = (mEnd - shift).clamp(s0, text.length);
  return SearchExcerpt('$pre$text$post', s0 + pre.length, e0 + pre.length);
}

/// 🐞 S-13: عبارتِ جستجو همیشه از همین‌جا رد می‌شود — هم در موتورِ جستجو (یافتن) و هم
/// در نقشه‌ی هایلایت (نارنجی‌کردن). فاصله‌ی ابتدا/انتها حذف و فاصله‌های پشتِ‌هم یکی
/// می‌شوند. قبلاً موتور trim می‌کرد ولی هایلایت عبارتِ خام را می‌گرفت؛ پس «collocation »
/// (با فاصله در انتها) collocations را پیدا می‌کرد ولی هیچ‌چیز نارنجی نمی‌شد.
String normalizeQuery(String query) =>
    query.trim().replaceAll(RegExp(r'\s+'), ' ');

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

/// 🌟 TR-8: نشانه‌های {blk}/{/blk} را برمی‌دارد (متن همان می‌ماند) — برای ترجمه‌ای که جایی
/// نشان داده می‌شود که پاسخ دیگر پنهان نیست (پنجره‌ی خودِ پاسخ)، یا برای اندازه‌گیری.
String stripBlankMarkers(String text) =>
    text.replaceAll('{blk}', '').replaceAll('{/blk}', '');

/// 🌟 TR-8: بخش‌های پنهان ({blk}…{/blk}) را با «____» عوض می‌کند — همان کاری که گزیده‌ی متنِ
/// «مرورِ من» با جای‌خالی‌های متنِ انگلیسی می‌کند.
String maskBlankParts(String text) =>
    text.replaceAll(RegExp(r'\{blk\}.*?\{/blk\}', dotAll: true), '____');
