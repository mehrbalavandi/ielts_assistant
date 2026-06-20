import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/library_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/login_screen.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/auth_provider.dart';

import 'features/content_viewer/presentation/using_gemini/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 گوش دادن زنده به وضعیت احراز هویت
    final authState = ref.watch(authProvider);
    Widget initialScreen;
    switch (authState) {
      case AuthState.initial:
        initialScreen = const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
        break;
      case AuthState.unauthenticated:
        initialScreen = const LoginScreen(); // کاربر توکن ندارد
        break;
      case AuthState.authenticated:
        initialScreen = const LibraryScreen(); // 🌟 ورود خودکار به کتاب‌ها!
        break;
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
