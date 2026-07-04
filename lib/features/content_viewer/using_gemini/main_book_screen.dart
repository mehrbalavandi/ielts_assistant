import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/book_search_delegate.dart';

class MainBookScreen extends ConsumerStatefulWidget {
  const MainBookScreen({super.key});

  @override
  ConsumerState<MainBookScreen> createState() => _MainBookScreenState();
}

class _MainBookScreenState extends ConsumerState<MainBookScreen> {
  // 🌟 رفع یک باگ ساختاری مهم:
  //
  // قبلاً این خط مستقیم داخل build() بود:
  //   future: DocumentLoader.loadBookFromJson(activeBook.jsonAssetPath)
  //
  // یعنی هر بار build() اجرا می‌شد یک Future کاملاً تازه ساخته می‌شد.
  // چون این ویجت هم activeSearchProvider را watch می‌کند، هر بار دکمه‌ی
  // بعدی/قبلیِ جستجو زده می‌شد (یا حتی هر جابه‌جایی currentIndex)، کل
  // build() دوباره اجرا و یک Future تازه به FutureBuilder داده می‌شد.
  // FutureBuilder با دیدن یک Future جدید (متفاوت از قبلی)، وضعیتش را
  // ریست می‌کند: یک فریم به ConnectionState.waiting برمی‌گردد (یعنی
  // به‌جای ReadingCanvasScreen موقتاً CircularProgressIndicator نشان
  // می‌دهد)، و چون نوع ویجت در آن نقطه از درخت عوض می‌شود
  // (ReadingCanvasScreen ↔ Center)، فلاتر مجبور می‌شود کل
  // ReadingCanvasScreen (و state داخلی‌اش — GlobalKeyها،
  // ItemScrollController، همه‌ی منطق اسکرول دقیق) را dispose و از نو
  // بسازد؛ درست وسط اسکرول به نتیجه‌ی جستجو! این دقیقاً همان چیزی بود که
  // باعث می‌شد اسکرول دقیق هیچ‌وقت به‌طور پایدار به هدف نرسد.
  //
  // راه‌حل: Future را فقط یک‌بار (و فقط وقتی کتاب واقعاً عوض شود) می‌سازیم
  // و در طول عمر ویجت نگهش می‌داریم.
  Future<BookContent>? _bookContentFuture;
  String? _loadedBookId;

  @override
  Widget build(BuildContext context) {
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadedBookId != activeBook.id) {
      _loadedBookId = activeBook.id;
      _bookContentFuture = DocumentLoader.loadBookFromJson(
        activeBook.jsonAssetPath,
      );
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
                child: Directionality(
                  textDirection: TextDirection.rtl,
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
                            ref.read(activeSearchProvider.notifier).state =
                                null,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: FutureBuilder<BookContent>(
        // 🌟 حالا این Future فقط با تغییر واقعیِ کتاب دوباره ساخته می‌شود
        future: _bookContentFuture,
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
