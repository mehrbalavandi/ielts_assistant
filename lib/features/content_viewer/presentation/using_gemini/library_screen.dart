import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "کتابخانه",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // نمایش ۲ کتاب در هر ردیف
          childAspectRatio: 0.7, // نسبت ابعاد جلد کتاب
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: availableBooks.length,
        itemBuilder: (context, index) {
          final book = availableBooks[index];
          return GestureDetector(
            onTap: () {
              // ۱. ذخیره کتاب به عنوان کتاب فعال در حافظه و Riverpod
              ref.read(activeBookProvider.notifier).setActiveBook(book);

              // ۲. هدایت به بوم نقاشی
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MainBookScreen()),
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
                      // می‌توانید از Image.asset استفاده کنید
                      child: Container(
                        color: Colors.blueGrey.shade100,
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
      ),
    );
  }
}
