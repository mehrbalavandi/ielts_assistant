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
  final List<String> sampleAudioFiles;
  final int sampleAudioVersion;
  final List<String> sampleImages;
  final int sampleImagesVersion;

  final String? jsonFile;
  final int jsonVersion;
  final List<String> audioFiles;
  final int audioVersion;
  final List<String> images;
  final int imagesVersion;

  // --- 📱 اطلاعات محلی (Local) ---
  final String? localSamplePath;
  final int localSampleVersion;
  final int localSampleAudioVersion;
  final int localSampleImagesVersion;

  final String? localJsonPath;
  final int localJsonVersion;
  final int localAudioVersion;
  final int localImagesVersion;

  // --- ⚙️ وضعیت‌های منطقی و UI ---
  final bool isPurchased;
  final bool isDownloading;
  final double downloadProgress;

  // 🌟 هوش تشخیص آپدیت و دانلود (دقیقاً مطابق سناریوی شما)
  bool get isSampleDownloaded =>
      localSamplePath != null && File(localSamplePath!).existsSync();
  bool get isJsonDownloaded =>
      localJsonPath != null && File(localJsonPath!).existsSync();

  bool get hasSampleJsonUpdate =>
      isSampleDownloaded && (localSampleVersion < sampleVersion);
  bool get hasSampleAudioUpdate => localSampleAudioVersion < sampleAudioVersion;
  bool get hasSampleImagesUpdate =>
      localSampleImagesVersion < sampleImagesVersion;
  bool get hasAnySampleUpdate =>
      hasSampleJsonUpdate || hasSampleAudioUpdate || hasSampleImagesUpdate;

  bool get hasJsonUpdate =>
      isJsonDownloaded && (localJsonVersion < jsonVersion);
  bool get hasAudioUpdate => localAudioVersion < audioVersion;
  bool get hasImagesUpdate => localImagesVersion < imagesVersion;
  bool get hasAnyMainUpdate =>
      hasJsonUpdate || hasAudioUpdate || hasImagesUpdate;

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

  // 🌟 دانلود منیجر موازی (Parallel Batch Downloader)
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
      int downloadedCount = 0;

      void onFileDownloaded() {
        downloadedCount++;
        if (totalFiles > 0) {
          _updateBook(
            book.id,
            isDownloading: true,
            downloadProgress: downloadedCount / totalFiles,
          );
        }
      }

      if (isSample) {
        // --- مدیریت نسخه نمونه ---
        totalFiles =
            (book.sampleFilePath != null &&
                    (!book.isSampleDownloaded || book.hasSampleJsonUpdate)
                ? 1
                : 0) +
            (book.hasSampleAudioUpdate ? book.sampleAudioFiles.length : 0) +
            (book.hasSampleImagesUpdate ? book.sampleImages.length : 0);

        if (totalFiles == 0) {
          _updateBook(book.id, isDownloading: false);
          return;
        }

        String? newSamplePath = book.localSamplePath;
        if (book.sampleFilePath != null &&
            (!book.isSampleDownloaded || book.hasSampleJsonUpdate)) {
          newSamplePath = '${bookFolder.path}/sample.json';
          await _downloadSingleFile(dio, book.sampleFilePath!, newSamplePath);
          onFileDownloaded();
        }

        if (book.hasSampleAudioUpdate) {
          await _downloadFilesConcurrently(
            dio,
            book.sampleAudioFiles,
            bookFolder.path,
            onFileDownloaded,
          );
        }

        if (book.hasSampleImagesUpdate) {
          await _downloadFilesConcurrently(
            dio,
            book.sampleImages,
            bookFolder.path,
            onFileDownloaded,
          );
        }

        _updateBook(
          book.id,
          localSamplePath: newSamplePath,
          localSampleVersion: book.sampleVersion,
          localSampleAudioVersion: book.sampleAudioVersion,
          localSampleImagesVersion: book.sampleImagesVersion,
          isDownloading: false,
        );
      } else {
        // --- مدیریت نسخه اصلی ---
        totalFiles =
            (book.jsonFile != null &&
                    (!book.isJsonDownloaded || book.hasJsonUpdate)
                ? 1
                : 0) +
            (book.hasAudioUpdate ? book.audioFiles.length : 0) +
            (book.hasImagesUpdate ? book.images.length : 0);

        if (totalFiles == 0) {
          _updateBook(book.id, isDownloading: false);
          return;
        }

        String? newJsonPath = book.localJsonPath;
        if (book.jsonFile != null &&
            (!book.isJsonDownloaded || book.hasJsonUpdate)) {
          newJsonPath = '${bookFolder.path}/main_content.json';
          await _downloadSingleFile(dio, book.jsonFile!, newJsonPath);
          onFileDownloaded();
        }

        if (book.hasAudioUpdate) {
          // 🌟 دانلود موازی تمام فایل‌های صوتی
          await _downloadFilesConcurrently(
            dio,
            book.audioFiles,
            bookFolder.path,
            onFileDownloaded,
          );
        }

        if (book.hasImagesUpdate) {
          // 🌟 دانلود موازی تمام تصاویر
          await _downloadFilesConcurrently(
            dio,
            book.images,
            bookFolder.path,
            onFileDownloaded,
          );
        }

        _updateBook(
          book.id,
          localJsonPath: newJsonPath,
          localJsonVersion: book.jsonVersion,
          localAudioVersion: book.audioVersion,
          localImagesVersion: book.imagesVersion,
          isDownloading: false,
        );
      }

      StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
    } catch (e) {
      _updateBook(book.id, isDownloading: false, downloadProgress: 0.0);
      debugPrint("Download Error: $e");
    }
  }

  // 🌟 متد جادویی برای دانلود موازی (۵ فایل همزمان برای جلوگیری از مسدود شدن سوکت)
  Future<void> _downloadFilesConcurrently(
    Dio dio,
    List<String> urls,
    String folderPath,
    VoidCallback onDownloaded,
  ) async {
    const int batchSize = 5;
    for (int i = 0; i < urls.length; i += batchSize) {
      final batch = urls.sublist(
        i,
        i + batchSize > urls.length ? urls.length : i + batchSize,
      );

      List<Future<void>> futures = batch.map((url) async {
        final fileName = url.split('/').last;
        await _downloadSingleFile(dio, url, '$folderPath/$fileName');
        onDownloaded();
      }).toList();

      await Future.wait(
        futures,
      ); // صبر می‌کند تا این ۵ فایل تمام شوند سپس سراغ ۵ تای بعدی می‌رود
    }
  }

  Future<void> _downloadSingleFile(Dio dio, String url, String savePath) async {
    try {
      await dio.download(url, savePath);
    } catch (e) {
      debugPrint("Failed to download $url: $e");
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
