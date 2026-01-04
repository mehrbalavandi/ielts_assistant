// lib/features/content_viewer/providers/content_provider.dart
import 'package:ielts_assistant/features/content_viewer/data/content_service.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_provider.g.dart';

@riverpod
Future<List<Book>> allContent(Ref ref) async {
  // گرفتن مسیر از پرووایدر تنظیمات
  final rootPath = ref.watch(settingsProvider);

  if (rootPath == null || rootPath.isEmpty) {
    return []; // اگر مسیری انتخاب نشده باشد
  }

  return await ContentService.scanRootFolder(rootPath);
}
