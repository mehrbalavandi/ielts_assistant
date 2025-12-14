import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:path/path.dart';

class FileTraversalService {
  Future<List<Subject>> traverseRootDirectory(String rootPath) async {
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
}
