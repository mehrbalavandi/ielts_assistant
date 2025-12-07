import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/file_service.dart';

// یک Provider برای دسترسی به سرویس پیمایش
final fileTraversalServiceProvider = Provider((ref) => FileTraversalService());

// نوتیفایر برای نگهداری و بارگذاری داده‌های ساختار پوشه
class DirectoryDataNotifier extends AsyncNotifier<List<Subject>> {
  String? _rootDirectoryPath;

  @override
  Future<List<Subject>> build() async {
    return []; // وضعیت اولیه خالی است
  }

  // تابع اصلی برای انتخاب پوشه و لود کردن داده‌ها
  Future<void> loadDirectoryData(String path) async {
    // تغییر وضعیت به لودینگ
    state = const AsyncValue.loading();
    _rootDirectoryPath = path;

    try {
      final service = ref.read(fileTraversalServiceProvider);
      // فراخوانی تابع پیمایش فایل
      final subjects = await service.traverseRootDirectory(path);

      // تغییر وضعیت به داده
      state = AsyncValue.data(subjects);
    } catch (e, st) {
      // تغییر وضعیت به خطا
      state = AsyncValue.error('خطا در بارگذاری داده‌ها: $e', st);
    }
  }

  // برای نمایش مسیر انتخاب شده در UI
  String? get rootDirectoryPath => _rootDirectoryPath;
}

// Provider اصلی که در UI مشاهده می‌شود
final directoryDataProvider =
    AsyncNotifierProvider<DirectoryDataNotifier, List<Subject>>(() {
      return DirectoryDataNotifier();
    });
