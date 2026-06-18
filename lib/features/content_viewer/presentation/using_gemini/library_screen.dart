import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_drawer.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 دریافت وضعیت Future (لودینگ، خطا، داده)
    final booksAsyncValue = ref.watch(availableBooksProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "کتابخانه",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // دکمه تازه‌سازی مجدد لیست از API
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(availableBooksProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(), // 🌟 اضافه شدن Drawer

      body: booksAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                "خطا در دریافت اطلاعات:\n$error",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (books) {
          if (books.isEmpty) {
            return const Center(child: Text("هیچ کتابی در سرور یافت نشد."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return GestureDetector(
                onTap: () {
                  ref.read(activeBookProvider.notifier).state = book;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainBookScreen(),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Container(
                            color: Colors.blueGrey.shade100,
                            // 🌟 اینجا در مراحل بعد می‌توانیم از CachedNetworkImage استفاده کنیم
                            child: const Icon(
                              Icons.book,
                              size: 50,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
