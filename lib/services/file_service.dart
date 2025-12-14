import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ielts_assistant/models/data_models.dart';
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
                      final mainTopicEntities = mainTopicDir.listSync()
                        ..sort(
                          (a, b) => a.path.compareTo(b.path),
                        ); // مرتب‌سازی درجا

                      // ✅ سطح: پیمایش زیرمبحث‌ها (Sub Topics)
                      final mainTopics = mainTopicEntities
                          .whereType<Directory>()
                          .map((mainTopicDir) {
                            // ۴. mainTopic (پوشه نهایی حاوی فایل‌ها)
                            // ساخت شیء mainTopic و استخراج فایل‌ها و مسیر JSON
                            return FinalTopic.fromDirectory(mainTopicDir);
                          })
                          .toList(); // همه زیرمبحث‌ها را در نظر بگیرید.

                      // ساخت mainTopic، فقط اگر حداقل یک mainTopic معتبر داشته باشد
                      return MainTopic(
                        realmId: mainTopicDir.path,
                        name: basename(mainTopicDir.path),
                        subTopics: mainTopics,
                      );
                    })
                    .where((pt) => pt.subTopics.isNotEmpty)
                    .toList(); // فقط مباحث اصلی دارای زیرمبحث را در نظر بگیرید.

                // ساخت unit، فقط اگر حداقل یک mainTopic معتبر داشته باشد
                return Unit(
                  name: basename(unitDir.path),
                  mainTopics: mainTopics,
                );
              })
              .where((l) => l.mainTopics.isNotEmpty)
              .toList(); // فقط درس‌های دارای mainTopic را در نظر بگیرید.

          // ساخت book، فقط اگر حداقل یک unit معتبر داشته باشد
          return Book(name: basename(bookDir.path), units: units);
        })
        .where((s) => s.units.isNotEmpty)
        .toList(); // فقط bookهای دارای unit را در نظر بگیرید.

    return books;
  }
}
