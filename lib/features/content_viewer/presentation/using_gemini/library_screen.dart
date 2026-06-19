import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_drawer.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/book_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 لیست کتاب‌ها الان مستقیماً از حافظه و با سرعت بالا پر می‌شود
    final books = ref.watch(booksProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "کتاب‌های من",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(booksProvider.notifier)
                .fetchMyBooks(), // همگام‌سازی دستی
          ),
        ],
      ),
      drawer: const AppDrawer(),

      body: books.isEmpty
          ? const Center(child: Text("درحال همگام‌سازی یا لیست خالی است..."))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade100,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Icon(
                            Icons.book,
                            size: 50,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // 🌟 کنترل‌گرهای دانلود و مشاهده
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: _buildActionSection(context, ref, book),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
  ) {
    if (book.isDownloading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: book.downloadProgress,
            color: Colors.indigo,
          ),
          const SizedBox(height: 4),
          Text(
            "${(book.downloadProgress * 100).toStringAsFixed(0)}%",
            style: const TextStyle(fontSize: 11),
          ),
        ],
      );
    }

    if (book.isDownloaded) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
        label: const Text("مطالعه", style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        onPressed: () {
          ref.read(activeBookProvider.notifier).state = book;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MainBookScreen()),
          );
        },
      );
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.cloud_download, size: 18),
      label: const Text("دانلود", style: TextStyle(fontSize: 12)),
      onPressed: () => ref.read(booksProvider.notifier).downloadBook(book),
    );
  }
}
