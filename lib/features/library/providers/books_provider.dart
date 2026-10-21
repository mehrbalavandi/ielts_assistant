import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ielts_assistant/core/license/license_service.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/network/session_events.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';

class BookModel {
  final String id;
  final String title;
  final String? folderName;

  // --- 🗂️ دسته و ترتیبِ نمایش (از سرور؛ قانونِ C-1) ---
  // null یعنی «سایر کتاب‌ها» (یا سرورِ قدیمی که هنوز دسته ندارد).
  final String? categoryId;
  final String? categoryTitle;
  final String? categoryDescription;
  final int? categorySort; // شماره‌ی ردیفِ دسته
  final int? sortOrder; // شماره‌ی ردیفِ کتاب داخلِ دسته‌اش

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

  // --- 🛍️ SF-1: معرفی در ویترین (از سرور؛ برای حالتِ آفلاین هم ذخیره می‌شود) ---
  /// null = سرورِ قدیمی که has_sample نمی‌فرستد (آن‌وقت وجودِ مسیرِ نمونه ملاک است).
  final bool? serverHasSample;

  /// 🛍️ SF-4: محتوای اصلی روی سرور هست؛ null = سرورِ قدیمی (خریدنی فرض می‌شود).
  final bool? serverHasContent;
  final int price;
  final int discount;
  final int finalPrice;
  final String? description;
  final String? author;
  final String? publisher;
  final String? level;
  final int? pageCount;
  final int? audioCount;

  /// نشانیِ نسبی یا مطلقِ جلد و نسخه‌اش (با جلدِ تازه عوض می‌شود).
  final String? coverUrl;
  final String? coverVersion;

  /// جلدِ دانلودشده روی همین دستگاه و نسخه‌اش (آفلاین).
  final String? localCoverPath;
  final String? localCoverVersion;

  /// دکمه‌ی «دریافت نمونه» فقط وقتی فعال است که نمونه واقعاً روی سرور هست.
  bool get hasSample =>
      serverHasSample ?? (sampleFilePath?.trim().isNotEmpty ?? false);

  /// 🛍️ SF-4: کتابِ بی‌محتوا خریدنی نیست («در حالِ آماده‌سازی»).
  bool get hasContent => serverHasContent ?? true;
  bool get hasLocalCover =>
      localCoverPath != null && File(localCoverPath!).existsSync();
  bool get hasDiscount => discount > 0 && finalPrice < price;
  bool get isFree => price <= 0;

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

  /// 🌟 DEV-4: نسخه‌ی کامل فقط با خرید **و** مجوزِ آفلاینِ معتبرِ همین دستگاه و همین کاربر
  /// باز می‌شود (LicenseService). isPurchased به‌تنهایی کافی نیست، چون در فایلِ ذخیره‌ی
  /// اپ است و قابلِ دست‌کاری.
  LicenseStatus get licenseStatus => LicenseService.status(id);
  bool get mainUnlocked => isPurchased && LicenseService.allows(id);

  /// خریده شده و دانلود شده، ولی مجوزِ این دستگاه الان معتبر نیست (آفلاینِ طولانی، ساعتِ عقب، …).
  bool get mainLocked => isPurchased && isJsonDownloaded && !mainUnlocked;

  /// کتاب همین حالا در صفحه‌ی مطالعه باز می‌شود (نسخه‌ی کاملِ مجاز، یا نمونه برای خریدارنشده).
  bool get canOpenReader =>
      (mainUnlocked && isJsonDownloaded) || (!isPurchased && isSampleDownloaded);

