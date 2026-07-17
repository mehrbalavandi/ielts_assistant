import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/book_search_delegate.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/library_screen.dart';

class MainBookScreen extends ConsumerStatefulWidget {
  const MainBookScreen({super.key});

  @override
  ConsumerState<MainBookScreen> createState() => _MainBookScreenState();
}

class _MainBookScreenState extends ConsumerState<MainBookScreen> {
  Future<List<PageData>>? _pagesFuture;
  String? _loadedBookId;

  void _ensureBookLoaded(String bookId, String jsonAssetPath) {
    if (_loadedBookId == bookId && _pagesFuture != null) return;
    _loadedBookId = bookId;
    _pagesFuture = DocumentLoader.loadBookFromJson(
      jsonAssetPath, // 'assets/data/testbook/index.json',
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureBookLoaded(activeBook.id, activeBook.jsonAssetPath);

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
                final targetBookId =
                    (session.results.first as SearchResult).bookId;

                // تغییر کتاب در صورت نیاز
                if (activeBook.id != targetBookId) {
                  final availableBooks = ref.read(booksProvider);
                  final targetBook = availableBooks.firstWhere(
                    (b) => b.id == targetBookId,
                  );
                  ref.read(activeBookProvider.notifier).state = targetBook;
                }

                // 🌟 حذف تأخیر (Future.delayed) برای جلوگیری از تداخل استیت‌ها
                // ریورپاد به صورت خودکار مقادیر را پیگیری کرده و به محض لود شدن
                // صفحه جدید، نتایج جستجو را اعمال می‌کند.
                ref.read(activeSearchProvider.notifier).state = session;
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
      bottomNavigationBar: searchSession != null
          ? Container(
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SafeArea(
                child: Directionality(
                  textDirection: TextDirection.rtl,
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
                            ref.read(activeSearchProvider.notifier).state =
                                null,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: FutureBuilder<List<PageData>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 🌟 اضافه شدن هندل کردن خطا
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "خطا در بارگیری کتاب:\n${snapshot.error}",
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }
          return ReadingCanvasScreen(
            documentPages: snapshot.data!,
            audioScripts: _extractAudioScripts(snapshot.data!),
          );
        },
      ),
    );
  }

  List<ParagraphData> _extractAudioScripts(List<PageData> pages) {
    final scripts = <ParagraphData>[];
    for (final page in pages) {
      for (final para in page.paragraphs) {
        if (para.startMs != null &&
            para.endMs != null &&
            para.audioTrackName != null) {
          scripts.add(para);
        }
      }
    }
    return scripts;
  }
}
