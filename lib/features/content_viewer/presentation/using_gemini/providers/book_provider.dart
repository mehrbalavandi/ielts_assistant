import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';

class BookModel {
  final String id;
  final String title;
  final String? folderName;

  // --- 🌐 اطلاعات سرور (Remote) ---
  final String? sampleFilePath;
  final int sampleVersion;
  final List<String> sampleAudioFiles; // 🌟 جدید
  final int sampleAudioVersion; // 🌟 جدید
  final List<String> sampleImages; // 🌟 جدید
  final int sampleImagesVersion; // 🌟 جدید

  final String? jsonFile;
  final int jsonVersion;
  final List<String> audioFiles;
  final int audioVersion;
  final List<String> images;
  final int imagesVersion;

  // --- 📱 اطلاعات محلی (Local) ---
  final String? localSamplePath;
  final int localSampleVersion;
  final int localSampleAudioVersion; // 🌟 جدید
  final int localSampleImagesVersion; // 🌟 جدید

  final String? localJsonPath;
  final int localJsonVersion;
  final int localAudioVersion;
  final int localImagesVersion;

  // --- ⚙️ وضعیت‌های منطقی و UI ---
  final bool isPurchased;
  final bool isDownloading;
  final double downloadProgress;

  // 🌟 هوش تشخیص آپدیت و دانلود (تفکیک نمونه و اصلی)
  bool get isSampleDownloaded =>
      localSamplePath != null && File(localSamplePath!).existsSync();
  bool get isJsonDownloaded =>
      localJsonPath != null && File(localJsonPath!).existsSync();

  // بررسی آپدیت‌های نسخه نمونه
  bool get hasSampleJsonUpdate =>
      isSampleDownloaded && (localSampleVersion < sampleVersion);
  bool get hasSampleAudioUpdate => localSampleAudioVersion < sampleAudioVersion;
  bool get hasSampleImagesUpdate =>
      localSampleImagesVersion < sampleImagesVersion;
  bool get hasAnySampleUpdate =>
      hasSampleJsonUpdate || hasSampleAudioUpdate || hasSampleImagesUpdate;

  // بررسی آپدیت‌های نسخه اصلی
  bool get hasJsonUpdate =>
      isJsonDownloaded && (localJsonVersion < jsonVersion);
  bool get hasAudioUpdate => localAudioVersion < audioVersion;
  bool get hasImagesUpdate => localImagesVersion < imagesVersion;
  bool get hasAnyMainUpdate =>
      hasJsonUpdate || hasAudioUpdate || hasImagesUpdate;

  // مسیردهی هوشمند (اگر نسخه اصلی بود آن را بده، وگرنه نسخه نمونه را بده)
  String get activeJsonPath =>
      localJsonPath ?? localSamplePath ?? 'assets/data/$id.json';
  String get jsonAssetPath => activeJsonPath;

