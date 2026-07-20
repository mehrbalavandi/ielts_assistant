import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart'; // برای دسترسی به TranslatableContentWrapper

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
    GlobalKey? exactMatchKey, // 🌟 اضافه شد
    RegExp? interactivesPattern, // 🌟 اضافه شد: جستجوی سریع کلمات دیکشنری
    Map<String, InteractiveWord>? interactivesByText, // 🌟 اضافه شد
    // 🐞 رفع کرش: اگر تماس‌گیرنده (سطح پاراگراف) یک KeyClaim مشترک بدهد،
    // از همان استفاده کن تا وضعیتِ «مصرف‌شده» بین چند اسپن/سلول جدولِ یک
    // پاراگراف مشترک بماند. اگر داده نشود (مثلاً فراخوانی‌های مستقلِ مودالِ
    // کلمه‌ی مخفی که اصلاً exactMatchKey ندارند)، مثل قبل یکی محلی و
    // یک‌بارمصرف ساخته می‌شود.
    KeyClaim? sharedKeyClaim,
    String? listMarker, // 🌟 اگر پاراگراف مارکرِ لیست دارد، داخلِ مودالِ متنِ مخفی هم نشان داده شود
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
            listMarker: listMarker, // 🌟
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
        ),
      );
    }
    return spans;
  }

  static TextStyle applySpanStyle(TextStyle base, SpanData span, bool isDark) {
    double fontSize = base.fontSize ?? 16.0;

    bool isBold = span.markers.contains("b");
    bool isItalic = span.markers.contains("i");
    bool isUnderline = span.markers.contains("u");

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
      if (span.textColor!.length == 6 || span.textColor!.length == 7)
        buffer.write('ff');
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
      if (span.fillColor!.length == 6 || span.fillColor!.length == 7)
        buffer.write('ff');
      buffer.write(span.fillColor!.replaceFirst('#', ''));
      try {
        bgColor = Color(int.parse(buffer.toString(), radix: 16));
      } catch (_) {}
    }

    return base.copyWith(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
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
  }) {
    if (interactives.isEmpty || content.isEmpty) {
      return applyMapToText(
        content,
        baseStyle,
        localMap,
        activeOcc,
        exactMatchKey: exactMatchKey,
        keyClaim: keyClaim,
      );
    }

    // 🌟 رفع مشکل کندی اسکرول (مسیر سریع): یک عبور خطی با RegExp ترکیبی
    // (که در PageData.fromJson یک‌بار برای کل صفحه ساخته شده) به‌جای اسکن
    // مکرر تمام کلمات دیکشنری به ازای هر موقعیت از متن. این دقیقاً همان
    // معنای «leftmost match، در تساوی طولانی‌ترین کلمه» را حفظ می‌کند،
    // چون کلمات از قبل نزولی بر اساس طول در pattern چیده شده‌اند.
    if (pattern != null && byText != null && byText.isNotEmpty) {
      return _processDictionaryWordsFast(
        content,
        pattern,
        byText,
        context,
        baseStyle,
        interactiveColor,
        localMap,
        activeOcc,
        exactMatchKey: exactMatchKey,
        keyClaim: keyClaim,
      );
    }

    if (interactives.isEmpty)
      return applyMapToText(
        content,
        baseStyle,
        localMap,
        activeOcc,
        exactMatchKey: exactMatchKey,
        keyClaim: keyClaim,
      );

    // ── مسیر قدیمی: فقط وقتی pattern/byText از بیرون پاس داده نشده باشد ──
    // (fallback ایمنی؛ در استفاده‌ی عادی از داخل ReadingCanvasScreen هیچ‌وقت
    // به اینجا نمی‌رسیم چون همیشه pattern پاس داده می‌شود)
    List<InlineSpan> spans = [];
    String remainingText = content;

    while (remainingText.isNotEmpty) {
      int bestIndex = -1;
      InteractiveWord? matchedWord;
      for (var word in interactives) {
        int index = remainingText.indexOf(word.exactText);
        if (index != -1 && (bestIndex == -1 || index < bestIndex)) {
          bestIndex = index;
          matchedWord = word;
        }
      }

      if (bestIndex != -1 && matchedWord != null) {
        if (bestIndex > 0)
          spans.addAll(
            applyMapToText(
              remainingText.substring(0, bestIndex),
              baseStyle,
              localMap?.sublist(0, bestIndex),
              activeOcc,
              exactMatchKey: exactMatchKey,
              keyClaim: keyClaim,
            ),
          );

        List<int>? wordMap;
        if (localMap != null) {
          wordMap = localMap.sublist(
            bestIndex,
            bestIndex + matchedWord.exactText.length,
          );
        }

        TextStyle interactiveBaseStyle = baseStyle.copyWith(
          color: interactiveColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        );

        if (wordMap == null || wordMap.every((v) => v == -1)) {
          spans.add(
            TextSpan(
              text: matchedWord.exactText,
              style: interactiveBaseStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => _showWordModal(context, matchedWord!),
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
            ),
          );
        }

        remainingText = remainingText.substring(
          bestIndex + matchedWord.exactText.length,
        );
        localMap = localMap?.sublist(bestIndex + matchedWord.exactText.length);
      } else {
        spans.addAll(
          applyMapToText(
            remainingText,
            baseStyle,
            localMap,
            activeOcc,
            exactMatchKey: exactMatchKey,
            keyClaim: keyClaim,
          ),
        );
        break;
      }
    }
    return spans;
  }

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
          ),
        );
      }

      List<int>? wordMap;
      if (localMap != null) {
        wordMap = localMap.sublist(match.start, match.end);
      }

      TextStyle interactiveBaseStyle = baseStyle.copyWith(
        color: interactiveColor,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
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
          ),
        );
        chunk = content[i];
        currentState = wordMap[i];
      }
    }
    if (chunk.isNotEmpty)
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
        ),
      );
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
  }) {
    TextStyle finalStyle = baseStyle;
    bool isActive = false;
    if (state != -1) {
      isActive = state == activeOcc;
      finalStyle = baseStyle.copyWith(
        backgroundColor: isActive
            ? Colors.orangeAccent
            : Colors.yellowAccent.withOpacity(0.6),
        color: isActive ? Colors.white : Colors.black,
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
  }) {
    if (localMap == null || localMap.every((v) => v == -1))
      return [TextSpan(text: content, style: baseStyle)];

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
          ),
        );
        chunk = content[i];
        currentState = localMap[i];
      }
    }
    if (chunk.isNotEmpty)
      spans.add(
        _createTextSpan(
          chunk,
          currentState,
          activeOcc,
          baseStyle,
          exactMatchKey: exactMatchKey,
          keyClaim: keyClaim,
        ),
      );
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
  }) {
    if (state == -1) return TextSpan(text: text, style: baseStyle);
    bool isActive = state == activeOcc;
    final TextStyle finalStyle = baseStyle.copyWith(
      backgroundColor: isActive
          ? Colors.orangeAccent
          : Colors.yellowAccent.withOpacity(0.6),
      color: isActive ? Colors.white : Colors.black,
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

        return Padding(
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
                const SizedBox(height: 24),
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
  final GlobalKey? exactMatchKey; // 🌟 فیلد جدید
  final String? listMarker; // 🌟 اگر پاراگراف مارکرِ لیست دارد، داخلِ مودال هم نشان داده شود

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
    this.exactMatchKey, // 🌟 دریافت فیلد
    this.listMarker, // 🌟
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

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

    // 🔍 لاگِ موقتِ تشخیصی — یک‌بار تست کن و خروجیِ کنسول را برایم بفرست تا
    // دقیقاً ببینم کدام مقدار اشتباه است؛ بعد از تشخیص حذفش می‌کنم.
    if (hasAnyMatch) {
      debugPrint(
        '[BLANK-DEBUG] hiddenText="${hiddenText.substring(0, hiddenText.length > 20 ? 20 : hiddenText.length)}" '
        'activeOcc=$activeOcc matchedOccurrences=$matchedOccurrences '
        'hasActive=$hasActive hiddenMatchCount=$hiddenMatchCount',
      );
    }

    final Color buttonColor = isDarkTheme
        ? Colors.grey.shade800
        : Colors.grey.shade200;
    final Color iconColor = isDarkTheme
        ? Colors.grey.shade300
        : Colors.grey.shade700;
    final Color? highlightColor = hasActive
        ? Colors.orangeAccent
        : (hasAnyMatch ? Colors.amber.shade700 : null);

    final Widget content = GestureDetector(
      onTap: () => _showHiddenTextModal(context, isDarkTheme),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(12),
          border: highlightColor != null
              ? Border.all(color: highlightColor, width: 2.0)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_rounded,
              size: 16,
              color: highlightColor ?? iconColor,
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
                  color: highlightColor ?? iconColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // 🌟 این دقیقاً همان occurrence فعال جستجوست — با GlobalKey دقیق
    // بپیچانش تا اسکرول بتواند مستقیم روی همین آیکون بایستد
    if (exactMatchKey != null) {
      return KeyedSubtree(key: exactMatchKey, child: content);
    }
    return content;
  }

  void _showHiddenTextModal(BuildContext context, bool isDarkTheme) {
    // 🌟 ۱. استخراج متن کامل برای محاسبه طول و بررسی کلمات تعاملی
    String fullText = hiddenText;
    if (innerSpans != null && innerSpans!.isNotEmpty) {
      fullText = innerSpans!.map((span) => span.content).join();
    }
    int textLength = fullText.length;

    // 🌟 ۲. بررسی هوشمند: آیا این متن حاوی کلمه تعاملی (قابل کلیک) هست یا خیر؟
    bool hasInteractiveWords = false;
    if (interactives != null && interactives!.isNotEmpty) {
      // بررسی می‌کند آیا هیچ‌کدام از کلمات کلیدی تعاملی در این متن وجود دارند؟
      // نکته: اگر مدل شما فیلد خاصی مثل .targetWord دارد، به جای item از آن استفاده کنید
      hasInteractiveWords = interactives!.any(
        (item) =>
            fullText.toLowerCase().contains(item.toString().toLowerCase()),
      );
    }
    // 🌟 ۳. قانون طلایی: فقط در صورتی بنر بالا باز شود که متن کوتاه باشد و هیچ تعاملی درونش نباشد
    final bool useTopBanner = textLength < 40 && !hasInteractiveWords;
    // متد محلی برای تولید محتوای تعاملی (برای جلوگیری از تکرار کد در دایالوگ و مودال)
    List<InlineSpan> buildRevealedSpans() {
      List<InlineSpan> spans = [];
      // 🌟 اگر این پاراگراف مارکرِ لیست دارد، همان‌جا داخلِ مودال هم نشانش بده
      // (قبلاً فقط بیرونِ آیکونِ چشم نشان داده می‌شد، نه داخلِ متنِ آشکارشده)
      if (listMarker != null && listMarker!.isNotEmpty) {
        spans.add(
          TextSpan(
            text: '$listMarker  ',
            style: textStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : Colors.black87,
            ),
          ),
        );
      }
      if (innerSpans != null && innerSpans!.isNotEmpty) {
        int innerOffset = 0;
        for (var span in innerSpans!) {
          TextStyle spanStyle = TextRenderEngine.applySpanStyle(
            textStyle,
            span,
            isDarkTheme,
          );
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
          List<InlineSpan> interactiveSpans =
              TextRenderEngine.buildInteractiveText(
                span.content,
                interactives,
                context,
                spanStyle,
                localHighlightMap: spanMapSlice,
                activeOccurrence: activeOcc,
              );

          if (span.hasBorders == "true") {
            Color? hexToColor(String? hex) {
              if (hex == null || hex.isEmpty || hex.toLowerCase() == 'auto')
                return null;
              final buffer = StringBuffer();
              if (hex.length == 6 || hex.length == 7) buffer.write('ff');
              buffer.write(hex.replaceFirst('#', ''));
              try {
                return Color(int.parse(buffer.toString(), radix: 16));
              } catch (_) {
                return null;
              }
            }

            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  decoration: BoxDecoration(
                    color: hexToColor(span.fillColor),
                    border: Border.all(
                      color:
                          hexToColor(span.borders?.color) ??
                          Colors.grey.shade600,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text.rich(TextSpan(children: interactiveSpans)),
                ),
              ),
            );
          } else {
            spans.addAll(interactiveSpans);
          }
          innerOffset += span.content.length;
        }
      } else {
        spans.addAll(
          TextRenderEngine.buildInteractiveText(
            hiddenText,
            interactives,
            context,
            textStyle.copyWith(
              color: isDarkTheme ? Colors.white : Colors.black87,
              fontSize: textStyle.fontSize ?? 16.0,
              height: 1.6,
            ),
            localHighlightMap: blankMap,
            activeOccurrence: activeOcc,
            translationFa: translationFa,
            translationAr: translationAr,
          ),
        );
      }
      return spans;
    }

    if (useTopBanner) {
      // 🚀 حالت بنر کشویی از بالا (Top Banner) برای متون کوتاه
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "TopPopup",
        barrierColor: Colors.black45, // رنگ پس‌زمینه نیمه‌شفاف
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 16.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF1E212A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TranslatableContentWrapper(
                          originalContent: Text.rich(
                            TextSpan(children: buildRevealedSpans()),
                            textAlign: TextAlign.center,
                          ),
                          translationFa: translationFa,
                          translationAr: translationAr,
                          isDarkMode: isDarkTheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          // 🌟 جادوی انیمیشن: لغزش از بیرونِ صفحه (بالا) به سمت داخل با افکت فنری
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(
                    0,
                    -1.2,
                  ), // از سقفِ خارج از تصویر شروع می‌شود
                  end: Offset
                      .zero, // در جایگاه تعیین‌شده (کمی پایین‌تر از سقف) می‌ایستد
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack, // افکت زیبای فنری در لحظه توقف
                    reverseCurve: Curves.easeIn,
                  ),
                ),
            child: child,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDarkTheme ? const Color(0xFF1E212A) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          // 🌟 قابلیت اول: رندر کردن متن مخفی با ساختار تعاملی موتور رندر شما (دیکشنری + هایلایت جستجو)
          // چون متن داخل مودال فاقد تگ {blk} است، مستقیماً کلمات تعاملی آن پردازش و بازگردانده می‌شود.
          List<InlineSpan> revealedSpans = [];

          // 🌟 رندر کردن درخت استایل‌ها (همراه با برش‌زنیِ نقطه‌ایِ نقشه جستجو)
          if (innerSpans != null && innerSpans!.isNotEmpty) {
            int innerOffset = 0; // 🌟 شمارنده برای ردیابی موقعیت در نقشه اصلی

            for (var span in innerSpans!) {
              TextStyle spanStyle = TextRenderEngine.applySpanStyle(
                textStyle,
                span,
                isDarkTheme,
              );

              // 🌟 برش زدن دقیق نقشه جستجو به اندازه طول همین تکه از متن
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

              // 🌟 ۱. ابتدا محتوای تعاملی (دیکشنری/هایلایت) را می‌سازیم
              List<InlineSpan> interactiveSpans =
                  TextRenderEngine.buildInteractiveText(
                    span.content,
                    interactives,
                    context,
                    spanStyle,
                    localHighlightMap: spanMapSlice, // 🌟 ارسال برش اختصاصی
                    activeOccurrence: activeOcc,
                  );

              // 🌟 اصلاح اساسی: تشخیص بسیار منعطف‌تر برای رسم باکس اطراف تکه متن
              final String bordersStr =
                  span.hasBorders?.toString().toLowerCase().trim() ?? "false";
              bool hasBorderFlag = bordersStr == "true" || bordersStr == "1";
              bool hasBorderObject = span.borders != null;

              // اگر در JSON به هر شکلی به حاشیه اشاره شده باشد (یا فلگ true باشد یا آبجکت borders وجود داشته باشد)
              bool isInlineBorder = hasBorderFlag || hasBorderObject;

              if (isInlineBorder) {
                // متد کمکی محلی برای تبدیل رنگ Hex
                Color? hexToColor(String? hex) {
                  if (hex == null || hex.isEmpty || hex.toLowerCase() == 'auto')
                    return null;
                  final buffer = StringBuffer();
                  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
                  buffer.write(hex.replaceFirst('#', ''));
                  try {
                    return Color(int.parse(buffer.toString(), radix: 16));
                  } catch (_) {
                    return null;
                  }
                }

                // 🌟 ۳. پیچیدن متن در کانتینرِ کادردار (WidgetSpan)
                revealedSpans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 2.0,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      decoration: BoxDecoration(
                        color: hexToColor(span.fillColor),
                        border: Border.all(
                          color:
                              hexToColor(span.borders?.color) ??
                              Colors.grey.shade600,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      // رندر کردن متن‌های تعاملی درون این کادر
                      child: Text.rich(TextSpan(children: interactiveSpans)),
                    ),
                  ),
                );
              } else {
                // 🌟 اگر بوردر نداشت، مثل قبل مستقیماً به لیست اضافه می‌شود
                revealedSpans.addAll(interactiveSpans);
              }

              innerOffset += span.content.length; // 🌟 حرکت به جلو در نقشه
            }
          } else {
            // 🌟 فال‌بک برای متون ساده یا JSONهای قدیمی
            // 🌟 فال‌بک برای متون ساده یا JSONهای قدیمی
            revealedSpans = TextRenderEngine.buildInteractiveText(
              hiddenText,
              interactives,
              context,
              textStyle.copyWith(
                color: isDarkTheme ? Colors.white : Colors.black87,
                fontSize: textStyle.fontSize ?? 16.0,
                height: 1.6,
              ),
              localHighlightMap: blankMap,
              activeOccurrence: activeOcc,
              translationFa: translationFa,
              translationAr: translationAr,
            );
          }
          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),

                          // 🌟 قابلیت دوم: استفاده از Wrapper اختصاصی شما برای فعال‌سازی لمس طولانی و نمایش ترجمه پاراگراف
                          child: TranslatableContentWrapper(
                            originalContent: Text.rich(
                              TextSpan(children: revealedSpans),
                              textAlign: TextAlign.justify,
                            ),
                            translationFa: translationFa,
                            translationAr: translationAr,
                            isDarkMode: isDarkTheme,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }
}