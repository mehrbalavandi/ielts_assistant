import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// part 'book_provider.g.dart';

// مدل ساده برای کتاب‌ها
class BookModel {
  final String id;
  final String title;
  final String remoteJsonUrl;
  final String remoteCoverUrl;
  final String? localJsonPath;
  final String? localCoverPath;

  // 🌟 این خط اضافه شد تا خطای jsonAssetPath برطرف شود (پل ارتباطی موقت)
  String get jsonAssetPath => localJsonPath ?? 'assets/data/$id.json';

  BookModel({
    required this.id,
    required this.title,
    required this.remoteJsonUrl,
    required this.remoteCoverUrl,
    this.localJsonPath,
    this.localCoverPath,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'بدون عنوان',
      remoteJsonUrl: json['jsonUrl'] ?? '',
      remoteCoverUrl: json['coverUrl'] ?? '',
      localJsonPath: json['localJsonPath'],
      localCoverPath: json['localCoverPath'],
    );
  }
}

// 🌟 پرووایدر دریافت لیست کتاب‌ها از سرور
final availableBooksProvider = FutureProvider<List<BookModel>>((ref) async {
  final baseUrl = ref.watch(baseUrlProvider);

  // اگر آدرس سرور تنظیم نشده بود، لیست خالی برگردان
  if (baseUrl == null || baseUrl.trim().isEmpty) return [];

  final dio = ref.watch(dioProvider);

  try {
    // فرض بر این است که API شما در مسیر /api/books قرار دارد
    final response = await dio.get('$baseUrl/api/books');

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => BookModel.fromJson(json)).toList();
    } else {
      throw Exception('خطا در دریافت اطلاعات از سرور');
    }
  } catch (e) {
    throw Exception('خطای ارتباط با سرور: $e');
  }
});

// پرووایدر مدیریت کتاب فعال (همان کدهای قبلی خودتان)
final activeBookProvider = StateProvider<BookModel?>((ref) {
  // فعلاً ساده‌سازی شده تا زمانی که دانلود منجر به ذخیره آفلاین شود
  return null;
});

// 🌟 کلاس مدیریت نشست جستجو (اضافه شدن jumpTrigger برای اجبار به اسکرول)
class SearchSession {
  final String query;
  final List<dynamic> results; // از نوع SearchResult
  final int currentIndex;
  final int jumpTrigger; // 🌟 متغیر جدید برای اجبار به پرش

  SearchSession({
    required this.query,
    required this.results,
    required this.currentIndex,
    this.jumpTrigger = 0,
  });

  SearchSession copyWith({int? currentIndex, int? jumpTrigger}) {
    return SearchSession(
      query: query,
      results: results,
      currentIndex: currentIndex ?? this.currentIndex,
      jumpTrigger: jumpTrigger ?? this.jumpTrigger,
    );
  }
}

// پرووایدر سراسری
final activeSearchProvider = StateProvider<SearchSession?>((ref) => null);
