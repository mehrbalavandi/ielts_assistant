import 'package:get_storage/get_storage.dart';

// کلیدهای ذخیره‌سازی
class StorageKeys {
  static const String loopMode = 'settings_loopMode';
  static const String showTranslation = 'settings_showTranslation';
  static const String lastRootDirectoryPath = 'last_root_directory_path';
  static const String lastPlayedTopicId = 'audio_lastPlayedTopicId';
  static const String lastPlayedPositionMs = 'audio_lastPlayedPositionMs';

  static const String lastbook = 'last_book';
  static const String lastunit = 'last_unit';
}

class StorageService {
  final _box = GetStorage();

  void saveLastDirectoryPath(String path) {
    _box.write(StorageKeys.lastRootDirectoryPath, path);
  }

  String? getLastDirectoryPath() {
    return _box.read(StorageKeys.lastRootDirectoryPath);
  }

  void saveLoopMode(String mode) {
    _box.write(StorageKeys.loopMode, mode);
  }

  String? getLoopMode() {
    return _box.read(StorageKeys.loopMode);
  }

  void saveShowTranslation(bool value) {
    _box.write(StorageKeys.showTranslation, value);
  }

  bool getShowTranslation() {
    return _box.read(StorageKeys.showTranslation) ?? false;
  }

  void saveLastPlayedTopicId(String realmId) {
    _box.write(StorageKeys.lastPlayedTopicId, realmId);
  }

  String? getLastPlayedTopicId() {
    return _box.read(StorageKeys.lastPlayedTopicId);
  }

  void saveLastPlayedPosition(int milliseconds) {
    _box.write(StorageKeys.lastPlayedPositionMs, milliseconds);
  }

  int? getLastPlayedPositionMs() {
    return _box.read(StorageKeys.lastPlayedPositionMs);
  }

  Future<void> saveLastbook(String book) async {
    await _box.write(StorageKeys.lastbook, book);
  }

  String? getLastbook() {
    return _box.read(StorageKeys.lastbook);
  }

  Future<void> saveLastunit(String unit) async {
    await _box.write(StorageKeys.lastunit, unit);
  }

  String? getLastUnit() {
    return _box.read(StorageKeys.lastunit);
  }
}
