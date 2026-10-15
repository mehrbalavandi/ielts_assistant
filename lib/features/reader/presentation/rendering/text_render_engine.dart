import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/answer_display.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/interactive_color.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/reader/presentation/reading_canvas.dart'; // برای دسترسی به TranslatableContentWrapper

// 🌟 رفع مشکل اسکرول نادقیق جستجو:
// یک GlobalKey فقط می‌تواند به یک ویجت وصل باشد. چون یک "occurrence" واحد
// گاهی (در مرز یک کلمه دیکشنری) به چند تکه‌ی InlineSpan شکسته می‌شود،
// این کلاس مطمئن می‌شود کلید دقیق فقط یک‌بار مصرف می‌شود و به اولین
// تکه‌ای که واقعاً همان occurrence فعال است متصل می‌گردد.
//
// 🐞 رفع باگ کرش رندر (RenderBox did not set its size / _RenderScaledInlineWidget):
// قبلاً buildInteractiveText به ازای *هر* اسپن (و هر پاراگرافِ داخل هر
// سلولِ جدول) یک نمونه‌ی تازه از این کلاس می‌ساخت. وقتی نتیجه‌ی فعالِ
// جستجو دقیقاً روی مرزِ دو اسپن یا دو سلول جدول می‌افتاد (چون عبارتِ
// جستجو از ترکیب چند تکه به دست آمده بود)، هر دو طرفِ مرز مستقل از هم
// فکر می‌کردند «هنوز کسی کلید را claim نکرده» و هر دو یک WidgetSpan با
// همان exactMatchKey (یک GlobalKey واحد) می‌ساختند. استفاده‌ی هم‌زمان از
// یک GlobalKey برای دو ویجت مختلف در یک فریم، درخت رندر را در میانه‌ی
// layout به‌هم می‌ریزد و باعث می‌شد یک RenderObject کاملاً نامرتبط
// (اینجا: _RenderScaledInlineWidget داخلی فلاتر) بدون اینکه اندازه‌اش
// را ست کند از performLayout خارج شود. کلاس حالا public است تا از سطح
// پاراگراف (در reading_canvas_screen.dart) یک نمونه‌ی واحد بین همه‌ی
// اسپن‌ها و سلول‌های جدولِ همان پاراگراف به اشتراک گذاشته شود.
class KeyClaim {
  bool used = false;
}

class TextRenderEngine {
  static List<InlineSpan> buildInteractiveText(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle, {
    Color interactiveColor = Colors.blue,
    List<int>? localHighlightMap,
    int? activeOccurrence,
    String? translationFa, // 🌟 اضافه شد
    String? translationAr, // 🌟 اضافه شد
    List<SpanData>? innerSpans,
    // 🌟 محتوای غنیِ جای‌خالی (جدول/عکس/…) — تا مودال با رندرِ صفحه ساخته شود.
    List<ParagraphData>? hiddenParagraphs,
    GlobalKey? exactMatchKey, // 🌟 اضافه شد
    RegExp? interactivesPattern, // 🌟 اضافه شد: جستجوی سریع کلمات دیکشنری
    Map<String, InteractiveWord>? interactivesByText, // 🌟 اضافه شد
    // 🐞 رفع کرش: اگر تماس‌گیرنده (سطح پاراگراف) یک KeyClaim مشترک بدهد،
    // از همان استفاده کن تا وضعیتِ «مصرف‌شده» بین چند اسپن/سلول جدولِ یک
    // پاراگراف مشترک بماند. اگر داده نشود (مثلاً فراخوانی‌های مستقلِ مودالِ
    // کلمه‌ی مخفی که اصلاً exactMatchKey ندارند)، مثل قبل یکی محلی و
    // یک‌بارمصرف ساخته می‌شود.
    KeyClaim? sharedKeyClaim,
    // 🐞 رفع باگ شماره‌ی لیست: فقط برای پاراگراف‌های کاملاً-یک-بلانک
    // (تمرین-۰۵ استایل) از بالادست (reading_canvas_screen.dart) پر می‌شود؛
    // تا InteractiveBlankWord رد می‌شود تا داخل مودال prepend شود، نه
    // در نمای جمع‌شده.
    String? listMarker,
    // 🐞 رفع باگ هایلایت جستجو: وقتی true باشد، همه‌ی occurrenceهای
    // یافت‌شده (نه فقط دقیقاً همان activeOccurrence) به‌رنگ orangeAccent
    // نشان داده می‌شوند. فقط داخل مودالِ جای‌خالی (که خودش یک نتیجه‌ی
    // فعالِ گروه‌بندی‌شده است) true پاس داده می‌شود؛ در رندر عادیِ صفحه
    // false می‌ماند تا تمایز نارنجی/زردِ معمول حفظ شود.
    bool allMatchesActive = false,
    // 🐞 مارکرهای خودِ اسپنِ جای‌خالی (والد). لازم است چون مارکرهای جدیدِ
    // s/sub/sup در baseStyle «پخته» شده‌اند (خط‌خوردگی روی decoration و
    // بالانویس/زیرنویس روی fontFeatures + کوچک‌شدنِ ۰٫۷۵ فونت) و اگر همان
    // استایل داخلِ مودال به‌عنوانِ پایه‌ی InnerSpanها یا به شماره‌ی لیست
    // برسد، به همه‌ی متنِ آشکارشده نشت می‌کند. با داشتنِ خودِ مارکرها
    // می‌شود دقیقاً همان‌ها را خنثی کرد (و اندازه‌ی فونت را برگرداند).
    List<String>? blankParentMarkers,
  }) {
    if (content.isEmpty) return [];
    List<InlineSpan> spans = [];
    // 🌟 یک‌بار مصرف بودن کلید دقیق را برای کل پاراگراف (نه فقط همین اسپن) تضمین می‌کند
    final KeyClaim keyClaim = sharedKeyClaim ?? KeyClaim();

    final RegExp blankRegex = RegExp(r'\{blk\}(.*?)\{/blk\}', dotAll: true);
    final matches = blankRegex.allMatches(content);
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        var slice = localHighlightMap?.sublist(currentIndex, match.start);
        spans.addAll(
          _processDictionaryWords(
            content.substring(currentIndex, match.start),
            interactives,
            context,
            baseStyle,
            interactiveColor,
            slice,
            activeOccurrence,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
            pattern: interactivesPattern,
            byText: interactivesByText,
            allMatchesActive: allMatchesActive,
          ),
        );
      }

      // 🌟 بازگشت به منطق دقیق خودتان برای جلوگیری از شیفت شدن هایلایت‌ها
      int startOfHidden = match.start + 5; // عبور از {blk}
      int endOfHidden = match.end - 6; // قبل از {/blk}
      List<int>? blankMapSlice;

