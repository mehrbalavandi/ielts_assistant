import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/data/paged_book_store.dart';
import 'package:ielts_assistant/features/reader/presentation/reading_canvas.dart';
import 'package:ielts_assistant/features/audio/presentation/audio_player_bar.dart';
import 'package:ielts_assistant/features/audio/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/search/presentation/book_search_delegate.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  // 🐞 بازنویسیِ اصلیِ لودِ تنبل: قبلاً این‌جا کلِ کتاب (List<PageData>) یک‌جا
  // await می‌شد. حالا فقط منیفستِ سبکِ index.json (بدونِ محتوای صفحات)
  // await می‌شود — خودِ صفحات فقط وقتی واقعاً دیده شوند از دیسک لود
  // می‌شوند (داخلِ ReadingCanvas/_LazyPage). چون PagedBookStore خودش
  // AudioScripts/AudioLinksIndex را هم همین‌جا (از همان یک‌بار خواندنِ
  // index.json) استخراج می‌کند، دیگر نیازی به فراخوانیِ جداگانه‌ی
  // DocumentLoader.loadAudioScripts/loadAudioLinksIndex نیست.
  PagedBookStore? _pagedBookStore;
  Future<void>? _manifestFuture;
  String? _loadedBookId;

  void _ensureBookLoaded(BookModel book) {
    if (_loadedBookId == book.id && _pagedBookStore != null) return;
    _loadedBookId = book.id;
    // 🐞 اگر کتابِ دیگری قبلاً باز بوده، ایزوله‌ی دائمیِ آن را قبل از
    // جایگزینی آزاد می‌کنیم — وگرنه هر عوض‌کردنِ کتاب یک ایزوله‌ی زنده‌ی
    // بی‌مصرف پشتِ سر می‌گذارد.
    _pagedBookStore?.dispose();
    _pagedBookStore = PagedBookStore(book: book);
    _manifestFuture = _pagedBookStore!.ensureManifestLoaded();
    // 🐞 رفعِ باگِ «نتیجه‌ی جستجوی قدیمی دوباره ظاهر می‌شود»: activeSearchProvider
    // قبلاً هیچ‌وقت با بازشدنِ کتابِ جدید (یا حتی همان کتاب برای بارِ دوم)
    // پاک نمی‌شد — یعنی یک جستجویِ قدیمی از یک بازدیدِ قبلی همچنان می‌ماند.
    // چون این تابع حینِ build() اجرا می‌شود و activeSearchProvider هم در
    // همین build وُچ می‌شود، ریست‌کردنش را با addPostFrameCallback به بعدِ
    // این فریم موکول می‌کنیم (وگرنه «rebuild حینِ build» می‌شود).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(activeSearchProvider) != null) {
        ref.read(activeSearchProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    // 🐞 با بسته‌شدنِ صفحه‌ی کتاب، ایزوله‌ی دائمیِ decode هم باید کشته شود.
    _pagedBookStore?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeBook = ref.watch(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);
    final audioState = ref.watch(audioPlayerProvider);

    if (activeBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _ensureBookLoaded(activeBook);
    final pagedBookStore = _pagedBookStore!;

    // 🐞 باگی که کاربر گرفت: قبلاً هم canPop و هم منطقِ دکمه‌ی back فقط
    // `searchSession != null` را چک می‌کردند، ولی نوارِ جستجو با شرطِ
    // سخت‌گیرانه‌ترِ `query.isNotEmpty` نمایش داده می‌شود. `_jumpToAudioLocation`
    // (برای «پلی‌لیستِ کتاب») یک SearchSessionِ مصنوعی با query خالی می‌سازد تا
    // فقط از مکانیزمِ اسکرول استفاده کند — پس بعد از هر پرشِ صوتی یک سشنِ
    // نامرئی باقی می‌ماند و دکمه‌ی back یک بارِ اضافه «مصرف» می‌شد بدونِ
    // این‌که چیزی روی صفحه بسته شود. حالا هر سه جا از همین یک متغیر
    // استفاده می‌کنند، پس نمی‌توانند از هم واگرا شوند.
    final bool searchBarVisible =
        searchSession != null && searchSession.query.isNotEmpty;

    // 🐞 وقتی در حالتِ جستجو هستیم (نوارِ قبلی/بعدیِ جستجو نمایش داده
    // می‌شود) یا نوارِ کوچکِ پلیرِ صوتی بالای صفحه نمایان است، دکمه‌ی بازِ
    // گوشی باید اول از همان حالت خارج شود، نه این‌که مستقیم کلِ صفحه را
    // pop کند و کاربر را به library_screen ببرد. اگر هر دو هم‌زمان فعال
    // باشند، اول جستجو بسته می‌شود (چون معمولاً کاری است که همین الان
    // رویش تمرکز دارید)، و با بارِ بعدیِ دکمه‌ی برگشت، پلیر بسته می‌شود.
    return PopScope(
      canPop: !searchBarVisible && audioState.currentPath == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (searchBarVisible) {
          ref.read(activeSearchProvider.notifier).state = null;
        } else if (audioState.currentPath != null) {
          ref.read(audioPlayerProvider.notifier).stopAndClear();
          // سشنِ مصنوعیِ نامرئی (اگر مانده باشد) هم همین‌جا پاک می‌شود تا
          // فشارِ بعدیِ back مستقیم به ویترین برود.
          if (searchSession != null) {
            ref.read(activeSearchProvider.notifier).state = null;
          }
        }
      },
      child: Scaffold(
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
              onPressed: () => showBookAudioPlaylist(context, pagedBookStore),
            ),
            // 🌟 دکمه‌ی تعویضِ زبانِ محتوا از این‌جا به دراور منتقل شد
            // (shared/widgets/app_drawer.dart) — کارِ همیشگی‌ای نیست که
            // جای دائمی در نوارِ بالا بگیرد، و آن آیکونِ تک‌حرفیِ «ع/ف» هم
            // خودش را توضیح نمی‌داد.
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                final SearchSession? session = await showSearch<SearchSession?>(
                  context: context,
                  delegate: BookSearchDelegate(ref),
                );

                if (session != null && context.mounted) {
                  // 🐞 رفعِ باگِ «مودالِ صوتی دوبار باز می‌شود»: قبلاً این‌جا
                  // برایِ نتایجِ صوتی مستقیماً openAudioSearchResult صدا زده
                  // می‌شد — ولی خودِ آن تابع activeSearchProvider را هم
                  // آپدیت می‌کند، که چون reading_canvas_screen.dart هم به
                  // همین پرووایدر listen می‌کند و شاخه‌ی صوتیِ خودش را دارد،
                  // دوباره openAudioSearchResult را صدا می‌زد — یعنی مودال دو
                  // بار باز می‌شد. حالا این‌جا فقط state تنظیم می‌شود (دقیقاً
                  // مثلِ نتایجِ متنی)؛ تنها همان listenerِ reading_canvas_screen.dart
                  // تصمیم می‌گیرد چه اتفاقی بیفتد (چه اسکرول به صفحه، چه بازکردنِ پلیر).
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
        // 🐞 همان مشکل، سمتِ پایینِ صفحه: قبلاً این اسلات مستقیماً بینِ
        // Container و null جابه‌جا می‌شد، یعنی نوار در یک فریم ناپدید
        // می‌شد. AnimatedSwitcher نگهش می‌دارد تا انیمیشنِ جمع‌شدن تمام
        // شود (axisAlignment: 1.0 یعنی به‌سمتِ پایین جمع می‌شود، جهتی که
        // با محلِ خودِ نوار جور است). رنگ هم از shade50 به shade100 و یک
        // خطِ ضخیمِ نیلی در لبه‌ی بالا تغییر کرد تا از صفحه‌ی کتاب جدا
        // دیده شود.
        // 🌟 به‌جای پیامِ متنی (که کاربر ترجیح داد نباشد)، خودِ رفتنِ نوار
        // پررنگ‌تر شد: خروج عمداً کندتر از ورود است (۴۲۰ در برابر ۲۲۰
        // میلی‌ثانیه) و علاوه بر جمع‌شدن و محوشدن، نوار به‌سمتِ پایین از
        // صفحه سُر می‌خورد. سه حرکتِ هم‌زمانِ کُند چیزی است که چشم از دست
        // نمی‌دهد؛ محوشدنِ سریع بود که دیده نمی‌شد.
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1.0,
            child: FadeTransition(
              opacity: animation,
              // begin زیرِ صفحه است، پس همین یک Tween هنگامِ ورود نوار را
              // بالا می‌آورد و هنگامِ خروج — که AnimatedSwitcher انیمیشن را
              // برعکس اجرا می‌کند — پایین می‌بَرد؛ بدونِ نیاز به دو بیلدر.
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
          child: searchBarVisible
              ? Container(
                  key: const ValueKey('searchNavBarVisible'),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    border: const Border(
                      top: BorderSide(color: Colors.indigo, width: 3),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
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
                                              .read(
                                                activeSearchProvider.notifier,
                                              )
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
                                              .read(
                                                activeSearchProvider.notifier,
                                              )
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
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                ref.read(activeSearchProvider.notifier).state =
                                    null,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('searchNavBarHidden')),
        ),
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
            return ReadingCanvas(
              pagedBookStore: pagedBookStore,
              audioScripts: pagedBookStore.audioScripts,
              precomputedAudioLinksIndex: pagedBookStore.audioLinksIndex,
            );
          },
        ),
      ),
    );
  }
}
