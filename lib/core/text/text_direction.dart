import 'package:flutter/widgets.dart';

/// 🌟 UI-2: جهتِ متن از روی خودِ متن.
///
/// همه‌ی اپ راست‌به‌چپ است (`builder`ِ `MaterialApp` در app.dart)، چون زبانِ رابطِ کاربری
/// فارسی است. ولی متنی که از بیرون می‌آید (عنوان و توضیحِ کتاب و دسته، نامِ دستگاه، اعلانِ
/// سرور، …) ممکن است انگلیسی باشد؛ برای چنین متنی جهت از **اولین حرفِ «قوی»** گرفته
/// می‌شود — همان قاعده‌ی `dir="auto"` در مرورگرها (Unicode Bidi، P2–P3): عدد، علامت و
/// فاصله حساب نمی‌شوند. پس «Mindset for IELTS 1 (Student's Book)» چپ‌به‌راست می‌ماند و
/// پرانتزِ آخرش برعکس نمی‌شود، و «کتابِ Mindset دانلود شد» راست‌به‌چپ است.
///
/// متنی که زبانش از پیش معلوم است، به این تشخیص نیازی ندارد: ترجمه‌ها (fa/ar) همیشه
/// راست‌به‌چپ‌اند و پاراگراف‌های کتاب جهتشان را از خودِ Word دارند (`para.direction`).
TextDirection textDirectionOf(
  String text, {
  TextDirection fallback = TextDirection.rtl,
}) {
  for (final int c in text.runes) {
    if (_isRtlLetter(c)) return TextDirection.rtl;
    if (_isLtrLetter(c)) return TextDirection.ltr;
  }
  return fallback;
}

/// حرفِ عبری، عربی، فارسی، سریانی، تانا و فرم‌های نمایشیِ عربی — بدونِ ارقامِ عربی/فارسی
/// (٠-٩ و ۰-۹) که «قوی» نیستند.
bool _isRtlLetter(int c) {
  if (c >= 0x0660 && c <= 0x0669) return false; // ٠-٩
  if (c >= 0x06F0 && c <= 0x06F9) return false; // ۰-۹
  if (c >= 0x0600 && c <= 0x0605) return false; // نشانه‌های قالب‌بندی
  if (c == 0x060C || c == 0x061B || c == 0x061F) return false; // ، ؛ ؟
  return (c >= 0x0590 && c <= 0x08FF) ||
      (c >= 0xFB1D && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF);
}

/// حرفِ لاتین (با حروفِ تکیه‌دار)، یونانی یا سیریلیک.
bool _isLtrLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) ||
    (c >= 0x370 && c <= 0x52F);

/// هم‌ترازیِ «ابتدای چیدمانِ اطراف» به‌صورتِ فیزیکی (راست در صفحه‌ی راست‌به‌چپ). عنوانِ
/// انگلیسی داخلِ صفحه‌ی فارسی ترتیبِ حروفش چپ‌به‌راست است ولی همان‌جایی می‌نشیند که
/// عنوان‌های فارسی می‌نشینند.
TextAlign textAlignToStartOf(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? TextAlign.right
    : TextAlign.left;

/// [Text] با جهتِ خودکار (UI-2) برای متنی که زبانش معلوم نیست. اگر [textAlign] داده
/// نشود، متن به ابتدای چیدمانِ اطراف می‌چسبد ([textAlignToStartOf]).
class AutoDirectionText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const AutoDirectionText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      textDirection: textDirectionOf(
        data,
        fallback: Directionality.of(context),
      ),
      textAlign: textAlign ?? textAlignToStartOf(context),
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// متنِ با جهتِ نامعلوم (عنوانِ انگلیسیِ کتاب، نامِ دستگاه، عبارتِ جستجو) **داخلِ یک جمله‌ی
/// فارسی** را جدا می‌کند (U+2068 FIRST STRONG ISOLATE … U+2069 POP DIRECTIONAL ISOLATE)، تا
/// ترتیبِ داخلِ خودش (پرانتز، عدد، نقطه) با جمله‌ی اطراف قاطی نشود: «Mindset 1 (A)» درست
/// دیده می‌شود، نه «(Mindset 1 (A». این دو نویسه دیده نمی‌شوند.
String bidiIsolate(String text) => '\u2068$text\u2069';
