import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/library/presentation/library_screen.dart';
import 'package:ielts_assistant/features/settings/presentation/settings_screen.dart';

/// ویجتِ ریشه: تم، زبان‌ها، و انتخابِ صفحه‌ی شروع.
class IeltsAssistantApp extends ConsumerWidget {
  const IeltsAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // اگر آدرس سرور هنوز تنظیم نشده، اول باید تنظیمات باز شود؛
    // در غیر این صورت همه‌ی کاربران (مهمان یا عضو) وارد ویترین می‌شوند.
    final baseUrl = StorageService.getBaseUrl();
    final Widget initialScreen = (baseUrl == null || baseUrl.isEmpty)
        ? const SettingsScreen()
        : const LibraryScreen();

    return MaterialApp(
      title: 'IELTS Assistant',
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      locale: const Locale('en', 'US'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
      ),
      home: initialScreen,
    );
  }
}
