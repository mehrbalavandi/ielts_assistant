import 'package:get_storage/get_storage.dart';

class StorageService {
  static final _box = GetStorage();

  // کلیدها
  static const String _tokenKey = 'auth_token';
  static const String _booksKey = 'offline_books';
  static const String _baseUrlKey = 'base_url';

  // --- مدیریت توکن ---
  static String? getToken() {
    return _box.read(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _box.write(_tokenKey, token);
  }

  static Future<void> removeToken() async {
    await _box.remove(_tokenKey);
  }

  // --- مدیریت آدرس سرور ---
  static String? getBaseUrl() {
    return _box.read(_baseUrlKey);
  }

  static Future<void> saveBaseUrl(String url) async {
    await _box.write(_baseUrlKey, url);
  }

  // --- مدیریت کتاب‌های آفلاین ---
  static List<dynamic>? getOfflineBooks() {
    return _box.read(_booksKey);
  }

  static Future<void> saveOfflineBooks(List<dynamic> booksJson) async {
    await _box.write(_booksKey, booksJson);
  }

  static void saveLastBookId(String bookId) {
    _box.write('lastBookId', bookId);
  }

  static String? getLastBookId() {
    return _box.read('lastBookId');
  }

  static void clearLastBookId() {
    _box.remove('lastBookId');
  }

  static void clearOfflineBooks() {
    _box.remove(_booksKey);
  }
}
