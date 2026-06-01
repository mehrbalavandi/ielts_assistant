import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/models.dart';

class TextRenderEngine {
  /// این متد یک متن ساده را می‌گیرد، در آن به دنبال کلمات تعاملی می‌گردد
  /// و لیستی از TextSpan ها را برمی‌گرداند.
  static List<InlineSpan> buildInteractiveText(
    String content,
    List<InteractiveWord> interactives,
    BuildContext context, // برای نمایش Modal
    TextStyle baseStyle, // <--- ورودی جدید
  ) {
    if (interactives.isEmpty || content.isEmpty) {
      // تغییر ۱: اعمال baseStyle در حالتی که کلمه تعاملی نداریم
      return [TextSpan(text: content, style: baseStyle)];
    }

    List<InlineSpan> spans = [];
    String remainingText = content;

    // مرتب‌سازی کلمات تعاملی بر اساس طول
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
              style: baseStyle, // اینجا درست بود
            ),
          );
        }

        spans.add(
          TextSpan(
            text: matchedWord.exactText,
            style: baseStyle.merge(
              const TextStyle(
                color: Colors.blue,
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
        // تغییر ۲: اعمال baseStyle به باقی‌مانده متن (دقیقاً جایی که قطع می‌شد)
        spans.add(TextSpan(text: remainingText, style: baseStyle));
        break;
      }
    }
    return spans;
  }

  // نمایش مدال کاستوم هنگام کلیک روی کلمه
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
