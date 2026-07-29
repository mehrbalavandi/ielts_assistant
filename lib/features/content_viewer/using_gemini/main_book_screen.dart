import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/paged_book_store.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/book_search_delegate.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/library_screen.dart';

class MainBookScreen extends ConsumerStatefulWidget {
  const MainBookScreen({super.key});

  @override
  ConsumerState<MainBookScreen> createState() => _MainBookScreenState();
}

class _MainBookScreenState extends ConsumerState<MainBookScreen> {
  // 🐞 بازنویسیِ اصلیِ لودِ تنبل: قبلاً این‌جا کلِ کتاب (List<PageData>) یک‌جا
  // await می‌شد. حالا فقط منیفستِ سبکِ index.json (بدونِ محتوای صفحات)
  // await می‌شود — خودِ صفحات فقط وقتی واقعاً دیده شوند از دیسک لود
  // می‌شوند (داخلِ ReadingCanvasScreen/_LazyPage). چون PagedBookStore خودش
  // AudioScripts/AudioLinksIndex را هم همین‌جا (از همان یک‌بار خواندنِ
  // index.json) استخراج می‌کند، دیگر نیازی به فراخوانیِ جداگانه‌ی
  // DocumentLoader.loadAudioScripts/loadAudioLinksIndex نیست.
  PagedBookStore? _pagedBookStore;
  Future<void>? _manifestFuture;
  String? _loadedBookId;

  void _ensureBookLoaded(BookModel book) {
    if (_loadedBookId == book.id && _pagedBookStore != null) return;
    _loadedBookId = book.id;
    _pagedBookStore = PagedBookStore(book: book);
    _manifestFuture = _pagedBookStore!.ensureManifestLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureBookLoaded(activeBook);
    final pagedBookStore = _pagedBookStore!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(activeBook.title, style: const TextStyle(fontSize: 16)),
        actions: [
          // 🐞 دسترسیِ مستقل به پلی‌لیستِ کتاب: قبلاً این دکمه فقط داخلِ
          // نوارِ کوچکِ پلیر بود که تا پخش‌نشدنِ حداقل یک فایل، اصلاً نشان
          // داده نمی‌شد — یعنی برای دیدنِ پلی‌لیست، اول باید یک فایل را پخش
          // می‌کردید. حالا این‌جا، همیشه در AppBar، مستقل از وضعیتِ پخش.
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'پلی‌لیستِ کتاب',
            onPressed: () => showBookAudioPlaylist(context),
          ),
          // 🌟 تعویضِ زبانِ محتوا: فارسی ↔ عربی
          IconButton(
            tooltip: 'تغییر زبان (فارسی/عربی)',
            icon: Text(
              ref.watch(languageProvider) == 'fa' ? 'ع' : 'ف',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => ref.read(languageProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final SearchSession? session = await showSearch<SearchSession?>(
                context: context,
                delegate: BookSearchDelegate(ref),
              );

              if (session != null && context.mounted) {
                final tappedResult =
                    session.results[session.currentIndex] as SearchResult;
                final targetBookId = tappedResult.bookId;

                // تغییر کتاب در صورت نیاز
                if (activeBook.id != targetBookId) {
                  final availableBooks = ref.read(booksProvider);
                  final targetBook = availableBooks.firstWhere(
                    (b) => b.id == targetBookId,
                  );
                  ref.read(activeBookProvider.notifier).state = targetBook;
                }

                if (tappedResult.audioTrackName != null) {
                  // 🐞 این نتیجه از یک اسکریپتِ صوتی آمده — طبقِ خواسته،
                  // به‌جای اسکرول به یک صفحه، دقیقاً مثلِ آیکونِ چشمِ متنِ
                  // مخفی عمل می‌کنیم، ولی این‌بار هدف آیکونِ پخش است: فایلِ
                  // صوتی را resolve و پخش می‌کنیم، به لحظه‌ی دقیقِ کلمه‌ی
                  // یافت‌شده seek می‌کنیم، و پلیرِ کامل را باز می‌کنیم.
                  final resolvedPath = InlineAudioLink.resolveAudioPath(
                    tappedResult.audioTrackName!,
                    activeBook,
                  );
                  await ref
                      .read(audioPlayerProvider.notifier)
                      .playFile(resolvedPath);
                  if (tappedResult.matchedStartMs != null) {
                    ref
                        .read(audioPlayerProvider.notifier)
                        .seek(
                          Duration(milliseconds: tappedResult.matchedStartMs!),
                        );
                  }
                  if (context.mounted) {
                    showCombinedPlayerModal(
                      context,
                      ref,
                      pagedBookStore.audioScripts,
                    );
                  }
                } else {
                  // 🌟 حذف تأخیر (Future.delayed) برای جلوگیری از تداخل استیت‌ها
                  // ریورپاد به صورت خودکار مقادیر را پیگیری کرده و به محض لود شدن
                  // صفحه جدید، نتایج جستجو را اعمال می‌کند.
                  ref.read(activeSearchProvider.notifier).state = session;
                }
              }
            },
          ),
          // IconButton(
          //   icon: const Icon(Icons.library_books_rounded),
          //   onPressed: () {
          //     ref.read(activeSearchProvider.notifier).state = null;
          //     Navigator.pushReplacement(
          //       context,
          //       MaterialPageRoute(builder: (context) => const LibraryScreen()),
          //     );
          //   },
          // ),
        ],
      ),
      // 🐞 رفع باگ: این نوار قبلاً با هر activeSearchProvider غیرِ null نشان
      // داده می‌شد — از جمله SearchSessionِ مصنوعی‌ای که _jumpToAudioLocation
      // (برای «پلی‌لیستِ کتاب») می‌سازد تا فقط از همان مکانیزمِ اسکرول
      // استفاده کند. چون آن SearchSession عمداً query خالی دارد (تا
      // هایلایتِ متن فعال نشود)، همین را برای تشخیصِ «این یک جستجوی واقعی
      // است، نه صرفاً یک پرش» هم به کار می‌بریم.
      bottomNavigationBar:
          searchSession != null && searchSession.query.isNotEmpty
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
      body: FutureBuilder<void>(
        future: _manifestFuture,
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
          if (pagedBookStore.pageCount == 0) {
            return const Center(child: Text("داده‌ای یافت نشد."));
          }
          return ReadingCanvasScreen(
            pagedBookStore: pagedBookStore,
            audioScripts: pagedBookStore.audioScripts,
            precomputedAudioLinksIndex: pagedBookStore.audioLinksIndex,
          );
        },
      ),
    );
  }
}
