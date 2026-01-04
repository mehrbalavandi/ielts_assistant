import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:ielts_assistant/shared/providers/storage_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  static const _pathKey = 'audio_root_path';

  @override
  String? build() {
    final box = ref.read(storageProvider);
    return box.read(_pathKey);
  }

  Future<void> updatePath(String newPath) async {
    final box = ref.read(storageProvider);
    await box.write(_pathKey, newPath);
    state = newPath; // به‌روزرسانی وضعیت که باعث ری‌بیلد شدن بقیه جاها می‌شود
  }

  Future<String?> pickAndSaveDirectory(String? previousPath) async {
    String? result = previousPath;
    try {
      var res = await Permission.manageExternalStorage.status;
      if (!res.isGranted) {
        Permission.manageExternalStorage.request().then((onValue) async {
          var res2 = await Permission.manageExternalStorage.status;
          if (res2.isGranted) {
            try {
              bool existPreviousPath = false;
              if (previousPath != null &&
                  await Directory(previousPath).exists()) {
                existPreviousPath = true;
              }
              final String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath(
                    initialDirectory: existPreviousPath ? previousPath : null,
                  );

              if (selectedDirectory != null) {
                result = selectedDirectory;
              }
            } catch (exception) {
              String st = exception.toString();
              debugPrint(st);
            }
          }
        });
      } else if (res.isGranted) {
        try {
          bool existPreviousPath = false;
          if (previousPath != null && await Directory(previousPath).exists()) {
            existPreviousPath = true;
          }
          final String? selectedDirectory = await FilePicker.platform
              .getDirectoryPath(
                initialDirectory: existPreviousPath ? previousPath : null,
              );

          result = selectedDirectory;
        } catch (exception) {
          String st = exception.toString();
          debugPrint(st);
        }
      }
    } catch (exception) {
      String st = exception.toString();
      debugPrint(st);
    }
    return result;
  }
}
