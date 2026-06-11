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
      // 🌟 تغییر: تغییر تایپ جنریک FutureBuilder از List<ParagraphData> به List<PageData>
      body: FutureBuilder<List<PageData>>(
        future: DocumentLoader.loadBookFromJson(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("خطا در بارگذاری: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }

          // 🌟 تغییر: صدا زدن بوم نقاشی با پارامتر جدید documentPages
          return ReadingCanvasScreen(documentPages: snapshot.data!);
        },
      ),
    );
  }
}
