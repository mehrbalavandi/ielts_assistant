import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/library_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class MainBookScreen extends ConsumerWidget {
  const MainBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBook = ref.watch(libraryProvider).currentBook;

    if (currentBook == null) {
      //return const SizedBox.shrink();
      ref.read(libraryProvider.notifier).selectBook(availableBooks.first);
      return const Center(child: Text("کتابی یافت نشد."));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentBook.title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // 🌟 خروج از کتاب و بازگشت به کتابخانه
            ref.read(libraryProvider.notifier).closeBook();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: پیاده‌سازی صفحه جستجو در مرحله بعد
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PageData>>(
        future: DocumentLoader.loadBookFromJson(
          currentBook.jsonAssetPath,
        ), // 🌟 مسیر داینامیک
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("خطا در بارگذاری: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }

          return ReadingCanvasScreen(documentPages: snapshot.data!);
        },
      ),
    );
  }
}
