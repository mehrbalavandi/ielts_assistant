import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/login_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/auth_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await StorageService.removeToken();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // بررسی آدرس سرور
    final baseUrl = StorageService.getBaseUrl();

    Widget initialScreen;
    if (baseUrl == null || baseUrl.isEmpty) {
      initialScreen = const SettingsScreen();
    } else {
      // 🌟 همه کاربران (چه مهمان و چه عضو) وارد ویترین می‌شوند
      final activeBook = ref.watch(activeBookProvider);
      initialScreen = activeBook != null
          ? const MainBookScreen()
          : const LibraryScreen();
    }

    return MaterialApp(
      title: 'IELTS Assistant',
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
