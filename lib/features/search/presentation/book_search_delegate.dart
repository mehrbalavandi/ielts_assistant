import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart'; // افزوده شد برای شناسایی کلاس‌ها
import 'package:ielts_assistant/features/reader/data/paged_book_store.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

class BookSearchDelegate extends SearchDelegate<SearchSession?> {
  final WidgetRef ref;

  /// 🌟 S-15: کتابِ باز — برای نشان دادنِ درس و مهارتِ هر نتیجه (فهرستِ کتاب).
  final PagedBookStore? store;

  /// 🌟 S-17: نتیجه‌ای که کاربر آخرین بار در صفحه دیده بود (برگشت از صفحه به همین فهرست): در
  /// فهرست هایلایت و به آن اسکرول می‌شود. null = جستجوی تازه.
  SearchResult? _resumeTarget;
  bool _resumeShown = false;

  /// [resume]: جلسه‌ی جستجوی در حالِ پیمایش (S-17)؛ همان عبارت و همان فهرست بی‌جستجوی دوباره.
  /// عبارت را showSearch(query: …) در کادر می‌گذارد.
  BookSearchDelegate(this.ref, {this.store, SearchSession? resume}) {
    if (resume != null && resume.query.isNotEmpty) {
      final List<SearchResult> results =
          resume.results.whereType<SearchResult>().toList();
      _debouncedQuery.value = resume.query;
      _lastSearchQuery = resume.query;
      _cachedSearchFuture = Future.value(results);
      if (resume.currentIndex >= 0 && resume.currentIndex < resume.results.length) {
        final Object? t = resume.results[resume.currentIndex];
        if (t is SearchResult) _resumeTarget = t;
      }
    }
  }

  /// S-15: «درس 1: Relationships · Reading» برای نتیجه‌ی متن، و برای نتیجه‌ی اسکریپتِ صوتی
  /// جای اولین دکمه‌ی همان فایل در کتاب.
  String? _locationOf(SearchResult r) {
    final PagedBookStore? s = store;
    if (s == null || s.outline.isEmpty) return null;
    if (r.audioTrackName != null) {
      for (final entry in s.audioLinksIndex) {
        if (entry.fileName == r.audioTrackName) {
          return outlineLocationLabel(s.outline, entry.pageNumber, entry.paraIndex);
        }
      }
      return null;
    }
    return outlineLocationLabel(s.outline, r.pageNumber, r.paraIndex);
  }

  Timer? _debounce;
  final ValueNotifier<String> _debouncedQuery = ValueNotifier<String>('');

  // 🌟 کَش کردن Future برای جلوگیری از اجرای تکراری جستجو با هر بار Rebuild شدن UI
  Future<List<SearchResult>>? _cachedSearchFuture;
  String _lastSearchQuery = '';
  // 🌟 اگر لیستِ کتاب‌ها هنگامِ آخرین جستجو خالی بود (هنوز از API لود نشده)،
  // آن نتیجه را «قطعی» تلقی نمی‌کنیم — وگرنه جستجوی روی صفر کتاب برای همیشه
  // کش می‌شد و حتی بعد از لود شدنِ کتاب‌ها دوباره اجرا نمی‌شد.
  bool _lastSearchWasOnEmptyBooks = false;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  final ValueNotifier<int> _retryTick = ValueNotifier<int>(0);

