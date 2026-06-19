import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/mahbub/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dio_provider.dart'; // پرووایدر دیو که در مراحل قبل ساختیم

// کلاس وضعیت برای مدیریت دانلود کتاب‌ها
class BookDownloadState {
  final List<dynamic> myBooks;
  final bool isLoadingBooks;
  final Map<int, double>
  downloadProgress; // آیدی کتاب -> درصد دانلود (0.0 تا 1.0)
  final Map<int, String>
  localFilePaths; // آیدی کتاب -> آدرس فایل ذخیره شده روی گوشی
  final String? errorMessage;

  BookDownloadState({
    this.myBooks = const [],
    this.isLoadingBooks = false,
    this.downloadProgress = const {},
    this.localFilePaths = const {},
    this.errorMessage,
  });

  BookDownloadState copyWith({
    List<dynamic>? myBooks,
    bool? isLoadingBooks,
    Map<int, double>? downloadProgress,
    Map<int, String>? localFilePaths,
    String? errorMessage,
  }) {
    return BookDownloadState(
      myBooks: myBooks ?? this.myBooks,
      isLoadingBooks: isLoadingBooks ?? this.isLoadingBooks,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localFilePaths: localFilePaths ?? this.localFilePaths,
      errorMessage: errorMessage,
    );
  }
}

// کلاس مدیریت وضعیت با ریورپاد
class BookNotifier extends StateNotifier<BookDownloadState> {
  final Dio _dio;
  final StorageService _storage;

  BookNotifier(this._dio, this._storage) : super(BookDownloadState()) {
    // به محض ساخته شدن این کلاس، دیتای آفلاین را در State بارگذاری می‌کنیم
    _loadOfflineData();
  }
  // متد خصوصی برای لود کردن دیتای ذخیره شده
  void _loadOfflineData() {
    final cachedBooks = _storage.getMyBooks();
    final cachedPaths = _storage.getLocalFilePaths();

    state = state.copyWith(myBooks: cachedBooks, localFilePaths: cachedPaths);
  }

  // ۱. دریافت لیست کتاب‌ها (با پشتیبانی آفلاین)
  Future<void> fetchMyBooks() async {
    // اگر کش خالی بود لودینگ نشان بده، اگر پر بود لودینگ نده تا کاربر متوجه تاخیر نشود
    if (state.myBooks.isEmpty) {
      state = state.copyWith(isLoadingBooks: true, errorMessage: null);
    }

    try {
      final response = await _dio.get('/my-books');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> freshBooks = response.data['data'];

        // ۱. به‌روزرسانی حافظه گوشی
        _storage.saveMyBooks(freshBooks);

        // ۲. به‌روزرسانی وضعیت اپلیکیشن
        state = state.copyWith(myBooks: freshBooks, isLoadingBooks: false);
      }
    } on DioException catch (e) {
      // اگر خطا مربوط به قطعی اینترنت بود و ما دیتای کش داریم، خطا نده!
      if (e.type == DioExceptionType.connectionError &&
          state.myBooks.isNotEmpty) {
        state = state.copyWith(isLoadingBooks: false);
        return; // خروج بی‌سروصدا
      }

      final msg =
          e.response?.data['message'] ??
          'خطا در ارتباط با سرور. لطفاً اینترنت را بررسی کنید.';
      state = state.copyWith(isLoadingBooks: false, errorMessage: msg);
    }
  }

  // ۲. دانلود و ثبت وضعیت آفلاین
  Future<void> downloadBook(int bookId, String fileName) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDocDir.path}/$fileName';

      await _dio.download(
        '/books/$bookId/download',
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final updatedProgress = Map<int, double>.from(
              state.downloadProgress,
            );
            updatedProgress[bookId] = progress;
            state = state.copyWith(downloadProgress: updatedProgress);
          }
        },
      );

      // به‌روزرسانی مَپ فایل‌های لوکال
      final updatedPaths = Map<int, String>.from(state.localFilePaths);
      updatedPaths[bookId] = savePath;

      // 💾 ذخیره مسیر در حافظه دائمی گوشی (تا دفعه بعد از همینجا خوانده شود)
      _storage.saveLocalFilePaths(updatedPaths);

      final updatedProgress = Map<int, double>.from(state.downloadProgress);
      updatedProgress.remove(bookId);

      state = state.copyWith(
        localFilePaths: updatedPaths,
        downloadProgress: updatedProgress,
      );
    } on DioException catch (e) {
      final msg =
          e.response?.data['message'] ??
          'خطا در دانلود فایل. لطفاً مجدداً تلاش کنید.';
      state = state.copyWith(errorMessage: msg);
    }
  }
}

// ⚠️ آپدیت پرووایدر نهایی برای تزریق StorageService
final bookProvider = StateNotifierProvider<BookNotifier, BookDownloadState>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider); // دریافت پرووایدر استوریج
  return BookNotifier(dio, storage);
});
