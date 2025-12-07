import 'dart:io';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:path/path.dart';

class FileTraversalService {
  // تابع کمکی برای خواندن پوشه نهایی مبحث
  Topic? _traverseTopicDirectory(Directory topicDir) {
    try {
      return Topic.fromDirectory(topicDir);
    } catch (e) {
      print('Error processing topic directory ${topicDir.path}: $e');
      return null;
    }
  }

  // تابع کمکی برای خواندن پوشه درس (سطح ۲)
  Lesson? _traverseLessonDirectory(Directory lessonDir) {
    // فقط زیرپوشه‌ها را فیلتر می‌کنیم (مباحث)
    final topicDirs = lessonDir.listSync().whereType<Directory>().toList();
    final topics = <Topic>[];

    for (final topicDir in topicDirs) {
      final topic = _traverseTopicDirectory(topicDir);
      if (topic != null) {
        topics.add(topic);
      }
    }

    if (topics.isNotEmpty) {
      return Lesson(name: basename(lessonDir.path), topics: topics);
    }
    return null;
  }

  // تابع اصلی برای شروع پیمایش از پوشه ریشه (سطح ۱)
  Future<List<Subject>> traverseRootDirectory(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      return [];
    }

    // فهرست کردن پوشه‌های سطح اول (ریاضی ۱، ریاضی ۲، ...)
    final subjectDirs = rootDir.listSync().whereType<Directory>().toList();
    final subjects = <Subject>[];

    for (final subjectDir in subjectDirs) {
      // پیمایش زیرپوشه‌های درس
      final lessonDirs = subjectDir.listSync().whereType<Directory>().toList();
      final lessons = <Lesson>[];

      for (final lessonDir in lessonDirs) {
        final lesson = _traverseLessonDirectory(lessonDir);
        if (lesson != null) {
          lessons.add(lesson);
        }
      }

      if (lessons.isNotEmpty) {
        subjects.add(
          Subject(name: basename(subjectDir.path), lessons: lessons),
        );
      }
    }

    return subjects;
  }
}
