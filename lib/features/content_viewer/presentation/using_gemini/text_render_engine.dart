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
  }) {
    if (content.isEmpty) return [];

    List<InlineSpan> spans = [];

    // 🌟 ۱. ابتدا متن را بر اساس تگ‌های {blk} و {/blk} جستجو و تکه‌تکه می‌کنیم
    final RegExp blankRegex = RegExp(r'\{blk\}(.*?)\{/blk\}');
    final matches = blankRegex.allMatches(content);

    int currentIndex = 0;

    for (final match in matches) {
      // متنی که قبل از جای خالی قرار دارد را به موتور کلمات تعاملی می‌فرستیم
      if (match.start > currentIndex) {
        String beforeText = content.substring(currentIndex, match.start);
        spans.addAll(
          _processDictionaryWords(
            beforeText,
            interactives,
            context,
            baseStyle,
            interactiveColor,
          ),
        );
      }

      // خود جای خالی را به یک ویجت دکمه‌مانند و هوشمند تبدیل می‌کنیم
      String hiddenText = match.group(1) ?? '';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InteractiveBlankWord(
            hiddenText: hiddenText,
            textStyle: baseStyle,
          ),
        ),
      );

      currentIndex = match.end;
    }

    // 🌟 ۲. اگر متنی بعد از آخرین جای خالی باقی مانده بود، آن را هم پردازش می‌کنیم
    if (currentIndex < content.length) {
      String remainingText = content.substring(currentIndex);
      spans.addAll(
        _processDictionaryWords(
          remainingText,
          interactives,
          context,
          baseStyle,
          interactiveColor,
        ),
      );
    }

    return spans;
  }

  // متد کمکی که همان منطق قبلیِ پردازش دیکشنری کلمات تعاملی را دارد
  static List<InlineSpan> _processDictionaryWords(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle,
    Color interactiveColor,
  ) {
    if (interactives.isEmpty || content.isEmpty) {
      return [TextSpan(text: content, style: baseStyle)];
    }

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
        if (bestIndex > 0) {
          spans.add(
            TextSpan(
              text: remainingText.substring(0, bestIndex),
              style: baseStyle,
            ),
          );
        }

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
        spans.add(TextSpan(text: remainingText, style: baseStyle));
        break;
      }
    }
    return spans;
  }

  static void _showWordModal(BuildContext context, InteractiveWord word) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
              Text(
                word.pronounceFa,
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(),
              Text(
                "معنی: ${word.translationFa}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "توضیح: ${word.explanationFa}",
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
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
