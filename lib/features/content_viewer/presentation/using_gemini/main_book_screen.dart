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
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    if (activeBook == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));//

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
              );
              if (session != null && context.mounted) {
                // اگر کاربر کتاب دیگری را انتخاب کرده بود، سوییچ کن
                final targetBookId =
                    (session.results.first as SearchResult).bookId;
                if (activeBook.id != targetBookId) {
                  final targetBook = availableBooks.firstWhere(
                    (b) => b.id == targetBookId,
                  );
                  ref
                      .read(activeBookProvider.notifier)
                      .setActiveBook(targetBook);
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
              ref.read(activeSearchProvider.notifier).state = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LibraryScreen()),
              );
            },
          ),
        ],
      ),

      // 🌟 نوار حرفه‌ای ناوبری بین نتایج جستجو در پایین صفحه
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
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.indigo,
                          ),
                          onPressed:
                              searchSession.currentIndex <
                                  searchSession.results.length - 1
                              ? () =>
                                    ref
                                        .read(activeSearchProvider.notifier)
                                        .state = searchSession.copyWith(
                                      currentIndex:
                                          searchSession.currentIndex + 1,
                                    )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.indigo,
                          ),
                          onPressed: searchSession.currentIndex > 0
                              ? () =>
                                    ref
                                        .read(activeSearchProvider.notifier)
                                        .state = searchSession.copyWith(
                                      currentIndex:
                                          searchSession.currentIndex - 1,
                                    )
                              : null,
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

      body: FutureBuilder<List<PageData>>(
        future: DocumentLoader.loadBookFromJson(activeBook.jsonAssetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text("داده‌ای یافت نشد."));
          return ReadingCanvasScreen(documentPages: snapshot.data!);
        },
      ),
    );
  }
}
