import 'package:get_storage/get_storage.dart';

class StorageService {
  final _box = GetStorage();

  // کلیدهای ذخیره‌سازی
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';
  // 🔑 کلیدهای جدید برای کش آفلاین
  static const _myBooksKey = 'my_books_cache';
  static const _localPathsKey = 'local_file_paths';
  // ذخیره توکن
  void saveToken(String token) => _box.write(_tokenKey, token);

  // خواندن توکن
  String? getToken() => _box.read<String>(_tokenKey);

  // ذخیره اطلاعات کاربر (به صورت Map)
  void saveUser(Map<String, dynamic> user) => _box.write(_userKey, user);

  // خواندن اطلاعات کاربر
  Map<String, dynamic>? getUser() => _box.read<Map<String, dynamic>>(_userKey);

  // پاکسازی کل اطلاعات در هنگام Logout
  void clearAuth() {
    _box.remove(_tokenKey);
    _box.remove(_userKey);
  }

  void saveMyBooks(List<dynamic> books) => _box.write(_myBooksKey, books);

  List<dynamic> getMyBooks() => _box.read<List<dynamic>>(_myBooksKey) ?? [];

  // ذخیره مسیر فایل‌های دانلود شده
  void saveLocalFilePaths(Map<int, String> paths) {
    // تبدیل کلید int به String برای سازگاری با JSON
    final stringKeyMap = paths.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    _box.write(_localPathsKey, stringKeyMap);
  }

  // خواندن مسیر فایل‌های دانلود شده
  Map<int, String> getLocalFilePaths() {
    final Map<String, dynamic>? storedMap = _box.read<Map<String, dynamic>>(
      _localPathsKey,
    );
    if (storedMap == null) return {};

    // برگرداندن کلیدها به حالت int
    return storedMap.map(
      (key, value) => MapEntry(int.parse(key), value.toString()),
    );
  }
}
