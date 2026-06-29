import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/library_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/main_book_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _box = GetStorage();

  @override
  void initState() {
    super.initState();
    // لود کردن آدرس قبلی
    _urlController.text = _box.read('base_url') ?? 'http://10.110.198.220:8000';
  }

  void _saveSettings() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      StorageService.saveBaseUrl(url);
      ref.invalidate(dioProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('آدرس سرور با موفقیت ذخیره شد')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً آدرس سرور را وارد کنید')),
      );
    }
    final activeBook = ref.watch(activeBookProvider);

    if (activeBook != null) {
      // اگر کتاب فعال وجود دارد، به صفحه اصلی کتاب برو
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainBookScreen()),
        (route) => false,
      );
    } else {
      // اگر کتاب فعال وجود ندارد، به صفحه ویترین برو
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تنظیمات سیستم")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud_sync_rounded,
              size: 80,
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),

            const Text(
              "آدرس سرور مرکزی",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: "مثال: http://10.110.198.220:8000",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ذخیره تنظیمات",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
