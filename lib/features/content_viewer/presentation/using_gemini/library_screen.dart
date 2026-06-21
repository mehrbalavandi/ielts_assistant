import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/login_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_drawer.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/auth_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/book_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "ویترین کتاب‌ها",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(booksProvider.notifier).fetchBooks(),
          ),
          // 🌟 نمایش هوشمند دکمه ورود یا خروج
          if (authState == AuthState.unauthenticated)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: "ورود / ثبت‌نام",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "خروج از حساب",
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
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
                childAspectRatio: 0.55,
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade100,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 50,
                                color: Colors.blueGrey,
                              ),
                            ),
                            // 🌟 برچسب VIP برای کتاب‌های خریداری شده
                            if (book.isPurchased)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "خریداری شده",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

                      // بخش دکمه‌های عملیاتی (نسخه نمونه یا کامل)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 4.0,
                        ),
                        child: _buildActionSection(
                          context,
                          ref,
                          book,
                          authState,
                        ),
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
    AuthState authState,
  ) {
    // در حین دانلود
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

    // 🌟 حالت اول: کتاب خریداری شده است (دسترسی کامل)
    if (book.isPurchased) {
      if (book.isDownloaded) {
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 16),
          label: const Text("مطالعه کامل", style: TextStyle(fontSize: 11)),
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
        icon: const Icon(Icons.cloud_download, size: 16),
        label: const Text("دانلود کامل", style: TextStyle(fontSize: 11)),
        onPressed: () => ref.read(booksProvider.notifier).downloadBook(book),
      );
    }

    // 🌟 حالت دوم: کاربر مهمان است یا کتاب را نخریده (نسخه نمونه)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (book.isDownloaded)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              side: const BorderSide(color: Colors.indigo),
            ),
            onPressed: () {
              ref.read(activeBookProvider.notifier).state = book;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MainBookScreen()),
              );
            },
            child: const Text(
              "مطالعه نمونه",
              style: TextStyle(fontSize: 11, color: Colors.indigo),
            ),
          )
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: () =>
                ref.read(booksProvider.notifier).downloadBook(book),
            child: const Text("دریافت نمونه", style: TextStyle(fontSize: 11)),
          ),

        const SizedBox(height: 4),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 2),
          ),
          onPressed: () {
            if (authState == AuthState.unauthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "برای خرید ابتدا باید وارد حساب کاربری خود شوید.",
                  ),
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            } else {
              // 🌟 اینجا کاربر را به درگاه پرداخت یا صفحه جزئیات خرید هدایت کنید
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("در حال انتقال به صفحه خرید...")),
              );
            }
          },
          child: const Text(
            "خرید کتاب",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
