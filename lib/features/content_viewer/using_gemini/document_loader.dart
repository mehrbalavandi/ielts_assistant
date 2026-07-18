import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';

class DocumentLoader {
  // 🌟 دریافت مسیر فایل به عنوان پارامتر ورودی
  static Future<List<PageData>> loadBookFromJson(String path) async {
    final decoded = jsonDecode(await _readText(path));

    if (decoded is List) {
      // ساختار قدیم: آرایه‌ی مستقیم صفحات
      return decoded
          .map((p) => PageData.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      // 🌟 index.json: هر آیتمِ Pages فقط مانیفست است ({n, file, version})
      if (_looksLikeIndex(decoded)) return _loadFromIndex(decoded, path);
      // ساختار تک‌فایلِ فعلی: {Pages:[full pages], Interactives:[...]}
      return _loadFromSharedInteractivesStructure(decoded);
    }
    throw FormatException('ساختار JSON کتاب ناشناخته است: $path');
  }

  static Future<String> _readText(String path) async {
    if (path.startsWith('assets/')) return rootBundle.loadString(path);
    final file = File(path);
    if (!await file.exists()) throw Exception('فایل یافت نشد: $path');
    return file.readAsString();
  }

  static bool _looksLikeIndex(Map<String, dynamic> d) {
    final pages = (d['Pages'] ?? d['pages']) as List?;
    if (pages == null || pages.isEmpty) return false;
    final first = pages.first;
    return first is Map &&
        (first.containsKey('file') || first.containsKey('File'));
  }

  static String _dirOf(String p) {
    final i = p.lastIndexOf('/');
    return i <= 0 ? '' : p.substring(0, i);
  }

  static Future<List<PageData>> _loadFromIndex(
    Map<String, dynamic> index,
    String indexPath,
  ) async {
    final baseDir = _dirOf(indexPath);
    final entries = (index['Pages'] ?? index['pages']) as List? ?? [];

    final List<Map<String, dynamic>> pageJsons = [];
    for (final e in entries) {
      final rel = (e['file'] ?? e['File']) as String; // "pages/page_0001.json"
      final full = baseDir.isEmpty ? rel : '$baseDir/$rel';
      pageJsons.add(jsonDecode(await _readText(full)) as Map<String, dynamic>);
    }

    // همان مسیرِ «Interactives مشترک» را با ساختارِ سرهم‌شده تغذیه کن
    return _loadFromSharedInteractivesStructure({
      'Pages': pageJsons,
      'Interactives':
          index['Interactives'] ?? index['interactives'] ?? const [],
    });
  }

  static List<PageData> _loadFromSharedInteractivesStructure(
    Map<String, dynamic> decoded,
  ) {
    final pagesJson = (decoded['Pages'] ?? decoded['pages']) as List? ?? [];
    final rawInteractivesJson =
        (decoded['Interactives'] ?? decoded['interactives']) as List? ?? [];

    // 🌟 حذف موارد تکراری بر اساس exactText — فقط اولین موردِ هر متن نگه
    // داشته می‌شود (طبق درخواست: قبل از شروع برنامه انجام شود).
    final sharedInteractives = _dedupeInteractives(
      rawInteractivesJson
          .map((e) => InteractiveWord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    // مرتب‌سازی نزولی بر اساس طول متن: دقیقاً همان رفتار قبلی، تا در
    // موقعیت‌های هم‌ابتدا طولانی‌ترین کلمه برنده‌ی تطبیق شود
    // (مثلاً «ice cream» باید قبل از «ice» تشخیص داده شود).
    sharedInteractives.sort(
      (a, b) => b.exactText.length.compareTo(a.exactText.length),
    );

    final nonEmptyWords = sharedInteractives
        .where((w) => w.exactText.isNotEmpty)
        .toList();

    // 🌟 این RegExp و این Map فقط یک‌بار برای کل کتاب ساخته می‌شوند (نه یک‌بار
    // به‌ازای هر صفحه مثل قبل) و بین همه‌ی صفحات به اشتراک گذاشته می‌شوند.
    final RegExp? sharedPattern = nonEmptyWords.isEmpty
        ? null
        : RegExp(
            nonEmptyWords.map((w) => RegExp.escape(w.exactText)).join('|'),
          );

    final Map<String, InteractiveWord> sharedByText = {
      for (final w in nonEmptyWords) w.exactText: w,
    };

    return pagesJson.map((pageJson) {
      final page = PageData.fromJson(
        pageJson as Map<String, dynamic>,
        sharedInteractives: sharedInteractives,
        sharedPattern: sharedPattern,
        sharedByText: sharedByText,
      );

      // 🌟 با اینکه دیکشنری اصلی حالا سطح کتاب است، بخش‌های رندر فعلی
      // برنامه (مثل _buildStyledInteractiveText و پلیر صوتی) هنوز از
      // para.interactives استفاده می‌کنند. برای اینکه این بخش‌ها بدون
      // تغییر کار کنند، همان‌جا برای هر پاراگراف زیرمجموعه‌ای از دیکشنری
      // مشترک را که واقعاً در متنِ همان پاراگراف ظاهر شده محاسبه و تزریق
      // می‌کنیم (به‌صورت بازگشتی، شامل پاراگراف‌های داخل سلول‌های جدول).
      // از همان RegExp/Map از‌قبل‌ساخته‌شده استفاده می‌شود، پس این کار
      // برای هر پاراگراف یک اسکن خطی است، نه یک حلقه به‌ازای هر کلمه.
      final annotatedParagraphs = page.paragraphs
          .map(
            (p) => _attachRelevantInteractives(p, sharedPattern, sharedByText),
          )
          .toList();

      return PageData(
        pageNumber: page.pageNumber,
        paragraphs: annotatedParagraphs,
        interactives: page.interactives,
        interactivesPattern: page.interactivesPattern,
        interactivesByText: page.interactivesByText,
      );
    }).toList();
  }

  // 🌟 حذف موارد تکراری بر اساس exactText — فقط اولین موردِ هر متن باقی
  // می‌ماند؛ ترتیب اصلیِ لیست (بجز حذف تکراری‌ها) دست‌نخورده می‌ماند.
  static List<InteractiveWord> _dedupeInteractives(
    List<InteractiveWord> source,
  ) {
    final seen = <String>{};
    final result = <InteractiveWord>[];
    for (final word in source) {
      if (word.exactText.isEmpty) continue;
      if (seen.add(word.exactText)) {
        result.add(word);
      }
    }
    return result;
  }

  // 🌟 متنِ مستقیمِ یک اسپن را برمی‌گرداند؛ اگر innerSpans داشته باشد
  // (مثلاً یک باکسِ شناور با محتوای متنیِ داخلی)، متنِ آن‌ها هم به‌صورت
  // بازگشتی لحاظ می‌شود — چون یک کلمه‌ی دیکشنری ممکن است فقط داخل
  // innerSpans ظاهر شده باشد.
  static String _flattenSpanText(SpanData span) {
    final buffer = StringBuffer();
    if (span.type == 'text') buffer.write(span.content);
    for (final inner in span.innerSpans) {
      buffer.write(_flattenSpanText(inner));
    }
    return buffer.toString();
  }

  // 🌟 برای یک پاراگراف مشخص، از میان کل دیکشنریِ مشترکِ کتاب، فقط آن
  // کلماتی را نگه می‌دارد که واقعاً در متنِ همین پاراگراف ظاهر شده‌اند —
  // دقیقاً همان چیزی که para.interactives قبلاً (از JSON محلی صفحه)
  // نمایندگی می‌کرد. با استفاده از همان RegExp/Map مشترکِ از‌قبل‌ساخته‌شده،
  // این کار یک اسکن خطیِ متن است (نه یک حلقه به‌ازای هر کلمه‌ی دیکشنری).
  // اگر پاراگراف شامل جدول باشد، پاراگراف‌های داخل سلول‌ها هم به‌صورت
  // بازگشتی و مستقل پردازش می‌شوند.
  static ParagraphData _attachRelevantInteractives(
    ParagraphData para,
    RegExp? sharedPattern,
    Map<String, InteractiveWord> sharedByText,
  ) {
    final directText = para.spans.map(_flattenSpanText).join();

    List<InteractiveWord> matched = const [];
    if (directText.isNotEmpty && sharedPattern != null) {
      final matchedTexts = <String>{
        for (final m in sharedPattern.allMatches(directText)) m.group(0)!,
      };
      matched = matchedTexts
          .map((text) => sharedByText[text])
          .whereType<InteractiveWord>()
          .toList();
    }

    final processedSpans = para.spans.map((span) {
      if (span.type != 'table' || span.tableRows.isEmpty) return span;
      final newRows = span.tableRows.map((row) {
        final newCells = row.cells.map((cell) {
          return cell.copyWith(
            paragraphs: cell.paragraphs
                .map(
                  (p) => _attachRelevantInteractives(
                    p,
                    sharedPattern,
                    sharedByText,
                  ),
                )
                .toList(),
          );
        }).toList();
        return row.copyWith(cells: newCells);
      }).toList();
      return span.copyWith(tableRows: newRows);
    }).toList();

    return para.copyWith(spans: processedSpans, interactives: matched);
  }
}
