import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'book_provider.dart';

class MyBooksScreen extends ConsumerStatefulWidget {
  const MyBooksScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends ConsumerState<MyBooksScreen> {
  @override
  void initState() {
    super.initState();
    // به محض باز شدن صفحه، لیست کتاب‌های خریداری شده از سرور خوانده می‌شود
    Future.microtask(() => ref.read(bookProvider.notifier).fetchMyBooks());
  }

  @override
  Widget build(BuildContext context) {
    final bookState = ref.watch(bookProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('کتاب‌های من')),
      body: bookState.isLoadingBooks
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: bookState.myBooks.length,
              itemBuilder: (context, index) {
                final book = bookState.myBooks[index];
                final int bookId = book['id'];

                final isDownloading = bookState.downloadProgress.containsKey(
                  bookId,
                );
                final progress = bookState.downloadProgress[bookId] ?? 0.0;
                final isDownloaded = bookState.localFilePaths.containsKey(
                  bookId,
                );

                return ListTile(
                  title: Text(book['title']),
                  subtitle: Text('سطح: ${book['cefr_level']}'),
                  trailing: isDownloaded
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ) // فایل آفلاین موجود است
                      : isDownloading
                      ? CircularProgressIndicator(
                          value: progress,
                        ) // در حال دانلود
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            // فرستادن آیدی کتاب و نام فایل برای ذخیره سازی
                            ref
                                .read(bookProvider.notifier)
                                .downloadBook(bookId, 'book_$bookId.zip');
                          },
                        ),
                );
              },
            ),
    );
  }
}
