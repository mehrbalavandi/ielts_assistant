import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart'; // افزوده شد برای شناسایی کلاس‌ها

class BookSearchDelegate extends SearchDelegate<SearchSession?> {
  final WidgetRef ref;
  BookSearchDelegate(this.ref);

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

  void _ensureRetryTimerIfBooksEmpty(List<BookModel> books) {
    if (books.isNotEmpty) {
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
    final availableBooks = ref.read(booksProvider);
    _ensureRetryTimerIfBooksEmpty(
      availableBooks,
    ); // 🌟 اگر هنوز خالی است، تلاشِ دوره‌ای را فعال کن

    // 🌟 یک جستجوی جدید در دو حالت اجرا می‌شود: کوئری عوض شده، یا کوئریِ قبلی
    // روی لیستِ خالیِ کتاب‌ها اجرا شده بود و حالا کتاب‌ها بار شده‌اند (نباید نتیجهٔ
    // «صفر کتاب» برای همیشه کش بماند).
    final bool shouldResearch =
        _cachedSearchFuture == null ||
        _lastSearchQuery != debouncedQuery ||
        (_lastSearchWasOnEmptyBooks && availableBooks.isNotEmpty);

    if (shouldResearch) {
      _lastSearchQuery = debouncedQuery;
      _lastSearchWasOnEmptyBooks = availableBooks.isEmpty;
      _cachedSearchFuture = CrossBookSearchEngine.searchAllBooks(
        debouncedQuery,
        availableBooks,
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
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.indigo),
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
                  Text(
                    'صفحه ${result.pageNumber}',
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
                    query: query,
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
