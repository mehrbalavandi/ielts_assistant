import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

// 🌟 کلاس شمارنده برای ایجاد استایل Chrome-like (نارنجی برای هدف، زرد برای بقیه)
class SearchMatchCounter {
  int current = 0;
  final int? activeTargetIndex;
  SearchMatchCounter({this.activeTargetIndex});
}

class TextRenderEngine {
  static List<InlineSpan> buildInteractiveText(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context,
    TextStyle baseStyle, {
    Color interactiveColor = Colors.blue,
    String? searchQuery,
    SearchMatchCounter? matchCounter,
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
            searchQuery,
            matchCounter,
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
          searchQuery,
          matchCounter,
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
    String? searchQuery,
    SearchMatchCounter? matchCounter,
  ) {
    if (interactives.isEmpty || content.isEmpty) {
      return _highlightSearch(content, baseStyle, searchQuery, matchCounter);
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
        if (bestIndex > 0)
          spans.addAll(
            _highlightSearch(
              remainingText.substring(0, bestIndex),
              baseStyle,
              searchQuery,
              matchCounter,
            ),
          );

        // 🌟 همگام‌سازی استایل کلمات تعاملی با سیستم جستجو
        bool isSearched = false;
        bool isActiveMatch = false;
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          String nWord = _normalizeText(matchedWord.exactText);
          String nQuery = _normalizeText(searchQuery);
          int wordMatchIdx = nWord.indexOf(nQuery);
          while (wordMatchIdx != -1) {
            isSearched = true;
            if (matchCounter != null) {
              if (matchCounter.activeTargetIndex != null &&
                  matchCounter.current == matchCounter.activeTargetIndex)
                isActiveMatch = true;
              matchCounter.current++;
            }
            wordMatchIdx = nWord.indexOf(nQuery, wordMatchIdx + nQuery.length);
          }
        }

        TextStyle intStyle = baseStyle.copyWith(
          color: interactiveColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        );
        if (isSearched) {
          intStyle = intStyle.copyWith(
            backgroundColor: isActiveMatch
                ? Colors.orangeAccent
                : Colors.yellowAccent.withOpacity(0.6),
            color: isActiveMatch ? Colors.white : Colors.black,
          );
        }

        // 🌟 اختصاص دقیق Recognizer برای باز شدن مودال
        spans.add(
          TextSpan(
            text: matchedWord.exactText,
            style: intStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showWordModal(context, matchedWord!),
          ),
        );

        remainingText = remainingText.substring(
          bestIndex + matchedWord.exactText.length,
        );
      } else {
        spans.addAll(
          _highlightSearch(remainingText, baseStyle, searchQuery, matchCounter),
        );
        break;
      }
    }
    return spans;
  }

  static List<InlineSpan> _highlightSearch(
    String text,
    TextStyle baseStyle,
    String? query,
    SearchMatchCounter? matchCounter,
  ) {
    if (query == null || query.trim().isEmpty)
      return [TextSpan(text: text, style: baseStyle)];
    String nText = _normalizeText(text);
    String nQuery = _normalizeText(query);
    if (!nText.contains(nQuery))
      return [TextSpan(text: text, style: baseStyle)];

    List<InlineSpan> spans = [];
    int start = 0;
    int matchIdx = nText.indexOf(nQuery, start);

    while (matchIdx != -1) {
      if (matchIdx > start)
        spans.add(
          TextSpan(text: text.substring(start, matchIdx), style: baseStyle),
        );

      // 🌟 جادوی نارنجی شدن کلمه هدف!
      bool isActive =
          matchCounter != null &&
          matchCounter.activeTargetIndex != null &&
          matchCounter.current == matchCounter.activeTargetIndex;
      Color bgColor = isActive
          ? Colors.orangeAccent
          : Colors.yellowAccent.withOpacity(0.6);
      Color textColor = isActive ? Colors.white : Colors.black;

      spans.add(
        TextSpan(
          text: text.substring(matchIdx, matchIdx + query.length),
          style: baseStyle.copyWith(backgroundColor: bgColor, color: textColor),
        ),
      );

      if (matchCounter != null) matchCounter.current++;
      start = matchIdx + query.length;
      matchIdx = nText.indexOf(nQuery, start);
    }
    if (start < text.length)
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    return spans;
  }

  static String _normalizeText(String text) {
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
    bool isDarkTheme =
        (widget.textStyle.color?.computeLuminance() ?? 0.0) > 0.5;
    Color hiddenBg = isDarkTheme ? Colors.white24 : Colors.black12;
    Color hiddenBorder = isDarkTheme ? Colors.white54 : Colors.black38;
    Color hiddenText = isDarkTheme ? Colors.white70 : Colors.black54;
    Color revealedBg = isDarkTheme
        ? Colors.tealAccent.withOpacity(0.2)
        : Colors.teal.withOpacity(0.1);
    Color revealedBorder = isDarkTheme ? Colors.tealAccent : Colors.teal;
    Color revealedText = isDarkTheme ? Colors.tealAccent : Colors.teal.shade800;

    return GestureDetector(
      onTap: () => setState(() => _isRevealed = !_isRevealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
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
