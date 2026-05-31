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
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return const SizedBox(height: 24);
    }

    List<Widget> blockElements = []; // برای نگه داشتن جدول‌ها و عکس‌های خطی
    List<InlineSpan> inlineSpans = []; // برای نگه داشتن متن‌ها

    for (var span in para.spans) {
      if (span.type == "text") {
        inlineSpans.addAll(
          TextRenderEngine.buildInteractiveText(
            span.content,
            para.interactives,
            context,
          ),
        );
      } else if (span.type == "table") {
        // --- پردازش جدول ---
        // ابتدا اگر متن‌هایی قبل از جدول در این پاراگراف بوده، آن‌ها را به بلاک‌ها اضافه می‌کنیم
        if (inlineSpans.isNotEmpty) {
          blockElements.add(_buildRichText(inlineSpans, para.direction));
          inlineSpans = []; // ریست کردن برای متن‌های بعد از جدول
        }

        // اضافه کردن جدول به بلاک‌ها
        blockElements.add(_buildTable(span, context));
      }
    }

    // اضافه کردن متن‌های باقی‌مانده (بعد از جدول یا اگر جدولی نبود)
    if (inlineSpans.isNotEmpty) {
      blockElements.add(_buildRichText(inlineSpans, para.direction));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: para.direction == "RTL"
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: blockElements, // نمایش پشت سر هم متن‌ها و جدول‌ها
      ),
    );
  }

  // متد کمکی برای رندر متن
  Widget _buildRichText(List<InlineSpan> spans, String direction) {
    return RichText(
      textDirection: direction == "RTL" ? TextDirection.rtl : TextDirection.ltr,
      text: TextSpan(
        style: const TextStyle(fontSize: 18, color: Colors.black, height: 1.6),
        children: spans,
      ),
    );
  }

  // متد کمکی برای رندر جدول (فراخوانی بازگشتی)
  Widget _buildTable(SpanData tableSpan, BuildContext context) {
    List<Widget> rowWidgets = [];

    for (var row in tableSpan.tableRows) {
      List<Widget> cellWidgets = [];

      for (var cell in row.cells) {
        // محاسبه عرض سلول (استفاده از Expanded با ضریب فِلِکس یا کانتینر با عرض درصدی)
        // از آنجا که عرض مجازی کانتینر اصلی را قبلاً 800 در نظر گرفتیم:
        double cellWidth = cell.widthPercent != null
            ? 800 * (cell.widthPercent! / 100)
            : 0; // اگر درصد نداشت، می‌توانید از Expanded استفاده کنید

        cellWidgets.add(
          SizedBox(
            width: cellWidth > 0 ? cellWidth : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cell.paragraphs
                  .map((p) => _buildParagraph(p, context))
                  .toList(), // <--- فراخوانی بازگشتی!
            ),
          ),
        );
      }

      rowWidgets.add(
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // سلول‌ها از بالا تراز شوند
          children: cellWidgets,
        ),
      );
    }

    return Column(children: rowWidgets);
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
