import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/data/content_service.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('انتخاب مسیر فایل‌های صوتی'),
            onTap: () async {
              String? previousPath = ref.read(settingsProvider);
              String? selectedDirectory = await ref
                  .read(settingsProvider.notifier)
                  .pickAndSaveDirectory(previousPath);
              // if (selectedDirectory != previousPath) {
              await ref
                  .read(settingsProvider.notifier)
                  .updatePath(selectedDirectory!);
              // }
              await ContentService.scanRootFolder(selectedDirectory);
            },
          ),
          const Divider(),
          ListTile(
            textColor: Colors.red,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('پاکسازی تمام بوکمارک‌ها'),
            onTap: () => _confirmClear(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    // نمایش Dialog و فراخوانی متد clearAllBookmarks در صورت تایید
  }
}