  // 🌟 مسیردهی هوشمند و امن برای بوم نقاشی
  String get activeJsonPath {
    // ۱. اگر کاربر لاگین است، کتاب را خریده، مجوزِ این دستگاه معتبر است و فایل اصلی را دارد:
    if (mainUnlocked && isJsonDownloaded) {
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
    this.categoryId,
    this.categoryTitle,
    this.categoryDescription,
    this.categorySort,
    this.sortOrder,

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
    this.serverHasSample,
    this.serverHasContent,
    this.price = 0,
    this.discount = 0,
    this.finalPrice = 0,
    this.description,
    this.author,
    this.publisher,
    this.level,
    this.pageCount,
    this.audioCount,
    this.coverUrl,
    this.coverVersion,
    this.localCoverPath,
    this.localCoverVersion,
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
    String? localCoverPath,
    String? localCoverVersion,
    bool clearLocalCover = false,
    // 🌟 DEV-1: محتوای کامل از دستگاه پاک شد (دستگاه از حساب جدا شده) — نمونه می‌ماند.
    bool clearMain = false,
  }) {
    return BookModel(
      id: id,
      title: title,
      folderName: folderName,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      categoryDescription: categoryDescription,
      categorySort: categorySort,
      sortOrder: sortOrder,
      localPageVersions: clearMain
          ? const {}
          : (localPageVersions ?? this.localPageVersions),
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
      localJsonPath: clearMain ? null : (localJsonPath ?? this.localJsonPath),
      localJsonVersion: clearMain ? 0 : (localJsonVersion ?? this.localJsonVersion),
      localAudioVersion: clearMain
          ? 0
          : (localAudioVersion ?? this.localAudioVersion),
      localImagesVersion: clearMain
          ? 0
          : (localImagesVersion ?? this.localImagesVersion),

      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isPurchased: clearMain ? false : (isPurchased ?? this.isPurchased),
      isPaused: isPaused ?? this.isPaused,
      serverHasSample: serverHasSample,
      serverHasContent: serverHasContent,
      price: price,
      discount: discount,
      finalPrice: finalPrice,
      description: description,
      author: author,
      publisher: publisher,
      level: level,
      pageCount: pageCount,
      audioCount: audioCount,
      coverUrl: coverUrl,
      coverVersion: coverVersion,
      localCoverPath: clearLocalCover
          ? null
          : (localCoverPath ?? this.localCoverPath),
      localCoverVersion: clearLocalCover
          ? null
          : (localCoverVersion ?? this.localCoverVersion),
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) {
    // 🗂️ سرور: {"category": {id, title, description, sort_order} | null, "sort_order": n}
    // ذخیره‌ی آفلاین هم با همین شکل نوشته می‌شود (toJson).
    final Map<String, dynamic>? category = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : null;
    return BookModel._fromJson(json, category);
  }

  factory BookModel._fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? category,
  ) => BookModel(
    id: json['id']?.toString() ?? '',
    title: json['title'] ?? 'بدون عنوان',
    folderName: json['folder_name'],
    categoryId: category?['id']?.toString(),
    categoryTitle: (category?['title'] as String?)?.trim(),
    categoryDescription: (category?['description'] as String?)?.trim(),
    categorySort: (category?['sort_order'] as num?)?.toInt(),
    sortOrder: (json['sort_order'] as num?)?.toInt(),

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

    serverHasSample: json['has_sample'] is bool ? json['has_sample'] as bool : null,
    serverHasContent: json['has_content'] is bool ? json['has_content'] as bool : null,
    price: _asInt(json['price']) ?? 0,
    discount: _asInt(json['discount']) ?? 0,
    finalPrice: _asInt(json['final_price']) ?? _asInt(json['price']) ?? 0,
    description: _asText(json['description']),
    author: _asText(json['author']),
    publisher: _asText(json['publisher']),
    level: _asText(json['level']),
    pageCount: _asInt(json['page_count']),
    audioCount: _asInt(json['audio_count']),
    coverUrl: _asText(json['cover_url']),
    coverVersion: _asText(json['cover_version']),
    localCoverPath: json['localCoverPath'] as String?,
    localCoverVersion: json['localCoverVersion'] as String?,
  );

  /// MySQL گاهی عدد را رشته برمی‌گرداند؛ هر دو پذیرفته می‌شود.
  static int? _asInt(Object? v) => v is num
      ? v.round()
      : (v is String ? num.tryParse(v)?.round() : null);

  static String? _asText(Object? v) {
    final String t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'folder_name': folderName,
    'category': categoryId == null
        ? null
        : {
            'id': categoryId,
            'title': categoryTitle,
            'description': categoryDescription,
            'sort_order': categorySort,
          },
    'sort_order': sortOrder,
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

    'has_sample': serverHasSample,
    'has_content': serverHasContent,
    'price': price,
    'discount': discount,
    'final_price': finalPrice,
    'description': description,
    'author': author,
    'publisher': publisher,
    'level': level,
    'page_count': pageCount,
    'audio_count': audioCount,
    'cover_url': coverUrl,
    'cover_version': coverVersion,
    'localCoverPath': localCoverPath,
    'localCoverVersion': localCoverVersion,
  };
}

