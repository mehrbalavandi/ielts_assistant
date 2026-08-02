import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

class BookModel {
  final String id;
  final String title;
  final String? folderName;

  // --- 🌐 اطلاعات سرور (Remote) ---
  final Map<String, String> localPageVersions; // remotePagePath -> hash
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
  // 🌟 حالتِ مکث: با isDownloading فرق دارد — یعنی دانلود شروع شده ولی
  // موقتاً متوقف است و فایلِ نیمه‌کاره روی دیسک نگه داشته شده تا با
  // ادامه‌دادن، از همان‌جا (نه از صفر) دنبال شود.
  final bool isPaused;

  // 🌟 هوش تشخیص آپدیت و دانلود (دقیقاً مطابق سناریوی شما)
  bool get isSampleDownloaded =>
      localSamplePath != null && File(localSamplePath!).existsSync();
  bool get isJsonDownloaded =>
      localJsonPath != null && File(localJsonPath!).existsSync();

  bool get hasSampleJsonUpdate =>
      isSampleDownloaded && (localSampleVersion < sampleVersion);
  bool get hasSampleAudioUpdate {
    return localSampleAudioVersion < sampleAudioVersion;
  }

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

  // 🌟 مسیردهی هوشمند و امن برای بوم نقاشی
  String get activeJsonPath {
    // ۱. اگر کاربر لاگین است، کتاب را خریده و فایل اصلی را دارد:
    if (isPurchased && isJsonDownloaded) {
      return localJsonPath!;
    }
    // ۲. در غیر این صورت، حتی اگر فایل اصلی را در حافظه داشت، فقط نسخه نمونه را به او نشان بده:
    if (isSampleDownloaded) {
      return localSamplePath!;
    }
    // ۳. مسیر پیش‌فرض (فال‌بک برای جلوگیری از کرش)
    return 'assets/data/$id.json';
  }

  String get jsonAssetPath => activeJsonPath;

  BookModel({
    required this.id,
    required this.title,
    this.folderName,

    this.localPageVersions = const {},
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
    this.isPaused = false,
  });

