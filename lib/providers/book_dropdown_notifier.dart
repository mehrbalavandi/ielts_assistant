// -------------------
// Provider نگهداری آیتم انتخاب شده (باید در دسترس Notifier باشد)
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/providers/directory_state.dart';
import 'package:ielts_assistant/providers/unit_dropdown_notifier.dart';
import 'package:ielts_assistant/services/storage_service.dart';

final selectedBookProvider = StateProvider<Book?>((ref) => null);
final _storageBox = GetStorage();

// Notifier اصلی برای مدیریت لیست آیتم‌ها و بازیابی وضعیت ذخیره شده
class BookDropdownNotifier extends AsyncNotifier<List<Book>> {
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

  // متدی برای به‌روزرسانی و ذخیره وضعیت در آینده
  Future<void> selectItem(Book item) async {
    ref.read(selectedBookProvider.notifier).state = item;
    // ذخیره در get_storage
    await _storageService.saveLastbook(item.name);
  }
}

final bookDropdownProvider =
    AsyncNotifierProvider<BookDropdownNotifier, List<Book>>(
      BookDropdownNotifier.new,
    );
