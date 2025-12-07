import 'dart:convert';
import 'dart:io';

// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

Future<bool> setImagesPathNewMethod(SettingsController settingsCtrl) async {
  try {
    var res = await Permission.manageExternalStorage.status;
    if (!res.isGranted) {
      Permission.manageExternalStorage.request().then((onValue) async {
        var res2 = await Permission.manageExternalStorage.status;
        if (res2.isGranted) {
          try {
            String? previousPath;
            if (await Directory(imagesPath).exists()) {
              previousPath = imagesPath;
            }
            String? selectedDirectory = (previousPath != null)
                ? await getDirectoryPath(initialDirectory: previousPath)
                : await getDirectoryPath();

            if (selectedDirectory != null) {
              await box.write(
                StorageVariables.imagesPath.name,
                selectedDirectory,
              );
              if (selectedDirectory != imagesPath) {
                stuffTypesListProvider.notifyToListeners(flag: true);
                imagesPath = selectedDirectory;
                settingsCtrl.updateImagesPath(selectedDirectory);
                return true;
              }
            }
          } catch (exception) {
            // TODO
          }
        }
      });
    } else if (res.isGranted) {
      try {
        String? previousPath;
        if (await Directory(imagesPath).exists()) {
          previousPath = imagesPath;
        }
        String? selectedDirectory = (previousPath != null)
            ? await getDirectoryPath(initialDirectory: previousPath)
            : await getDirectoryPath();

        if (selectedDirectory != null) {
          await box.write(StorageVariables.imagesPath.name, selectedDirectory);
          if (selectedDirectory != imagesPath) {
            stuffTypesListProvider.notifyToListeners(flag: true);
            imagesPath = selectedDirectory;
            settingsCtrl.updateImagesPath(selectedDirectory);
            return true;
          }
        }
      } catch (exception) {}
    }
  } catch (exception) {}
  return false;
}