  BookModel copyWith({
    Map<String, String>? localPageVersions,
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
    bool? isPaused,
  }) {
    return BookModel(
      id: id,
      title: title,
      folderName: folderName,
      localPageVersions: localPageVersions ?? this.localPageVersions,
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
      isPaused: isPaused ?? this.isPaused,
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? 'بدون عنوان',
    folderName: json['folder_name'],

    localPageVersions:
        (json['localPageVersions'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        const {},
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
    'localPageVersions': localPageVersions,
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

  String _dirOf(String p) {
    final i = p.lastIndexOf('/');
    return i <= 0 ? '' : p.substring(0, i);
  }

  /// index.json را می‌گیرد و فقط صفحاتی که هَش‌شان عوض شده. مسیرِ سروریِ هر صفحه از
  /// dirname(مسیرِ سروریِ index) + file ساخته می‌شود؛ فایل‌های محلی هم‌ساختار ذخیره می‌شوند.
  Future<(bool, Map<String, String>)> _downloadIndexAndPages(
    Dio dio,
    String bookId,
    String remoteIndexPath,
    String localIndexPath,
    Map<String, String> existingVersions,
    void Function() onFileDownloaded, {
    void Function(int changedPageCount)? onPageCountKnown,
  }) async {
    final okIndex = await _downloadSingleFile(
      dio,
      bookId,
      remoteIndexPath,
      localIndexPath,
    );
    if (!okIndex) return (false, existingVersions);
    onFileDownloaded();

    final index =
        jsonDecode(await File(localIndexPath).readAsString())
            as Map<String, dynamic>;
    final pageEntries = (index['Pages'] ?? index['pages']) as List? ?? const [];
    // 🐞 رفع باگِ «پوشه‌ی audio_scripts دانلود نمی‌شود»: اشاره‌گرهای
    // AudioScripts در index.json دقیقاً همان شکلِ {File, Version} را
    // دارند که Pages دارد — قبلاً این تابع فقط Pages را می‌خواند، پس
    // فایل‌های audio_scripts/*.json هیچ‌وقت دانلود نمی‌شدند. با
    // ترکیب‌کردنشان در همین لیست، بقیه‌ی منطقِ موجود (تشخیصِ تغییرکرده‌ها
    // از رویِ هَش، دانلودِ دلتا) بدونِ هیچ تغییرِ دیگری هم برایشان اجرا
    // می‌شود.
    final audioScriptEntries =
        (index['AudioScripts'] ?? index['audioScripts']) as List? ?? const [];
    final entries = [...pageEntries, ...audioScriptEntries];

    final remoteRoot = _dirOf(
      remoteIndexPath,
    ); // books/foo  یا  books/foo/sample
    final localRoot = _dirOf(localIndexPath);
    final versions = Map<String, String>.from(existingVersions);

    // 🌟 اول لیستِ صفحاتِ واقعاً تغییرکرده را بساز تا مخرجِ نوارِ پیشرفت درست شود
    // (قبلاً «۱» برای کل JSON فرض می‌شد؛ با صدها صفحه، درصد به‌اشتباه به
    // «تعداد صفحه × ۱۰۰٪» می‌رسید)
    final changed = <MapEntry<String, String>>[]; // remotePagePath -> version
    for (final e in entries) {
      final rel = (e['file'] ?? e['File']) as String; // pages/page_0001.json
      final ver = (e['version'] ?? e['Version'])?.toString() ?? '';
      final remotePagePath = '$remoteRoot/$rel';
      if (versions[remotePagePath] != ver) {
        changed.add(MapEntry(remotePagePath, ver));
      }
    }
    onPageCountKnown?.call(changed.length);

    for (final entry in changed) {
      final remotePagePath = entry.key;
      final ver = entry.value;
      final rel = remotePagePath.substring(remoteRoot.length + 1);
      final localPagePath = '$localRoot/$rel';
      await Directory(_dirOf(localPagePath)).create(recursive: true);

      if (await _downloadSingleFile(
        dio,
        bookId,
        remotePagePath,
        localPagePath,
      )) {
        versions[remotePagePath] = ver;
        onFileDownloaded();
      }
    }
    return (true, versions);
  }

  // ─────────────── دانلودِ یکجا (ZIP) با قابلیتِ مکث/ادامه ───────────────
  // 🌟 چرا: دانلودِ فایل‌به‌فایل با صدها صفحه/صوت/تصویر بسیار کند است. حالا
  // سرور یک آرشیوِ واحد می‌دهد و همین‌جا استخراج می‌شود. چون سرور هدرِ Range
  // را پشتیبانی می‌کند، دانلودِ نیمه‌کاره در یک فایلِ .part نگه داشته می‌شود
  // و با ادامه‌دادن، از همان بایتِ آخر (نه از صفر) دنبال می‌شود.

  /// برای هر کتابِ در حالِ دانلود یک CancelToken نگه می‌داریم تا بشود مکث کرد.
  final Map<String, CancelToken> _zipCancelTokens = {};

  /// کاربر خودش مکث کرده (در برابرِ قطعِ اتفاقیِ شبکه) — تا در catch بفهمیم
  /// این یک خطا نیست و نباید فایلِ نیمه‌کاره پاک شود.
  final Set<String> _userPaused = {};

  Future<String> _zipPartPath(BookModel book, bool isSample) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = book.folderName ?? book.id;
    return '${dir.path}/$folder/.download_${isSample ? 'sample' : 'main'}.part';
  }

  /// مکثِ دانلودِ در جریان. فایلِ .part دست‌نخورده می‌ماند.
  void pauseZipDownload(BookModel book) {
    final token = _zipCancelTokens[book.id];
    if (token == null || token.isCancelled) return;
    _userPaused.add(book.id);
    token.cancel('paused-by-user');
    _updateBook(book.id, isDownloading: false, isPaused: true);
  }

  /// ادامه‌ی دانلودِ مکث‌شده — همان مسیرِ عادی است، چون خودِ downloadBookZip
  /// وجودِ فایلِ .part را تشخیص می‌دهد و از ادامه‌ی آن شروع می‌کند.
  Future<void> resumeZipDownload(BookModel book, {bool isSample = false}) {
    return downloadBookZip(book, isSample: isSample);
  }

  Future<void> downloadBookZip(BookModel book, {bool isSample = false}) async {
    _userPaused.remove(book.id);
    // 🐞 «مکثِ اولِ نوارِ پیشرفت، بعد پرشدنِ ناگهانی» که تشخیص دادید، از
    // همین‌جا می‌آید: خودِ درخواستِ zip-info سمتِ سرور ensureZip را صدا
    // می‌زند، که برایِ هر کتابی که هنوز از رویِ آپلودِ حفظ‌شده (فیکسِ چند
    // نوبتِ قبل) سرو نمی‌شود، آرشیو را همان لحظه از نو می‌سازد — که برایِ
    // کتابِ بزرگ می‌تواند واقعاً چند ثانیه طول بکشد. تا الان این کل مدت
    // با یک نوارِ پیشرفتِ ثابت‌روی‌صفر نشان داده می‌شد که از «هیچ اتفاقی
    // نمی‌افتد» قابلِ‌تشخیص نبود. downloadProgress=-1 به‌عنوانِ نشانه‌ی
    // «در حالِ آماده‌سازی» به UI اجازه می‌دهد یک اسپینرِ نامعین نشان بدهد،
    // نه یک نوارِ گیرکرده.
    _updateBook(
      book.id,
      isDownloading: true,
      isPaused: false,
      downloadProgress: -1,
    );

    final token = CancelToken();
    _zipCancelTokens[book.id] = token;

    try {
      final dio = ref.read(dioProvider);
      final dir = await getApplicationDocumentsDirectory();
      final bookFolder = Directory('${dir.path}/${book.folderName ?? book.id}');
      if (!await bookFolder.exists()) {
        await bookFolder.create(recursive: true);
      }

      final scope = isSample ? 'sample' : 'main';

      // ۱. حجمِ کل را بگیر — هم برای درصدِ درست، هم برای اعتبارسنجیِ .part
      final infoRes = await dio.get(
        '/api/books/${book.id}/zip-info',
        queryParameters: {'scope': scope},
        cancelToken: token,
      );
      final info = infoRes.data as Map<String, dynamic>;
      final int totalBytes = (info['size'] as num?)?.toInt() ?? 0;

      final partPath = await _zipPartPath(book, isSample);
      final partFile = File(partPath);

      // 🐞 به‌محضِ برگشتنِ zip-info، از حالتِ نامعین خارج می‌شویم — اگر
      // دانلودِ قبلی نیمه‌کاره مانده (partFile موجود)، درصدِ واقعیِ همان‌جا
      // نشان داده می‌شود، نه دوباره صفر.
      final int alreadyOnDisk = await partFile.exists()
          ? await partFile.length()
          : 0;
      _updateBook(
        book.id,
        isDownloading: true,
        downloadProgress: totalBytes > 0
            ? (alreadyOnDisk / totalBytes) * 0.95
            : 0.0,
      );

      int alreadyHave = alreadyOnDisk;
      // اگر فایلِ نیمه‌کاره از حجمِ کل بزرگ‌تر است، یعنی مربوط به نسخه‌ی
      // قدیمی‌ترِ آرشیو بوده — دور بریز و از صفر شروع کن.
      if (totalBytes > 0 && alreadyHave > totalBytes) {
        await partFile.delete();
        alreadyHave = 0;
      }

      if (totalBytes > 0 && alreadyHave == totalBytes) {
        // قبلاً کامل دانلود شده بود ولی استخراج نشده — مستقیم برو به استخراج
        await _extractBookZip(partFile, bookFolder, isSample);
        await _finishZipDownload(book, isSample);
        return;
      }

      // ۲. دانلود با Range از همان‌جایی که قطع شده بود
      final response = await dio.get<ResponseBody>(
        '/api/books/${book.id}/download-zip',
        queryParameters: {'scope': scope},
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: alreadyHave > 0 ? {'Range': 'bytes=$alreadyHave-'} : null,
          // ۴۱۶ یعنی رنجِ نامعتبر (فایلِ سرور عوض شده) — خودمان هندل می‌کنیم
          validateStatus: (s) => s != null && s < 400 || s == 416,
        ),
      );

      if (response.statusCode == 416) {
        // رنجِ درخواستی معتبر نیست → از صفر شروع کن
        if (await partFile.exists()) await partFile.delete();
        _zipCancelTokens.remove(book.id);
        return downloadBookZip(book, isSample: isSample);
      }

      // اگر سرور ۲۰۰ داد (نه ۲۰۶)، یعنی Range را نادیده گرفته و کلِ فایل
      // را می‌فرستد — پس باید از اول بنویسیم، نه اینکه به دنباله‌ی قبلی
      // اضافه کنیم (وگرنه فایلِ خراب می‌شود).
      final bool serverHonoredRange = response.statusCode == 206;
      final int baseOffset = serverHonoredRange ? alreadyHave : 0;

      final sink = partFile.openWrite(
        mode: serverHonoredRange ? FileMode.append : FileMode.write,
      );
      int received = baseOffset;

      try {
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalBytes > 0) {
            _updateBook(
              book.id,
              isDownloading: true,
              // ۹۵٪ برای دانلود، ۵٪ باقی‌مانده برای استخراج
              downloadProgress: (received / totalBytes) * 0.95,
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // ۳. استخراج
      await _extractBookZip(partFile, bookFolder, isSample);
      await _finishZipDownload(book, isSample);
    } catch (e) {
      if (_userPaused.contains(book.id)) {
        // مکثِ عمدی — فایلِ .part عمداً نگه داشته می‌شود
        debugPrint("⏸️ دانلود مکث شد: ${book.id}");
      } else {
        _updateBook(
          book.id,
          isDownloading: false,
          isPaused: false,
          downloadProgress: 0.0,
        );
        debugPrint("🔴 خطای دانلودِ ZIP: $e");
      }
    } finally {
      _zipCancelTokens.remove(book.id);
    }
  }

  /// استخراجِ آرشیو در پوشه‌ی مقصد. ورودی‌های آرشیو از قبل با ساختارِ
  /// موردِ انتظارِ اپ ساخته شده‌اند (index.json و audio/images صاف در ریشه،
  /// pages/ و audio_scripts/ به‌صورتِ زیرپوشه) — پس فقط باز می‌شوند.
  Future<void> _extractBookZip(
    File partFile,
    Directory bookFolder,
    bool isSample,
  ) async {
    final targetRoot = isSample
        ? Directory('${bookFolder.path}/sample')
        : bookFolder;
    if (!await targetRoot.exists()) {
      await targetRoot.create(recursive: true);
    }

    final bytes = await partFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final entry in archive) {
      if (!entry.isFile) continue;
      // 🌟 محافظت در برابرِ Zip Slip: هیچ ورودی‌ای نباید بیرونِ پوشه‌ی مقصد بنویسد
      final safeName = entry.name.replaceAll('\\', '/');
      if (safeName.contains('..') || safeName.startsWith('/')) continue;

      // 🌟 آرشیو دقیقاً همان فایلِ ZIPی است که ادمین آپلود کرده — یعنی
      // audio/ و images/ داخلش زیرپوشه‌اند. ولی اپ فایل‌های صوتی/تصویری را
      // کنارِ خودِ index.json می‌جوید (resolveAudioPath و رندرکننده‌ی تصویر
      // هر دو از parent مسیرِ index.json استفاده می‌کنند). پس همین‌جا، تنها
      // جایی که چیدمانِ روی دیسکِ اپ را می‌شناسد، صافشان می‌کنیم؛
      // pages/ و audio_scripts/ ساختارشان دست‌نخورده می‌ماند.
      final segments = safeName.split('/');
      final String outName;
      if (segments.length > 1 &&
          (segments.first == 'audio' || segments.first == 'images')) {
        outName = segments.last;
      } else {
        outName = safeName;
      }

      final outFile = File('${targetRoot.path}/$outName');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }

    if (await partFile.exists()) {
      await partFile.delete();
    }
  }

  /// بعد از استخراجِ موفق: نسخه‌های محلی را برابرِ نسخه‌های سرور کن.
  Future<void> _finishZipDownload(BookModel book, bool isSample) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = '${dir.path}/${book.folderName ?? book.id}';

    if (isSample) {
      _updateBook(
        book.id,
        localSamplePath: '$folder/sample/index.json',
        localSampleVersion: book.sampleVersion,
        localSampleAudioVersion: book.sampleAudioVersion,
        localSampleImagesVersion: book.sampleImagesVersion,
        isDownloading: false,
        isPaused: false,
        downloadProgress: 1.0,
      );
    } else {
      _updateBook(
        book.id,
        localJsonPath: '$folder/index.json',
        localJsonVersion: book.jsonVersion,
        localAudioVersion: book.audioVersion,
        localImagesVersion: book.imagesVersion,
        isDownloading: false,
        isPaused: false,
        downloadProgress: 1.0,
      );
    }

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  /// حذفِ کاملِ محتوای دانلودشده‌ی یک کتاب (و ریست‌کردنِ نسخه‌های محلی، تا
  /// دفعه‌ی بعد دوباره کامل دانلود شود).
  Future<void> deleteDownloadedBook(BookModel book) async {
    // اگر همین حالا در حالِ دانلود است، اول متوقفش کن
    final token = _zipCancelTokens[book.id];
    if (token != null && !token.isCancelled) {
      token.cancel('deleted-by-user');
    }
    _zipCancelTokens.remove(book.id);
    _userPaused.remove(book.id);

    await _deleteBookFolder(book);

    state = state.map((b) {
      if (b.id != book.id) return b;
      return BookModel(
        id: b.id,
        title: b.title,
        folderName: b.folderName,
        sampleFilePath: b.sampleFilePath,
        sampleVersion: b.sampleVersion,
        sampleAudioFiles: b.sampleAudioFiles,
        sampleAudioVersion: b.sampleAudioVersion,
        sampleImages: b.sampleImages,
        sampleImagesVersion: b.sampleImagesVersion,
        jsonFile: b.jsonFile,
        jsonVersion: b.jsonVersion,
        audioFiles: b.audioFiles,
        audioVersion: b.audioVersion,
        images: b.images,
        imagesVersion: b.imagesVersion,
        isPurchased: b.isPurchased,
        // همه‌ی مقادیرِ محلی عمداً به حالتِ «دانلودنشده» برمی‌گردند
      );
    }).toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  // 🌟 ۱. دانلود منیجر موازی (به‌روزرسانی شده با ردیابی دقیق خطاها)
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

        // --- دانلود JSON نمونه (index + صفحات) ---
        String? newSamplePath = book.localSamplePath;
        int newSampleVer = book.localSampleVersion;
        Map<String, String> newPageVersions = book.localPageVersions;
        if (book.sampleFilePath != null &&
            (!book.isSampleDownloaded || book.hasSampleJsonUpdate)) {
          final localIndex = '${bookFolder.path}/sample/index.json';
          final (ok, versions) = await _downloadIndexAndPages(
            dio,
            book.id,
            book.sampleFilePath!,
            localIndex,
            book.localPageVersions,
            onFileDownloaded,
            onPageCountKnown: (n) => totalFiles += n,
          );
          if (ok) {
            newSamplePath = localIndex;
            newSampleVer = book.sampleVersion;
            newPageVersions = versions;
          }
        }

        // --- دانلود صوت نمونه ---
        int newSampleAudioVer = book.localSampleAudioVersion;
        if (book.hasSampleAudioUpdate || true) {
          bool allSuccess = await _downloadFilesConcurrently(
            dio,
            book.id,
            book.sampleAudioFiles,
            bookFolder.path,
            onFileDownloaded,
          );
          if (allSuccess) newSampleAudioVer = book.sampleAudioVersion;
        }

        // --- دانلود تصویر نمونه ---
        int newSampleImagesVer = book.localSampleImagesVersion;
        if (book.hasSampleImagesUpdate || true) {
          bool allSuccess = await _downloadFilesConcurrently(
            dio,
            book.id,
            book.sampleImages,
            bookFolder.path,
            onFileDownloaded,
          );
          if (allSuccess) newSampleImagesVer = book.sampleImagesVersion;
        }

        _updateBook(
          book.id,
          localSamplePath: newSamplePath,
          localSampleVersion: newSampleVer,
          localPageVersions: newPageVersions,
          localSampleAudioVersion: newSampleAudioVer,
          localSampleImagesVersion: newSampleImagesVer,
          isDownloading: false,
        );
      } else {
        // --- مدیریت نسخه اصلی (همان منطق ایمن بالا برای نسخه پولی) ---
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

        // --- دانلود JSON اصلی (index + صفحات) ---
        String? newJsonPath = book.localJsonPath;
        int newJsonVer = book.localJsonVersion;
        Map<String, String> newPageVersions = book.localPageVersions;
        if (book.jsonFile != null &&
            (!book.isJsonDownloaded || book.hasJsonUpdate)) {
          final localIndex = '${bookFolder.path}/index.json';
          final (ok, versions) = await _downloadIndexAndPages(
            dio,
            book.id,
            book.jsonFile!,
            localIndex,
            book.localPageVersions,
            onFileDownloaded,
            onPageCountKnown: (n) => totalFiles += n,
          );
          if (ok) {
            newJsonPath = localIndex;
            newJsonVer = book.jsonVersion;
            newPageVersions = versions;
          }
        }

        // --- دانلود صوت ---
        int newAudioVer = book.localAudioVersion;
        if (book.hasAudioUpdate) {
          bool allSuccess = await _downloadFilesConcurrently(
            dio,
            book.id,
            book.audioFiles,
            bookFolder.path,
            onFileDownloaded,
          );
          if (allSuccess) newAudioVer = book.audioVersion;
        }

        // --- دانلود تصویر ---
        int newImagesVer = book.localImagesVersion;
        if (book.hasImagesUpdate) {
          bool allSuccess = await _downloadFilesConcurrently(
            dio,
            book.id,
            book.images,
            bookFolder.path,
            onFileDownloaded,
          );
          if (allSuccess) newImagesVer = book.imagesVersion;
        }

        _updateBook(
          book.id,
          localJsonPath: newJsonPath,
          localJsonVersion: newJsonVer,
          localPageVersions: newPageVersions,
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

  // 🌟 ۲. کنترل‌گر فایل‌های موازی (برگرداندن وضعیت موفقیت کلی)
  Future<bool> _downloadFilesConcurrently(
    Dio dio,
    String bookId,
    List<String> paths,
    String folderPath,
    VoidCallback onDownloaded,
  ) async {
    const int batchSize = 5;
    bool allSuccess = true;

    for (int i = 0; i < paths.length; i += batchSize) {
      final batch = paths.sublist(
        i,
        i + batchSize > paths.length ? paths.length : i + batchSize,
      );

      List<Future<void>> futures = batch.map((remotePath) async {
        final fileName = remotePath.split('/').last;
        bool success = await _downloadSingleFile(
          dio,
          bookId,
          remotePath,
          '$folderPath/$fileName',
        );
        if (success) {
          onDownloaded();
        } else {
          allSuccess =
              false; // اگر حتی یک فایل دانلود نشد، وضعیت کلی را خطا در نظر بگیر
        }
      }).toList();

      await Future.wait(futures);
    }
    return allSuccess;
  }

  // 🌟 ۳. متد هسته دانلود (با پارسر هوشمند مسیر لاراول و حذف فایل ناقص)
  Future<bool> _downloadSingleFile(
    Dio dio,
    String bookId,
    String remotePath,
    String savePath,
  ) async {
    try {
      String pathQuery = remotePath;

      // اگر آدرس دیتابیس شامل http بود، آن را برای لاراول تمیز کن تا خطای 404 ندهد
      if (remotePath.startsWith('http')) {
        Uri uri = Uri.parse(remotePath);
        pathQuery = uri.path; // خروجی: /storage/books/sample.json
        if (pathQuery.startsWith('/storage/')) {
          pathQuery = pathQuery.replaceFirst('/storage/', '');
        } else if (pathQuery.startsWith('/public/')) {
          pathQuery = pathQuery.replaceFirst('/public/', '');
        } else if (pathQuery.startsWith('/')) {
          pathQuery = pathQuery.substring(1);
        }
      }

      final String downloadUrl =
          '/api/books/$bookId/download?path=${Uri.encodeComponent(pathQuery)}';

      final response = await dio.download(downloadUrl, savePath);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("🔴 خطای دانلود فایل: $remotePath");
      debugPrint("جزئیات خطا: $e");

      // پاک کردن فایل ناقصِ صفر بایتی در صورت شکست دانلود
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      return false;
    }
  }

  BookModel _updateBook(
    String id, {
    Map<String, String>? localPageVersions,
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
    bool? isPaused,
  }) {
    BookModel? updatedBook;
    state = state.map((b) {
      if (b.id == id) {
        updatedBook = b.copyWith(
          localPageVersions: localPageVersions,
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
          isPaused: isPaused,
        );
        return updatedBook!;
      }
      return b;
    }).toList();
    return updatedBook ?? state.firstWhere((b) => b.id == id);
  }

  Future<void> resetOfflinelocalJsonVersion() async {
    for (final book in state) {
      await _deleteBookContent(book, json: true);
    }

    state = state
        .map((book) => book.copyWith(localJsonPath: null, localJsonVersion: 0))
        .toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  Future<void> resetOfflinelocalAudioVersion() async {
    for (final book in state) {
      await _deleteBookContent(book, audio: true);
    }

    state = state.map((book) => book.copyWith(localAudioVersion: 0)).toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  Future<void> resetOfflinelocalImagesVersion() async {
    for (final book in state) {
      await _deleteBookContent(book, images: true);
    }

    state = state.map((book) => book.copyWith(localImagesVersion: 0)).toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  Future<void> resetOfflineVersions() async {
    for (final book in state) {
      await _deleteBookFolder(book);
    }

    state = state.map((book) {
      return book.copyWith(
        localSamplePath: null,
        localSampleVersion: 0,
        localSampleAudioVersion: 0,
        localSampleImagesVersion: 0,
        localJsonPath: null,
        localJsonVersion: 0,
        localAudioVersion: 0,
        localImagesVersion: 0,
      );
    }).toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  Future<void> _deleteBookFolder(BookModel book) async {
    final dir = await getApplicationDocumentsDirectory();

    final folder = Directory('${dir.path}/${book.folderName ?? book.id}');

    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<void> _deleteBookContent(
    BookModel book, {
    bool json = false,
    bool audio = false,
    bool images = false,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final bookFolder = Directory('${dir.path}/${book.folderName ?? book.id}');

    if (!await bookFolder.exists()) return;

    if (json) {
      final file = File('${bookFolder.path}/main_content.json');
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (audio) {
      for (final path in book.audioFiles) {
        final file = File('${bookFolder.path}/${path.split('/').last}');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    if (images) {
      for (final path in book.images) {
        final file = File('${bookFolder.path}/${path.split('/').last}');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
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