  void _ensureRetryTimerIfBookMissing(BookModel? activeBook) {
    if (activeBook != null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempts = 0;
      return;
    }
    if (_retryTimer != null) return; // از قبل در حالِ تلاشِ مجدد است
    _retryAttempts = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      _retryAttempts++;
      if (_retryAttempts > 15) {
        // 🌟 تا ۶ ثانیه صبر می‌کنیم؛ بعد از آن رها می‌کنیم تا کاربر خودش دوباره تایپ کند
        t.cancel();
        _retryTimer = null;
        return;
      }
      _retryTick.value++; // 🌟 باعثِ rebuild و تلاشِ دوباره‌ی جستجو می‌شود
    });
  }

  void _scheduleSearch() {
    if (query.trim() == _debouncedQuery.value)
      return; // جلوگیری از تریگر تکراری

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _debouncedQuery.value = query.trim();
    });
  }

  @override
  String get searchFieldLabel => 'جستجو در کتاب‌ها...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 3) {
      return const Center(child: Text('حداقل ۳ حرف وارد کنید.'));
    }
    _scheduleSearch();
    return _buildDebouncedResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // S-17: برگشت به فهرست ← بی‌صفحه‌کلید، مستقیم فهرستِ نتایج (یک‌بار).
    if (_resumeTarget != null && !_resumeShown) {
      _resumeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showResults(context);
      });
    }
    if (query.trim().length < 3) return const SizedBox.shrink();
    _scheduleSearch();
    return _buildDebouncedResults();
  }

  Widget _buildDebouncedResults() {
    return ValueListenableBuilder<String>(
      valueListenable: _debouncedQuery,
      builder: (context, debouncedQ, _) {
        final bool isPending = debouncedQ != query.trim();
        return Stack(
          children: [
            if (debouncedQ.length >= 3)
              // 🌟 با این ValueListenableBuilder، هر تیکِ retryِ ناشی از خالی‌بودنِ
              // لیستِ کتاب‌ها باعثِ rebuild می‌شود، پس وقتی booksProvider پر شود
              // (که ممکن است بعد از باز شدنِ جستجو از API برسد)، جستجو خودکار
              // دوباره اجرا می‌شود — قبلاً این تیک هیچ‌جا watch نمی‌شد.
              ValueListenableBuilder<int>(
                valueListenable: _retryTick,
                builder: (context, _, __) => _buildSearchResults(debouncedQ),
              ),
            if (isPending)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(String debouncedQuery) {
    final activeBook = ref.read(activeBookProvider);
    _ensureRetryTimerIfBookMissing(activeBook);

    final bool shouldResearch =
        _cachedSearchFuture == null ||
        _lastSearchQuery != debouncedQuery ||
        (_lastSearchWasOnEmptyBooks && activeBook != null);

    if (shouldResearch) {
      _lastSearchQuery = debouncedQuery;
      _lastSearchWasOnEmptyBooks = activeBook == null;
      _cachedSearchFuture = BookSearchEngine.searchAllBooks(
        debouncedQuery,
        activeBook == null ? const [] : [activeBook],
      );
    }

    return FutureBuilder<List<SearchResult>>(
      future: _cachedSearchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطا در جستجو: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('نتیجه‌ای یافت نشد.'));
        }

        final results = snapshot.data!;
        // S-17: برگشت از صفحه ← آخرین نتیجه‌ی دیده‌شده وسطِ فهرست و هایلایت‌شده.
        final int focus = _resumeTarget == null
            ? -1
            : results.indexWhere((r) => identical(r, _resumeTarget));
        return ScrollablePositionedList.builder(
          itemCount: results.length,
          initialScrollIndex: focus < 0 ? 0 : focus,
          initialAlignment: focus <= 0 ? 0 : 0.3,
          itemBuilder: (context, index) {
            final result = results[index];
            final bool isAudioResult = result.audioTrackName != null;
            final bool isLastSeen = index == focus;
            final String? where = _locationOf(result);
            return ListTile(
              selected: isLastSeen,
              selectedTileColor: Colors.indigo.withOpacity(0.10),
              leading: Icon(
                isAudioResult
                    ? Icons.play_circle_fill_rounded
                    : Icons.menu_book,
                color: isAudioResult ? Colors.orangeAccent : Colors.indigo,
              ),
              title: Text(
                result.bookTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🌟 S-15: درس و مهارت، بعد صفحه یا فایلِ صوتی.
                  Text(
                    [
                      if (where != null) where,
                      isAudioResult
                          ? (result.hiddenMatchCount > 1
                                ? 'اسکریپتِ صوتی: ${bidiIsolate(result.audioTrackName!)} (${result.hiddenMatchCount} نتیجه)'
                                : 'اسکریپتِ صوتی: ${bidiIsolate(result.audioTrackName!)}')
                          : 'صفحه ${result.pageNumber}',
                    ].join(' — '),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 11,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      result.matchedExcerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: () {
                final bookResults = results
                    .where((r) => r.bookId == result.bookId)
                    .toList();
                final tappedIndex = bookResults.indexOf(result);
                close(
                  context,
                  SearchSession(
                    // 🐞 S-13: همان عبارتی که واقعاً جستجو شد (بی‌فاصله‌ی اضافه)، نه
                    // متنِ خامِ کادر — وگرنه هایلایتِ نارنجی با نتیجه‌ها هم‌خوان نبود.
                    query: debouncedQuery,
                    results: bookResults,
                    currentIndex: tappedIndex,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void close(BuildContext context, SearchSession? result) {
    _debounce?.cancel();
    _retryTimer?.cancel();
    super.close(context, result);
  }
}
