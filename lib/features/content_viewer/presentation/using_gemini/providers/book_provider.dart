import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_settings_provider.dart';

class BookModel {
  final String id;
  final String title;
  final String remoteJsonUrl;
  final String remoteCoverUrl;
  final String? localJsonPath;
  final String? localCoverPath;

  // فیلدهای وضعیت دانلود (ذخیره نمی‌شوند، فقط در رم هستند)
  final bool isDownloading;
  final double downloadProgress;

  bool get isDownloaded =>
      localJsonPath != null && File(localJsonPath!).existsSync();
  String get jsonAssetPath => localJsonPath ?? 'assets/data/$id.json';

  BookModel({
    required this.id,
    required this.title,
    required this.remoteJsonUrl,
    required this.remoteCoverUrl,
    this.localJsonPath,
    this.localCoverPath,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  BookModel copyWith({
    String? localJsonPath,
    String? localCoverPath,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return BookModel(
      id: id,
      title: title,
      remoteJsonUrl: remoteJsonUrl,
      remoteCoverUrl: remoteCoverUrl,
      localJsonPath: localJsonPath ?? this.localJsonPath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: json['id'] ?? '',
    title: json['title'] ?? 'بدون عنوان',
    remoteJsonUrl: json['jsonUrl'] ?? '',
    remoteCoverUrl: json['coverUrl'] ?? '',
    localJsonPath: json['localJsonPath'],
    localCoverPath: json['localCoverPath'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'jsonUrl': remoteJsonUrl,
    'coverUrl': remoteCoverUrl,
    'localJsonPath': localJsonPath,
    'localCoverPath': localCoverPath,
  };
}

// 🌟 کلاس مدیریت کتاب‌ها به صورت Offline-First
class BooksNotifier extends Notifier<List<BookModel>> {
  @override
  List<BookModel> build() {
    // 🌟 مرحله ۳ (گام ۲): بارگذاری فوری اطلاعات از Storage در میلی‌ثانیه
    final offlineData = StorageService.getOfflineBooks();
    List<BookModel> initialBooks = [];
    if (offlineData != null) {
      initialBooks = offlineData
          .map((e) => BookModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 🌟 مرحله ۳ (گام ۳): همگام‌سازی پس‌زمینه بدون مسدود کردن UI
    Future.microtask(() => fetchMyBooks());

    return initialBooks;
  }

  Future<void> fetchMyBooks() async {
    try {
      final dio = ref.read(dioProvider);
      // فرض بر این است که API شما اطلاعات کاربر و کتاب‌هایش را برمی‌گرداند
      final response = await dio.get('/api/my-books');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        List<BookModel> freshBooks = data
            .map((json) => BookModel.fromJson(json))
            .toList();

        // حفظ وضعیت فایل‌های دانلود شده‌ی قبلی
        List<BookModel> mergedBooks = freshBooks.map((freshBook) {
          final existingBook = state
              .where((b) => b.id == freshBook.id)
              .firstOrNull;
          if (existingBook != null && existingBook.isDownloaded) {
            return freshBook.copyWith(
              localJsonPath: existingBook.localJsonPath,
              localCoverPath: existingBook.localCoverPath,
            );
          }
          return freshBook;
        }).toList();

        state = mergedBooks;
        // ذخیره نامحسوس در گوشی برای دفعات بعد
        StorageService.saveOfflineBooks(
          mergedBooks.map((b) => b.toJson()).toList(),
        );
      }
    } catch (e) {
      // اگر اینترنت قطع باشد، هیچ اتفاقی نمی‌افتد و کاربر با همان دیتای آفلاین (state فعلی) کار می‌کند
    }
  }

  // 🌟 مرحله ۴: جریان دانلود و مصرف فایل
  Future<void> downloadBook(BookModel book) async {
    // تغییر UI به حالت "در حال دانلود"
    _updateBook(book.id, isDownloading: true, downloadProgress: 0.0);

    try {
      final dio = ref.read(dioProvider);
      final dir = await getApplicationDocumentsDirectory();

      // تعیین مسیرهای ذخیره‌سازی فیزیکی
      final jsonSavePath = '${dir.path}/${book.id}_content.json';
      final coverSavePath = '${dir.path}/${book.id}_cover.png';

      // 🌟 دانلود فایل JSON با Dio
      await dio.download(
        book.remoteJsonUrl,
        jsonSavePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _updateBook(
              book.id,
              isDownloading: true,
              downloadProgress: received / total,
            );
          }
        },
      );

      // (در صورت نیاز می‌توانید اینجا فایل کاور را هم دانلود کنید)

      // پایان دانلود، ذخیره مسیرها در حافظه
      final updatedBook = _updateBook(
        book.id,
        localJsonPath: jsonSavePath,
        localCoverPath: coverSavePath,
        isDownloading: false,
      );

      // آپدیت کردن استوریج برای لودهای بعدی
      StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
    } catch (e) {
      // در صورت خطا، دانلود را لغو می‌کنیم
      _updateBook(book.id, isDownloading: false, downloadProgress: 0.0);
    }
  }

  BookModel _updateBook(
    String id, {
    String? localJsonPath,
    String? localCoverPath,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    BookModel? updatedBook;
    state = state.map((b) {
      if (b.id == id) {
        updatedBook = b.copyWith(
          localJsonPath: localJsonPath,
          localCoverPath: localCoverPath,
          isDownloading: isDownloading,
          downloadProgress: downloadProgress,
        );
        return updatedBook!;
      }
      return b;
    }).toList();
    return updatedBook ?? state.firstWhere((b) => b.id == id);
  }
}

final booksProvider = NotifierProvider<BooksNotifier, List<BookModel>>(
  () => BooksNotifier(),
);

final activeBookProvider = StateProvider<BookModel?>((ref) => null);

class SearchSession {
  final String query;
  final List<dynamic> results;
  final int currentIndex;
  final int jumpTrigger;
  SearchSession({
    required this.query,
    required this.results,
    required this.currentIndex,
    this.jumpTrigger = 0,
  });
  SearchSession copyWith({int? currentIndex, int? jumpTrigger}) =>
      SearchSession(
        query: query,
        results: results,
        currentIndex: currentIndex ?? this.currentIndex,
        jumpTrigger: jumpTrigger ?? this.jumpTrigger,
      );
}

final activeSearchProvider = StateProvider<SearchSession?>((ref) => null);