/// 🗂️ قانونِ C-1: ترتیبِ نمایشِ کتاب‌ها — دسته‌ها به شماره‌ی ردیفِ دسته («سایر»
/// آخر)، داخلِ هر دسته به شماره‌ی ردیفِ کتاب؛ نه ترتیبِ آپلود. برای مساوی‌ها
/// ترتیبِ فعلی حفظ می‌شود (مرتب‌سازیِ پایدار).
List<BookModel> sortBooksForCatalog(List<BookModel> books) {
  final indexed = books.asMap().entries.toList();
  int cmp(int a, int b) => a.compareTo(b);
  indexed.sort((x, y) {
    final a = x.value, b = y.value;
    final int byOther = cmp(
      a.categoryId == null ? 1 : 0,
      b.categoryId == null ? 1 : 0,
    );
    if (byOther != 0) return byOther;
    final int byCategory = cmp(a.categorySort ?? 0, b.categorySort ?? 0);
    if (byCategory != 0) return byCategory;
    final int byCategoryId = (a.categoryId ?? '').compareTo(b.categoryId ?? '');
    if (byCategoryId != 0) return byCategoryId;
    final int byRow = cmp(a.sortOrder ?? 1 << 30, b.sortOrder ?? 1 << 30);
    if (byRow != 0) return byRow;
    return cmp(x.key, y.key);
  });
  return [for (final e in indexed) e.value];
}

/// 🗂️ یک دسته با کتاب‌هایش (به ترتیبِ C-1). key = شناسه‌ی دسته یا 'other'.
class BookCategoryGroup {
  final String key;
  final String title;
  final String? description;
  final List<BookModel> books;
  const BookCategoryGroup({
    required this.key,
    required this.title,
    required this.description,
    required this.books,
  });
}

/// 🗂️ گروه‌بندیِ کتاب‌ها بر اساسِ دسته، به ترتیبِ C-1.
List<BookCategoryGroup> groupBooksForCatalog(List<BookModel> books) {
  final List<BookCategoryGroup> groups = [];
  final Map<String, List<BookModel>> byKey = {};
  for (final b in sortBooksForCatalog(books)) {
    final key = b.categoryId ?? 'other';
    final list = byKey[key];
    if (list != null) {
      list.add(b);
    } else {
      final fresh = <BookModel>[b];
      byKey[key] = fresh;
      groups.add(
        BookCategoryGroup(
          key: key,
          title: (b.categoryTitle?.isNotEmpty ?? false)
              ? b.categoryTitle!
              : 'سایر کتاب‌ها',
          description: b.categoryDescription,
          books: fresh,
        ),
      );
    }
  }
  return groups;
}

