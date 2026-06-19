import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // مقداردهی اولیه حافظه

  // اجرای اپلیکیشن با پوشش Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

// 🌟 تغییر از StatelessWidget به ConsumerWidget برای دسترسی به Riverpod
class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 بررسی وضعیت تنظیمات سرور
    final baseUrl = ref.watch(baseUrlProvider);

    Widget initialScreen;
    if (baseUrl == null || baseUrl.isEmpty) {
      initialScreen =
          const SettingsScreen(); // هدایت به تنظیمات در صورت خالی بودن
    } else {
      final activeBook = ref.watch(activeBookProvider);
      initialScreen = activeBook != null
          ? const MainBookScreen()
          : const LibraryScreen();
    }

    return MaterialApp(
      title: 'Course Navigator',
      supportedLocales: const [Locale("fa", "IR"), Locale("en", "US")],
      locale: const Locale("en", "US"),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
      ),
      home: initialScreen,
    );
  }
}
