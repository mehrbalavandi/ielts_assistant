import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/login_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/app_drawer.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/auth_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  void initState() {
    super.initState();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _openLastBook();
    // });
  }

  Future<void> _openLastBook() async {
    final lastBookId = StorageService.getLastBookId();
    if (lastBookId == null) return;
    // کمی صبر می‌کنیم تا fetchBooks انجام شود
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final books = ref.read(booksProvider);
    final book = books.where((e) => e.id == lastBookId).firstOrNull;
    if (book == null) return;
    ref.read(activeBookProvider.notifier).state = book;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainBookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    final authState = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = switch (width) {
      < 300 => 1,
      < 600 => 2,
      < 900 => 3,
      < 1200 => 4,
      _ => 5,
    };
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
          if (authState == AuthState.unauthenticated)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: "ورود / ثبت‌نام",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "خروج از حساب",
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
        ],
      ),
      drawer: const AppDrawer(),

      body: Column(
        children: [
          // 🌟 نوار هشدار وضعیت مهمان / آفلاین
          if (authState == AuthState.unauthenticated)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepOrange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "شما در حالت مهمان/آفلاین هستید. برای بروزرسانی لیست و دسترسی به کتاب‌های خریداری شده، وارد حساب خود شوید.",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: books.isEmpty
                ? const Center(
                    child: Text("درحال همگام‌سازی یا لیست خالی است..."),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];

                      // 🌟 بررسی اینکه آیا کاربر اصلاً شرایط رفتن به بوم نقاشی را دارد یا خیر
                      bool canOpenCanvas =
                          (book.isPurchased && book.isJsonDownloaded) ||
                          (!book.isPurchased && book.isSampleDownloaded);

                      return GestureDetector(
                        onTap: canOpenCanvas
                            ? () {
                                StorageService.saveLastBookId(book.id);
                                // 🌟 انتقال به صفحه مطالعه با ضربه روی هر جای کارت (در صورت آماده بودن فایل)
                                ref.read(activeBookProvider.notifier).state =
                                    book;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainBookScreen(),
                                  ),
                                );
                              }
                            : null,
                        child: Card(
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
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_rounded,
                                        size: 50,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
    AuthState authState,
  ) {
    // --- ۱. حالت در حال دانلود ---
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

    // --- ۲. حالت کتاب خریداری شده (نسخه اصلی) ---
    if (book.isPurchased) {
      if (book.isJsonDownloaded) {
        // 🌟 تغییر از isDownloaded به isJsonDownloaded
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 14,
              ),
              label: const Text("مطالعه کامل", style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: () {
                ref.read(activeBookProvider.notifier).state = book;

                StorageService.saveLastBookId(book.id);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MainBookScreen()),
                );
              },
            ),
            // نمایش دکمه آپدیت فقط در صورت وجود نسخه جدید برای فایل‌های اصلی
            if (book
                .hasAnyMainUpdate) // 🌟 تغییر از hasAnyUpdate به hasAnyMainUpdate
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.0),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text(
                      "به‌روزرسانی محتوا",
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    onPressed: () => ref
                        .read(booksProvider.notifier)
                        .downloadBookContent(
                          book,
                          isSample: false,
                        ), // 🌟 استفاده از متد جدید
                  ),
                ],
              ),
          ],
        );
      }
      return ElevatedButton.icon(
        icon: const Icon(Icons.cloud_download, size: 14),
        label: const Text("دانلود کامل", style: TextStyle(fontSize: 11)),
        onPressed: () => ref
            .read(booksProvider.notifier)
            .downloadBookContent(book, isSample: false),
      );
    }

    // --- ۳. حالت مهمان / نسخه نمونه ---
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (book.isSampleDownloaded) ...[
          // 🌟 تغییر از isDownloaded به isSampleDownloaded
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
          ),
          // نمایش آپدیت برای نسخه نمونه
          if (book.hasAnySampleUpdate) // 🌟 تشخیص آپدیت برای فایل‌های نمونه
            OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 12),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                foregroundColor: Colors.orange,
              ),
              onPressed: () => ref
                  .read(booksProvider.notifier)
                  .downloadBookContent(book, isSample: true),
              label: const Text("آپدیت نمونه", style: TextStyle(fontSize: 11)),
            ),
        ] else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: () => ref
                .read(booksProvider.notifier)
                .downloadBookContent(book, isSample: true),
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
