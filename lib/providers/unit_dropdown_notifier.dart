// -------------------
// Provider نگهداری آیتم انتخاب شده (باید در دسترس Notifier باشد)
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/providers/book_dropdown_notifier.dart';
import 'package:ielts_assistant/providers/directory_state.dart';
import 'package:ielts_assistant/services/storage_service.dart';

final selectedUnitProvider = StateProvider<Unit?>((ref) => null);
final _storageBox = GetStorage();

// Notifier اصلی برای مدیریت لیست آیتم‌ها و بازیابی وضعیت ذخیره شده
class UnitDropdownNotifier extends AsyncNotifier<List<Unit>> {
  final _storageService = StorageService();
  @override
  Future<List<Unit>> build() async {
    final savedPath =
        _storageBox.read(StorageKeys.lastRootDirectoryPath) as String?;

    if (savedPath != null) {
      state = const AsyncValue.loading();

      try {
        final units = ref.read(selectedBookProvider)?.units;
        if (units != null && units.isNotEmpty) {
          final storedUnitName = _storageService.getLastUnit();

          Unit? storedUnit;
          if (storedUnitName != null) {
            storedUnit = units
                .where((item) => item.name == storedUnitName)
                .firstOrNull;
          }
          if (storedUnit != null) {
            Future.microtask(() {
              ref.read(selectedUnitProvider.notifier).state = storedUnit;
            });
          }
          return units;
        } else {
          return [];
        }
      } catch (e, st) {
        debugPrint('Error traversing saved path: $e');
        // در صورت خطا، مسیر ذخیره شده را پاک کنید تا دفعه بعد دوباره انتخاب شود
        await _storageBox.remove(StorageKeys.lastRootDirectoryPath);
        return []; // بازگشت وضعیت خالی
      }
    }

    // اگر هیچ مسیری ذخیره نشده باشد
    return [];
  }

  Future<void> selectItemBaseOnSelectedBook(Book book) async {
    final units = book.units;
    if (units.isNotEmpty) {
      final storedUnitName = _storageService.getLastUnit();

      Unit? storedUnit;
      if (storedUnitName != null) {
        storedUnit = units
            .where((item) => item.name == storedUnitName)
            .firstOrNull;
      }
      if (storedUnit != null) {
        ref.read(selectedUnitProvider.notifier).state = storedUnit;
      }
    }
  }

  // متدی برای به‌روزرسانی و ذخیره وضعیت در آینده
  Future<void> selectItem(Unit item) async {
    ref.read(selectedUnitProvider.notifier).state = item;
    // ذخیره در get_storage
    await _storageService.saveLastunit(item.name);
  }
}

final unitDropdownProvider =
    AsyncNotifierProvider<UnitDropdownNotifier, List<Unit>>(
      UnitDropdownNotifier.new,
    );
