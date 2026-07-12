import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';

class BookSearchDelegate extends SearchDelegate<SearchSession?> {
  final WidgetRef ref;
  BookSearchDelegate(this.ref);

  Timer? _debounce;
  final ValueNotifier<String> _debouncedQuery = ValueNotifier<String>('');

  void _scheduleSearch() {
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
    if (query.trim().length < 3)
      return const Center(child: Text('حداقل ۳ حرف وارد کنید.'));
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
        final bool isPending =
            debouncedQ != query.trim(); // 🌟 هنوز تایمر تمام نشده
        return Stack(
          children: [
            if (debouncedQ.length >= 3) _buildSearchResults(debouncedQ),
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
    return FutureBuilder<List<SearchResult>>(
      future: CrossBookSearchEngine.searchAllBooks(
        debouncedQuery,
        availableBooks,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
                // فیلتر کردن تمام نتایج همین کتاب برای استفاده در دکمه‌های بعدی/قبلی
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
    super.close(context, result);
  }
}
