import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/settings_screen.dart';
import 'package:path_provider/path_provider.dart'; // مسیر را تنظیم کنید

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
              StorageService.clearOfflineBooks();
              // پاکسازی حافظه
              // این فقط یک مثال است. در عمل، شما باید داده‌های واقعی را پاک کنید.
              // برای مثال، اگر از SharedPreferences استفاده می‌کنید:
              // SharedPreferences.getInstance().then((prefs) => prefs.clear());
              // یا اگر فایل‌ها را ذخیره کرده‌اید، آن‌ها را حذف کنید.
              // File('path_to_your_file').deleteSync();
              if (Platform.isWindows) {
                final dir = await getApplicationSupportDirectory();

                if (await dir.exists()) {
                  await dir.delete(recursive: true);
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("حافظه پاکسازی شد!")),
              );
            },
          ),
        ],
      ),
    );
  }
}
