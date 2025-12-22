// providers/folder_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'folder_provider.g.dart';

@riverpod
class SelectedFolder extends _$SelectedFolder {
  @override
  String? build() {
    // مقداردهی اولیه از حافظه
    return StorageService.getLastSelectedFolder();
  }

  Future<void> selectFolder(String? path) async {
    if (path == null) {
      state = null;
      await StorageService.saveLastSelectedFolder('');
    } else {
      state = path;
      await StorageService.saveLastSelectedFolder(path);
    }
  }
}
