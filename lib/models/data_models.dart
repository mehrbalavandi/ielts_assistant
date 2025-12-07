import 'dart:io';
import 'package:path/path.dart';

class Subject {
  final String name;
  final List<Lesson> lessons;
  Subject({required this.name, required this.lessons});
}

// مدل برای دروس درون هر کتاب
class Lesson {
  final String name;
  final List<Topic> topics;
  Lesson({required this.name, required this.topics});
}

class Topic {
  final String name;
  final List<String> audioFilePaths; // تغییر: لیست مسیرهای صوتی
  final String jsonFilePath;
  final String txtFilePath;
  final String realmId;

  Topic({
    required this.name,
    required this.audioFilePaths,
    required this.jsonFilePath,
    required this.txtFilePath,
    required this.realmId,
  });

  factory Topic.fromDirectory(Directory topicDir) {
    final files = topicDir.listSync(recursive: false);

    // استخراج تمامی فایل‌های صوتی موجود در پوشه مبحث
    final List<String> audioPaths = files
        .where(
          (f) =>
              f.path.endsWith('.mp3') ||
              f.path.endsWith('.m4a') ||
              f.path.endsWith('.wav'),
        )
        .map((f) => f.path)
        .toList();

    final jsonFile = files.firstWhere(
      (f) => f.path.endsWith('.json'),
      orElse: () => File(''),
    );
    final txtFile = files.firstWhere(
      (f) => f.path.endsWith('.txt'),
      orElse: () => File(''),
    );

    final realmId = topicDir.path;

    return Topic(
      name: basename(topicDir.path),
      audioFilePaths: audioPaths, // ذخیره لیست مسیرها
      jsonFilePath: jsonFile.path,
      txtFilePath: txtFile.path,
      realmId: realmId,
    );
  }
}
