import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  // 🌟 فیلد جدید برای تشخیص مالکیت کتاب
  final bool isPurchased;

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
    this.isPurchased = false, // پیش‌فرض: کاربر فقط به نمونه دسترسی دارد
  });

  BookModel copyWith({
    String? localJsonPath,
    String? localCoverPath,
    bool? isDownloading,
    double? downloadProgress,
    bool? isPurchased,
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
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? 'بدون عنوان',
    remoteJsonUrl: json['jsonUrl'] ?? '',
    remoteCoverUrl: json['coverUrl'] ?? '',
    localJsonPath: json['localJsonPath'],
    localCoverPath: json['localCoverPath'],
    isPurchased:
        json['isPurchased'] == true ||
        json['is_purchased'] == true, // 🌟 دریافت وضعیت خرید از API
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'jsonUrl': remoteJsonUrl,
    'coverUrl': remoteCoverUrl,
    'localJsonPath': localJsonPath,
    'localCoverPath': localCoverPath,
    'is_purchased': isPurchased,
  };
}

class BooksNotifier extends Notifier<List<BookModel>> {
  @override
  List<BookModel> build() {
    final offlineData = StorageService.getOfflineBooks();
    List<BookModel> initialBooks = [];
    if (offlineData != null) {
      initialBooks = offlineData
          .map((e) => BookModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    Future.microtask(() => fetchBooks());
    return initialBooks;
  }

  // 🌟 تغییر نام به fetchBooks چون حالا ویترین عمومی است
  Future<void> fetchBooks() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/my-books');

      if (response.statusCode == 200) {
        final rawData = response.data;
        List<dynamic> dataList = [];

        // 🌟 بررسی هوشمند ساختار داده دریافتی از سرور لاراول
        if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
          // حالت Pagination یا Resource Wrapper لاراول
          dataList = rawData['data'];
        } else if (rawData is List) {
          // حالت آرایه مستقیم
          dataList = rawData;
        }

        List<BookModel> freshBooks = dataList
            .map((json) => BookModel.fromJson(json))
            .toList();

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
        StorageService.saveOfflineBooks(
          mergedBooks.map((b) => b.toJson()).toList(),
        );
      }
    } catch (e) {
      // استفاده از داده‌های آفلاین در صورت قطعی اینترنت
      debugPrint("Fetch Books Error: $e");
    }
  }

  Future<void> downloadBook(BookModel book) async {
    _updateBook(book.id, isDownloading: true, downloadProgress: 0.0);

    try {
      final dio = ref.read(dioProvider);
      final dir = await getApplicationDocumentsDirectory();

      final jsonSavePath = '${dir.path}/${book.id}_content.json';
      final coverSavePath = '${dir.path}/${book.id}_cover.png';

      // 🌟 سرور شما باید بر اساس توکن ارسالی، خودش تشخیص دهد که آیا فایل کامل را
      // ارسال کند یا فایل نسخه نمونه (Sample) را. فلاتر فقط لینک را فراخوانی می‌کند.
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

      _updateBook(
        book.id,
        localJsonPath: jsonSavePath,
        localCoverPath: coverSavePath,
        isDownloading: false,
      );
      StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
    } catch (e) {
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
