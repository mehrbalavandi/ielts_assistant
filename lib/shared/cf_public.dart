import 'dart:convert';
import 'dart:io';

// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/add_or_edit_tempelate.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:permission_handler/permission_handler.dart';

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

  List<TextSegmentEnglish> fillGapsInFullText(
    String fullText,
    List<TextSegmentEnglish> inputSegments,
  ) {
    final List<TextSegmentEnglish> result = [];

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
          result.add(TextSegmentEnglish(text: plain, isInteractive: false));
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
        result.add(TextSegmentEnglish(text: rest, isInteractive: false));
      }
    }

    return result;
  }

  List<TextSegmentEnglish> processSegmentsEnglish(
    List<TextSegmentEnglish> segments,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      // اگر جستجویی نیست، همان segments اصلی را برگردانید.
      return segments;
    }
    // .asMap().entries.map((entry) {
    //       final index = entry.key;
    //       final status = sentenceStates[index] ?? SentenceStatus.hide;
    final fullText = segments.map((s) => s.text).join();
    final List<TextSegmentEnglish> microSegments = [];
    int currentTextIndex = 0;

    // 1. پیدا کردن تمامی تطابق‌های عبارت جستجو
    final matches = RegExp(
      searchQuery,
      caseSensitive: false,
    ).allMatches(fullText).toList();

    if (matches.isEmpty) {
      // اگر تطابقی پیدا نشد، همان segments اصلی را برگردانید.
      return segments;
    }

    // 2. تکرار بر روی segments اصلی و اعمال شکستگی
    for (final segment in segments) {
      final segmentText = segment.text;
      final originText = segment.isInteractive ? segmentText : null;
      final segmentStart = currentTextIndex;
      final segmentEnd = currentTextIndex + segmentText.length;

      int segmentCurrentPosition = 0; // پوزیشن داخلی در segmentText

      // بررسی تداخل این segment با هر یک از نتایج جستجو
      for (final match in matches) {
        final matchStart = match.start;
        final matchEnd = match.end;

        // بررسی تداخل
        if (segmentStart < matchEnd && segmentEnd > matchStart) {
          // 1. قسمت قبل از هایلایت (اگر وجود دارد)
          final nonHighlightStart = segmentStart + segmentCurrentPosition;
          final nonHighlightEnd = matchStart > segmentStart
              ? matchStart
              : segmentStart;

          if (nonHighlightEnd > nonHighlightStart) {
            final startInSegment = nonHighlightStart - segmentStart;
            final endInSegment = nonHighlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentEnglish(
                text: text,
                originText: originText,
                isInteractive: segment.isInteractive,
                isBold: segment.isBold,
                isBlank: segment.isBlank,
                hasSubItems: segment.hasSubItems,
                subItems: segment.subItems,
                translation: segment.translation,
                explanation: segment.explanation,
              ),
            );
            segmentCurrentPosition = endInSegment;
          }

          // 2. قسمت هایلایت شده (بخشی از تطابق که در این segment قرار دارد)
          final highlightStart = matchStart > segmentStart
              ? matchStart
              : segmentStart;
          final highlightEnd = matchEnd < segmentEnd ? matchEnd : segmentEnd;

          if (highlightEnd > highlightStart) {
            final startInSegment = highlightStart - segmentStart;
            final endInSegment = highlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentEnglish(
                text: text,
                originText: originText,
                isInteractive: segment.isInteractive,
                isBold: segment.isBold,
                isBlank: segment.isBlank,
                hasSubItems: segment.hasSubItems,
                subItems: segment.subItems,
                translation: segment.translation,
                explanation: segment.explanation,
                isAmberHighlighted: true, // اعمال هایلایت
              ),
            );
            segmentCurrentPosition = endInSegment;
          }
        }
      }

      // 3. قسمت باقی‌مانده از segment بعد از آخرین تطابق (اگر وجود دارد)
      if (segmentCurrentPosition < segmentText.length) {
        final text = segmentText.substring(segmentCurrentPosition);
        microSegments.add(
          TextSegmentEnglish(
            text: text,
            originText: originText,
            isInteractive: segment.isInteractive,
            isBold: segment.isBold,
            isBlank: segment.isBlank,
            hasSubItems: segment.hasSubItems,
            subItems: segment.subItems,
            translation: segment.translation,
            explanation: segment.explanation,
          ),
        );
      }

      currentTextIndex += segmentText.length;
    }

    return microSegments;
  }

  List<TextSegmentPersian> processSegmentsPersian(
    List<TextSegmentPersian> segments,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      // اگر جستجویی نیست، همان segments اصلی را برگردانید.
      return segments;
    }
    // .asMap().entries.map((entry) {
    //       final index = entry.key;
    //       final status = sentenceStates[index] ?? SentenceStatus.hide;
    final fullText = segments.map((s) => s.text).join();
    final List<TextSegmentPersian> microSegments = [];
    int currentTextIndex = 0;

    // 1. پیدا کردن تمامی تطابق‌های عبارت جستجو
    final matches = RegExp(
      searchQuery,
      caseSensitive: false,
    ).allMatches(fullText).toList();

    if (matches.isEmpty) {
      // اگر تطابقی پیدا نشد، همان segments اصلی را برگردانید.
      return segments;
    }

    // 2. تکرار بر روی segments اصلی و اعمال شکستگی
    for (final segment in segments) {
      final segmentText = segment.text;
      final segmentStart = currentTextIndex;
      final segmentEnd = currentTextIndex + segmentText.length;

      int segmentCurrentPosition = 0; // پوزیشن داخلی در segmentText

      // بررسی تداخل این segment با هر یک از نتایج جستجو
      for (final match in matches) {
        final matchStart = match.start;
        final matchEnd = match.end;

        // بررسی تداخل
        if (segmentStart < matchEnd && segmentEnd > matchStart) {
          // 1. قسمت قبل از هایلایت (اگر وجود دارد)
          final nonHighlightStart = segmentStart + segmentCurrentPosition;
          final nonHighlightEnd = matchStart > segmentStart
              ? matchStart
              : segmentStart;

          if (nonHighlightEnd > nonHighlightStart) {
            final startInSegment = nonHighlightStart - segmentStart;
            final endInSegment = nonHighlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentPersian(text: text, isBold: segment.isBold),
            );
            segmentCurrentPosition = endInSegment;
          }

          // 2. قسمت هایلایت شده (بخشی از تطابق که در این segment قرار دارد)
          final highlightStart = matchStart > segmentStart
              ? matchStart
              : segmentStart;
          final highlightEnd = matchEnd < segmentEnd ? matchEnd : segmentEnd;

          if (highlightEnd > highlightStart) {
            final startInSegment = highlightStart - segmentStart;
            final endInSegment = highlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentPersian(
                text: text,
                isBold: segment.isBold,
                isAmberHighlighted: true, // اعمال هایلایت
              ),
            );
            segmentCurrentPosition = endInSegment;
          }
        }
      }

      // 3. قسمت باقی‌مانده از segment بعد از آخرین تطابق (اگر وجود دارد)
      if (segmentCurrentPosition < segmentText.length) {
        final text = segmentText.substring(segmentCurrentPosition);
        microSegments.add(
          TextSegmentPersian(text: text, isBold: segment.isBold),
        );
      }

      currentTextIndex += segmentText.length;
    }

    return microSegments;
  }

  Future<bool?> getExternalStoragePermissionStatus() async {
    try {
      var res = await Permission.manageExternalStorage.status;
      if (!res.isGranted) {
        Permission.manageExternalStorage.request().then((onValue) async {
          var res2 = await Permission.manageExternalStorage.status;
          if (res2.isGranted) {
            return true;
          } else {
            return false;
          }
        });
      } else if (res.isGranted) {
        return true;
      }
    } catch (exception) {
      return false;
    }
    return false;
  }

  Future<bool> savePersianTextSegmentToExternalStorage({
    required String fileName,
    required TextSegmentPersian textSement,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentPersian>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      if (content.isEmpty) {
        segments.add(textSement);
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      } else {
        var existingData = jsonDecode(content);
        if (existingData is! List) {
          existingData = [existingData];
        }
        segments = existingData
            .map((json) => TextSegmentPersian.fromJson(json))
            .toList();
        // segments.add(PersianTextSegment(text: '\n\n'));
        segments.add(textSement);
        // تبدیل لیست به JSON با فرمت خوانا (pretty)
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return false;
    }
  }

  Future<bool> saveMainTextSegmentToExternalStorage({
    required String fileName,
    required TextSegmentEnglish textSement,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentEnglish>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      if (content.isEmpty) {
        segments.add(textSement);
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      } else {
        var existingData = jsonDecode(content);
        if (existingData is! List) {
          existingData = [existingData];
        }
        segments = existingData
            .map((json) => TextSegmentEnglish.fromJson(json))
            .toList();
        // segments.add(MainTextSegment(text: '\n\n', isInteractive: false));
        segments.add(textSement);
        // تبدیل لیست به JSON با فرمت خوانا (pretty)
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return false;
    }
  }

  Future<bool> saveNoteTextSegmentToExternalStorage({
    required String fileName,
    required TextSegmentPersian textSement,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentPersian>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      if (content.isEmpty) {
        segments.add(textSement);
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      } else {
        var existingData = jsonDecode(content);
        if (existingData is! List) {
          existingData = [existingData];
        }
        segments = existingData
            .map((json) => TextSegmentPersian.fromJson(json))
            .toList();
        // segments.add(PersianTextSegment(text: '\n\n'));
        segments.add(textSement);
        // تبدیل لیست به JSON با فرمت خوانا (pretty)
        final jsonString = encoder.convert(
          segments.map((s) => s.toJson()).toList(),
        );
        await file.writeAsString(jsonString, flush: true, encoding: utf8);
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return false;
    }
  }

  Future<List<TextSegmentEnglish>?> updateMainTextSegmentToExternalStorage({
    required String fileName,
    required int index,
    required String newText,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentEnglish>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      var existingData = jsonDecode(content);
      if (existingData is! List) {
        existingData = [existingData];
      }
      segments = existingData
          .map((json) => TextSegmentEnglish.fromJson(json))
          .toList();
      // segments.add(MainTextSegment(text: '\n\n', isInteractive: false));
      segments.removeAt(index);
      segments.insert(
        index,
        TextSegmentEnglish(text: newText, isInteractive: false),
      );
      // تبدیل لیست به JSON با فرمت خوانا (pretty)
      final jsonString = encoder.convert(
        segments.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonString, flush: true, encoding: utf8);
      return segments;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return null;
    }
  }

  Future<List<TextSegmentPersian>?> updatePersianTextSegmentToExternalStorage({
    required String fileName,
    required int index,
    required String newText,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentPersian>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      var existingData = jsonDecode(content);
      if (existingData is! List) {
        existingData = [existingData];
      }
      segments = existingData
          .map((json) => TextSegmentPersian.fromJson(json))
          .toList();
      // segments.add(MainTextSegment(text: '\n\n', isInteractive: false));
      segments.removeAt(index);
      segments.insert(index, TextSegmentPersian(text: newText));
      // تبدیل لیست به JSON با فرمت خوانا (pretty)
      final jsonString = encoder.convert(
        segments.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonString, flush: true, encoding: utf8);
      return segments;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return null;
    }
  }

  Future<bool?> showPopupAddTempelate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            onSubmit: (allText, enText, faText, noteText) async {
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/00/Content';
              if (!Directory(newTemplateDirectory).existsSync()) {
                Directory(newTemplateDirectory).createSync(recursive: true);
              }
              String allTextFileName = '$newTemplateDirectory/me.1.txt';
              if (!File(allTextFileName).existsSync()) {
                File(allTextFileName).createSync(recursive: true);
              }
              //! محتوای فارسی
              String faFileName = '$newTemplateDirectory/me.3.translation.json';
              if (!File(faFileName).existsSync()) {
                File(faFileName).createSync(recursive: true);
              }
              bool result1 = await CfPublic()
                  .savePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    textSement: faText,
                  );

              if (result1) {
                //! محتوای انگلیسی
                String enFileName = '$newTemplateDirectory/me.2.english.json';
                if (!File(enFileName).existsSync()) {
                  File(enFileName).createSync(recursive: true);
                }
                bool result2 = await CfPublic()
                    .saveMainTextSegmentToExternalStorage(
                      fileName: enFileName,
                      textSement: enText,
                    );
                if (result2) {
                  //! محتوای نکات
                  String noteFileName = '$newTemplateDirectory/me.4.notes.json';
                  if (!File(noteFileName).existsSync()) {
                    File(noteFileName).createSync(recursive: true);
                  }
                  if (noteText != null) {
                    bool result3 = await CfPublic()
                        .savePersianTextSegmentToExternalStorage(
                          fileName: noteFileName,
                          textSement: noteText,
                        );
                    if (result3) {
                      //! فایل متنی کل
                      File(
                        allTextFileName,
                      ).writeAsStringSync(allText, encoding: utf8);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      } else {
                        if (context.mounted) {
                          Navigator.pop(context, false);
                        }
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.pop(context, false);
                      }
                    }
                  }
                } else {
                  File(
                    allTextFileName,
                  ).writeAsStringSync(allText, encoding: utf8);
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  } else {
                    if (context.mounted) {
                      Navigator.pop(context, false);
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(context, false);
                  }
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },
          ),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as bool;
    } else {
      return false;
    }
  }

  Future<bool?> showPopupEditTempelate(
    BuildContext context,
    WidgetRef ref,
    int index,
    String initEnglishText,
    String initPersianText,
    String initNoteText,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            initEnglishText: initEnglishText,
            initPersianText: initPersianText,
            initNotes: initNoteText,
            onSubmit: (_, enText, faText, noteText) async {
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/00/Content';
              if (!Directory(newTemplateDirectory).existsSync()) {
                Directory(newTemplateDirectory).createSync(recursive: true);
              }
              String allTextFileName = '$newTemplateDirectory/me.1.txt';
              if (!File(allTextFileName).existsSync()) {
                File(allTextFileName).createSync(recursive: true);
              }
              //! محتوای فارسی
              String faFileName = '$newTemplateDirectory/me.3.translation.json';
              if (!File(faFileName).existsSync()) {
                File(faFileName).createSync(recursive: true);
              }
              final result1 = await CfPublic()
                  .updatePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    index: index,
                    newText: faText.text,
                  );
              if (result1 != null) {
                //! محتوای انگلیسی
                String enFileName = '$newTemplateDirectory/me.2.english.json';
                if (!File(enFileName).existsSync()) {
                  File(enFileName).createSync(recursive: true);
                }
                final result2 = await CfPublic()
                    .updateMainTextSegmentToExternalStorage(
                      fileName: enFileName,
                      index: index,
                      newText: enText.text,
                    );
                if (result2 != null) {
                  //! محتوای نکات
                  String noteFileName = '$newTemplateDirectory/me.4.notes.json';
                  if (!File(noteFileName).existsSync()) {
                    File(noteFileName).createSync(recursive: true);
                  }
                  if (noteText != null) {
                    final result3 = await CfPublic()
                        .updatePersianTextSegmentToExternalStorage(
                          fileName: noteFileName,
                          index: index,
                          newText: noteText.text,
                        );
                    if (result3 != null) {
                      //! فایل متنی کل
                      String allText = '';
                      for (int i = 0; i < result2.length; i++) {
                        if (i == 0) {
                          allText =
                              '${result1[i].text}\n${result2[i].text}\n${result3[i].text}';
                        } else {
                          allText =
                              '$allText\n\n${result1[i].text}\n${result2[i].text}\n${result3[i].text}';
                        }
                      }
                      File(
                        allTextFileName,
                      ).writeAsStringSync(allText, encoding: utf8);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.pop(context, false);
                      }
                    }
                  } else {
                    //! فایل متنی کل
                    String allText = '';
                    for (int i = 0; i < result2.length; i++) {
                      if (i == 0) {
                        allText = '${result1[i].text}\n${result2[i].text}';
                      } else {
                        allText =
                            '$allText\n\n${result1[i].text}\n${result2[i].text}';
                      }
                    }
                    File(
                      allTextFileName,
                    ).writeAsStringSync(allText, encoding: utf8);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                } else {
                  if (context.mounted) {
                    Navigator.pop(context, false);
                  }
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },
          ),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as bool;
    } else {
      return false;
    }
  }

  Future<List<TextSegmentEnglish>?> deleteMainTextSegmentFromExternalStorage({
    required String fileName,
    required int index,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentEnglish>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      var existingData = jsonDecode(content);
      if (existingData is! List) {
        existingData = [existingData];
      }
      segments = existingData
          .map((json) => TextSegmentEnglish.fromJson(json))
          .toList();
      // segments.add(MainTextSegment(text: '\n\n', isInteractive: false));
      segments.removeAt(index);
      // تبدیل لیست به JSON با فرمت خوانا (pretty)
      final jsonString = encoder.convert(
        segments.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonString, flush: true, encoding: utf8);
      return segments;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return null;
    }
  }

  Future<List<TextSegmentPersian>?>
  deletePersianTextSegmentFromExternalStorage({
    required String fileName,
    required int index,
  }) async {
    final file = File(fileName);
    var segments = <TextSegmentPersian>[];
    final encoder = JsonEncoder.withIndent('  '); // دو فاصله برای هر سطح

    try {
      final content = await file.readAsString();
      var existingData = jsonDecode(content);
      if (existingData is! List) {
        existingData = [existingData];
      }
      segments = existingData
          .map((json) => TextSegmentPersian.fromJson(json))
          .toList();
      // segments.add(MainTextSegment(text: '\n\n', isInteractive: false));
      segments.removeAt(index);
      // تبدیل لیست به JSON با فرمت خوانا (pretty)
      final jsonString = encoder.convert(
        segments.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonString, flush: true, encoding: utf8);
      return segments;
    } catch (e) {
      debugPrint('⚠️ خطا در خواندن فایل: $e');
      return null;
    }
  }

  Future<bool?> deleteTempelate(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final rootPath = ref.read(settingsProvider);
    String newTemplateDirectory =
        '$rootPath/قالبهای موقعیتی/Band 4–5/Days/00/Content';
    if (!Directory(newTemplateDirectory).existsSync()) {
      Directory(newTemplateDirectory).createSync(recursive: true);
    }
    String allTextFileName = '$newTemplateDirectory/me.1.txt';
    if (!File(allTextFileName).existsSync()) {
      File(allTextFileName).createSync(recursive: true);
    }
    //! محتوای انگلیسی
    String enFileName = '$newTemplateDirectory/me.2.english.json';
    if (!File(enFileName).existsSync()) {
      File(enFileName).createSync(recursive: true);
    }
    final result1 = await CfPublic().deleteMainTextSegmentFromExternalStorage(
      fileName: enFileName,
      index: index,
    );
    if (result1 != null) {
      //! محتوای فارسی
      String faFileName = '$newTemplateDirectory/me.3.translation.json';
      if (!File(faFileName).existsSync()) {
        File(faFileName).createSync(recursive: true);
      }
      final result2 = await CfPublic()
          .deletePersianTextSegmentFromExternalStorage(
            fileName: faFileName,
            index: index,
          );
      if (result2 != null) {
        String allText = '';
        for (int i = 0; i < result1.length; i++) {
          if (i == 0) {
            allText = '${result1[i].text}\n${result2[i].text}';
          } else {
            allText = '$allText\n\n${result1[i].text}\n${result2[i].text}';
          }
        }
        //! محتوای خام
        File(allTextFileName).writeAsStringSync(allText, encoding: utf8);
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }
}
