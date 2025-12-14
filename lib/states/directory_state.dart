import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/file_service.dart'; // استفاده از GetStorage
// ... سایر ایمپورت‌ها: data_models.dart, file_service.dart

// کلید ذخیره‌سازی
const String _ROOT_PATH_KEY = 'lastRootDirectoryPath';

final _storageBox = GetStorage(); // نمونه GetStorage

final fileTraversalServiceProvider = Provider((ref) => FileTraversalService());

// تعریف StateNotifier برای مدیریت داده های برنامه
class DirectoryDataNotifier extends AsyncNotifier<List<Book>> {
  String? _rootDirectoryPath;

  @override
  Future<List<Book>> build() async {
    // ۱. تلاش برای بازیابی مسیر ذخیره شده
    final savedPath = _storageBox.read(_ROOT_PATH_KEY) as String?;

    if (savedPath != null) {
      // مسیر ذخیره شده پیدا شد. شروع پیمایش خودکار.

      // حالت را به لودینگ تغییر دهید
      state = const AsyncValue.loading();
      _rootDirectoryPath = savedPath;

      try {
        final service = ref.read(fileTraversalServiceProvider);
        final subjects = await service.traverseRootDirectory(savedPath);

        // اگر پیمایش موفقیت آمیز بود
        return subjects;
      } catch (e, st) {
        // اگر مسیر ذخیره شده دیگر معتبر نباشد (مثلاً پوشه حذف شده باشد)
        print('Error traversing saved path: $e');

        // در صورت خطا، مسیر ذخیره شده را پاک کنید تا دفعه بعد دوباره انتخاب شود
        await _storageBox.remove(_ROOT_PATH_KEY);
        return []; // بازگشت وضعیت خالی
      }
    }

    // اگر هیچ مسیری ذخیره نشده باشد
    return [];
  }

  // تابع برای انتخاب پوشه و لود کردن داده ها (قبلی)
  Future<void> loadDirectoryData(String path) async {
    state = const AsyncValue.loading();
    _rootDirectoryPath = path;

    try {
      final service = ref.read(fileTraversalServiceProvider);
      final subjects = await service.traverseRootDirectory(path);

      // **۲. ذخیره مسیر جدید در GetStorage پس از موفقیت**
      await _storageBox.write(_ROOT_PATH_KEY, path);

      state = AsyncValue.data(subjects);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? get rootDirectoryPath => _rootDirectoryPath;
}

final directoryDataProvider =
    AsyncNotifierProvider<DirectoryDataNotifier, List<Book>>(() {
      return DirectoryDataNotifier();
    });
