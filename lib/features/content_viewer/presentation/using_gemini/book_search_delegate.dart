import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/cross_book_search_engine.dart';

class BookSearchDelegate extends SearchDelegate<SearchResult?> {
  final WidgetRef ref;

  BookSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'جستجو در تمام کتاب‌ها...';

  // تغییر فونت و استایل فیلد جستجو (اختیاری)
  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);

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
      icon: const AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: kAlwaysCompleteAnimation,
      ),
      onPressed: () => close(context, null), // بستن صفحه جستجو
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 3) {
      return const Center(child: Text('لطفاً حداقل ۳ حرف وارد کنید.'));
    }
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 3) return const SizedBox.shrink();
    return _buildSearchResults(); // جستجوی در لحظه هنگام تایپ (Live Search)
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<SearchResult>>(
      future: CrossBookSearchEngine.searchAllBooks(query, availableBooks),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('خطا: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                  const SizedBox(height: 4),
                  // نمایش متن انگلیسی یافته شده به صورت چپ‌چین
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      result.matchedExcerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // با زدن روی نتیجه، آن را به صفحه قبل (MainBookScreen) برمی‌گردانیم
                close(context, result);
              },
            );
          },
        );
      },
    );
  }
}
