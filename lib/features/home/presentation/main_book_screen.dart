import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class MainBookScreen extends StatelessWidget {
  const MainBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("IELTS Assistant")),
      body: FutureBuilder<List<ParagraphData>>(
        future: DocumentLoader.loadBookFromJson(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("خطا در بارگذاری: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }

          // اگر داده‌ها موفقیت‌آمیز لود شدند، بوم نقاشی را صدا بزن
          return ReadingCanvasScreen(documentParagraphs: snapshot.data!);
        },
      ),
    );
  }
}
