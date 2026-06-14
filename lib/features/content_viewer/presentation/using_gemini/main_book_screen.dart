import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/book_search_delegate.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';

class MainBookScreen extends ConsumerWidget {
  const MainBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // گرفتن اطلاعات کتابی که در حال حاضر انتخاب شده است
    final activeBook = ref.watch(activeBookProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBook.title, style: const TextStyle(fontSize: 16)),
        actions: [
          // 🌟 دکمه جستجوی سراسری
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final SearchResult? result = await showSearch<SearchResult?>(
                context: context,
                delegate: BookSearchDelegate(ref),
              );

              if (result != null && context.mounted) {
                // اگر کتاب متفاوت بود، کتاب جدید را لود کن
                if (activeBook.id != result.bookId) {
                  final targetBook = availableBooks.firstWhere(
                    (b) => b.id == result.bookId,
                  );
                  ref
                      .read(activeBookProvider.notifier)
                      .setActiveBook(targetBook);
                }

                // 🌟 با یک تأخیر بسیار کوتاه (برای اطمینان از رندر شدن بوم نقاشی)، دستور پرش را صادر می‌کنیم
                Future.delayed(const Duration(milliseconds: 300), () {
                  ref.read(searchJumpTargetProvider.notifier).state = result;
                });
              }
            },
          ),
          // 🌟 دکمه بازگشت به کتابخانه
          IconButton(
            icon: const Icon(Icons.library_books_rounded),
            tooltip: 'کتابخانه',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LibraryScreen()),
              );
            },
          ),
        ],
      ),
      // لود کردن کتاب بر اساس مسیر داینامیک
      body: FutureBuilder<List<PageData>>(
        future: DocumentLoader.loadBookFromJson(activeBook.jsonAssetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("خطا در بارگذاری: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }

          // پاس دادن صفحات کتاب به بوم نقاشی
          return ReadingCanvasScreen(documentPages: snapshot.data!);
        },
      ),
    );
  }
}
