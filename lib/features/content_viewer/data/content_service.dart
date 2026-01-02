import 'dart:io';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:path/path.dart' as p;

class ContentService {
  static Future<List<Book>> scanRootFolder(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return [];

    List<Book> books = [];
    final bookDirs = rootDir.listSync().whereType<Directory>();

    for (var bDir in bookDirs) {
      List<Unit> units = [];
      for (var uDir in bDir.listSync().whereType<Directory>()) {
        List<Topic> topics = [];
        for (var tDir in uDir.listSync().whereType<Directory>()) {
          List<PageContent> pages = [];
          for (var pDir in tDir.listSync().whereType<Directory>()) {
            List<FinalTopic> finals = [];
            for (var fDir in pDir.listSync().whereType<Directory>()) {
              finals.add(await _parseFinalTopic(fDir));
            }
            pages.add(
              PageContent(name: p.basename(pDir.path), finalTopics: finals),
            );
          }
          topics.add(Topic(name: p.basename(tDir.path), pages: pages));
        }
        units.add(Unit(name: p.basename(uDir.path), topics: topics));
      }
      books.add(Book(name: p.basename(bDir.path), units: units));
    }
    return books;
  }

  static Future<FinalTopic> _parseFinalTopic(Directory dir) async {
    final files = dir.listSync().whereType<File>();
    String eng = "", trans = "", audio = "";
    for (var file in files) {
      if (file.path.endsWith('.english.json')) eng = await file.readAsString();
      if (file.path.endsWith('.translation.json'))
        trans = await file.readAsString();
      if (p.basename(file.path) == 'soundName.txt')
        audio = (await file.readAsString()).trim();
    }
    return FinalTopic(
      name: p.basename(dir.path),
      englishText: eng,
      translationText: trans,
      audioFileName: audio.isNotEmpty ? audio : null,
      realmId: '',
      jsonFilePath: '',
      translationFilePath: '',
      audioFilePaths: [],
    );
  }
}
