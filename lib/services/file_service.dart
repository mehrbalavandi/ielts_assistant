import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/models/data_models.dart';
import 'package:path/path.dart';

class FileTraversalService {
  Future<List<Book>> traverseRootDirectory(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      debugPrint('Root directory not found: $rootPath');
      return [];
    }

    // ۱. book (Mindset 1، Mindset ۲، ...)
    // لیست کردن، تبدیل به لیست، مرتب‌سازی
    final bookEntities = rootDir.listSync()
      ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

    final books = bookEntities
        .whereType<Directory>()
        .map((bookDir) {
          // ۲. unit (Unit 01، Unit 02، ...)
          // لیست کردن، تبدیل به لیست، مرتب‌سازی
          final unitEntities = bookDir.listSync()
            ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

          // پیمایش داخل book: unitها
          final units = unitEntities
              .whereType<Directory>()
              .map((unitDir) {
                // ۳. mainTopic (مبحث اصلی ۱، مبحث اصلی ۲، ...)
                // لیست کردن، تبدیل به لیست، مرتب‌سازی
                final mainTopicEntities = unitDir.listSync()
                  ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

                // پیمایش داخل unit: mainTopicها
                final mainTopics = mainTopicEntities
                    .whereType<Directory>()
                    .map((mainTopicDir) {
                      // ۴. mainTopic (پوشه نهایی حاوی فایل‌ها)
                      // لیست کردن، تبدیل به لیست، مرتب‌سازی
                      final subTopicEntities = mainTopicDir.listSync()
                        ..sort(
                          (a, b) => a.path.compareTo(b.path),
                        ); // مرتب‌سازی درجا

                      // ✅ سطح: پیمایش زیرمبحث‌ها (Sub Topics)
                      final subTopics = subTopicEntities
                          .whereType<Directory>()
                          .map((subTopicDir) {
                            final finalTopicEntities = subTopicDir.listSync()
                              ..sort(
                                (a, b) => a.path.compareTo(b.path),
                              ); // مرتب‌سازی درجا
                            final finalTopics = finalTopicEntities
                                .whereType<Directory>()
                                .map((finalTopicDir) {
                                  // ۴. mainTopic (پوشه نهایی حاوی فایل‌ها)
                                  // ساخت شیء mainTopic و استخراج فایل‌ها و مسیر JSON
                                  return FinalTopic.fromDirectory(
                                    finalTopicDir,
                                  );
                                })
                                .toList(); // همه زیرمبحث‌ها را در نظر بگیرید.
                            return PageContent(
                              realmId: subTopicDir.path,
                              name: basename(subTopicDir.path),
                              finalTopics: finalTopics,
                            ); // همه زیرمبحث‌ها را در نظر بگیرید.
                          })
                          .where((x) => x.finalTopics.isNotEmpty)
                          .toList();
                      // ساخت mainTopic، فقط اگر حداقل یک mainTopic معتبر داشته باشد
                      return Topic(
                        realmId: mainTopicDir.path,
                        name: basename(mainTopicDir.path),
                        pageContents: subTopics,
                      );
                    })
                    .where((pt) => pt.pageContents.isNotEmpty)
                    .toList(); // فقط مباحث اصلی دارای زیرمبحث را در نظر بگیرید.

                // ساخت unit، فقط اگر حداقل یک mainTopic معتبر داشته باشد
                return Unit(name: basename(unitDir.path), topics: mainTopics);
              })
              .where((l) => l.topics.isNotEmpty)
              .toList(); // فقط درس‌های دارای mainTopic را در نظر بگیرید.

          // ساخت book، فقط اگر حداقل یک unit معتبر داشته باشد
          return Book(name: basename(bookDir.path), units: units);
        })
        .where((s) => s.units.isNotEmpty)
        .toList(); // فقط bookهای دارای unit را در نظر بگیرید.

    return books;
  }

  /*
Future<List<Subject>> traverseRootDirectory2(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      debugPrint('Root directory not found: $rootPath');
      return [];
    }

    // ۱. Subject (Mindset 1، Mindset ۲، ...)
    // لیست کردن، تبدیل به لیست، مرتب‌سازی
    final subjectEntities = rootDir.listSync()
      ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

    final subjects = subjectEntities
        .whereType<Directory>()
        .map((subjectDir) {
          // ۲. Lesson (Unit 01، Unit 02، ...)
          // لیست کردن، تبدیل به لیست، مرتب‌سازی
          final lessonEntities = subjectDir.listSync()
            ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

          // پیمایش داخل Subject: Lessonها
          final lessons = lessonEntities
              .whereType<Directory>()
              .map((lessonDir) {
                // ۳. ParentTopic (مبحث اصلی ۱، مبحث اصلی ۲، ...)
                // لیست کردن، تبدیل به لیست، مرتب‌سازی
                final parentTopicEntities = lessonDir.listSync()
                  ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

                // پیمایش داخل Lesson: ParentTopicها
                final parentTopics = parentTopicEntities
                    .whereType<Directory>()
                    .map((parentTopicDir) {
                      // ۴. SubTopic (پوشه نهایی حاوی فایل‌ها)
                      // لیست کردن، تبدیل به لیست، مرتب‌سازی
                      final subTopicEntities = parentTopicDir.listSync()
                        ..sort(
                          (a, b) => a.path.compareTo(b.path),
                        ); // مرتب‌سازی درجا

                      // ✅ سطح: پیمایش زیرمبحث‌ها (Sub Topics)
                      final subTopics = subTopicEntities
                          .whereType<Directory>()
                          .map((subTopicDir) {
                            // ۴. SubTopic (پوشه نهایی حاوی فایل‌ها)
                            // ساخت شیء SubTopic و استخراج فایل‌ها و مسیر JSON
                            return SubTopic.fromDirectory(subTopicDir);
                          })
                          .toList(); // همه زیرمبحث‌ها را در نظر بگیرید.

                      // ساخت ParentTopic، فقط اگر حداقل یک SubTopic معتبر داشته باشد
                      return ParentTopic(
                        realmId: parentTopicDir.path,
                        name: basename(parentTopicDir.path),
                        subTopics: subTopics,
                      );
                    })
                    .where((pt) => pt.subTopics.isNotEmpty)
                    .toList(); // فقط مباحث اصلی دارای زیرمبحث را در نظر بگیرید.

                // ساخت Lesson، فقط اگر حداقل یک ParentTopic معتبر داشته باشد
                return Lesson(
                  name: basename(lessonDir.path),
                  parentTopics: parentTopics,
                );
              })
              .where((l) => l.parentTopics.isNotEmpty)
              .toList(); // فقط درس‌های دارای ParentTopic را در نظر بگیرید.

          // ساخت Subject، فقط اگر حداقل یک Lesson معتبر داشته باشد
          return Subject(name: basename(subjectDir.path), lessons: lessons);
        })
        .where((s) => s.lessons.isNotEmpty)
        .toList(); // فقط Subjectهای دارای Lesson را در نظر بگیرید.

    return subjects;
  }
 و کلاسهای class Subject {
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
*/
}
