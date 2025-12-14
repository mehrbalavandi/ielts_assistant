import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:path/path.dart';

class FileTraversalService {
  // تابع اصلی برای شروع پیمایش از پوشه ریشه (سطح ۱)
  // Future<List<Subject>> traverseRootDirectory(String rootPath) async {
  //   final rootDir = Directory(rootPath);
  //   if (!await rootDir.exists()) {
  //     debugPrint('Root directory not found: $rootPath');
  //     return [];
  //   }
  //   // ۱. Subject (ریاضی ۱، ریاضی ۲، ...)
  //   final subjects = rootDir
  //       .listSync()
  //       .whereType<Directory>()
  //       .map((subjectDir) {
  //         // پیمایش داخل Subject: Lessonها
  //         final lessons = subjectDir
  //             .listSync()
  //             .whereType<Directory>()
  //             .map((lessonDir) {
  //               // ۲. Lesson (درس ۱، درس ۲، ...)
  //               // پیمایش داخل Lesson: ParentTopicها
  //               final parentTopics = lessonDir
  //                   .listSync()
  //                   .whereType<Directory>()
  //                   .map((parentTopicDir) {
  //                     // ۳. ParentTopic (مبحث اصلی ۱، مبحث اصلی ۲، ...)
  //                     // ✅ سطح جدید: پیمایش زیرمبحث‌ها (Sub Topics)
  //                     final subTopics = parentTopicDir
  //                         .listSync()
  //                         .whereType<Directory>()
  //                         .map((subTopicDir) {
  //                           // ۴. SubTopic (پوشه نهایی حاوی فایل‌ها)
  //                           // ساخت شیء SubTopic و استخراج فایل‌ها و مسیر JSON
  //                           return SubTopic.fromDirectory(subTopicDir);
  //                         })
  //                         // .where((st) => st.audioFilePaths.isNotEmpty)
  //                         // .toList(); // فقط زیرمبحث‌های دارای فایل صوتی را در نظر بگیرید.
  //                         .toList(); // همه زیرمبحث‌ها را در نظر بگیرید.
  //                     // ساخت ParentTopic، فقط اگر حداقل یک SubTopic معتبر داشته باشد
  //                     return ParentTopic(
  //                       realmId: parentTopicDir.path,
  //                       name: basename(parentTopicDir.path),
  //                       subTopics: subTopics,
  //                     );
  //                   })
  //                   .where((pt) => pt.subTopics.isNotEmpty)
  //                   .toList(); // فقط مباحث اصلی دارای زیرمبحث را در نظر بگیرید.
  //               // ساخت Lesson، فقط اگر حداقل یک ParentTopic معتبر داشته باشد
  //               return Lesson(
  //                 name: basename(lessonDir.path),
  //                 topics: parentTopics,
  //               );
  //             })
  //             .where((l) => l.topics.isNotEmpty)
  //             .toList(); // فقط درس‌های دارای ParentTopic را در نظر بگیرید.
  //         // ساخت Subject، فقط اگر حداقل یک Lesson معتبر داشته باشد
  //         return Subject(name: basename(subjectDir.path), lessons: lessons);
  //       })
  //       .where((s) => s.lessons.isNotEmpty)
  //       .toList(); // فقط Subjectهای دارای Lesson را در نظر بگیرید.
  //   return subjects;
  // }

  Future<List<Subject>> traverseRootDirectory(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      debugPrint('Root directory not found: $rootPath');
      return [];
    }

    // ۱. Subject (ریاضی ۱، ریاضی ۲، ...)
    // لیست کردن، تبدیل به لیست، مرتب‌سازی
    final subjectEntities = rootDir.listSync()
      ..sort((a, b) => a.path.compareTo(b.path)); // مرتب‌سازی درجا

    final subjects = subjectEntities
        .whereType<Directory>()
        .map((subjectDir) {
          // ۲. Lesson (درس ۱، درس ۲، ...)
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

                      // ✅ سطح جدید: پیمایش زیرمبحث‌ها (Sub Topics)
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
                  topics: parentTopics,
                );
              })
              .where((l) => l.topics.isNotEmpty)
              .toList(); // فقط درس‌های دارای ParentTopic را در نظر بگیرید.

          // ساخت Subject، فقط اگر حداقل یک Lesson معتبر داشته باشد
          return Subject(name: basename(subjectDir.path), lessons: lessons);
        })
        .where((s) => s.lessons.isNotEmpty)
        .toList(); // فقط Subjectهای دارای Lesson را در نظر بگیرید.

    return subjects;
  }
}
