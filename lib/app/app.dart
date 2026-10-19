import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/app/app_messenger.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/auth/providers/session_guard.dart';
import 'package:ielts_assistant/features/library/presentation/library_screen.dart';
import 'package:ielts_assistant/features/settings/presentation/settings_screen.dart';

/// ویجتِ ریشه: تم، زبان‌ها، و انتخابِ صفحه‌ی شروع.
class IeltsAssistantApp extends ConsumerWidget {
  const IeltsAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🌟 DEV-1: از شروعِ اپ گوش می‌دهد که سرور نشستِ این دستگاه را تمام‌شده اعلام کند.
    ref.watch(sessionGuardProvider);
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
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver], // 🌟 C-6
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        // 🌟 UI-1: نوارِ بالای همه‌ی صفحه‌ها مثلِ صفحه‌ی مطالعه: پس‌زمینه‌ی آبی، عنوان و آیکون‌های
        // سفید، نوارِ وضعیتِ گوشی با آیکون‌های روشن. (TabBarهای داخلِ AppBar رنگِ سفید را خودشان
        // می‌گیرند: appBarTabBar در lib/app/app_theme.dart.)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: initialScreen,
    );
  }
}
