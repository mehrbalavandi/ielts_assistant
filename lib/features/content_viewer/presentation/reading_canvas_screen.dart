import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/text_render_engine.dart';
import 'package:ielts_assistant/shared/models/models.dart';

class ReadingCanvasScreen extends StatelessWidget {
  final List<ParagraphData> documentParagraphs; // لیستی که از JSON پارس شده است

  const ReadingCanvasScreen({Key? key, required this.documentParagraphs})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // رنگ پس‌زمینه بیرون از کاغذ
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.5,
        boundaryMargin: const EdgeInsets.all(
          40,
        ), // اجازه اسکرول به بیرون از کادر
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              width: 800, // عرض مجازی ثابت برای تبلت و موبایل
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: documentParagraphs
                    .map((para) => _buildParagraph(para, context))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(ParagraphData para, BuildContext context) {
    // ۱. اگر پاراگراف خالی است (یعنی Enter خالی در Word زده شده)
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return const SizedBox(height: 24); // فاصله عمودی
    }

    // ۲. پردازش اسپن‌های پاراگراف (متن‌ها و جای‌خالی‌ها)
    List<InlineSpan> inlineSpans = [];

    for (var span in para.spans) {
      if (span.type == "text") {
        // تشخیص جای خالی (Cloze Test)
        if (span.markers.contains("blank")) {
          inlineSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _buildBlankWidget(
                span.content,
              ), // ویجت کاستوم شما برای جای خالی
            ),
          );
        } else {
          // متن معمولی که ممکن است دارای کلمات تعاملی باشد
          inlineSpans.addAll(
            TextRenderEngine.buildInteractiveText(
              span.content,
              para.interactives,
              context,
            ),
          );
        }
      }
      // مدیریت عکس‌ها، جدول‌ها و غیره ...
    }

    // ۳. رندر نهایی پاراگراف به همراه دکمه ترجمه کل پاراگراف
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: para.direction == "RTL"
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          RichText(
            textDirection: para.direction == "RTL"
                ? TextDirection.rtl
                : TextDirection.ltr,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black,
                height: 1.6,
              ),
              children: inlineSpans,
            ),
          ),

          // دکمه کوچک برای نمایش ترجمه کل پاراگراف (در صورت وجود)
          if (para.translationFa != null && para.translationFa!.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(
                  Icons.g_translate,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  // نمایش ترجمه کل پاراگراف در یک SnackBar یا Dialog
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(para.translationFa!)));
                },
              ),
            ),
        ],
      ),
    );
  }

  // ویجت جای خالی (Cloze Test)
  Widget _buildBlankWidget(String hiddenAnswer) {
    return GestureDetector(
      onTap: () {
        // تغییر استیت با Riverpod برای نمایش جواب
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Text(
          "     ",
          style: TextStyle(letterSpacing: 2),
        ), // یا نمایش hiddenAnswer اگر استیت true است
      ),
    );
  }
}
