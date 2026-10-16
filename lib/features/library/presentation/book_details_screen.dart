import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/presentation/book_actions.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';

// 🛍️ SF-1: جزئیاتِ کتاب پیش از دانلودِ نمونه یا خرید — جلد، نویسنده، ناشر، سطح، تعدادِ
// صفحه و فایلِ صوتی، قیمت و توضیح. همه از دادهٔ ذخیره‌شدهٔ ویترین می‌آید، پس آفلاین هم
// کار می‌کند؛ دکمه‌ها همان BookActionSectionِ کارتِ ویترین‌اند (پیشرفتِ دانلود هم زنده).

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BookModel? book = ref.watch(
      booksProvider.select((list) => list.where((b) => b.id == bookId).firstOrNull),
    );
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('این کتاب دیگر در ویترین نیست.')),
      );
    }

    final bool wide = MediaQuery.sizeOf(context).width >= 640;
    final Widget cover = AspectRatio(
      aspectRatio: 3 / 4,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: BookCover(book: book, iconSize: 72),
      ),
    );
    final Widget info = _Info(book: book);
    final Widget actions = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: BookActionSection(book: book, fontSize: 14),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'به‌روزرسانیِ اطلاعات',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(booksProvider.notifier).fetchBooks(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(booksProvider.notifier).fetchBooks(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: cover),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [info, const SizedBox(height: 20), actions],
                    ),
                  ),
                ],
              )
            else ...[
              Center(child: SizedBox(width: 200, child: cover)),
              const SizedBox(height: 20),
              info,
              const SizedBox(height: 20),
              Center(child: actions),
            ],
            if (book.description != null) ...[
              const SizedBox(height: 24),
              const Text(
                'درباره‌ی کتاب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SelectableText(
                book.description!,
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.book});

  final BookModel book;

  @override
  Widget build(BuildContext context) {
    final TextStyle label = TextStyle(color: Colors.grey.shade600, fontSize: 13);
    final List<(IconData, String, String)> rows = [
      if (book.author != null) (Icons.person_outline_rounded, 'نویسنده', book.author!),
      if (book.publisher != null) (Icons.apartment_rounded, 'ناشر', book.publisher!),
      if (book.level != null) (Icons.signal_cellular_alt_rounded, 'سطح', book.level!),
      if (book.categoryTitle != null) (Icons.collections_bookmark_outlined, 'دسته', book.categoryTitle!),
      if ((book.pageCount ?? 0) > 0) (Icons.description_outlined, 'صفحه', '${book.pageCount}'),
      if ((book.audioCount ?? 0) > 0) (Icons.headphones_rounded, 'فایلِ صوتی', '${book.audioCount}'),
      (
        Icons.auto_stories_outlined,
        'نمونه‌ی رایگان',
        book.hasSample || book.isSampleDownloaded ? 'دارد' : 'ندارد',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (book.isPurchased)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'خریداری شده',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        else
          BookPrice(book: book, large: true),
        const SizedBox(height: 16),
        for (final (IconData icon, String name, String value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.indigo.shade300),
                const SizedBox(width: 8),
                SizedBox(width: 96, child: Text(name, style: label)),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
