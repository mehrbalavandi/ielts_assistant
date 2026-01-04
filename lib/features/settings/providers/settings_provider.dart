import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/shared/providers/storage_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Future<void> pickAndSaveDirectory() async {
  //   // ۱. اجرای عملیات انتخاب پوشه (ممکن است زمان‌بر باشد)
  //   final String? directoryPath = await _pickDirectory();

  //   // ۲. چک کردن mounted بعد از await (شکاف ناهمگام)
  //   // این خط بررسی می‌کند که آیا هنوز پرووایدر زنده است یا خیر
  //   if (!ref.mounted) return;

  //   if (directoryPath != null) {
  //     // ۳. حالا با خیال راحت از ref استفاده کنید
  //     await ref.read(storageProvider).write(_pathKey, directoryPath);
  //     state = directoryPath;
  //   }
  // }

  Future<void> pickAndSaveDirectory() async {
    try {
      var res = await Permission.manageExternalStorage.status;
      if (!res.isGranted) {
        Permission.manageExternalStorage.request().then((onValue) async {
          var res2 = await Permission.manageExternalStorage.status;
          if (res2.isGranted) {
            try {
              bool existPreviousPath = false;
              String? previousPath = ref.read(storageProvider).read(_pathKey);
              if (previousPath != null &&
                  await Directory(previousPath).exists()) {
                existPreviousPath = true;
              }
              final String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath(
                    initialDirectory: existPreviousPath ? previousPath : null,
                  );

              if (selectedDirectory != null) {
                if (selectedDirectory != previousPath) {
                  await ref
                      .read(storageProvider)
                      .write(_pathKey, selectedDirectory);
                }

                await _loadDirectoryData(selectedDirectory);
              }
            } catch (exception) {
              // TODO
            }
          }
        });
      } else if (res.isGranted) {
        try {
          bool existPreviousPath = false;
          String? previousPath = ref.read(storageProvider).read(_pathKey);
          if (previousPath != null && await Directory(previousPath).exists()) {
            existPreviousPath = true;
          }
          final String? selectedDirectory = await FilePicker.platform
              .getDirectoryPath(
                initialDirectory: existPreviousPath ? previousPath : null,
              );

          if (selectedDirectory != null) {
            if (selectedDirectory != previousPath) {
              await ref
                  .read(storageProvider)
                  .write(_pathKey, selectedDirectory);
            }

            await _loadDirectoryData(selectedDirectory);
          }
        } catch (exception) {}
      }
    } catch (exception) {}
  }

  Future<void> _loadDirectoryData(String path) async {
    // ref.invalidate(allContentProvider);
  }
}
