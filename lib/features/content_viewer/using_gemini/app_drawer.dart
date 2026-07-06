import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/settings_screen.dart';
import 'package:path_provider/path_provider.dart'; // مسیر را تنظیم کنید

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo,
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            child: const Column(
              children: [
                Icon(Icons.library_books, size: 60, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  "IELTS Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("تنظیمات"),
            onTap: () {
              Navigator.pop(context); // بستن دراور
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text("پاکسازی حافظه"),
            onTap: () async {
              // StorageService.clearOfflineBooks();
              // // پاکسازی حافظه
              // // این فقط یک مثال است. در عمل، شما باید داده‌های واقعی را پاک کنید.
              // // برای مثال، اگر از SharedPreferences استفاده می‌کنید:
              // // SharedPreferences.getInstance().then((prefs) => prefs.clear());
              // // یا اگر فایل‌ها را ذخیره کرده‌اید، آن‌ها را حذف کنید.
              // // File('path_to_your_file').deleteSync();
              // if (Platform.isWindows) {
              //   final dir = await getApplicationSupportDirectory();

              //   if (await dir.exists()) {
              //     await dir.delete(recursive: true);
              //   }
              // }
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text("حافظه پاکسازی شد!")),
              // );
            },
          ),
          // 🌟 دکمه مخفی که فقط در حالت Debug نمایش داده می‌شود
          if (kDebugMode) ...[
            const Divider(color: Colors.redAccent),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن متن اصلی (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref.read(booksProvider.notifier).resetOfflinelocalJsonVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ورژن متن اصلی روی ۰ تنظیم شد!'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن فایل‌های صوتی (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref
                    .read(booksProvider.notifier)
                    .resetOfflinelocalAudioVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ورژن فایل‌های صوتی روی ۰ تنظیم شد!'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن فایل‌های تصویری (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref
                    .read(booksProvider.notifier)
                    .resetOfflinelocalImagesVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'ورژن فایل‌های تصویری روی ۰ تنظیم شد!',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن محتواها (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref.read(booksProvider.notifier).resetOfflineVersions();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'ورژن فایل‌های اصلی و دمو روی ۰ تنظیم شد!',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
