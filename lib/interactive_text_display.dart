import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// 1. مدل داده (Data Model)
class TextSegment {
  final String text;
  final bool isInteractive;
  final String? translation; // ترجمه فارسی
  final String? explanation; // توضیحات تکمیلی

  TextSegment({
    required this.text,
    this.isInteractive = false,
    this.translation,
    this.explanation,
  });
}

class InteractiveTextDisplay extends StatefulWidget {
  const InteractiveTextDisplay({super.key});

  @override
  State<InteractiveTextDisplay> createState() => _InteractiveTextDisplayState();
}

class _InteractiveTextDisplayState extends State<InteractiveTextDisplay> {
  final List<TextSegment> conversationData = [
    TextSegment(text: "Customer: Yes, I'm "),
    TextSegment(
      text: "**(1) looking for a gift**",
      isInteractive: true,
      translation: "دنبال یک هدیه هستم",
      explanation:
          "این عبارت به معنای \"دنبال هدیه گشتن\" یا \"قصد خرید هدیه داشتن\" است.",
    ),
    TextSegment(text: " for my sister. She's going to be 18 next week. "),
    TextSegment(text: "Sales assistant: Do you "),
    TextSegment(
      text: "**(2) have anything particular in mind**",
      isInteractive: true,
      translation: "مورد خاصی در ذهن دارید",
      explanation: "این اصطلاح به معنای \"تصور خاصی از چیزی داشتن\" است.",
    ),
    TextSegment(text: " — a necklace, perhaps?"),
  ];
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('متن تعاملی')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'متن انگلیسی:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _buildInteractiveRichText(context),
            const SizedBox(height: 20),
            // در اینجا می‌توانید ترجمه فارسی غیر تعاملی را قرار دهید
            const Text(
              'نکته: روی عبارات بولد شده کلیک کنید.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // 3. تابع سازنده RichText
  Widget _buildInteractiveRichText(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 16, height: 1.5),
        children: conversationData.map((segment) {
          if (segment.isInteractive) {
            return TextSpan(
              text: segment.text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange, // رنگی متفاوت برای جلب توجه
                decoration:
                    TextDecoration.underline, // زیرخط برای نمایش کلیک‌پذیری
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // نمایش پاپ‌آپ (Popup) با اطلاعات
                  _showPopup(
                    context,
                    segment.translation!,
                    segment.explanation!,
                  );
                },
            );
          } else {
            return TextSpan(
              text: segment.text,
              style: const TextStyle(color: Colors.black87),
            );
          }
        }).toList(),
      ),
    );
  }

  // 4. تابع نمایش پاپ‌آپ (AlertDialog)
  void _showPopup(
    BuildContext context,
    String translation,
    String explanation,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '💡 معنی و توضیحات اصطلاح',
            textDirection: TextDirection.rtl,
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'ترجمه فارسی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(translation, textDirection: TextDirection.rtl),
                const Divider(height: 20),
                Text(
                  'توضیحات تکمیلی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(explanation, textDirection: TextDirection.rtl),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('بستن'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