      if (localHighlightMap != null) {
        if (startOfHidden < localHighlightMap.length &&
            endOfHidden <= localHighlightMap.length) {
          blankMapSlice = localHighlightMap.sublist(startOfHidden, endOfHidden);
        }
      }
      bool isThisTheTarget =
          blankMapSlice != null &&
          activeOccurrence != null &&
          blankMapSlice.contains(activeOccurrence);
      // 🌟 حتی اگر isThisTheTarget باشد، فقط وقتی کلید را واقعاً بده که
      // قبلاً توسط تکه‌ی دیگری (قبل از این جای‌خالی) مصرف نشده باشد
      final bool claimBlankKey = isThisTheTarget && !keyClaim.used;
      if (claimBlankKey) keyClaim.used = true;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InteractiveBlankWord(
            hiddenText: match.group(1) ?? '',
            textStyle: baseStyle,
            interactives: interactives,
            blankMap: blankMapSlice, // 🌟 ارسال برش دقیق به دکمه
            activeOcc: activeOccurrence,
            translationFa: translationFa,
            translationAr: translationAr,
            innerSpans: innerSpans,
            hiddenParagraphs: hiddenParagraphs,
            // TR-2: کلماتِ دیکشنری داخلِ پاسخ با همان جستجوی سریعِ صفحه
            interactivesPattern: interactivesPattern,
            interactivesByText: interactivesByText,
            parentMarkers: blankParentMarkers, // 🐞 برای خنثی‌سازی s/sub/sup
            listMarker: listMarker, // 🐞 برای prepend داخل مودال
            exactMatchKey: claimBlankKey
                ? exactMatchKey
                : null, // 🌟 اتصال کلید فقط به همین هدف!
          ),
        ),
      );
      currentIndex = match.end;
    }
    if (currentIndex < content.length) {
      var slice = localHighlightMap?.sublist(currentIndex);
      spans.addAll(
        _processDictionaryWords(
          content.substring(currentIndex),
          interactives,
          context,
          baseStyle,
          interactiveColor,
          slice,
          activeOccurrence,
          exactMatchKey: exactMatchKey,
          keyClaim: keyClaim,
          pattern: interactivesPattern,
          byText: interactivesByText,
          allMatchesActive: allMatchesActive,
        ),
      );
    }
    return spans;
  }

  /// نگاشتِ نامِ سبکِ زیرخط (که سی‌شارپ از w:u ورد ساخته) به enum فلاتر.
  /// null یعنی «سبکِ پیش‌فرضِ فلاتر» — همان رفتارِ قبلی برای کتاب‌هایی که
  /// هنوز با نسخه‌ی جدیدِ استخراج‌کننده ساخته نشده‌اند.
  static TextDecorationStyle? decorationStyleFromWord(String? style) {
    switch (style) {
      case 'double':
        return TextDecorationStyle.double;
      case 'dotted':
        return TextDecorationStyle.dotted;
      case 'dashed':
        return TextDecorationStyle.dashed;
      case 'wavy':
        return TextDecorationStyle.wavy;
      case 'solid':
        return TextDecorationStyle.solid;
      default:
        return null;
    }
  }

  /// هگزِ ورد (با یا بدون #، ۶ یا ۸ رقمی) → Color. برای رنگِ زیرخط.
  static Color? hexToColor(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.isEmpty || h.toLowerCase() == 'auto') return null;
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  static TextStyle applySpanStyle(TextStyle base, SpanData span, bool isDark) {
    double fontSize = base.fontSize ?? 16.0;

    bool isBold = span.markers.contains("b");
    bool isItalic = span.markers.contains("i");
    bool isUnderline = span.markers.contains("u");
    // 🐞 مارکرهای جدید: خط‌خورده / زیرنویس / بالانویس
    bool isStrike = span.markers.contains("s");
    bool isSub = span.markers.contains("sub");
    bool isSup = span.markers.contains("sup");

    Color color = isDark ? Colors.white : Colors.black87;
    Color? bgColor; // 🌟 متغیر جدید برای ذخیره رنگ پس‌زمینه

    for (var marker in span.markers) {
      if (marker.startsWith("sz:")) {
        double? s = double.tryParse(marker.substring(3));
        if (s != null) fontSize = s / 2;
      }
    }

    // ۱. پردازش رنگ متن
    if (span.textColor != null &&
        span.textColor!.isNotEmpty &&
        span.textColor != "auto") {
      final buffer = StringBuffer();
      if (span.textColor!.length == 6 || span.textColor!.length == 7) {
        buffer.write('ff');
      }
      buffer.write(span.textColor!.replaceFirst('#', ''));
      try {
        color = Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    } else {
      color = isDark ? Colors.white : Colors.black87;
    }

    // 🌟 ۲. پردازش رنگ پس‌زمینه (FillColor)
    if (span.fillColor != null &&
        span.fillColor!.isNotEmpty &&
        span.fillColor != "auto") {
      final buffer = StringBuffer();
      if (span.fillColor!.length == 6 || span.fillColor!.length == 7) {
        buffer.write('ff');
      }
      buffer.write(span.fillColor!.replaceFirst('#', ''));
      try {
        bgColor = Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    }

    // 🐞 زیرنویس/بالانویس: فلاتر در TextStyle چیزی معادلِ vertical-align ندارد.
    // روشِ استانداردِ تقریب: اندازه‌ی فونت را کوچک کن و با `fontFeatures` از
    // خودِ فونت رقمِ sub/sup بخواه؛ اگر فونت آن ویژگی را نداشته باشد، حداقل
    // اندازه‌ی کوچک‌ترِ آن باقی می‌ماند (fontFeatures بی‌اثر است، نه خراب‌کننده).
    // 🐞 اصلاحِ خطای کامپایل: FontFeature.superscript()/.subscript() به‌عنوانِ
    // سازنده‌ی نام‌دار در این نسخه‌ی SDK وجود ندارند. سازنده‌ی پایه
    // `FontFeature(String tag, [int value=1])` همیشه هست؛ تگ‌های چهارحرفیِ
    // استانداردِ OpenType مستقیماً استفاده می‌شوند: 'sups'=بالانویس، 'subs'=زیرنویس.
    // 🐞 نکته‌ی مهمِ copyWith: در فلاتر `copyWith(fontFeatures: null)` مقدار را
    // پاک نمی‌کند، بلکه مقدارِ قبلیِ base را نگه می‌دارد (`x ?? this.x`). پس اگر
    // اسپنِ والد (مثلاً جای‌خالیِ بالانویس) روی base فیچرِ 'sups' گذاشته باشد،
    // هر InnerSpanِ غیرِ بالانویس هم بالانویس می‌ماند. با دادنِ لیستِ خالی
    // (که null نیست) مقدار واقعاً بازنویسی و خنثی می‌شود.
    // 🌟 'smcp' (حروفِ کوچکِ بزرگ‌نما) می‌تواند هم‌زمان با بالا/زیرنویس باشد،
    // پس لیست ساخته می‌شود نه یک ترنریِ انحصاری. لیستِ خالی عمدی است — دلیلش
    // همان نکته‌ی copyWith(null) پایین‌تر.
    final List<FontFeature> _feat = <FontFeature>[
      if (isSup) const FontFeature('sups'),
      if (isSub) const FontFeature('subs'),
      if (span.markers.contains("smallcaps")) const FontFeature('smcp'),
    ];
    final double _finalSize = (isSup || isSub) ? fontSize * 0.75 : fontSize;

    // 🐞 چند decoration هم‌زمان (مثلاً هم زیرخط هم خط‌خورده) با combine
    final List<TextDecoration> _decos = [
      if (isUnderline) TextDecoration.underline,
      if (isStrike) TextDecoration.lineThrough,
    ];

    // 🌟 نوع/ضخامت/رنگِ زیرخط از سند ورد.
    // ⚠️ نکته‌ای که در فلاتر گریزناپذیر است: decorationStyle و
    // decorationColor روی *همه‌ی* decorationهای یک TextStyle اعمال می‌شوند.
    // پس اگر یک ران هم‌زمان زیرخطِ نقطه‌چین و خط‌خورده باشد، خط‌خورده هم
    // نقطه‌چین می‌شود. جداکردنشان نیازمندِ دو TextSpanِ تودرتوست که ارزشش
    // را ندارد؛ ترکیبِ زیرخطِ غیرساده + خط‌خوردگی در عمل نادر است.
    final TextDecorationStyle? _uStyle = isUnderline
        ? decorationStyleFromWord(span.underlineStyle)
        : null;
    final Color? _uColor = isUnderline ? hexToColor(span.underlineColor) : null;

    return base.copyWith(
      fontSize: _finalSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _decos.isEmpty
          ? TextDecoration.none
          : TextDecoration.combine(_decos),
      decorationStyle: _uStyle,
      decorationColor: _uColor,
      decorationThickness: isUnderline ? span.underlineThickness : null,
      // 🌟 فاصله‌ی حروف. صفرِ صریح لازم است نه null: با null مقدارِ base
      // حفظ می‌شود و فاصله‌ی یک اسپن به اسپن‌های بعدی نشت می‌کند — دقیقاً
      // همان تله‌ای که قبلاً با fontFeatures خوردیم.
      letterSpacing: span.letterSpacing ?? 0.0,
      fontFeatures: _feat,
      color: color,
      backgroundColor: bgColor, // 🌟 اعمال رنگ پس‌زمینه به استایل نهایی
    );
  }

  static List<InlineSpan> _processDictionaryWords(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle,
    Color interactiveColor,
    List<int>? localMap,
    int? activeOcc, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    RegExp? pattern,
    Map<String, InteractiveWord>? byText,
    bool allMatchesActive = false,
  }) {
    if (interactives.isEmpty || content.isEmpty) {
      return applyMapToText(
        content,
        baseStyle,
        localMap,
        activeOcc,
        exactMatchKey: exactMatchKey,
        keyClaim: keyClaim,
        allMatchesActive: allMatchesActive,
      );
    }

    // 🌟 رفع مشکل کندی اسکرول (مسیر سریع): یک عبور خطی با RegExp ترکیبی
    // (که در PageData.fromJson یک‌بار برای کل صفحه ساخته شده) به‌جای اسکن
    // مکرر تمام کلمات دیکشنری به ازای هر موقعیت از متن. این دقیقاً همان
    // معنای «leftmost match، در تساوی طولانی‌ترین کلمه» را حفظ می‌کند،
    // چون کلمات از قبل نزولی بر اساس طول در pattern چیده شده‌اند.
    // 🐞 W-1: مسیرِ کندِ قدیمی (indexOf روی هر کلمه) حذف شد. «gain» را وسطِ «again»
    // هم پیدا می‌کرد. اگر الگو از بیرون نیامده، همین‌جا یک‌بار برای همین فهرست
    // ساخته و نگه داشته می‌شود؛ همه‌ی مسیرها فقط کلمه‌ی کامل را تطبیق می‌دهند.
    RegExp? effectivePattern = pattern;
    Map<String, InteractiveWord>? effectiveByText = byText;
    if (effectivePattern == null ||
        effectiveByText == null ||
        effectiveByText.isEmpty) {
      effectivePattern = _fallbackPattern(interactives);
      effectiveByText = _fallbackByText(interactives);
    }
    if (effectivePattern == null) {
      return applyMapToText(
        content,
        baseStyle,
        localMap,
        activeOcc,
        exactMatchKey: exactMatchKey,
        keyClaim: keyClaim,
        allMatchesActive: allMatchesActive,
      );
    }
    return _processDictionaryWordsFast(
      content,
      effectivePattern,
      effectiveByText,
      context,
      baseStyle,
      interactiveColor,
      localMap,
      activeOcc,
      exactMatchKey: exactMatchKey,
      keyClaim: keyClaim,
      allMatchesActive: allMatchesActive,
    );
  }

  // W-1: الگوی ساخته‌شده برای فهرست‌هایی که الگوی آماده ندارند، به ازای همان
  // نمونه‌ی فهرست (Expando: با دور ریخته شدنِ فهرست، این هم می‌رود).
  static final Expando<RegExp> _fallbackPatterns = Expando<RegExp>();
  static final Expando<Map<String, InteractiveWord>> _fallbackMaps =
      Expando<Map<String, InteractiveWord>>();

  static RegExp? _fallbackPattern(List<InteractiveWord> words) {
    final RegExp? cached = _fallbackPatterns[words];
    if (cached != null) return cached;
    final RegExp? built = buildInteractivesPattern(words);
    if (built != null) _fallbackPatterns[words] = built;
    return built;
  }

  static Map<String, InteractiveWord> _fallbackByText(
    List<InteractiveWord> words,
  ) => _fallbackMaps[words] ??= {
    for (final w in words)
      if (w.exactText.isNotEmpty) w.exactText: w,
  };

  // 🌟 نسخه‌ی سریع: یک عبور خطی روی متن با RegExp ترکیبی (pattern) که
  // همه‌ی کلمات دیکشنری صفحه را یک‌جا شامل می‌شود، به‌جای اسکن مکرر تمام
  // کلمات به ازای هر موقعیت. با اینکه content به ازای هر بخش از پاراگراف
  // (بین جای‌خالی‌ها) دوباره صدا زده می‌شود، هر بار فقط یک عبور خطی روی
  // همان بخش کوچک انجام می‌شود؛ کار سنگین (ساخت pattern) فقط یک‌بار در
  // PageData.fromJson انجام شده.
  static List<InlineSpan> _processDictionaryWordsFast(
    String content,
    RegExp pattern,
    Map<String, InteractiveWord> byText,
    BuildContext context,
    TextStyle baseStyle,
    Color interactiveColor,
    List<int>? localMap,
    int? activeOcc, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    bool allMatchesActive = false,
  }) {
    List<InlineSpan> spans = [];
    int currentIndex = 0;

    for (final match in pattern.allMatches(content)) {
      final InteractiveWord? matchedWord = byText[match.group(0)];
      if (matchedWord == null) continue; // احتیاطی؛ نباید پیش بیاید

      if (match.start > currentIndex) {
        spans.addAll(
          applyMapToText(
            content.substring(currentIndex, match.start),
            baseStyle,
            localMap?.sublist(currentIndex, match.start),
            activeOcc,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
            allMatchesActive: allMatchesActive,
          ),
        );
      }

      List<int>? wordMap;
      if (localMap != null) {
        wordMap = localMap.sublist(match.start, match.end);
      }

      final bool hasOwnDecoration =
          baseStyle.decoration != null &&
          baseStyle.decoration != TextDecoration.none;
      TextStyle interactiveBaseStyle = baseStyle.copyWith(
        color: interactiveColor,
        // 🐞 قبلاً همیشه decoration را به‌طورِ اجباری underline/dotted
        // می‌گذاشت — یعنی اگر خودِ کلمه در سندِ Word استایلِ دیگری داشت
        // (یا حتی هیچ decorationای نداشت)، این‌جا از بین می‌رفت. حالا فقط
        // وقتی خودِ span هیچ decorationِ خاصی ندارد، همان زیرخطِ نقطه‌چینِ
        // «قابلِ‌کلیک‌بودن» پیش‌فرض اعمال می‌شود؛ اگر خودِ کلمه از قبل
        // decorationِ واقعی (مثلاً زیرخطِ خودِ Word) داشته باشد، همان حفظ
        // می‌شود.
        // W-2: TextDecoration.none (صفحه همیشه decoration را مقدار می‌دهد، حتی
        // وقتی Word زیرخطی ندارد) هم «بی‌decoration» است؛ وگرنه زیرخطِ نقطه‌چین در
        // صفحه هیچ‌وقت کشیده نمی‌شد و کلمه فقط با رنگ جدا می‌شد.
        decoration: hasOwnDecoration
            ? baseStyle.decoration
            : TextDecoration.underline,
        decorationStyle: hasOwnDecoration
            ? baseStyle.decorationStyle
            : TextDecorationStyle.dotted,
        // 🐞 AS-2: زیرخطِ نقطه‌چینِ «قابلِ‌لمس» هم‌رنگِ خودِ کلمه است. قبلاً اگر پایه
        // decorationColor داشت (صفحه‌ی اسکریپتِ صوتی: رنگِ متن)، زیرخط به رنگِ متنِ
        // عادی کشیده می‌شد و کلمه از بقیه جدا نمی‌شد.
        decorationColor: hasOwnDecoration
            ? baseStyle.decorationColor
            : interactiveColor,
      );

      if (wordMap == null || wordMap.every((v) => v == -1)) {
        spans.add(
          TextSpan(
            text: matchedWord.exactText,
            style: interactiveBaseStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showWordModal(context, matchedWord),
          ),
        );
      } else {
        spans.addAll(
          _sliceInteractiveWord(
            matchedWord,
            wordMap,
            interactiveBaseStyle,
            activeOcc,
            context,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
            allMatchesActive: allMatchesActive,
          ),
        );
      }

      currentIndex = match.end;
    }

    if (currentIndex < content.length) {
      spans.addAll(
        applyMapToText(
          content.substring(currentIndex),
          baseStyle,
          localMap?.sublist(currentIndex),
          activeOcc,
          exactMatchKey: exactMatchKey,
          keyClaim: keyClaim,
          allMatchesActive: allMatchesActive,
        ),
      );
    }

    return spans;
  }

  static List<InlineSpan> _sliceInteractiveWord(
    InteractiveWord word,
    List<int> wordMap,
    TextStyle baseStyle,
    int? activeOcc,
    BuildContext context, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    bool allMatchesActive = false,
  }) {
    List<InlineSpan> spans = [];
    int currentState = wordMap[0];
    String chunk = "";
    String content = word.exactText;

    for (int i = 0; i < content.length; i++) {
      if (wordMap[i] == currentState) {
        chunk += content[i];
      } else {
        spans.add(
          _createInteractiveTextSpan(
            chunk,
            currentState,
            activeOcc,
            baseStyle,
            word,
            context,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
            allMatchesActive: allMatchesActive,
          ),
        );
        chunk = content[i];
        currentState = wordMap[i];
      }
    }
    if (chunk.isNotEmpty) {
      spans.add(
        _createInteractiveTextSpan(
          chunk,
          currentState,
          activeOcc,
          baseStyle,
          word,
          context,
          exactMatchKey: exactMatchKey,
          keyClaim: keyClaim,
          allMatchesActive: allMatchesActive,
        ),
      );
    }
    return spans;
  }

  // 🌟 رفع مشکل اسکرول نادقیق: قبلاً همیشه TextSpan برمی‌گرداند و راهی
  // برای «چسباندن» GlobalKey به دقیقاً همان کلمه‌ی هدف وجود نداشت (چون
  // TextSpan یک Element/RenderObject مستقل ندارد). حالا وقتی این تکه
  // دقیقاً occurrence فعالِ جستجو باشد، آن را در یک WidgetSpan کوچک
  // (با همان استایل) می‌پیچیم تا GlobalKey بتواند به آن وصل شود.
  static InlineSpan _createInteractiveTextSpan(
    String text,
    int state,
    int? activeOcc,
    TextStyle baseStyle,
    InteractiveWord word,
    BuildContext context, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    bool allMatchesActive = false,
  }) {
    TextStyle finalStyle = baseStyle;
    bool isActive = false;
    if (state != -1) {
      isActive = state == activeOcc;
      // 🐞 رفع باگ هایلایت جستجو: داخل مودالِ جای‌خالی، همه‌ی موارد
      // یافت‌شده باید orangeAccent باشند نه فقط دقیقاً همان activeOcc.
      // توجه: isActive (برای منطق exactMatchKey/اسکرول) دست‌نخورده می‌ماند؛
      // فقط رنگ از showAsActive تبعیت می‌کند.
      final bool showAsActive = allMatchesActive || isActive;
      finalStyle = baseStyle.copyWith(
        backgroundColor: showAsActive
            ? Colors.orangeAccent
            : Colors.yellowAccent.withOpacity(0.6),
        color: showAsActive ? Colors.white : Colors.black,
      );
    }

    if (isActive &&
        exactMatchKey != null &&
        keyClaim != null &&
        !keyClaim.used) {
      keyClaim.used = true;
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: KeyedSubtree(
          key: exactMatchKey,
          child: GestureDetector(
            onTap: () => _showWordModal(context, word),
            child: Text(text, style: finalStyle),
          ),
        ),
      );
    }

    return TextSpan(
      text: text,
      style: finalStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _showWordModal(context, word),
    );
  }

  // 🌟 متدی که حالا علاوه بر بیرون کلاس، داخل جای‌خالی هم برای هایلایت‌های داخلی استفاده می‌شود
  static List<InlineSpan> applyMapToText(
    String content,
    TextStyle baseStyle,
    List<int>? localMap,
    int? activeOcc, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    bool allMatchesActive = false,
  }) {
    if (localMap == null || localMap.every((v) => v == -1)) {
      return [TextSpan(text: content, style: baseStyle)];
    }

    List<InlineSpan> spans = [];
    int currentState = localMap[0];
    String chunk = "";

    for (int i = 0; i < content.length; i++) {
      if (localMap[i] == currentState) {
        chunk += content[i];
      } else {
        spans.add(
          _createTextSpan(
            chunk,
            currentState,
            activeOcc,
            baseStyle,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
            allMatchesActive: allMatchesActive,
          ),
        );
        chunk = content[i];
        currentState = localMap[i];
      }
    }
    if (chunk.isNotEmpty) {
      spans.add(
        _createTextSpan(
          chunk,
          currentState,
          activeOcc,
          baseStyle,
          exactMatchKey: exactMatchKey,
          keyClaim: keyClaim,
          allMatchesActive: allMatchesActive,
        ),
      );
    }
    return spans;
  }

  // 🌟 رفع مشکل اسکرول نادقیق: مشابه _createInteractiveTextSpan، اگر این
  // تکه دقیقاً همان occurrence فعالِ جستجو باشد، به‌جای TextSpan ساده،
  // در یک WidgetSpan کوچک پیچیده می‌شود تا بشود GlobalKey دقیق را به آن
  // وصل کرد و اسکرول را دقیقاً روی همین کلمه متوقف کرد (نه ابتدای پاراگراف).
  static InlineSpan _createTextSpan(
    String text,
    int state,
    int? activeOcc,
    TextStyle baseStyle, {
    GlobalKey? exactMatchKey,
    KeyClaim? keyClaim,
    bool allMatchesActive = false,
  }) {
    if (state == -1) return TextSpan(text: text, style: baseStyle);
    bool isActive = state == activeOcc;
    // 🐞 رفع باگ هایلایت جستجو: داخل مودالِ جای‌خالی، همه‌ی موارد یافت‌شده
    // باید orangeAccent باشند نه فقط دقیقاً همان activeOcc. isActive (برای
    // منطق exactMatchKey/اسکرول) دست‌نخورده می‌ماند؛ فقط رنگ از
    // showAsActive تبعیت می‌کند.
    final bool showAsActive = allMatchesActive || isActive;
    final TextStyle finalStyle = baseStyle.copyWith(
      backgroundColor: showAsActive
          ? Colors.orangeAccent
          : Colors.yellowAccent.withOpacity(0.6),
      color: showAsActive ? Colors.white : Colors.black,
    );

    if (isActive &&
        exactMatchKey != null &&
        keyClaim != null &&
        !keyClaim.used) {
      keyClaim.used = true;
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: KeyedSubtree(
          key: exactMatchKey,
          child: Text(text, style: finalStyle),
        ),
      );
    }

    return TextSpan(text: text, style: finalStyle);
  }

  static void _showWordModal(BuildContext context, InteractiveWord word) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // 🌟 دوزبانه: بر اساس زبانِ انتخابی، فیلدهای عربی یا فارسی (با fallback)
        final lang = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(languageProvider);
        final bool ar = lang == 'ar';
        String pick(String arabic, String farsi) => ar
            ? (arabic.isNotEmpty ? arabic : farsi)
            : (farsi.isNotEmpty ? farsi : arabic);
        final String pronounce = pick(word.pronounceAr, word.pronounceFa);
        final String translation = pick(word.translationAr, word.translationFa);
        final String explanation = pick(word.explanationAr, word.explanationFa);
        final String meaningLabel = ar ? 'المعنى' : 'معنی';
        final String explainLabel = ar ? 'الشرح' : 'توضیح';

        // اسکرول‌پذیر: با نوارِ «مرور» روی گوشیِ افقی ممکن است جا کم بیاید.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      word.exactText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        word.cefrLevel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(pronounce, style: const TextStyle(color: Colors.grey)),
                const Divider(),
                Text(
                  "$meaningLabel: $translation",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "$explainLabel: $explanation",
                  style: const TextStyle(fontSize: 14),
                ),
                // 🌟 ST-3: افزودن به واژه‌های مرور (اهمیت، وضعیت، یادداشت).
                const SizedBox(height: 16),
                WordStudyBar(word: word),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InteractiveBlankWord extends StatelessWidget {
  final String hiddenText;
  final TextStyle textStyle;
  final List<int>? blankMap;
  final int? activeOcc;
  final List<InteractiveWord>
  interactives; // 🌟 ۱. لیست کلمات تعاملی برای دیکشنری
  final String? translationFa; // 🌟 ۲. ترجمه فارسی برای لمس طولانی
  final String? translationAr; // 🌟 ۳. ترجمه عربی برای لمس طولانی
  final List<SpanData>? innerSpans;
  // 🌟 محتوای غنیِ جای‌خالی؛ وقتی پر است مودال با buildHiddenRichContent
  // (همان رندرِ صفحه) ساخته می‌شود — جدول، عکس، لیست و … بی‌محدودیت.
  final List<ParagraphData>? hiddenParagraphs;
  // 🌟 TR-2: الگوی آماده‌ی کلماتِ دیکشنریِ کتاب (همان که صفحه دارد). بدونِ آن،
  // کلمات با جستجوی کندِ کلمه‌به‌کلمه پیدا می‌شدند.
  final RegExp? interactivesPattern;
  final Map<String, InteractiveWord>? interactivesByText;
  // 🐞 مارکرهای خودِ اسپنِ جای‌خالی (b/i/u/s/sub/sup/sz:/fn:…). برای این است
  // که بدانیم چه چیزی از قبل داخلِ textStyle «پخته» شده تا هنگامِ ساختنِ
  // استایلِ پایه‌ی InnerSpanها و شماره‌ی لیست همان را خنثی کنیم.
  final List<String>? parentMarkers;
  final GlobalKey? exactMatchKey; // 🌟 فیلد جدید
  // 🐞 رفع باگ شماره‌ی لیست: فقط برای پاراگراف‌های کاملاً-یک-بلانک پر
  // می‌شود (تمرین-۰۵ استایل)؛ در نمای جمع‌شده استفاده نمی‌شود، فقط برای
  // prepend کردن داخل مودالِ بازشده.
  final String? listMarker;

  const InteractiveBlankWord({
    super.key,
    required this.hiddenText,
    required this.textStyle,
    required this.interactives,
    this.blankMap,
    this.activeOcc,
    this.translationFa,
    this.translationAr,
    this.innerSpans,
    this.hiddenParagraphs,
    this.interactivesPattern,
    this.interactivesByText,
    this.parentMarkers,
    this.exactMatchKey, // 🌟 دریافت فیلد
    this.listMarker,
  });

  @override
  Widget build(BuildContext context) {
    // 🌟 همه‌ی occurrenceهای منحصربه‌فردی که داخلِ همین جای‌خالی پنهان‌اند
    // (این عدد مستقل از گروه‌بندیِ ناوبری است؛ مستقیم از روی blankMap محاسبه می‌شود)
    final Set<int> matchedOccurrences =
        blankMap?.where((e) => e >= 0).toSet() ?? const {};
    final int hiddenMatchCount = matchedOccurrences.length;

    // نارنجی = نتیجه‌ی فعالِ جستجو همین‌جاست؛ کهربایی = تطبیقِ غیرفعال هست؛
    // خاکستری = هیچ تطبیقی نیست
    final bool hasActive =
        activeOcc != null && matchedOccurrences.contains(activeOcc!);
    final bool hasAnyMatch = hiddenMatchCount > 0;

    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // 🌟 رفع مشکل جستجو: فقط دکمه‌ای نارنجی می‌شود که ایندکس جستجوی فعال را درون خود داشته باشد
    final bool hasSearchResult =
        blankMap != null && activeOcc != null && blankMap!.contains(activeOcc!);

    final Color buttonColor = hasActive
        ? Colors.orangeAccent
        : (hasAnyMatch
              ? Colors.yellowAccent.withOpacity(0.6)
              : (isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade200));
    final Color iconColor = hasActive
        ? Colors.white
        : ((isDarkTheme ? Colors.grey.shade300 : Colors.grey.shade700));
    final Color? borderColor = hasActive
        ? null // پس‌زمینه‌ی توپُر خودش کافی است؛ حاشیه لازم نیست
        : (hasAnyMatch ? Colors.yellowAccent.withOpacity(0.6) : null);

    // 🌟 H-6: آیکون لنگرِ پاپ‌آپِ جواب هم هست. وقتی پاپ‌آپِ همین آیکون باز است،
    // دکمه رنگِ اصلیِ تم و آیکونِ «چشمِ بسته» می‌گیرد تا معلوم باشد حباب مالِ
    // کدام جای‌خالی است و لمسِ دوباره آن را می‌بندد (رنگِ نارنجیِ جستجو مقدم است).
    // context بیرونی (نه context داخلِ لنگر) به نمایشِ جواب داده می‌شود: داخلِ لنگر
    // با باز/بسته‌شدنِ پاپ‌آپ دوباره ساخته می‌شود و دیکشنریِ داخلِ حباب به یک
    // context پایدار نیاز دارد.
    final Widget content = AnswerPopupAnchor(
      builder: (anchorContext, popup) {
        final bool popupOpen = popup.isOpen && !hasActive;
        final Color bg = popupOpen
            ? Theme.of(anchorContext).colorScheme.primary
            : buttonColor;
        final Color fg = popupOpen ? Colors.white : iconColor;
        return GestureDetector(
          onTap: () => _showHiddenTextModal(context, isDarkTheme, popup),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 2.0,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: borderColor != null && !popupOpen
                  ? Border.all(color: borderColor, width: 2.0)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  popupOpen
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                  color: fg,
                ),
                // 🌟 اگر بیش از یک موردِ یافت‌شده داخلِ همین جای‌خالی باشد، تعدادشان
                // کنارِ آیکون نشان داده می‌شود
                if (hiddenMatchCount > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$hiddenMatchCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    // 🌟 این دقیقاً همان occurrence فعال جستجوست — با GlobalKey دقیق
    // بپیچانش تا اسکرول بتواند مستقیم روی همین آیکون بایستد
    if (exactMatchKey != null) {
      return KeyedSubtree(key: exactMatchKey, child: content);
    }
    return content;
  }

  void _showHiddenTextModal(
    BuildContext context,
    bool isDarkTheme,
    AnswerPopupHandle popup,
  ) {
    // 🌟 جوابِ مخفی با جدول/عکس/…: مسیرِ جدا که همان رندرِ صفحه را به کار
    // می‌برد. جای‌خالی‌های فقط‌متنی (hiddenParagraphs == null) دقیقاً از همان
    // مسیرِ قبلیِ پایین (بنر/بات‌شیت + هایلایتِ جستجو) می‌روند.
    final List<ParagraphData>? richParas = hiddenParagraphs;
    if (richParas != null && richParas.isNotEmpty) {
      // جوابِ جدول/عکس‌دار همیشه «بلند» حساب می‌شود (H-5).
      _presentAnswer(
        context,
        isDarkTheme,
        popup,
        isShort: false,
        rich: true,
        body: (ctx) => _richAnswerBody(ctx, isDarkTheme, richParas),
      );
      return;
    }

    // 🌟 ۱. استخراج متن کامل برای محاسبه طول و بررسی کلمات تعاملی
    String fullText = hiddenText;
    if (innerSpans != null && innerSpans!.isNotEmpty) {
      fullText = innerSpans!.map((span) => span.content).join();
    }
    int textLength = fullText.length;

    // 🌟 ۲. بررسی هوشمند: آیا این متن حاوی کلمه تعاملی (قابل کلیک) هست یا خیر؟
    // 🐞 قبلاً item.toString() (یعنی «Instance of InteractiveWord») جستجو می‌شد و
    // نتیجه همیشه false بود. حالا همان تطبیقِ صفحه: الگوی آماده، وگرنه exactText.
    bool hasInteractiveWords = false;
    if (interactivesPattern != null) {
      hasInteractiveWords = interactivesPattern!.hasMatch(fullText);
    } else if (interactives.isNotEmpty) {
      hasInteractiveWords =
          buildInteractivesPattern(interactives)?.hasMatch(fullText) ?? false;
    }
    // 🌟 ۳. H-5: «جوابِ کوتاه» = متنِ کمتر از ۴۰ نویسه بدونِ لغتِ دیکشنری (همان
    // قانونِ قبلیِ بنر). کوتاه/بلند فقط تعیین می‌کند کدام تنظیمِ کاربر اعمال شود.
    final bool isShortAnswer = textLength < 40 && !hasInteractiveWords;

    // 🐞 رفع بوردر گم‌شده + یکی‌سازی: قبلاً این بخش دو پیاده‌سازیِ تقریباً
    // یکسانِ موازی داشت (یکی همین‌جا برای بنرِ کوتاه با چکِ ضعیف‌ترِ
    // «span.hasBorders == "true"» که چون فیلد HasBorders هیچ‌وقت در JSON
    // ست نمی‌شود همیشه false بود؛ یکی کپیِ ~۱۱۰ خطیِ تقریباً یکسان داخل
    // showModalBottomSheet با چکِ درست‌تر). چون دو نسخه‌ی مستقل بودند، هر
    // بار فقط یکی‌شان اصلاح می‌شد و آن‌یکی regressی می‌ماند. حالا هر دو
    // مسیر (بنرِ کوتاه و بات‌شیتِ بلند) از همینِ یک تابع استفاده می‌کنند.
    // 🐞 منطقِ رندرِ یک InnerSpan (هایلایتِ جستجو + بوردر) که هم در حالتِ
    // مسطح (buildRevealedSpans، برای بنرِ کوتاه) و هم در حالتِ ردیفی
    // (buildNumberedLineGroups، پایین‌تر) لازم است — یک‌جا نگه داشته شده تا
    // دوباره دو نسخه‌ی موازی از منطقِ بوردر/هایلایت drift نکنند (همان
    // اشتباهی که قبلاً باعثِ گم‌شدنِ فیکسِ بوردر شده بود).
    // 🐞 مارکرهای جدید (s/sub/sup) در مودال و بنر:
    // textStyle که از بالادست می‌آید، استایلِ «خودِ اسپنِ جای‌خالی» است — یعنی
    // اگر آن اسپن خط‌خورده/بالانویس/زیرنویس باشد، این استایل از قبل
    // decoration=lineThrough، fontFeatures=['sups'|'subs'] و fontSize×۰٫۷۵
    // دارد. اگر همین را بدونِ خنثی‌سازی به‌عنوانِ پایه به InnerSpanها یا به
    // شماره‌ی لیست بدهیم، آن قالب‌بندی به کلِ متنِ آشکارشده نشت می‌کند
    // (مثلاً یک زیرنویسِ کوچک باعث می‌شود تمامِ متنِ مودال ریز و زیرنویس شود).
    // پس یک پایه‌ی «خنثی» می‌سازیم: قالب‌بندی‌های اجرایی پاک می‌شوند و
    // کوچک‌شدگیِ sub/sup هم برگردانده می‌شود. سپس هر InnerSpan قالب‌بندیِ
    // واقعیِ خودش را از applySpanStyle می‌گیرد.
    final List<String> _pMarkers = parentMarkers ?? const <String>[];
    final bool _parentShrunk =
        _pMarkers.contains("sub") || _pMarkers.contains("sup");
    final TextStyle neutralStyle = textStyle.copyWith(
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      fontFeatures: const <FontFeature>[],
      fontSize: _parentShrunk
          ? (textStyle.fontSize ?? 16.0) / 0.75
          : textStyle.fontSize,
    );

    List<InlineSpan> renderInnerSpan(SpanData span, List<int>? spanMapSlice) {
      TextStyle spanStyle = TextRenderEngine.applySpanStyle(
        neutralStyle,
        span,
        isDarkTheme,
      );
      List<InlineSpan> interactiveSpans = TextRenderEngine.buildInteractiveText(
        span.content,
        interactives,
        context,
        spanStyle,
        localHighlightMap: spanMapSlice,
        activeOccurrence: activeOcc,
        interactivesPattern: interactivesPattern,
        interactivesByText: interactivesByText,
        // 🐞 رفع باگ هایلایت جستجو: وقتی این مودال باز است یعنی این بلانک
        // از قبل «نتیجه‌ی فعالِ» جستجوست (وگرنه آیکون چشمِ نارنجی‌اش تپ
        // نمی‌شد)، پس همه‌ی occurrenceهای یافت‌شده‌ی داخلش باید نارنجی نشان
        // داده شوند، نه فقط اولین‌شان.
        allMatchesActive: true,
      );

      // 🐞 رفع بوردر گم‌شده: تشخیص منعطف‌تر (فلگِ رشته‌ای «true»/«1» یا خودِ
      // آبجکتِ borders)، نه فقط رشته‌ی hasBorders که هیچ‌وقت در JSON ست
      // نمی‌شود.
      final String bordersStr =
          span.hasBorders?.toString().toLowerCase().trim() ?? "false";
      final bool hasBorderFlag = bordersStr == "true" || bordersStr == "1";
      final bool hasBorderObject = span.borders != null;
      final bool isInlineBorder = hasBorderFlag || hasBorderObject;

      if (!isInlineBorder) return interactiveSpans;

      Color? hexToColor(String? hex) {
        if (hex == null || hex.isEmpty || hex.toLowerCase() == 'auto') {
          return null;
        }
        final buffer = StringBuffer();
        if (hex.length == 6 || hex.length == 7) buffer.write('ff');
        buffer.write(hex.replaceFirst('#', ''));
        try {
          return Color(int.parse(buffer.toString(), radix: 16));
        } catch (_) {
          return null;
        }
      }

      return [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            decoration: BoxDecoration(
              color: hexToColor(span.fillColor),
              border: Border.all(
                // 🐞 «auto»ِ سند = مشکی (مثلِ Word)؛ ولی این پنجره تمِ تیره هم
                // دارد و مشکی روی پس‌زمینه‌ی تیره ناپدید می‌شد، پس در تمِ تیره
                // «auto» همان رنگِ متن (سفید) است. خاکستری فقط وقتی سند اصلاً
                // بوردری تعریف نکرده و این جعبه پیش‌فرضِ خودِ اپ است.
                color: span.borders != null
                    ? (hexToColor(span.borders!.color) ??
                          (isDarkTheme ? Colors.white : Colors.black))
                    : Colors.grey.shade600,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text.rich(TextSpan(children: interactiveSpans)),
          ),
        ),
      ];
    }

    // 🐞 پارسِ عددِ پایه‌ی listMarker (مثلاً "1:" → عدد بعدی "2:")، مشترک بین
    // buildRevealedSpans و buildNumberedLineGroups.
    int? parsedNextNumber;
    String parsedSuffix = '';
    if (listMarker != null) {
      final numMatch = RegExp(r'^(\d+)(\D*)$').firstMatch(listMarker!);
      if (numMatch != null) {
        parsedNextNumber = int.parse(numMatch.group(1)!) + 1;
        parsedSuffix = numMatch.group(2) ?? '';
      }
    }

    // 🐞 رفع باگِ «هم‌ترازی خطوطِ برگشتی»: وقتی چند آیتمِ اصلیِ Word (هرکدام
    // با شماره‌ی خودشان) در یک {blk} ادغام شده‌اند، پیش‌تر همه‌شان را در
    // یک Text.rich تخت با «\n» می‌گذاشتیم — کارِ نمایشِ شماره را حل می‌کرد،
    // ولی چون RichText به‌طور بومی hanging-indent ندارد، اگر متنِ یک آیتم
    // بلند بود و wrap می‌خورد، خطِ برگشتی به‌جای هم‌ترازی زیرِ متنِ همان
    // آیتم، به حاشیه‌ی چپِ کل بازمی‌گشت — دقیقاً چیزی که کاربر گزارش کرد
    // (برخلافِ تمرین‌های عادی/غیرِ لیستی که اصلاً چنین انتظاری ندارند).
    // راه‌حل: هر آیتم را در Row جداگانه‌ی خودش می‌گذاریم — [جعبه‌ی
    // ثابت‌عرضِ شماره][Expanded(محتوا)] — دقیقاً همان الگویی که در نمای
    // جمع‌شده برای مارکرِ لیست استفاده می‌شود؛ اینجوری خطِ برگشتیِ هر آیتم
    // طبیعتاً زیرِ ستونِ محتوای همان Row می‌ایستد، نه زیرِ شماره.
    List<MapEntry<String, List<InlineSpan>>>? buildNumberedLineGroups() {
      if (innerSpans == null || innerSpans!.isEmpty) return null;
      final bool hasNewlineBoundary = innerSpans!.any((s) => s.content == "\n");
      if (!hasNewlineBoundary) return null;
      if (listMarker == null || listMarker!.isEmpty) return null;

      final List<MapEntry<String, List<InlineSpan>>> groups = [];
      String currentMarker = listMarker!;
      List<InlineSpan> current = [];
      int innerOffset = 0;
      int? nextNumber = parsedNextNumber;

      int idx = 0;
      while (idx < innerSpans!.length) {
        final span = innerSpans![idx];

        if (span.content == "\n") {
          groups.add(MapEntry(currentMarker, current));
          current = [];
          innerOffset += span.content.length;
          idx++;

          if (nextNumber != null) {
            final String expected = "$nextNumber$parsedSuffix";
            final SpanData? peek = (idx < innerSpans!.length)
                ? innerSpans![idx]
                : null;
            final bool alreadyEmbedded =
                peek != null && peek.content.trimLeft().startsWith(expected);
            if (alreadyEmbedded) {
              // 🐞 مارکرِ این خط از قبل توسطِ استخراج‌کننده‌ی C# به‌عنوانِ یک
              // InnerSpanِ مستقل تزریق شده — همان را به‌جای متن مصرف کن،
              // نه این‌که دوباره از رویِ عدد بسازی‌اش (که تکراری می‌شد).
              currentMarker = peek!.content.trim();
              innerOffset += peek.content.length;
              idx++;
            } else {
              currentMarker = "$nextNumber$parsedSuffix";
            }
            nextNumber = nextNumber + 1;
          } else {
            currentMarker = '';
          }
          continue;
        }

        List<int>? spanMapSlice;
        final int spanLen = span.content.length;
        if (blankMap != null && innerOffset + spanLen <= blankMap!.length) {
          spanMapSlice = blankMap!.sublist(innerOffset, innerOffset + spanLen);
        }
        current.addAll(renderInnerSpan(span, spanMapSlice));
        innerOffset += spanLen;
        idx++;
      }
      groups.add(MapEntry(currentMarker, current));
      return groups;
    }

    // 🐞 صفحه ۱۰ تمرین ۸: اگر محتوای مخفیِ merged پاراگراف‌های تورفته دارد
    // (مارکرِ «pindent:<pt>» روی اولین اسپنِ هر پاراگراف، از C#) و لیستِ
    // شماره‌دار نیست، هر پاراگراف را در بلاکِ جدا با padding واقعی (برابرِ
    // IndentLeftِ سند؛ اپ ۱pt≈۱px رندر می‌کند) می‌سازیم تا تورفتگی دقیقاً مثلِ
    // سند دیده شود — شاملِ خطوطِ wrap‌شده، نه فقط خطِ اول.
    double _parsePindent(SpanData s) {
      for (final m in s.markers) {
        if (m.startsWith("pindent:")) {
          return double.tryParse(m.substring(8)) ?? 0;
        }
      }
      return -1; // مارکرِ pindent ندارد
    }

    // 🐞 درخواستِ کاربر — حذفِ تورفتگیِ اضافه در مودال/بنر (Mindset 2 ص۴۹ تمرین
    // ۱۱): جوابِ BlkPa در سند تورفتگی دارد تا زیرِ متنِ آیتمِ شماره‌دارِ سؤال
    // بنشیند (IndentLeft=14.2). آیکونِ چشم در صفحه باید همان‌جا باشد، ولی در
    // مودال فقط خودِ جواب نشان داده می‌شود و متنِ سؤال نیست؛ پس آن تورفتگی دیگر
    // معنایی ندارد و فقط جواب را بی‌دلیل جلو می‌برد.
    // قاعده: «تورفتگیِ پایه» = کمترین تورفتگیِ بینِ پاراگراف‌های همین جواب، از
    // همه کم می‌شود. جوابِ تک‌پاراگرافی یا یکدست از لبه شروع می‌شود؛ اگر
    // پاراگراف‌های جواب *نسبت به هم* تورفتگیِ متفاوت دارند (مثلاً یک زیربند)،
    // همان اختلاف دقیقاً حفظ می‌شود. (لیستِ شماره‌دارِ داخلِ جواب از مسیرِ
    // buildNumberedLineGroups با تورفتگیِ آویزانِ واقعی رندر می‌شود.)
    List<Widget>? buildIndentedBlocks() {
      if (innerSpans == null || innerSpans!.isEmpty) return null;

      // گذرِ اول: تورفتگیِ هر بلاک (پاراگراف) و تورفتگیِ پایه
      final List<double> blockIndents = [];
      {
        double ind = 0;
        bool started = false;
        for (final span in innerSpans!) {
          if (span.content == "\n") {
            blockIndents.add(ind);
            ind = 0;
            started = false;
            continue;
          }
          final double p = _parsePindent(span);
          if (!started && p >= 0) ind = p;
          started = true;
        }
        blockIndents.add(ind);
      }
      final double baseIndent = blockIndents.reduce((a, b) => a < b ? a : b);
      final bool anyRelativeIndent = blockIndents.any(
        (i) => i - baseIndent > 0.5,
      );
      // بعد از کم‌کردنِ پایه هیچ تورفتگی‌ای نماند → همان مسیرِ تختِ معمولی
      if (!anyRelativeIndent) return null;

      final List<Widget> blocks = [];
      List<InlineSpan> current = [];
      double currentIndent = 0;
      int innerOffset = 0;
      bool started = false;

      void flush() {
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              left: (currentIndent - baseIndent).clamp(0.0, double.infinity),
              bottom: 6,
            ),
            child: Text.rich(
              TextSpan(
                children: current.isEmpty
                    ? [const TextSpan(text: "")]
                    : List.of(current),
              ),
              textAlign: TextAlign.left,
            ),
          ),
        );
        current = [];
        currentIndent = 0;
        started = false;
      }

      for (int idx = 0; idx < innerSpans!.length; idx++) {
        final span = innerSpans![idx];
        if (span.content == "\n") {
          flush();
          innerOffset += span.content.length;
          continue;
        }
        final double pind = _parsePindent(span);
        if (!started && pind >= 0) currentIndent = pind;
        started = true;

        List<int>? spanMapSlice;
        final int spanLen = span.content.length;
        if (blankMap != null && innerOffset + spanLen <= blankMap!.length) {
          spanMapSlice = blankMap!.sublist(innerOffset, innerOffset + spanLen);
        }
        current.addAll(renderInnerSpan(span, spanMapSlice));
        innerOffset += spanLen;
      }
      flush();
      return blocks;
    }

    List<InlineSpan> buildRevealedSpans() {
      List<InlineSpan> spans = [];

      // 🐞 رفع باگ «فقط شماره‌ی خط اول دیده می‌شود»: در فایل Word، هر خط
      // از این‌جور پاراگراف‌ها (مثل تمرین ۰۵ صفحه‌ی ۲۴) اصلاً یک پاراگرافِ
      // جداگانه با numPr خودش بوده (BlankWord2 + همان numId، شماره‌های
      // ۱ تا ۶)، اما استخراجِ C# این ۶ پاراگراف را در یک Content واحد ادغام
      // کرده و بین‌شان یک InnerSpan تک‌کاراکتریِ «\n» گذاشته — و فقط
      // ListMarker همان پاراگرافِ اول ("1:") را نگه داشته. پس اینجا با
      // شمردن همین مرزهای «\n» و افزایشِ عددِ ابتدای listMarker، شماره‌ی
      // خط‌های بعدی را بازسازی می‌کنیم. فقط وقتی listMarker با یک عددِ خالص
      // شروع شود این‌کار انجام می‌شود (مثلاً "1:", "1.")؛ برای مارکرهای
      // غیرعددی (مثل بولت «•» یا حرف «a») دست‌نخورده می‌ماند تا رفتارِ قبلی حفظ
      // شود، چون افزایشِ خودکارِ حرف/بولت معنای مشخصی ندارد.
      int? nextLineNumber = parsedNextNumber;
      String lineMarkerSuffix = parsedSuffix;
      InlineSpan buildLineMarkerSpan() {
        final span = TextSpan(
          text: "$nextLineNumber$lineMarkerSuffix  ",
          // 🐞 شماره‌ی خط از پایه‌ی خنثی ساخته می‌شود تا اگر خودِ جای‌خالی
          // خط‌خورده/بالانویس/زیرنویس بوده، شماره هم خط‌خورده یا ریز نشود.
          style: neutralStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? Colors.white : Colors.black87,
          ),
        );
        nextLineNumber = nextLineNumber! + 1;
        return span;
      }

      if (innerSpans != null && innerSpans!.isNotEmpty) {
        int innerOffset = 0;
        for (int idx = 0; idx < innerSpans!.length; idx++) {
          final span = innerSpans![idx];
          List<int>? spanMapSlice;
          if (blankMap != null) {
            int spanLen = span.content.length;
            if (innerOffset + spanLen <= blankMap!.length) {
              spanMapSlice = blankMap!.sublist(
                innerOffset,
                innerOffset + spanLen,
              );
            }
          }
          spans.addAll(renderInnerSpan(span, spanMapSlice));
          innerOffset += span.content.length;

          // 🐞 اگر این دقیقاً یک مرزِ خطِ تک‌کاراکتریِ «\n» بود (نه یک شکستِ
          // خط داخلِ متنِ یک تکه)، بلافاصله بعدش شماره‌ی خطِ بعدی را
          // prepend کن — مگر اینکه استخراج‌کننده‌ی C# (نسخه‌ی فیکس‌شده) خودش
          // همین مارکر را از قبل داخل InnerSpanِ بعدی گذاشته باشد؛ در آن
          // صورت اضافه‌کردنِ دوباره باعثِ نمایشِ تکراری («2: 2: ...») می‌شود.
          if (span.content == "\n" && nextLineNumber != null) {
            final String expectedMarker = "$nextLineNumber$lineMarkerSuffix";
            final String? nextContent = (idx + 1 < innerSpans!.length)
                ? innerSpans![idx + 1].content.trimLeft()
                : null;
            final bool alreadyEmbedded =
                nextContent != null && nextContent.startsWith(expectedMarker);
            if (!alreadyEmbedded) {
              spans.add(buildLineMarkerSpan());
            } else {
              nextLineNumber = nextLineNumber! + 1;
            }
          }
        }
      } else if (nextLineNumber != null && hiddenText.contains('\n')) {
        // 🐞 همان رفعِ باگ، برای موردی که innerSpans نداریم و فقط hiddenText
        // خام در دسترس است: به‌جای یک فراخوانیِ واحد برای کلِ متن، به ازای
        // هر خط جدا فراخوانی می‌کنیم تا بشود بینِ‌شان شماره prepend کرد؛
        // هایلایتِ جستجو هم به همان نسبت برشِ blankMap با offset دنبال
        // می‌شود تا دقتش از حالتِ قبلی کم نشود.
        int offset = 0;
        final lines = hiddenText.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          List<int>? lineMap;
          if (blankMap != null && offset + line.length <= blankMap!.length) {
            lineMap = blankMap!.sublist(offset, offset + line.length);
          }
          spans.addAll(
            TextRenderEngine.buildInteractiveText(
              line,
              interactives,
              context,
              textStyle.copyWith(
                color: isDarkTheme ? Colors.white : Colors.black87,
                fontSize: textStyle.fontSize ?? 16.0,
                height: 1.6,
              ),
              // W-2: رنگِ کلمه‌ی تعاملی متناسب با زمینه‌ی ظرف (روشن/تیره).
              interactiveColor: interactiveColorOn(
                answerSurfaceColor(isDarkTheme),
                textColor: isDarkTheme ? Colors.white : Colors.black87,
              ),
              localHighlightMap: lineMap,
              activeOccurrence: activeOcc,
              interactivesPattern: interactivesPattern,
              interactivesByText: interactivesByText,
              translationFa: translationFa,
              translationAr: translationAr,
              allMatchesActive: true,
            ),
          );
          offset += line.length + 1; // +۱ برای خودِ کاراکترِ \n
          if (i < lines.length - 1) {
            spans.add(const TextSpan(text: "\n"));
            // 🐞 همان گاردِ idempotency: اگر خطِ بعدی از قبل با همین مارکر
            // شروع شده (JSONِ استخراج‌شده با نسخه‌ی فیکس‌شده‌ی C#)، دوباره
            // prepend نکن.
            final String expectedMarker = "$nextLineNumber$lineMarkerSuffix";
            final bool alreadyEmbedded =
                i + 1 < lines.length &&
                lines[i + 1].trimLeft().startsWith(expectedMarker);
            if (!alreadyEmbedded) {
              spans.add(buildLineMarkerSpan());
            } else {
              nextLineNumber = nextLineNumber! + 1;
            }
          }
        }
      } else {
        spans = TextRenderEngine.buildInteractiveText(
          hiddenText,
          interactives,
          context,
          textStyle.copyWith(
            color: isDarkTheme ? Colors.white : Colors.black87,
            fontSize: textStyle.fontSize ?? 16.0,
            height: 1.6,
          ),
          // W-2
          interactiveColor: interactiveColorOn(
            answerSurfaceColor(isDarkTheme),
            textColor: isDarkTheme ? Colors.white : Colors.black87,
          ),
          localHighlightMap: blankMap,
          activeOccurrence: activeOcc,
          interactivesPattern: interactivesPattern,
          interactivesByText: interactivesByText,
          translationFa: translationFa,
          translationAr: translationAr,
          allMatchesActive: true, // 🐞 همان دلیلِ بالا
        );
      }

      // 🐞 رفع باگ شماره‌ی لیست: listMarker فقط برای پاراگراف‌های
      // کاملاً-یک-بلانک (تمرین-۰۵ استایل) از بالادست پر شده؛ همین‌جا (داخل
      // مودالِ بازشده، نه کنار آیکون چشمِ جمع‌شده) prepend می‌شود.
      if (listMarker != null && listMarker!.isNotEmpty) {
        spans.insert(
          0,
          TextSpan(
            text: "$listMarker  ",
            style: neutralStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : Colors.black87,
            ),
          ),
        );
      }
      return spans;
    }

    // 🌟 H-5/H-7: بدنه‌ی جواب یک‌بار تعریف می‌شود و هر سه ظرف (پاپ‌آپ، بنر، مودال)
    // همان را می‌کشند — پس شماره‌ی لیست، تورفتگی، بوردر و هایلایتِ جستجو در هر سه
    // یکسان است. (قبلاً بنر نسخه‌ی ساده‌تری داشت و شماره‌گذاریِ ردیفی را نمی‌دید.)
    Widget buildTextBody(BuildContext _) {
      final List<MapEntry<String, List<InlineSpan>>>? numberedGroups =
          buildNumberedLineGroups();
      final List<Widget>? indentedBlocks = buildIndentedBlocks();

      // 🐞 رفع باگِ «هم‌ترازی خطوطِ برگشتی»: اگر این پاراگراف واقعاً چند
      // آیتمِ اصلیِ Word ادغام‌شده است (numberedGroups != null)، به‌جای
      // یک Text.rich تخت، هر آیتم را در Row جداگانه‌ی خودش با
      // hanging-indentِ واقعی می‌سازیم؛ در غیرِ این‌صورت (بلانکِ عادی،
      // مثلِ تمرین ۰۲) رفتارِ قبلی دست‌نخورده می‌ماند.
      final Widget revealedContent;
      if (numberedGroups != null && numberedGroups.isNotEmpty) {
        double markerWidth = 24;
        for (final entry in numberedGroups) {
          final tp = TextPainter(
            text: TextSpan(
              text: entry.key,
              style: neutralStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          if (tp.width + 8 > markerWidth) markerWidth = tp.width + 8;
        }
        markerWidth = markerWidth.clamp(24, 64);

        revealedContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in numberedGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: markerWidth,
                      child: Text(
                        entry.key,
                        style: neutralStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkTheme ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: entry.value),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      } else if (indentedBlocks != null && indentedBlocks.isNotEmpty) {
        // 🐞 پاراگراف‌های تورفته (تمرین ۸ صفحه ۱۰): هر کدام بلاکِ جدا با
        // padding واقعی — تورفتگی دقیقاً مثلِ سند، حتی برای خطوطِ wrap‌شده.
        revealedContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: indentedBlocks,
        );
      } else {
        // جوابِ کوتاه وسط‌چین (مثلِ بنرِ قبلی)؛ جوابِ بلند تراز از دو طرف. عرضِ
        // ثابت داده نمی‌شود تا حباب/بنر برای جوابِ کوتاه به اندازه‌ی خودِ متن باشد.
        revealedContent = Text.rich(
          TextSpan(children: buildRevealedSpans()),
          textAlign: isShortAnswer ? TextAlign.center : TextAlign.justify,
        );
      }

      // 🌟 TR-2: ترجمه داخلِ همین ظرف، زیرِ پاسخ — با دکمه‌ی کوچکِ کنارِ متن یا
      // لمسِ طولانی.
      return TranslatableContentWrapper(
        originalContent: revealedContent,
        translationFa: translationFa,
        translationAr: translationAr,
        isDarkMode: isDarkTheme,
        toggle: TranslationToggle.side,
      );
    }

    // 🌟 H-6: عرضِ حبابِ پاپ‌آپ برای جوابِ کوتاه = عرضِ متن (با فونتِ بولد، که
    // پهن‌تر است، به‌علاوه‌ی حاشیه) — تا یک کلمه در حبابی تمام‌عرض گم نشود.
    double? popupWidth;
    if (isShortAnswer) {
      final String marker = (listMarker != null && listMarker!.isNotEmpty)
          ? '$listMarker  '
          : '';
      final tp = TextPainter(
        text: TextSpan(
          text: '$marker$fullText',
          style: neutralStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      popupWidth = tp.width * 1.08 + 28 + 16; // پدینگِ حباب + جا برای جعبه‌های بوردردار
      // TR-2: دکمه‌ی ترجمه کنارِ متن
      if (TranslatableContentWrapper.hasAny(translationFa, translationAr)) {
        popupWidth += kTranslateButtonSideWidth;
      }
      tp.dispose();
    }

    _presentAnswer(
      context,
      isDarkTheme,
      popup,
      isShort: isShortAnswer,
      body: buildTextBody,
      popupWidth: popupWidth,
    );
  }

  /// 🌟 H-5: ظرفِ جواب طبقِ تنظیماتِ کاربر (کوتاه/بلند جدا). پیش از هر نمایش،
  /// پاپ‌آپِ بازِ دیگر بسته می‌شود (داخلِ خودِ ظرف‌ها).
  void _presentAnswer(
    BuildContext context,
    bool isDarkTheme,
    AnswerPopupHandle popup, {
    required bool isShort,
    required WidgetBuilder body,
    bool rich = false,
    double? popupWidth,
  }) {
    AnswerDisplaySettings settings;
    try {
      settings = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(answerDisplayProvider);
    } catch (_) {
      // بیرون از ProviderScope (مثلاً تست): همان پیش‌فرض‌ها
      settings = const AnswerDisplaySettings(
        short: AnswerDisplayNotifier.defaultShort,
        long: AnswerDisplayNotifier.defaultLong,
      );
    }
    // H-9: در حالتِ «چند پاپ‌آپ» بنر/مودال پاپ‌آپ‌های باز را نمی‌بندد (زیرِ آن‌ها
    // می‌مانند و بعد از بستنِ بنر/مودال هنوز سرِ جایشان‌اند).
    final bool closePopups = settings.singlePopup;
    switch (settings.modeFor(isShort: isShort)) {
      case AnswerDisplayMode.popup:
        popup.toggle(
          body: body,
          isDarkTheme: isDarkTheme,
          preferredWidth: popupWidth,
          direction: settings.popupDirection,
          single: settings.singlePopup,
        );
      case AnswerDisplayMode.banner:
        showAnswerBanner(
          context,
          isDarkTheme: isDarkTheme,
          body: body,
          closePopups: closePopups,
        );
      case AnswerDisplayMode.modal:
        showAnswerSheet(
          context,
          isDarkTheme: isDarkTheme,
          body: body,
          rich: rich,
          closePopups: closePopups,
        );
    }
  }

  /// 🌟 بدنه‌ی جوابِ مخفیِ غنی (جدول، عکس، لیست، …): محتوا با
  /// buildHiddenRichContent — یعنی همان _buildParagraphِ صفحه — ساخته می‌شود، با
  /// عرضِ واقعیِ ظرف (مودال، بنر یا پاپ‌آپ) تا جدول‌ها و عکس‌ها درست جا شوند.
  Widget _richAnswerBody(
    BuildContext context,
    bool isDarkTheme,
    List<ParagraphData> paragraphs,
  ) {
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        // در تمِ تیره، محتوا روی یک «کاغذِ» روشن نشسته: رنگ‌های
        // جدول/متن/عکس از سند می‌آیند و برای صفحه‌ی روشن طراحی
        // شده‌اند (متنِ مشکی روی پس‌زمینه‌ی تیره دیده نمی‌شد).
        const double paperPad = 12;
        final double contentWidth = isDarkTheme
            ? constraints.maxWidth - paperPad * 2
            : constraints.maxWidth;
        Widget content = buildHiddenRichContent(
          layoutContext,
          paragraphs,
          contentWidth,
          interactives: interactives,
          interactivesPattern: interactivesPattern,
          interactivesByText: interactivesByText,
        );
        if (isDarkTheme) {
          content = Container(
            padding: const EdgeInsets.all(paperPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: content,
          );
        }
        // TR-2: ترجمه‌ی کلِ پاسخ. اگر پاراگرافِ والد ترجمه ندارد، ترجمه‌ی خودِ
        // پاراگراف‌های پاسخ پشتِ هم (اکسترکتور به آن‌ها جدا ترجمه می‌دهد، G-7).
        String? joined(String? Function(ParagraphData) pick) {
          final parts = [
            for (final p in paragraphs)
              if ((pick(p) ?? '').trim().isNotEmpty) pick(p)!.trim(),
          ];
          return parts.isEmpty ? null : parts.join('\n');
        }

        final bool parentHas = TranslatableContentWrapper.hasAny(
          translationFa,
          translationAr,
        );
        return TranslatableContentWrapper(
          originalContent: content,
          translationFa: parentHas
              ? translationFa
              : joined((p) => p.translationFa),
          translationAr: parentHas
              ? translationAr
              : joined((p) => p.translationAr),
          isDarkMode: isDarkTheme,
          toggle: TranslationToggle.below,
        );
      },
    );
  }
}