class BooksNotifier extends Notifier<List<BookModel>> {
  @override
  List<BookModel> build() {
    final offlineData = StorageService.getOfflineBooks();
    List<BookModel> initialBooks = [];
    if (offlineData != null) {
      initialBooks = sortBooksForCatalog(
        offlineData
            .map((e) => BookModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    // 🌟 DEV-6: بی‌حساب (خارج‌شده) هیچ کتابی «خریداری‌شده» نیست، حتی اگر فهرستِ ذخیره‌شده از
    // نشستِ قبلی مانده باشد؛ وگرنه کارت هم «خریداری شده» و هم «نیاز به تمدیدِ مجوز» می‌گفت.
    final String? token = StorageService.getToken();
    if (token == null || token.isEmpty) {
      initialBooks = [for (final BookModel b in initialBooks) _asSignedOut(b)];
    }

    Future.microtask(() => fetchBooks());
    return initialBooks;
  }

  /// 🌟 DEV-6: خروج از حساب ← ویترین فوراً حالتِ مهمان می‌گیرد: خریدها دیگر «خریداری شده»
  /// نیستند (برچسب و «نیاز به تمدیدِ مجوز» نمی‌آیند) و کتاب مثلِ ویترینِ مهمان قیمت و نمونه دارد.
  /// فایل‌های دانلودشده سرِ جایشان می‌مانند (مسیرها حفظ می‌شوند) و با ورودِ دوباره، سرور خرید را
  /// برمی‌گرداند و همان‌ها بی‌دانلودِ دوباره باز می‌شوند. بعد از سرور هم تازه می‌شود (اگر آنلاین).
  Future<void> onSignedOut() async {
    state = [for (final BookModel b in state) _asSignedOut(b)];
    await StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
    unawaited(fetchBooks());
  }

  /// 🌟 DEV-6/DEV-7: بی‌حساب، کتاب «خریداری‌شده» نیست — جز در مهلتِ بعد از خروج که مجوزِ همین
  /// دستگاه هنوز اجازه می‌دهد (کتابِ دانلودشده بی‌اینترنت هم باز می‌شود).
  BookModel _asSignedOut(BookModel b) => b.copyWith(
    isPurchased: b.isPurchased &&
        LicenseService.inSignedOutGrace &&
        LicenseService.allows(b.id),
  );

  /// 🌟 C-6: درخواستِ هم‌زمانِ دوم (برگشت به ویترین + فراخوانیِ صریح) همان درخواستِ در جریان
  /// را می‌گیرد، نه یک درخواستِ تازه.
  Future<void>? _fetching;

  Future<void> fetchBooks() =>
      _fetching ??= _fetchBooks().whenComplete(() => _fetching = null);

  Future<void> _fetchBooks() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/books');

      if (response.statusCode == 200) {
        final rawData = response.data;
        List<dynamic> dataList = [];

        // 🌟 DEV-1/4: سرور می‌گوید نشستِ این دستگاه تمام است (دستگاه جدا شده، توکنِ کپی‌شده،
        // توکنِ نسخه‌ی قدیمی) ← SessionGuard. وگرنه مجوزِ آفلاین تمدید می‌شود — پیش از
        // state = …، تا کارت‌ها با مجوزِ تازه ساخته شوند.
        if (rawData is Map) {
          final Object? session = rawData['session'];
          // bound=false: توکنِ نسخه‌ی قدیمیِ اپ (بی‌دستگاه) — یک‌بار خروج تا با ورودِ دوباره
          // دستگاه ثبت شود و مجوز بگیرد.
          if (session is Map &&
              (session['valid'] == false || session['bound'] == false)) {
            SessionEvents.emit(
              (session['reason'] ?? 'invalid_token').toString(),
              session['message']?.toString(),
            );
          }
          if (rawData['license'] != null) {
            await LicenseService.save(rawData['license']);
          }
        }

        if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
          dataList = rawData['data'];
        } else if (rawData is List) {
          dataList = rawData;
        }

        List<BookModel> freshBooks = dataList
            .map((json) => BookModel.fromJson(json))
            .toList();
        // 🌟 DEV-7: مهمان در مهلتِ بعد از خروج — سرور «خریده‌نشده» می‌گوید، ولی مجوزِ همین دستگاه
        // هنوز اجازه می‌دهد.
        final String? tokenNow = StorageService.getToken();
        if (tokenNow == null || tokenNow.isEmpty) {
          freshBooks = [
            for (final BookModel b in freshBooks)
              LicenseService.inSignedOutGrace && LicenseService.allows(b.id)
                  ? b.copyWith(isPurchased: true)
                  : b,
          ];
        }

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
              // 🛍️ SF-1: جلدِ دانلودشده می‌ماند؛ اگر نسخه‌اش عوض شده، _syncCovers تازه‌اش می‌کند.
              localCoverPath: existingBook.localCoverPath,
              localCoverVersion: existingBook.localCoverVersion,
            );
          }
          return freshBook;
        }).toList();

        // 🗂️ C-1: ترتیبِ نمایش از شماره‌ی ردیف‌هاست (سرور هم همین را می‌فرستد؛
        // این‌جا فقط برای اطمینان دوباره مرتب می‌شود).
        mergedBooks = sortBooksForCatalog(mergedBooks);
        state = mergedBooks;
        StorageService.saveOfflineBooks(
          mergedBooks.map((b) => b.toJson()).toList(),
        );
        // 🛍️ SF-1: جلدها برای حالتِ آفلاین روی دستگاه ذخیره می‌شوند.
        unawaited(_syncCovers());
      }
    } catch (e) {
      debugPrint("Fetch Books Error: $e");
    }
  }

  bool _syncingCovers = false;

  /// 🛍️ SF-1: جلدِ هر کتاب یک‌بار دانلود و روی دستگاه نگه داشته می‌شود (ویترینِ آفلاین).
  /// فقط وقتی دوباره گرفته می‌شود که نسخه‌اش روی سرور عوض شده یا فایل پاک شده باشد؛ تا
  /// جلدِ تازه کامل نرسیده، جلدِ قبلی نمایش داده می‌شود. جلدی که از سرور حذف شده، از
  /// دستگاه هم پاک می‌شود.
  Future<void> _syncCovers() async {
    if (_syncingCovers) return;
    _syncingCovers = true;
    bool changed = false;
    try {
      final dio = ref.read(dioProvider);
      final docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory('${docs.path}/covers');
      await dir.create(recursive: true);

      for (final BookModel b in List<BookModel>.of(state)) {
        if (b.coverUrl == null || b.coverVersion == null) {
          if (b.localCoverPath != null) {
            await _deleteQuietly(b.localCoverPath!);
            _setCover(b.id, null, null);
            changed = true;
          }
          continue;
        }
        if (b.localCoverVersion == b.coverVersion && b.hasLocalCover) continue;

        final String safe = b.coverVersion!.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        final String path = '${dir.path}/${b.id}_$safe';
        final String part = '$path.part';
        try {
          final res = await dio.download(
            b.coverUrl!,
            part,
            options: Options(receiveTimeout: const Duration(seconds: 30)),
          );
          if (res.statusCode == 200 && await File(part).length() > 0) {
            await File(part).rename(path);
            if (b.localCoverPath != null && b.localCoverPath != path) {
              await _deleteQuietly(b.localCoverPath!);
            }
            _setCover(b.id, path, b.coverVersion);
            changed = true;
          } else {
            await _deleteQuietly(part);
          }
        } catch (e) {
          debugPrint('Cover download failed for ${b.id}: $e');
          await _deleteQuietly(part);
        }
      }
    } catch (e) {
      debugPrint('Cover sync error: $e');
    } finally {
      _syncingCovers = false;
      if (changed) {
        StorageService.saveOfflineBooks(state.map((b) => b.toJson()).toList());
      }
    }
  }

  void _setCover(String id, String? path, String? version) {
    state = [
      for (final b in state)
        if (b.id == id)
          (path == null
              ? b.copyWith(clearLocalCover: true)
              : b.copyWith(localCoverPath: path, localCoverVersion: version))
        else
          b,
    ];
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
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

  /// استخراجِ آرشیو در پوشه‌ی مقصد، با حفظِ کاملِ ساختارِ داخلیِ آرشیو
  /// (index.json در ریشه؛ pages/ , audio/ , images/ , audio_scripts/ همگی
  /// به‌صورتِ زیرپوشه). دیگر چیزی صاف نمی‌شود.
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

      // 🐞 درخواستِ کاربر: چیدمانِ روی دیسک دقیقاً مثلِ آرشیو باشد — audio/ و
      // images/ به‌صورتِ زیرپوشه بمانند (مثلِ pages/ و audio_scripts/)، نه صاف
      // در ریشه. پیش‌تر این‌جا آن‌ها را صاف می‌کردیم؛ حالا مسیرِ کاملِ داخلِ
      // آرشیو حفظ می‌شود. (resolveAudioPath و رندرکننده‌ی تصویر هم به‌روز شدند
      // تا اول زیرپوشه را نگاه کنند و برای کتاب‌های قدیمیِ صافْ‌ذخیره‌شده هم
      // fallbackِ ریشه داشته باشند.)
      final outFile = File('${targetRoot.path}/$safeName');
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
        // 🐞 C-4: دسته و ترتیب هم باید بمانند. قبلاً این‌جا جا افتاده بودند، پس بعد از
        // «آزادسازیِ فضا» کتاب تا رفرشِ بعدیِ ویترین به «سایر کتاب‌ها» می‌رفت.
        categoryId: b.categoryId,
        categoryTitle: b.categoryTitle,
        categoryDescription: b.categoryDescription,
        categorySort: b.categorySort,
        sortOrder: b.sortOrder,
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
        // 🐞 معرفیِ ویترین (SF-1/SF-4) هم بماند؛ قبلاً تا رفرشِ بعدی قیمت و جلد و … گم می‌شد.
        serverHasSample: b.serverHasSample,
        serverHasContent: b.serverHasContent,
        price: b.price,
        discount: b.discount,
        finalPrice: b.finalPrice,
        description: b.description,
        author: b.author,
        publisher: b.publisher,
        level: b.level,
        pageCount: b.pageCount,
        audioCount: b.audioCount,
        coverUrl: b.coverUrl,
        coverVersion: b.coverVersion,
        localCoverPath: b.localCoverPath,
        localCoverVersion: b.localCoverVersion,
        // همه‌ی مقادیرِ محلی عمداً به حالتِ «دانلودنشده» برمی‌گردند
      );
    }).toList();

    await StorageService.saveOfflineBooks(
      state.map((b) => b.toJson()).toList(),
    );
  }

  /// 🌟 DEV-1: این دستگاه از حساب جدا شد ← محتوای کاملِ همه‌ی کتاب‌ها از دستگاه پاک می‌شود.
  /// فقط پوشه‌ی sample/ (نمونه‌ی رایگان) و جلدها می‌مانند. دانلودهای در جریان هم متوقف می‌شوند.
  Future<void> wipePurchasedContent() async {
    for (final CancelToken t in _zipCancelTokens.values) {
      if (!t.isCancelled) t.cancel('device-released');
    }
    _zipCancelTokens.clear();
    _userPaused.clear();

    final Directory docs = await getApplicationDocumentsDirectory();
    for (final BookModel book in state) {
      final Directory folder = Directory(
        '${docs.path}/${book.folderName ?? book.id}',
      );
      try {
        if (await folder.exists()) {
          await for (final FileSystemEntity e in folder.list()) {
            final String name = e.uri.pathSegments
                .where((p) => p.isNotEmpty)
                .last;
            if (name == 'sample') continue;
            await e.delete(recursive: true);
          }
        }
        // فایلِ نیمه‌دانلودِ نسخه‌ی کامل
        final File part = File(await _zipPartPath(book, false));
        if (await part.exists()) await part.delete();
      } catch (e) {
        debugPrint('wipe ${book.id}: $e');
      }
    }

    state = [
      for (final BookModel b in state)
        b.copyWith(
          clearMain: true,
          isDownloading: false,
          isPaused: false,
          downloadProgress: 0,
        ),
    ];
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
            '${bookFolder.path}/audio', // 🐞 زیرپوشه‌ی audio/
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
            '${bookFolder.path}/images', // 🐞 زیرپوشه‌ی images/
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

    // 🐞 مطمئن شو پوشه‌ی مقصد (مثلاً audio/ یا images/) وجود دارد.
    final targetDir = Directory(folderPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

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

    // 🐞 فایل‌ها ممکن است در زیرپوشه (audio/ , images/) یا — برای کتاب‌های
    // قدیمی — صاف در ریشه باشند؛ هر دو محل را پاک می‌کنیم.
    if (audio) {
      for (final path in book.audioFiles) {
        final base = path.split('/').last;
        for (final p in [
          '${bookFolder.path}/audio/$base',
          '${bookFolder.path}/$base',
        ]) {
          final file = File(p);
          if (await file.exists()) await file.delete();
        }
      }
    }

    if (images) {
      for (final path in book.images) {
        final base = path.split('/').last;
        for (final p in [
          '${bookFolder.path}/images/$base',
          '${bookFolder.path}/$base',
        ]) {
          final file = File(p);
          if (await file.exists()) await file.delete();
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

  /// 🌟 S-16: این تغییرِ نتیجه را خودِ پلیرِ صوتی انجام داده (پیمایشِ جستجو داخلِ برگه‌ی
  /// اسکریپت، به فایلِ صوتیِ بعدی)؛ صفحه‌ی مطالعه نباید دوباره پلیر باز کند. copyWith
  /// بدونِ ذکرش آن را false می‌کند.
  final bool handledInPlayer;
  SearchSession({
    required this.query,
    required this.results,
    required this.currentIndex,
    this.jumpTrigger = 0,
    this.handledInPlayer = false,
  });
  SearchSession copyWith({
    int? currentIndex,
    int? jumpTrigger,
    bool handledInPlayer = false,
  }) => SearchSession(
    query: query,
    results: results,
    currentIndex: currentIndex ?? this.currentIndex,
    jumpTrigger: jumpTrigger ?? this.jumpTrigger,
    handledInPlayer: handledInPlayer,
  );
}

final activeSearchProvider = StateProvider<SearchSession?>((ref) => null);
