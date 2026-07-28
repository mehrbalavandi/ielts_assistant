import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/language_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/document_loader.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart';
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
  // 🐞 رفع باگِ اسکریپتِ صوتی: _extractAudioScripts قبلی، پاراگراف‌های
  // *صفحاتِ معمولیِ کتاب* را برای startMs/endMs/audioTrackName می‌گشت — ولی
  // اسکریپتِ صوتی هیچ‌وقت داخلِ محتوای صفحات نبوده (از یک سندِ Word کاملاً
  // جدا می‌آید و مستقیماً به فیلدِ سطحِ‌بالای «AudioScripts» در index.json
  // نوشته می‌شود که loadBookFromJson اصلاً به آن دست نمی‌زند)، پس این تابع
  // همیشه لیستِ خالی برمی‌گرداند — یعنی قابلیتِ هایلایتِ هم‌زمان هیچ‌وقت
  // داده‌ای برای نمایش نداشت. حالا با DocumentLoader.loadAudioScripts که
  // مستقیماً همان فیلد را می‌خواند جایگزین شده.
  Future<List<AudioScriptTrack>>? _audioScriptsFuture;
  // 🐞 شاخصِ لینک‌های صوتی (AudioLinksIndex در index.json): تا پلی‌لیستِ
  // کتاب دیگر نیازی به گشتنِ زنده‌ی محتوایِ همه‌ی صفحاتِ لودشده نداشته
  // باشد — از قبل توسطِ ابزارِ C# محاسبه شده.
  Future<List<AudioLinkEntry>>? _audioLinksIndexFuture;
  String? _loadedBookId;

  void _ensureBookLoaded(String bookId, String jsonAssetPath) {
    if (_loadedBookId == bookId && _pagesFuture != null) return;
    _loadedBookId = bookId;
    _pagesFuture = DocumentLoader.loadBookFromJson(
      jsonAssetPath, // 'assets/data/testbook/index.json',
    );
    _audioScriptsFuture = DocumentLoader.loadAudioScripts(jsonAssetPath);
    _audioLinksIndexFuture = DocumentLoader.loadAudioLinksIndex(jsonAssetPath);
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
          return FutureBuilder<List<AudioScriptTrack>>(
            future: _audioScriptsFuture,
            builder: (context, audioSnapshot) {
              return FutureBuilder<List<AudioLinkEntry>>(
                future: _audioLinksIndexFuture,
                builder: (context, linksSnapshot) {
                  return ReadingCanvasScreen(
                    documentPages: snapshot.data!,
                    // 🐞 تا وقتی اسکریپتِ صوتی لود می‌شود (یا اگر خطا بخورد)، یک
                    // لیستِ خالی کافی است — کلِ صفحه‌ی خواندن نباید منتظرش بماند؛
                    // فقط پلیرِ صوتی موقتاً چیزی برای هایلایت نشان نمی‌دهد.
                    audioScripts: audioSnapshot.data ?? const [],
                    // 🐞 اگر این کتاب هنوز با ابزارِ جدیدِ C# استخراج نشده،
                    // لیست خالی می‌ماند و buildBookAudioPlaylist خودش به
                    // همان اسکنِ زنده‌ی قبلی برمی‌گردد (بدونِ خطا).
                    precomputedAudioLinksIndex: linksSnapshot.data ?? const [],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
