// lib/features/content_viewer/providers/content_provider.dart
import 'package:ielts_assistant/features/content_viewer/data/content_service.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_provider.g.dart';

// @riverpod
// Future<List<Book>> allContent(Ref ref) async {
//   // گرفتن مسیر از پرووایدر تنظیمات
//   final rootPath = ref.watch(settingsProvider);

//   if (rootPath == null || rootPath.isEmpty) {
//     return []; // اگر مسیری انتخاب نشده باشد
//   }
//   final result = await ContentService.scanRootFolder(rootPath);
//   return result;
// }

// content_provider.dart
@riverpod
class AllContent extends _$AllContent {
  @override
  FutureOr<List<Book>> build() async {
    return await _loadBooks();
  }

  Future<List<Book>> _loadBooks() async {
    final rootPath = ref.watch(settingsProvider);

    if (rootPath == null || rootPath.isEmpty) {
      return [];
    }

    return await ContentService.scanRootFolder(rootPath);
  }

  // متد برای آپدیت دستی
  Future<void> updateBooks(List<Book> newBooks) async {
    state = AsyncValue.data(newBooks);
  }

  // متد برای رفرش
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final books = await _loadBooks();
      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
