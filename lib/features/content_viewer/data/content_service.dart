import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:path/path.dart';

class ContentService {
  static Future<List<Book>> scanRootFolder(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      debugPrint('Root directory not found: $rootPath');
      return [];
    }
    final bookEntities = rootDir.listSync()
      ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

    final books = bookEntities
        .whereType<Directory>()
        .map((bookDir) {
          final unitEntities = bookDir.listSync()
            ..sort((a, b) => a.path.compareTo(b.path));
          final units = unitEntities
              .whereType<Directory>()
              .map((unitDir) {
                final topicEntities = unitDir.listSync()
                  ..sort((a, b) => a.path.compareTo(b.path));
                final mainTopics = topicEntities
                    .whereType<Directory>()
                    .map((mainTopicDir) {
                      final pageContentEntities = mainTopicDir.listSync()
                        ..sort((a, b) => a.path.compareTo(b.path));
                      final pageContents = pageContentEntities
                          .whereType<Directory>()
                          .map((pageContentDir) {
                            final finalTopicEntities = pageContentDir.listSync()
                              ..sort((a, b) => a.path.compareTo(b.path));
                            final finalTopics = finalTopicEntities
                                .whereType<Directory>()
                                .map((finalTopicDir) {
                                  // return FinalTopic.fromDirectory(
                                  //   finalTopicDir,
                                  // );
                                  return _parseFinalTopic(finalTopicDir);
                                })
                                .toList();
                            return PageContent(
                              realmId: pageContentDir.path,
                              name: basename(pageContentDir.path),
                              finalTopics: finalTopics,
                            );
                          })
                          .where((x) => x.finalTopics.isNotEmpty)
                          .toList();
                      return Topic(
                        realmId: mainTopicDir.path,
                        name: basename(mainTopicDir.path),
                        pageContents: pageContents,
                      );
                    })
                    .where((pt) => pt.pageContents.isNotEmpty)
                    .toList();
                return Unit(name: basename(unitDir.path), topics: mainTopics);
              })
              .where((l) => l.topics.isNotEmpty)
              .toList();
          return Book(name: basename(bookDir.path), units: units);
        })
        .where((s) => s.units.isNotEmpty)
        .toList();

    return books;
  }

  static FinalTopic _parseFinalTopic(Directory dir) {
    final files = dir.listSync();
    final jsonFileEntityEnglish = _findJsonFileEnglish(files);
    final jsonFilePathEnglish = jsonFileEntityEnglish?.path ?? '';
    final jsonFileEntityTranslation = _findJsonFileTranslation(files);
    final jsonFilePathTranslation = jsonFileEntityTranslation?.path ?? '';
    return FinalTopic(
      name: basename(dir.path),
      realmId: dir.path, // مسیر کامل پوشه به عنوان ID
      // audioFilePaths: audioFiles.cast<String>(),
      jsonFilePath: jsonFilePathEnglish,
      translationFilePath: jsonFilePathTranslation,
    );
  }

  static FileSystemEntity? _findJsonFileEnglish(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('english.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  static FileSystemEntity? _findJsonFileTranslation(
    List<FileSystemEntity> fileList,
  ) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere((f) => f.path.endsWith('translation.json'));
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }
}
