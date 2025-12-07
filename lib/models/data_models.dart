import 'dart:io';
import 'package:path/path.dart';

// مدل اصلی برای هر کتاب (ریاضی ۱، ریاضی ۲، ...)
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

// مدل نهایی برای هر مبحث (که حاوی فایل‌هاست)
class Topic {
  final String name;
  final String audioFilePath;
  final String jsonFilePath;
  final String txtFilePath;
  // یک شناسه منحصر به فرد (بر اساس مسیر فایل) برای ذخیره موقعیت در Realm
  final String realmId;

  Topic({
    required this.name,
    required this.audioFilePath,
    required this.jsonFilePath,
    required this.txtFilePath,
    required this.realmId,
  });

  // سازنده کارخانه (Factory) برای استخراج داده از پوشه مبحث
  factory Topic.fromDirectory(Directory topicDir) {
    // لیست کردن محتوای پوشه نهایی مبحث
    final files = topicDir.listSync(recursive: false);

    // جستجوی فایل‌ها بر اساس پسوند
    final audioFile = files.firstWhere(
      (f) => f.path.endsWith('.mp3') || f.path.endsWith('.m4a'),
      orElse: () => File(''),
    );
    final jsonFile = files.firstWhere(
      (f) => f.path.endsWith('.json'),
      orElse: () => File(''),
    );
    final txtFile = files.firstWhere(
      (f) => f.path.endsWith('.txt'),
      orElse: () => File(''),
    );

    // استفاده از مسیر کامل به عنوان RealmId
    final realmId = topicDir.path;

    return Topic(
      name: basename(
        topicDir.path,
      ), // نام پوشه را به عنوان نام مبحث در نظر می‌گیریم
      audioFilePath: audioFile.path,
      jsonFilePath: jsonFile.path,
      txtFilePath: txtFile.path,
      realmId: realmId,
    );
  }
}
