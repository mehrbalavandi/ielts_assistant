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
          final unitOrOtherEntities = bookDir.listSync()
            ..sort((a, b) => a.path.compareTo(b.path));
          final units = unitOrOtherEntities
              .whereType<Directory>()
              .where((x) => !basename(x.path).startsWith('Day'))
              .map((unitDir) {
                final topicOrOtherEntities = unitDir.listSync()
                  ..sort((a, b) => a.path.compareTo(b.path));
                final mainTopics = topicOrOtherEntities
                    .whereType<Directory>()
                    .where(
                      (x) =>
                          !basename(x.path).startsWith('Day') &&
                          !basename(x.path).startsWith('01. ') &&
                          !basename(x.path).startsWith('02. ') &&
                          !basename(x.path).startsWith('03. ') &&
                          !basename(x.path).startsWith('04. ') &&
                          !basename(x.path).startsWith('05. ') &&
                          !basename(x.path).startsWith('06. '),
                    )
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
                                  return CfPublic().parseFinalTopic(
                                    finalTopicDir,
                                  );
                                })
                                .where(
                                  (x) =>
                                      x.contentEnglish.isNotEmpty ||
                                      x.contentPersian.isNotEmpty,
                                )
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
                final otherContents = topicOrOtherEntities
                    .whereType<Directory>()
                    .where(
                      (x) =>
                          basename(x.path).startsWith('Day') ||
                          basename(x.path).startsWith('01. ') ||
                          basename(x.path).startsWith('02. ') ||
                          basename(x.path).startsWith('03. ') ||
                          basename(x.path).startsWith('04. ') ||
                          basename(x.path).startsWith('05. ') ||
                          basename(x.path).startsWith('06. '),
                    )
                    .map((otherDir) {
                      final finalTopicEntities = otherDir.listSync()
                        ..sort((a, b) => a.path.compareTo(b.path));
                      final finalTopics = finalTopicEntities
                          .whereType<Directory>()
                          .map((finalTopicDir) {
                            return CfPublic().parseFinalTopic(finalTopicDir);
                          })
                          .where(
                            (x) =>
                                x.contentEnglish.isNotEmpty ||
                                x.contentPersian.isNotEmpty,
                          )
                          .toList();
                      return OtherContent(
                        realmId: otherDir.path,
                        name: basename(otherDir.path),
                        finalTopics: finalTopics,
                      );
                    })
                    .toList();
                return Unit(
                  name: basename(unitDir.path),
                  topics: mainTopics,
                  otherContents: otherContents,
                );
              })
              .where(
                (l) =>
                    l.topics.isNotEmpty ||
                    (l.otherContents != null && l.otherContents!.isNotEmpty),
              )
              .toList();
          final otherContents = unitOrOtherEntities
              .whereType<Directory>()
              .where((x) => basename(x.path).startsWith('Day'))
              .map((otherDir) {
                final finalTopicEntities = otherDir.listSync()
                  ..sort((a, b) => a.path.compareTo(b.path));
                final finalTopics = finalTopicEntities
                    .whereType<Directory>()
                    .map((finalTopicDir) {
                      return CfPublic().parseFinalTopic(finalTopicDir);
                    })
                    .where(
                      (x) =>
                          x.contentEnglish.isNotEmpty ||
                          x.contentPersian.isNotEmpty,
                    )
                    .toList();
                return OtherContent(
                  realmId: otherDir.path,
                  name: basename(otherDir.path),
                  finalTopics: finalTopics,
                );
              })
              .toList();

          return Book(
            name: basename(bookDir.path),
            units: units,
            otherContents: otherContents,
          );
        })
        .where(
          (s) =>
              s.units.isNotEmpty ||
              (s.otherContents != null && s.otherContents!.isNotEmpty),
        )
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
