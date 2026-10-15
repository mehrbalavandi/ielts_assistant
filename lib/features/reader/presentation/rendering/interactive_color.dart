import 'package:flutter/material.dart';

// 🌟 قانونِ W-2 (RULES-rendering.md): رنگِ کلماتِ تعاملی از پس‌زمینه‌ی واقعیِ همان‌جا
// (اسپن ← پاراگراف ← سلول ← جدول ← صفحه/ظرف) و رنگِ متنِ کنارش ساخته می‌شود، نه یک
// آبیِ ثابت. مثلاً سرآغازِ SPEAKING هر Unit سلولی آبی (047FDC) با متنِ سفید است؛ آبیِ
// پیش‌فرض روی آن دیده نمی‌شد.

/// کمینه‌ی کنتراستِ دلخواه (WCAG برای متنِ عادی).
const double _kGoodContrast = 4.5;

/// اگر هیچ فامی به ۴٫۵ نرسید، اولین فامی که دست‌کم این‌قدر کنتراست دارد (مثلاً زرد روی
/// آبیِ متوسط) — بهتر از رنگی کم‌رنگ و نزدیک به سفید که کنتراستِ کمی بیشتری دارد.
const double _kFairContrast = 3.0;

/// فام‌ها به ترتیبِ ترجیح: اول آبیِ آشنا، بعد مکملِ آن (زرد/کهربایی)، صورتی، سبز.
const List<double> _kLightHues = [210, 52, 330, 140];
const List<double> _kDarkHues = [210, 30, 330, 140];

final Map<(int, int), Color> _cache = {};

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

double _hueDistance(double a, double b) {
  final double d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// فامِ یک رنگِ «رنگی»؛ null برای سفید/سیاه/خاکستری و رنگ‌های خیلی روشن/تیره.
double? _chromaticHue(Color c) {
  final HSLColor h = HSLColor.fromColor(c);
  if (h.saturation <= 0.25 || h.lightness <= 0.12 || h.lightness >= 0.88) {
    return null;
  }
  return h.hue;
}

/// رنگِ کلمه‌ی تعاملی روی [background] کنارِ متنی به رنگِ [textColor].
///
/// - **سمت:** هم‌سمتِ متن. متنِ روشن روی زمینه‌ی تیره ← رنگِ روشن، وگرنه رنگِ تیره. پس
///   کلمه حسِ همان متن را دارد و فقط با فامش جدا می‌شود.
/// - **فام:** فامی که به فامِ زمینه (اگر زمینه رنگی است) یا به فامِ متنِ رنگی نزدیک
///   است (کمتر از ۶۰/۴۵ درجه) کنار گذاشته می‌شود؛ آبی روی سلولِ آبی یا کنارِ تیترِ آبی
///   دیده نمی‌شد.
/// - **روشنی:** فقط در بازه‌ای که رنگ هنوز رنگی بماند (روشن ۰٫۵۵–۰٫۷۵، تیره ۰٫۴۸–۰٫۲۲)؛
///   اولین روشنی که کنتراستِ ۴٫۵ بدهد. اگر هیچ فامی به ۴٫۵ نرسید، اولین فام با کنتراستِ
///   ۳، وگرنه پرکنتراست‌ترین.
Color interactiveColorOn(Color background, {Color? textColor}) {
  final Color bg = background.withAlpha(255);
  final Color text = Color.alphaBlend(textColor ?? Colors.black87, bg);
  final (int, int) key = (bg.toARGB32(), text.toARGB32());
  final Color? cached = _cache[key];
  if (cached != null) return cached;

  final double? bgHue = _chromaticHue(bg);
  final double? textHue = _chromaticHue(text);
  final bool light = text.computeLuminance() > bg.computeLuminance();
  final List<double> hues = light ? _kLightHues : _kDarkHues;
  final double saturation = light ? 1.0 : 0.9;

  Color? fair;
  Color? best;
  double bestContrast = -1;
  for (final double hue in hues) {
    if (bgHue != null && _hueDistance(hue, bgHue) < 60) continue;
    if (textHue != null && _hueDistance(hue, textHue) < 45) continue;
    Color? firstFair;
    for (int i = 0; i <= 20; i++) {
      final double l = light ? 0.55 + i * 0.01 : 0.48 - i * 0.013;
      final Color c = HSLColor.fromAHSL(1, hue, saturation, l).toColor();
      final double k = _contrast(c, bg);
      if (k >= _kGoodContrast) return _cache[key] = c;
      if (k >= _kFairContrast) firstFair ??= c;
      if (k > bestContrast) {
        bestContrast = k;
        best = c;
      }
    }
    fair ??= firstFair;
  }
  return _cache[key] = fair ?? best ?? (light ? Colors.amberAccent : Colors.blue.shade900);
}
