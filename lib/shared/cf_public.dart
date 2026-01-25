import 'dart:io';

// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class CfPublic {
  // 1: ساخت یک نمونه استاتیک خصوصی از خود کلاس
  static final CfPublic _instance = CfPublic._internal();

  // 2: کانستراکتور خصوصی (برای جلوگیری از new کردن)
  CfPublic._internal();

  // 3: دسترسی عمومی به نمونه Singleton
  factory CfPublic() {
    return _instance;
  }
  //--------------------------------------------
  Future<List<OriginalContent>> getOriginalContentsAsync(
    List<Book>? books,
    NavigationState nav,
  ) async {
    List<OriginalContent> result = <OriginalContent>[];
    // final books = ref.read(allContentProvider).value;

    if (books != null) {
      List<Book> sortedBooks = <Book>[];
      // final nav = ref.read(navigationProvider);
      final selectedBook = nav.selectedBook;
      if (selectedBook != null) {
        final othersBooks = books.where((x) => x != selectedBook).toList();
        sortedBooks.add(selectedBook);
        sortedBooks.addAll(othersBooks);
      } else {
        sortedBooks.addAll(books);
      }

      for (var book in sortedBooks) {
        final units = book.units;
        if (units.isNotEmpty) {
          for (var unit in units) {
            final topics = unit.topics;
            if (topics.isNotEmpty) {
              for (var topic in topics) {
                final pages = topic.pageContents;
                if (pages.isNotEmpty) {
                  for (var page in pages) {
                    final finalTopics = page.finalTopics;
                    if (finalTopics.isNotEmpty) {
                      for (var finalTopic in finalTopics) {
                        Directory dir = Directory(finalTopic.realmId);
                        final files = dir.listSync();
                        final textFilePathOriginalContent =
                            findOriginalFileContent(files)?.path;
                        if (textFilePathOriginalContent != null) {
                          String content = File(
                            textFilePathOriginalContent,
                          ).readAsStringSync();
                          OriginalContent originalContent = OriginalContent(
                            book: book.name,
                            unit: unit.name,
                            topic: topic.name,
                            page: page.name,
                            root:
                                '${unit.name}>${topic.name}>${page.name}>${finalTopic.name}',
                            originalContent: content,
                            finalTopic: finalTopic,
                          );
                          result.add(originalContent);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    return result;
  }

  FileSystemEntity? findOriginalFileContent(List<FileSystemEntity> fileList) {
    try {
      // استفاده از firstWhere و مدیریت خطای StateError
      return fileList.firstWhere(
        (f) => !f.path.endsWith('sound.txt') && f.path.endsWith('.txt'),
      );
    } on StateError {
      // اگر هیچ فایلی با پسوند .json پیدا نشد
      return null;
    }
  }

  List<MainTextSegment> fillGapsInFullText(
    String fullText,
    List<MainTextSegment> inputSegments,
  ) {
    final List<MainTextSegment> result = [];

    int lastMatchEnd = 0;

    for (final seg in inputSegments) {
      final segText = seg.text;
      if (segText.isEmpty) continue;

      // پیدا کردن موقعیت واقعی segment در fullText، بعد از آخرین match
      final startIndex = fullText.indexOf(segText, lastMatchEnd);
      if (startIndex == -1) {
        // اگر اصلاً پیدا نشد، ازش صرف‌نظر کن ولی ادامه بده
        continue;
      }

      // اگر متن ساده‌ای بین انتهای قبلی و آغاز این segment هست → اضافه کن
      if (startIndex > lastMatchEnd) {
        final plain = fullText.substring(lastMatchEnd, startIndex);
        if (plain.isNotEmpty) {
          result.add(MainTextSegment(text: plain, isInteractive: false));
        }
      }

      // خود segment ورودی را اضافه کن
      result.add(seg);

      // به‌روزرسانی موقعیت آخرین کاراکتر پردازش‌شده
      lastMatchEnd = startIndex + segText.length;
    }

    // در آخر متن باقی‌مانده را هم اضافه کن
    if (lastMatchEnd < fullText.length) {
      final rest = fullText.substring(lastMatchEnd);
      if (rest.isNotEmpty) {
        result.add(MainTextSegment(text: rest, isInteractive: false));
      }
    }

    return result;
  }
}
