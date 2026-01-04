import 'package:ielts_assistant/shared/providers/storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:file_selector/file_selector.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  static const _pathKey = 'audio_root_path';

  @override
  String? build() {
    final box = ref.read(storageProvider);
    return box.read(_pathKey);
  }

  Future<void> pickAndSaveDirectory() async {
    final String? directoryPath = await getDirectoryPath();

    if (directoryPath != null) {
      await ref.read(storageProvider).write(_pathKey, directoryPath);
      state = directoryPath;
    }
  }
}
