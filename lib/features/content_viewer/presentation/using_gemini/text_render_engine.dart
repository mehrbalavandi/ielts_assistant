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
    List<int>? localHighlightMap, // نقشه دقیق جایگاه کلمات جستجوشده
    int? activeOccurrence, // شماره نتیجه‌ای که کاربر الان روی آن است
  }) {
    if (content.isEmpty) return [];
    List<InlineSpan> spans = [];

    final RegExp blankRegex = RegExp(r'\{blk\}(.*?)\{/blk\}');
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
    List<int>? localMap,
    int? activeOcc,
  ) {
    if (interactives.isEmpty || content.isEmpty)
      return _applyMapToText(content, baseStyle, localMap, activeOcc);

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
            _applyMapToText(
              remainingText.substring(0, bestIndex),
              baseStyle,
              localMap?.sublist(0, bestIndex),
              activeOcc,
            ),
          );

        bool isSearched = false;
        bool isActiveMatch = false;
        if (localMap != null) {
          var wordMap = localMap.sublist(
            bestIndex,
            bestIndex + matchedWord.exactText.length,
          );
          if (wordMap.any((val) => val != -1)) isSearched = true;
          if (activeOcc != null && wordMap.any((val) => val == activeOcc))
            isActiveMatch = true;
        }

        TextStyle intStyle = baseStyle.copyWith(
          color: interactiveColor,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        );
        if (isSearched)
          intStyle = intStyle.copyWith(
            backgroundColor: isActiveMatch
                ? Colors.orangeAccent
                : Colors.yellowAccent.withOpacity(0.6),
            color: isActiveMatch ? Colors.white : Colors.black,
          );

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
        localMap = localMap?.sublist(bestIndex + matchedWord.exactText.length);
      } else {
        spans.addAll(
          _applyMapToText(remainingText, baseStyle, localMap, activeOcc),
        );
        break;
      }
    }
    return spans;
  }

  static List<InlineSpan> _applyMapToText(
    String content,
    TextStyle baseStyle,
    List<int>? localMap,
    int? activeOcc,
  ) {
    if (localMap == null || localMap.every((v) => v == -1))
      return [TextSpan(text: content, style: baseStyle)];

    List<InlineSpan> spans = [];
    int currentState = localMap[0];
    String chunk = "";

    for (int i = 0; i < content.length; i++) {
      if (localMap[i] == currentState) {
        chunk += content[i];
      } else {
        spans.add(_createTextSpan(chunk, currentState, activeOcc, baseStyle));
        chunk = content[i];
        currentState = localMap[i];
      }
    }
    if (chunk.isNotEmpty)
      spans.add(_createTextSpan(chunk, currentState, activeOcc, baseStyle));
    return spans;
  }

  static TextSpan _createTextSpan(
    String text,
    int state,
    int? activeOcc,
    TextStyle baseStyle,
  ) {
    if (state == -1) return TextSpan(text: text, style: baseStyle);
    bool isActive = state == activeOcc;
    return TextSpan(
      text: text,
      style: baseStyle.copyWith(
        backgroundColor: isActive
            ? Colors.orangeAccent
            : Colors.yellowAccent.withOpacity(0.6),
        color: isActive ? Colors.white : Colors.black,
      ),
    );
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
