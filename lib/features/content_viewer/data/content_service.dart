import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:path/path.dart';

class ContentService {
  static Future<List<Book>> scanRootFolder(String rootPath) async {
    return await compute(_heavyScannerGetBooks, rootPath);
  }

  static List<Book> _heavyScannerGetBooks(String rootPath) {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
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
                                  return CfPublic().parseFinalTopic(
                                    finalTopicDir,
                                  );
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

  Future<String?> readFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print("Error reading file at $path: $e");
    }
    return null;
  }
}
