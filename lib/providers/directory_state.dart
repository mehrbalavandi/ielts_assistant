import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/providers/book_dropdown_notifier.dart';
import 'package:ielts_assistant/providers/unit_dropdown_notifier.dart';
import 'package:ielts_assistant/services/file_service.dart';
import 'package:ielts_assistant/services/storage_service.dart'; // استفاده از GetStorage
// ... سایر ایمپورت‌ها: data_models.dart, file_service.dart

final _storageBox = GetStorage(); // نمونه GetStorage
final fileTraversalServiceProvider = Provider((ref) => FileTraversalService());

// تعریف StateNotifier برای مدیریت داده های برنامه
class DirectoryDataNotifier extends AsyncNotifier<List<Book>> {
  String? _rootDirectoryPath;
  final _storageService = StorageService();

  @override
  Future<List<Book>> build() async {
    final savedPath =
        _storageBox.read(StorageKeys.lastRootDirectoryPath) as String?;

    if (savedPath != null) {
      state = const AsyncValue.loading();

      try {
        final service = ref.read(fileTraversalServiceProvider);
        final books = await service.traverseRootDirectory(savedPath);

        if (ref.read(selectedBookProvider)?.name == null) {
          final storedBookName = _storageService.getLastbook();
          Book? storedBook;
          if (storedBookName != null) {
            storedBook = books
                .where((item) => item.name == storedBookName)
                .firstOrNull;
          }
          if (storedBook != null) {
            ref.read(selectedBookProvider.notifier).state = storedBook;
          }
        }
        return books;
      } catch (e, st) {
        debugPrint('Error traversing saved path: $e');
        // در صورت خطا، مسیر ذخیره شده را پاک کنید تا دفعه بعد دوباره انتخاب شود
        await _storageBox.remove(StorageKeys.lastRootDirectoryPath);
        return []; // بازگشت وضعیت خالی
      }
    }

    // اگر هیچ مسیری ذخیره نشده باشد
    ref.read(selectedBookProvider.notifier).state = null;
    ref.read(selectedUnitProvider.notifier).state = null;
    return [];
  }

  // تابع برای انتخاب پوشه و لود کردن داده ها (قبلی)
  Future<void> loadDirectoryData(String path) async {
    state = const AsyncValue.loading();
    _rootDirectoryPath = path;

    try {
      final service = ref.read(fileTraversalServiceProvider);
      final books = await service.traverseRootDirectory(path);

      // **۲. ذخیره مسیر جدید در GetStorage پس از موفقیت**
      await _storageBox.write(StorageKeys.lastRootDirectoryPath, path);

      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? get rootDirectoryPath => _rootDirectoryPath;
  void selectItem(Book item) {
    ref.read(selectedBookProvider.notifier).state = item;
    // ذخیره در get_storage
    _storageService.saveLastbook(item.name);
  }
}

final directoryDataProvider =
    AsyncNotifierProvider<DirectoryDataNotifier, List<Book>>(() {
      return DirectoryDataNotifier();
    });
