import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class TextRenderEngine {
  static List<InlineSpan> buildInteractiveText(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle, {
    Color interactiveColor = Colors.blue,
    String? highlightQuery, // 🌟 اضافه شدن کوئری
  }) {
    if (content.isEmpty) return [];
    List<InlineSpan> spans = [];

    final RegExp blankRegex = RegExp(r'\{blk\}(.*?)\{/blk\}');
    final matches = blankRegex.allMatches(content);
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        String beforeText = content.substring(currentIndex, match.start);
        spans.addAll(
          _processDictionaryWords(
            beforeText,
            interactives,
            context,
            baseStyle,
            interactiveColor,
            highlightQuery,
          ),
        );
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InteractiveBlankWord(
            hiddenText: match.group(1) ?? '',
            textStyle: baseStyle,
          ),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < content.length) {
      spans.addAll(
        _processDictionaryWords(
          content.substring(currentIndex),
          interactives,
          context,
          baseStyle,
          interactiveColor,
          highlightQuery,
        ),
      );
    }
    return spans;
  }

  static List<InlineSpan> _processDictionaryWords(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle,
    Color interactiveColor,
    String? query,
  ) {
    if (interactives.isEmpty || content.isEmpty)
      return _highlightPlainText(content, baseStyle, query); // 🌟

    List<InlineSpan> spans = [];
    String remainingText = content;
    interactives.sort(
      (a, b) => b.exactText.length.compareTo(a.exactText.length),
    );

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
            _highlightPlainText(
              remainingText.substring(0, bestIndex),
              baseStyle,
              query,
            ),
          ); // 🌟

        spans.add(
          TextSpan(
            text: matchedWord.exactText,
            style: baseStyle.merge(
              TextStyle(
                color: interactiveColor,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showWordModal(context, matchedWord!),
          ),
        );
        remainingText = remainingText.substring(
          bestIndex + matchedWord.exactText.length,
        );
      } else {
        spans.addAll(
          _highlightPlainText(remainingText, baseStyle, query),
        ); // 🌟
        break;
      }
    }
    return spans;
  }

  // 🌟 تابع هوشمند برای زرد کردن متن (با پشتیبانی از عربی/فارسی)
  static List<InlineSpan> _highlightPlainText(
    String text,
    TextStyle style,
    String? query,
  ) {
    if (query == null || query.isEmpty)
      return [TextSpan(text: text, style: style)];
    List<InlineSpan> spans = [];

    // نرمال‌سازی برای پیدا کردن جایگاه دقیق بدون خطا
    String normText = text
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('\u200c', ' ');
    String normQuery = query
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('\u200c', ' ');

    int start = 0;
    int matchIdx = normText.indexOf(normQuery, start);

    while (matchIdx != -1) {
      if (matchIdx > start)
        spans.add(
          TextSpan(text: text.substring(start, matchIdx), style: style),
        );
      spans.add(
        TextSpan(
          text: text.substring(
            matchIdx,
            matchIdx + query.length,
          ), // استخراج با حروف بزرگ/کوچک اصلی
          style: style.copyWith(
            backgroundColor: Colors.yellowAccent.withOpacity(0.6),
            color: Colors.black,
          ),
        ),
      );
      start = matchIdx + query.length;
      matchIdx = normText.indexOf(normQuery, start);
    }
    if (start < text.length)
      spans.add(TextSpan(text: text.substring(start), style: style));
    return spans;
  }

  static void _showWordModal(BuildContext context, InteractiveWord word) {
    /* ... (همان کد قبلی مودال لغت) ... */
  }
}

// ============================================================================
// 🌟 ویجت هوشمند جای خالی (Cloze Test Blank)
// ============================================================================
class InteractiveBlankWord extends StatefulWidget {
  final String hiddenText;
  final TextStyle textStyle;

  const InteractiveBlankWord({
    super.key,
    required this.hiddenText,
    required this.textStyle,
  });

  @override
  State<InteractiveBlankWord> createState() => _InteractiveBlankWordState();
}

class _InteractiveBlankWordState extends State<InteractiveBlankWord> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    // 🌟 هوشمندی رنگ‌ها: اگر در مودال تاریک باشیم، پس‌زمینه متن‌ها فرق می‌کند
    bool isDarkTheme =
        (widget.textStyle.color?.computeLuminance() ?? 0.0) > 0.5;

    // رنگ‌های حالت مخفی (خالی)
    Color hiddenBg = isDarkTheme ? Colors.white24 : Colors.black12;
    Color hiddenBorder = isDarkTheme ? Colors.white54 : Colors.black38;
    Color hiddenText = isDarkTheme ? Colors.white70 : Colors.black54;

    // رنگ‌های حالت آشکار شده (مشخص می‌شود که اینجا قبلاً جای خالی بوده)
    Color revealedBg = isDarkTheme
        ? Colors.tealAccent.withOpacity(0.2)
        : Colors.teal.withOpacity(0.1);
    Color revealedBorder = isDarkTheme ? Colors.tealAccent : Colors.teal;
    Color revealedText = isDarkTheme ? Colors.tealAccent : Colors.teal.shade800;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isRevealed = !_isRevealed; // امکان مخفی کردن مجدد با لمس دوباره
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        // وقتی متن آشکار می‌شود، باکس کمی بازتر می‌شود
        padding: EdgeInsets.symmetric(
          horizontal: _isRevealed ? 6.0 : 20.0,
          vertical: 2.0,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: _isRevealed ? revealedBg : hiddenBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isRevealed ? revealedBorder : hiddenBorder,
            width: 1,
          ),
        ),
        child: Text(
          _isRevealed ? widget.hiddenText : "?",
          style: widget.textStyle.copyWith(
            color: _isRevealed ? revealedText : hiddenText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