  BookModel({
    required this.id,
    required this.title,
    this.folderName,
    this.sampleFilePath,
    this.sampleVersion = 0,
    this.sampleAudioFiles = const [],
    this.sampleAudioVersion = 0,
    this.sampleImages = const [],
    this.sampleImagesVersion = 0,
    this.jsonFile,
    this.jsonVersion = 0,
    this.audioFiles = const [],
    this.audioVersion = 0,
    this.images = const [],
    this.imagesVersion = 0,

    this.localSamplePath,
    this.localSampleVersion = 0,
    this.localSampleAudioVersion = 0,
    this.localSampleImagesVersion = 0,
    this.localJsonPath,
    this.localJsonVersion = 0,
    this.localAudioVersion = 0,
    this.localImagesVersion = 0,

    this.isPurchased = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  BookModel copyWith({
    String? localSamplePath,
    int? localSampleVersion,
    int? localSampleAudioVersion,
    int? localSampleImagesVersion,
    String? localJsonPath,
    int? localJsonVersion,
    int? localAudioVersion,
    int? localImagesVersion,
    bool? isDownloading,
    double? downloadProgress,
    bool? isPurchased,
  }) {
    return BookModel(
      id: id,
      title: title,
      folderName: folderName,
      sampleFilePath: sampleFilePath,
      sampleVersion: sampleVersion,
      sampleAudioFiles: sampleAudioFiles,
      sampleAudioVersion: sampleAudioVersion,
      sampleImages: sampleImages,
      sampleImagesVersion: sampleImagesVersion,
      jsonFile: jsonFile,
      jsonVersion: jsonVersion,
      audioFiles: audioFiles,
      audioVersion: audioVersion,
      images: images,
      imagesVersion: imagesVersion,

      localSamplePath: localSamplePath ?? this.localSamplePath,
      localSampleVersion: localSampleVersion ?? this.localSampleVersion,
      localSampleAudioVersion:
          localSampleAudioVersion ?? this.localSampleAudioVersion,
      localSampleImagesVersion:
          localSampleImagesVersion ?? this.localSampleImagesVersion,
      localJsonPath: localJsonPath ?? this.localJsonPath,
      localJsonVersion: localJsonVersion ?? this.localJsonVersion,
      localAudioVersion: localAudioVersion ?? this.localAudioVersion,
      localImagesVersion: localImagesVersion ?? this.localImagesVersion,

      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? 'بدون عنوان',
    folderName: json['folder_name'],

    sampleFilePath: json['sample_file_path'],
    sampleVersion: json['sample_version'] ?? 0,
    sampleAudioFiles: List<String>.from(json['sample_audio_files'] ?? []),
    sampleAudioVersion: json['sample_audio_version'] ?? 0,
    sampleImages: List<String>.from(json['sample_images'] ?? []),
    sampleImagesVersion: json['sample_images_version'] ?? 0,

    jsonFile: json['json_file'],
    jsonVersion: json['json_version'] ?? 0,
    audioFiles: List<String>.from(json['audio_files'] ?? []),
    audioVersion: json['audio_version'] ?? 0,
    images: List<String>.from(json['images'] ?? []),
    imagesVersion: json['images_version'] ?? 0,

    localSamplePath: json['localSamplePath'],
    localSampleVersion: json['localSampleVersion'] ?? 0,
    localSampleAudioVersion: json['localSampleAudioVersion'] ?? 0,
    localSampleImagesVersion: json['localSampleImagesVersion'] ?? 0,

    localJsonPath: json['localJsonPath'],
    localJsonVersion: json['localJsonVersion'] ?? 0,
    localAudioVersion: json['localAudioVersion'] ?? 0,
    localImagesVersion: json['localImagesVersion'] ?? 0,

    isPurchased: json['isPurchased'] == true || json['is_purchased'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'folder_name': folderName,

    'sample_file_path': sampleFilePath,
    'sample_version': sampleVersion,
    'sample_audio_files': sampleAudioFiles,
    'sample_audio_version': sampleAudioVersion,
    'sample_images': sampleImages,
    'sample_images_version': sampleImagesVersion,

    'json_file': jsonFile,
    'json_version': jsonVersion,
    'audio_files': audioFiles,
    'audio_version': audioVersion,
    'images': images,
    'images_version': imagesVersion,

    'localSamplePath': localSamplePath,
    'localSampleVersion': localSampleVersion,
    'localSampleAudioVersion': localSampleAudioVersion,
    'localSampleImagesVersion': localSampleImagesVersion,
    'localJsonPath': localJsonPath,
    'localJsonVersion': localJsonVersion,
    'localAudioVersion': localAudioVersion,
    'localImagesVersion': localImagesVersion,

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

  Future<void> fetchBooks() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/books');

      if (response.statusCode == 200) {
        final rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
          dataList = rawData['data'];
        } else if (rawData is List) {
          dataList = rawData;
        }

        List<BookModel> freshBooks = dataList
            .map((json) => BookModel.fromJson(json))
            .toList();

        List<BookModel> mergedBooks = freshBooks.map((freshBook) {
          final existingBook = state
              .where((b) => b.id == freshBook.id)
              .firstOrNull;

          if (existingBook != null) {
            // حفظ تمامی نسخه‌های محلی برای نمونه و اصلی
            return freshBook.copyWith(
              localSamplePath: existingBook.localSamplePath,
              localSampleVersion: existingBook.localSampleVersion,
              localSampleAudioVersion: existingBook.localSampleAudioVersion,
              localSampleImagesVersion: existingBook.localSampleImagesVersion,

              localJsonPath: existingBook.localJsonPath,
              localJsonVersion: existingBook.localJsonVersion,
              localAudioVersion: existingBook.localAudioVersion,
              localImagesVersion: existingBook.localImagesVersion,
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
      debugPrint("Fetch Books Error: $e");
    }
  }

  // 🌟 دانلود منیجر ارتقا یافته با پشتیبانی از فایل‌های نمونه
  Future<void> downloadBookContent(
    BookModel book, {
    bool isSample = false,
  }) async {
    _updateBook(book.id, isDownloading: true, downloadProgress: 0.0);

    try {
      final dio = ref.read(dioProvider);
      final dir = await getApplicationDocumentsDirectory();

      final bookFolder = Directory('${dir.path}/${book.folderName ?? book.id}');
      if (!await bookFolder.exists()) {
        await bookFolder.create(recursive: true);
      }

      int totalFiles = 0;
      int downloadedFiles = 0;

      if (isSample) {
        // --- 1️⃣ جریان دانلود نسخه نمونه (Sample) ---
        totalFiles =
            1 + book.sampleAudioFiles.length + book.sampleImages.length;

        // الف) دانلود فایل متنی JSON نمونه
        String? newSamplePath = book.localSamplePath;
        int newSampleVer = book.localSampleVersion;

        if (book.sampleFilePath != null &&
            (!book.isSampleDownloaded || book.hasSampleJsonUpdate)) {
          newSamplePath = '${bookFolder.path}/sample.json';
          await _downloadSingleFile(dio, book.sampleFilePath!, newSamplePath);
          newSampleVer = book.sampleVersion;
        }
        downloadedFiles++;
        _updateProgress(book.id, downloadedFiles, totalFiles);

        // ب) دانلود فایل‌های صوتی نمونه
        int newSampleAudioVer = book.localSampleAudioVersion;
        if (book.hasSampleAudioUpdate) {
          for (String audioUrl in book.sampleAudioFiles) {
            final fileName = audioUrl.split('/').last;
            await _downloadSingleFile(
              dio,
              audioUrl,
              '${bookFolder.path}/$fileName',
            );
            downloadedFiles++;
            _updateProgress(book.id, downloadedFiles, totalFiles);
          }
          newSampleAudioVer = book.sampleAudioVersion;
        } else {
          downloadedFiles += book.sampleAudioFiles.length; // از قبل دانلود شده
        }

        // ج) دانلود تصاویر نمونه
        int newSampleImagesVer = book.localSampleImagesVersion;
        if (book.hasSampleImagesUpdate) {
          for (String imageUrl in book.sampleImages) {
            final fileName = imageUrl.split('/').last;
            await _downloadSingleFile(
              dio,
              imageUrl,
              '${bookFolder.path}/$fileName',
            );
            downloadedFiles++;
            _updateProgress(book.id, downloadedFiles, totalFiles);
          }
          newSampleImagesVer = book.sampleImagesVersion;
        }

        _updateBook(
          book.id,
          localSamplePath: newSamplePath,
          localSampleVersion: newSampleVer,
          localSampleAudioVersion: newSampleAudioVer,
          localSampleImagesVersion: newSampleImagesVer,
          isDownloading: false,
        );
      } else {
        // --- 2️⃣ جریان دانلود نسخه کامل (Main) ---
        totalFiles = 1 + book.audioFiles.length + book.images.length;

        // الف) دانلود فایل JSON اصلی
        String? newJsonPath = book.localJsonPath;
        int newJsonVer = book.localJsonVersion;

        if (book.jsonFile != null &&
            (!book.isJsonDownloaded || book.hasJsonUpdate)) {
          newJsonPath = '${bookFolder.path}/main_content.json';
          await _downloadSingleFile(dio, book.jsonFile!, newJsonPath);
          newJsonVer = book.jsonVersion;
        }
        downloadedFiles++;
        _updateProgress(book.id, downloadedFiles, totalFiles);

        // ب) دانلود فایل‌های صوتی اصلی
        int newAudioVer = book.localAudioVersion;
        if (book.hasAudioUpdate) {
          for (String audioUrl in book.audioFiles) {
            final fileName = audioUrl.split('/').last;
            await _downloadSingleFile(
              dio,
              audioUrl,
              '${bookFolder.path}/$fileName',
            );
            downloadedFiles++;
            _updateProgress(book.id, downloadedFiles, totalFiles);
          }
          newAudioVer = book.audioVersion;
        }

        // ج) دانلود تصاویر اصلی
        int newImagesVer = book.localImagesVersion;
        if (book.hasImagesUpdate) {
          for (String imageUrl in book.images) {
            final fileName = imageUrl.split('/').last;
            await _downloadSingleFile(
              dio,
              imageUrl,
              '${bookFolder.path}/$fileName',
            );
            downloadedFiles++;
            _updateProgress(book.id, downloadedFiles, totalFiles);
          }
          newImagesVer = book.imagesVersion;
        }

        _updateBook(
          book.id,
          localJsonPath: newJsonPath,
          localJsonVersion: newJsonVer,
          localAudioVersion: newAudioVer,
          localImagesVersion: newImagesVer,
          isDownloading: false,
        );
      }

      StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
    } catch (e) {
      _updateBook(book.id, isDownloading: false, downloadProgress: 0.0);
      debugPrint("Download Error: $e");
    }
  }

  // متد کمکی برای دانلود یک فایل تکی
  Future<void> _downloadSingleFile(Dio dio, String url, String savePath) async {
    try {
      await dio.download(url, savePath);
    } catch (e) {
      debugPrint("Failed to download $url: $e");
      // در یک سناریوی واقعی، می‌توانید فایل‌های خطا خورده را به یک لیست اضافه کنید
      // تا کاربر بداند کدام بخش‌ها دانلود نشده‌اند.
    }
  }

  // متد کمکی برای محاسبه درصد کلی پیشرفت بر اساس تعداد فایل‌ها
  void _updateProgress(String bookId, int downloaded, int total) {
    if (total > 0) {
      _updateBook(
        bookId,
        isDownloading: true,
        downloadProgress: downloaded / total,
      );
    }
  }

  BookModel _updateBook(
    String id, {
    String? localSamplePath,
    int? localSampleVersion,
    int? localSampleAudioVersion,
    int? localSampleImagesVersion,
    String? localJsonPath,
    int? localJsonVersion,
    int? localAudioVersion,
    int? localImagesVersion,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    BookModel? updatedBook;
    state = state.map((b) {
      if (b.id == id) {
        updatedBook = b.copyWith(
          localSamplePath: localSamplePath,
          localSampleVersion: localSampleVersion,
          localSampleAudioVersion: localSampleAudioVersion,
          localSampleImagesVersion: localSampleImagesVersion,
          localJsonPath: localJsonPath,
          localJsonVersion: localJsonVersion,
          localAudioVersion: localAudioVersion,
          localImagesVersion: localImagesVersion,
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
