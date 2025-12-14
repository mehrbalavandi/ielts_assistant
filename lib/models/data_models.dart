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
  final List<ParentTopic> parentTopics;
  Lesson({required this.name, required this.parentTopics});
}

// کلاس مبحث اصلی (Parent Topic) که اکنون شامل لیستی از زیرمبحث‌ها است
class ParentTopic {
  final String name;
  final String realmId;
  final List<SubTopic> subTopics; // ✅ لیست زیرمبحث‌ها

  ParentTopic({
    required this.name,
    required this.realmId,
    required this.subTopics,
  });
}

// کلاس نهایی که فایل‌های صوتی و JSON را در خود دارد (سطح نهایی پیمایش)
class SubTopic {
  final String name;
  final String realmId; // شناسه منحصر به فرد (مسیر کامل پوشه)
  final List<String> audioFilePaths;
  final String jsonFilePath; // مسیر فایل متنی درس
  final String translationFilePath; // مسیر فایل متنی ترجمه درس

  SubTopic({
    required this.name,
    required this.realmId,
    required this.audioFilePaths,
    required this.jsonFilePath,
    required this.translationFilePath,
  });

  // تابع کمکی برای پیدا کردن فایل JSON و جلوگیری از خطای StateError
  // اگر فایل پیدا نشود، null برمی‌گرداند.
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

  // متد سازنده کارخانه‌ای برای ساخت شیء SubTopic از روی پوشه نهایی
  factory SubTopic.fromDirectory(Directory subTopicDir) {
    final files = subTopicDir.listSync();

    // ۱. استخراج مسیر فایل‌های صوتی (.mp3)
    final audioFiles = files
        .where((f) => f.path.endsWith('.mp3'))
        .map((f) => f.path)
        .toList();

    // ۲. استخراج فایل JSON
    final jsonFileEntityEnglish = _findJsonFileEnglish(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathEnglish = jsonFileEntityEnglish?.path ?? '';
    // ۲. استخراج فایل JSON
    final jsonFileEntityTranslation = _findJsonFileTranslation(files);

    // ۳. مدیریت خطای Null: دسترسی شرطی به 'path'
    // اگر jsonFileEntity برابر null باشد، jsonFilePath یک رشته خالی خواهد بود.
    final jsonFilePathTranslation = jsonFileEntityTranslation?.path ?? '';

    return SubTopic(
      name: basename(subTopicDir.path),
      realmId: subTopicDir.path, // مسیر کامل پوشه به عنوان ID
      audioFilePaths: audioFiles.cast<String>(),
      jsonFilePath: jsonFilePathEnglish,
      translationFilePath: jsonFilePathTranslation,
    );
  }
}
// class Topic {
//   final String name;
//   final List<String> audioFilePaths; // تغییر: لیست مسیرهای صوتی
//   final String jsonFilePath;
//   final String txtFilePath;
//   final String realmId;

//   Topic({
//     required this.name,
//     required this.audioFilePaths,
//     required this.jsonFilePath,
//     required this.txtFilePath,
//     required this.realmId,
//   });

//   factory Topic.fromDirectory(Directory topicDir) {
//     debugPrint('--- Checking Topic: ${topicDir.path}');
//     final files = topicDir.listSync(recursive: false);
//     debugPrint('Found items: ${files.length}');

//     // ۲. ببینید مسیر فایل MP3 شما چه شکلی است (اگر پیدایش نکرده):
//     for (var f in files) {
//       if (f.path.endsWith('.mp3') || f.path.endsWith('.MP3')) {
//         debugPrint('--- YES! MP3 found: ${f.path}');
//       } else {
//         debugPrint('--- Item: ${f.path} (NOT AUDIO)');
//       }
//     }
//     // استخراج تمامی فایل‌های صوتی موجود در پوشه مبحث
//     final List<String> audioPaths = files
//         .where(
//           (f) =>
//               f.path.endsWith('.mp3') ||
//               f.path.endsWith('.m4a') ||
//               f.path.endsWith('.wav'),
//         )
//         .map((f) => f.path)
//         .toList();

//     final jsonFile = files.firstWhere(
//       (f) => f.path.endsWith('.json'),
//       orElse: () => File(''),
//     );
//     final txtFile = files.firstWhere(
//       (f) => f.path.endsWith('.txt'),
//       orElse: () => File(''),
//     );

//     final realmId = topicDir.path;
//     debugPrint('Final audioPaths count: ${audioPaths.length}');
//     return Topic(
//       name: basename(topicDir.path),
//       audioFilePaths: audioPaths, // ذخیره لیست مسیرها
//       jsonFilePath: jsonFile.path,
//       txtFilePath: txtFile.path,
//       realmId: realmId,
//     );
//   }
// }
