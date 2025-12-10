import 'dart:io';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:path/path.dart';

class FileTraversalService {
  // تابع اصلی برای شروع پیمایش از پوشه ریشه (سطح ۱)
  Future<List<Subject>> traverseRootDirectory(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      print('Root directory not found: $rootPath');
      return [];
    }

    // ۱. Subject (ریاضی ۱، ریاضی ۲، ...)
    final subjects = rootDir
        .listSync()
        .whereType<Directory>()
        .map((subjectDir) {
          // پیمایش داخل Subject: Lessonها
          final lessons = subjectDir
              .listSync()
              .whereType<Directory>()
              .map((lessonDir) {
                // ۲. Lesson (درس ۱، درس ۲، ...)

                // پیمایش داخل Lesson: ParentTopicها
                final parentTopics = lessonDir
                    .listSync()
                    .whereType<Directory>()
                    .map((parentTopicDir) {
                      // ۳. ParentTopic (مبحث اصلی ۱، مبحث اصلی ۲، ...)

                      // ✅ سطح جدید: پیمایش زیرمبحث‌ها (Sub Topics)
                      final subTopics = parentTopicDir
                          .listSync()
                          .whereType<Directory>()
                          .map((subTopicDir) {
                            // ۴. SubTopic (پوشه نهایی حاوی فایل‌ها)
                            // ساخت شیء SubTopic و استخراج فایل‌ها و مسیر JSON
                            return SubTopic.fromDirectory(subTopicDir);
                          })
                          .where((st) => st.audioFilePaths.isNotEmpty)
                          .toList(); // فقط زیرمبحث‌های دارای فایل صوتی را در نظر بگیرید.

                      // ساخت ParentTopic، فقط اگر حداقل یک SubTopic معتبر داشته باشد
                      return ParentTopic(
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
