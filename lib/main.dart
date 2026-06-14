import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';

// ایمپورت‌های مربوط به صفحه‌ها و پرووایدر
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';

Future<void> main() async {
  // این خط برای اطمینان از مقداردهی اولیه فلاتر قبل از استفاده از get_storage است
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // مقداردهی اولیه حافظه

  // اجرای اپلیکیشن با پوشش Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

// 🌟 تغییر از StatelessWidget به ConsumerWidget برای دسترسی به Riverpod
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  // 🌟 اضافه شدن WidgetRef ref به ورودی‌های متد build
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 خواندن وضعیت آخرین کتاب باز شده از حافظه
    final activeBook = ref.watch(activeBookProvider);

    return MaterialApp(
      title: 'Course Navigator',
      supportedLocales: const [Locale("fa", "IR"), Locale("en", "US")],
      locale: const Locale("en", "US"),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
      ),
      // 🌟 سیستم مسیریابی هوشمند: اگر کاربر قبلاً کتابی خوانده مستقیم به آن می‌رود، وگرنه به کتابخانه
      home: activeBook != null ? const MainBookScreen() : const LibraryScreen(),
    );
  }
}
