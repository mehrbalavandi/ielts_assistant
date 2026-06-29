import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/book_search_delegate.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/library_screen.dart';

class MainBookScreen extends ConsumerWidget {
  const MainBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBook.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final SearchSession? session = await showSearch<SearchSession?>(
                context: context,
                delegate: BookSearchDelegate(ref),
                query: searchSession?.query ?? '',
              );

              if (session != null && context.mounted) {
                final targetBookId =
                    (session.results.first as SearchResult).bookId;
                if (activeBook.id != targetBookId) {
                  // 🌟 اصلاح شد: گرفتن لیست کتاب‌ها از پرووایدرِ API
                  final availableBooks = ref.read(booksProvider);

                  // اگر کتاب پیدا شد، سوییچ کن
                  if (availableBooks.any((b) => b.id == targetBookId)) {
                    final targetBook = availableBooks.firstWhere(
                      (b) => b.id == targetBookId,
                    );

                    // 🌟 اصلاح شد: تغییر مستقیم وضعیت پرووایدر با دات استیت (.state)
                    ref.read(activeBookProvider.notifier).state = targetBook;
                  }
                }
                Future.delayed(const Duration(milliseconds: 200), () {
                  ref.read(activeSearchProvider.notifier).state = session;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_books_rounded),
            onPressed: () {
              // ref.read(activeSearchProvider.notifier).state = null;
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => const LibraryScreen()),
              // );
            },
          ),
        ],
      ),

      bottomNavigationBar: searchSession != null
          ? Container(
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // 🌟 دکمه بعدی (با قابلیت چرخش و تریگر همیشگی)
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.indigo,
                          ),
                          onPressed: () {
                            int nextIdx =
                                (searchSession.currentIndex + 1) %
                                searchSession.results.length;
                            ref
                                .read(activeSearchProvider.notifier)
                                .state = searchSession.copyWith(
                              currentIndex: nextIdx,
                              jumpTrigger:
                                  searchSession.jumpTrigger +
                                  1, // اجبار به اسکرول مجدد
                            );
                          },
                        ),
                        // 🌟 دکمه قبلی (با قابلیت چرخش و تریگر همیشگی)
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.indigo,
                          ),
                          onPressed: () {
                            int prevIdx =
                                (searchSession.currentIndex -
                                    1 +
                                    searchSession.results.length) %
                                searchSession.results.length;
                            ref
                                .read(activeSearchProvider.notifier)
                                .state = searchSession.copyWith(
                              currentIndex: prevIdx,
                              jumpTrigger:
                                  searchSession.jumpTrigger +
                                  1, // اجبار به اسکرول مجدد
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${searchSession.currentIndex + 1} از ${searchSession.results.length}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () =>
                          ref.read(activeSearchProvider.notifier).state = null,
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: FutureBuilder<BookContent>(
        // 🌟 نوع خروجی تغییر کرد
        future: DocumentLoader.loadBookFromJson(activeBook.jsonAssetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.pages.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }

          // 🌟 ارسال صفحات و اسکریپت‌ها به صورت مجزا به بوم نقاشی
          return ReadingCanvasScreen(
            documentPages: snapshot.data!.pages,
            audioScripts: snapshot.data!.audioScripts,
          );
        },
      ),
    );
  }
}
