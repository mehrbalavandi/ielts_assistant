import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';

// 🌟 RM-2: حالتِ «خوانا» = تبدیلِ داده‌ی صفحه پیش از رندر، نه یک رندرکننده‌ی دوم.
// رندرکننده‌ی فعلی کاملاً از روی داده (مارکرهای sz:/fn:، ResponsiveStrategy، فاصله‌ها)
// تصمیم می‌گیرد؛ پس همین‌جا داده عوض می‌شود و همه‌چیزِ دیگر — جای‌خالی‌ها، ترجمه،
// دیکشنری، جستجو، صوت، «مرورِ من» — بی‌تغییر کار می‌کند. متنِ پاراگراف‌ها و ترتیب و
// تعدادشان دست نمی‌خورد (جستجو و «رفتن به متن» به اندیسِ پاراگراف وابسته‌اند).
//
// چه عوض می‌شود:
// - اندازه‌ی متن: متنِ عادیِ کتاب (۱۱٫۵pt) ← ۱۵px × ضریبِ کاربر؛ تیترها نسبتِ خود را با
//   توانِ ۰٫۷۵ نگه می‌دارند (درشت ولی نه غول‌پیکر)، بینِ ۰٫۸۵ و ۱٫۹ برابرِ متنِ عادی.
// - فونت: همه‌ی متنِ لاتین Source Sans 3 (فونتِ اصلیِ خودِ کتاب)؛ فونت‌های نمادین
//   (Wingdings، Symbol، ایموجی) و فارسی همان می‌مانند.
// - فاصله‌ی خطوط حداقل ۱٫۵؛ فاصله‌ی پیش/پس از پاراگراف حداکثر ۱۴.
// - جدول‌های «واژه‌ای» (همه‌ی سلول‌ها کوتاه، مثلِ کادرِ best/close/happy): عرضِ ستون‌های
//   سند هم‌پای متن بزرگ می‌شود تا واژه‌ها نشکنند؛ چیدمانِ جدول همان کتاب می‌ماند.
// - گوشی (عرضِ ≤ ۶۰۰): تورفتگی‌ها ۶۰٪ (حداکثر ۲۴)، و جدول‌های چندستونه:
//   · جدولِ واژه‌ای ← همان جدولِ کتاب (نه چیپ‌های جدا، نه فهرستِ عمودی)
//   · جدولِ داده‌ای با سرستون (≥۳ ردیف) ← ردیف‌به‌ردیف، هر ردیف یک کارت (stackRows)
//   · بقیه (صفحه‌آرایی: شماره‌ی تمرین | متن | نکته، گفت‌وگو: Examiner | متن، جمله | کادر)
//     ← «ردیفی» (rowFlow): ترتیبِ خواندن همان ترتیبِ Word است (ردیف‌به‌ردیف)؛ سلولِ اولِ
//     باریک (شماره، برچسبِ گوینده) کنارِ بقیه‌ی ردیف می‌ماند و سلول‌های دیگر زیرِ هم
//     می‌آیند؛ سلول‌های خالی حذف می‌شوند. دیگر هیچ جدولی ستون‌به‌ستون (همه‌ی شماره‌ها
//     با هم، بعد همه‌ی متن‌ها) چیده نمی‌شود.
//   جدولِ تک‌ستونه، نشانِ شماره‌ی تمرین (CompactTable)، جدولِ جریانی (wrap) و متنِ
//   چندستونی (MultiColumnTable / layoutReflow) دست نمی‌خورند.

@immutable
class ReadableOptions {
  final double fontScale;

  /// گوشی (عرضِ ≤ ۶۰۰)، همان آستانه‌ی isLargeScreenِ رندرکننده‌ی جدول.
  final bool narrow;

  const ReadableOptions({required this.fontScale, required this.narrow});

  @override
  bool operator ==(Object other) =>
      other is ReadableOptions &&
      other.fontScale == fontScale &&
      other.narrow == narrow;

  @override
  int get hashCode => Object.hash(fontScale, narrow);
}

/// اندازه‌ی متنِ عادیِ کتاب (pt) — مرجعِ مقیاس.
const double _kBookBodyPt = 11.5;

/// اندازه‌ی متنِ عادی در حالتِ خوانا (px) با ضریبِ ۱.
const double kReadableBodyPx = 15.0;

final Expando<_Cached> _cache = Expando<_Cached>('readablePage');

class _Cached {
  _Cached(this.options, this.page);
  final ReadableOptions options;
  final PageData page;
}

/// نسخه‌ی «خوانا»ی صفحه (برای هر صفحه و هر تنظیم یک‌بار ساخته و نگه داشته می‌شود).
PageData readablePage(PageData page, ReadableOptions options) {
  final _Cached? c = _cache[page];
  if (c != null && c.options == options) return c.page;
  final PageData out = PageData(
    pageNumber: page.pageNumber,
    paragraphs: [
      for (final p in page.paragraphs) _ReadableTransform(options).paragraph(p),
    ],
    interactives: page.interactives,
    interactivesPattern: page.interactivesPattern,
    interactivesByText: page.interactivesByText,
  );
  _cache[page] = _Cached(options, out);
  return out;
}

class _ReadableTransform {
  _ReadableTransform(this.o);

  final ReadableOptions o;

  double get _base => kReadableBodyPx * o.fontScale;

  double _size(double pt) {
    final double v = _base * math.pow(pt / _kBookBodyPt, 0.75).toDouble();
    return v.clamp(_base * 0.85, _base * 1.9).toDouble();
  }

  String _szMarker(double px) => 'sz:${(px * 2).toStringAsFixed(1)}';

  double? _indent(double? v, {double cap = 24}) {
    if (v == null || !o.narrow) return v;
    final double s = v * 0.6;
    return s.clamp(-cap, cap).toDouble();
  }

  ParagraphData paragraph(ParagraphData p) {
    return p.copyWith(
      spans: [for (final s in p.spans) span(s)],
      lineSpacing: math.max(p.lineSpacing ?? 1.3, 1.5),
      spaceBefore: math.min(p.spaceBefore, 14.0),
      spaceAfter: math.min(p.spaceAfter, 14.0),
      indentLeft: _indent(p.indentLeft),
      indentRight: _indent(p.indentRight, cap: 12),
      indentFirstLine: _indent(p.indentFirstLine),
      // اندازه‌ی شماره هم مثلِ متن (رندرکننده pt را مستقیم px می‌گیرد).
      listMarkerSize: p.listMarkerSize == null
          ? null
          : _size(p.listMarkerSize!),
    );
  }

  SpanData span(SpanData s) {
    if (s.type == 'text') {
      return s.copyWith(
        markers: _markers(s.markers),
        innerSpans: [for (final i in s.innerSpans) span(i)],
        hiddenParagraphs: s.hiddenParagraphs == null
            ? null
            : [for (final p in s.hiddenParagraphs!) paragraph(p)],
      );
    }
    if (s.type == 'table' || s.type == 'layout') {
      final bool wordGrid = _isWordGrid(s);
      // جدولِ واژه‌ای: عرضِ ستون‌ها به نسبتِ بزرگ‌شدنِ متن (۱۱٫۵pt ← ۱۵px × ضریب).
      final double widthScale = wordGrid ? _base / _kBookBodyPt : 1.0;
      final List<TableRowData> rows = [
        for (final r in s.tableRows)
          r.copyWith(
            cells: [
              for (final c in r.cells)
                c.copyWith(
                  paragraphs: [for (final p in c.paragraphs) paragraph(p)],
                  widthPt: (c.widthPt == null || widthScale == 1.0)
                      ? null
                      : c.widthPt! * widthScale,
                ),
            ],
          ),
      ];
      final String? strategy = o.narrow ? _tableStrategy(s, wordGrid) : null;
      return s.copyWith(tableRows: rows, responsiveStrategy: strategy);
    }
    return s;
  }

  List<String> _markers(List<String> markers) {
    final List<String> out = [];
    bool hasSize = false;
    for (final String m in markers) {
      if (m.startsWith('sz:')) {
        final double? halfPt = double.tryParse(m.substring(3));
        if (halfPt != null) {
          out.add(_szMarker(_size(halfPt / 2)));
          hasSize = true;
          continue;
        }
      } else if (m.startsWith('fn:') && !_keepFont(m.substring(3))) {
        out.add('fn:Source Sans 3');
        continue;
      }
      out.add(m);
    }
    if (!hasSize) out.add(_szMarker(_base));
    return out;
  }

  /// فونت‌هایی که نماد یا خطِ فارسی‌اند و جایگزینی خرابشان می‌کند.
  static bool _keepFont(String name) {
    final String n = name.toLowerCase();
    return n.contains('wingdings') ||
        n.contains('webdings') ||
        n.contains('symbol') ||
        n.contains('emoji') ||
        n.contains('zar') ||
        n.contains('titr') ||
        n.contains('yekan') ||
        n.contains('tahoma');
  }

  // ───────── جدول روی گوشی ─────────

  /// null = راهبردِ خودِ کتاب بماند.
  String? _tableStrategy(SpanData t, bool wordGrid) {
    final String current = t.responsiveStrategy ?? '';
    // متنِ چندستونی (merge) و جدولِ جریانیِ خودِ کتاب. ColumnStackTable (layoutReflow
    // = stack) دست می‌خورد: کتاب آن را ستون‌به‌ستون زیرِ هم می‌چیند، خوانا ردیفی.
    if (t.layoutReflow == 'merge' || current == 'wrap') return null;
    final String style = (t.tableStyleId ?? t.tableStyleName ?? '')
        .toLowerCase()
        .replaceAll(' ', '');
    if (style.contains('compacttable') || style.contains('multicolumntable')) {
      return null;
    }
    final List<TableRowData> rows = t.tableRows;
    if (rows.isEmpty) return null;
    final int cols = rows.fold(0, (m, r) => math.max(m, r.cells.length));
    if (cols <= 1) return null;

    // کادرِ واژه‌ها همان جدولِ کتاب؛ اگر کتاب خودش «زیرِ هم» خواسته بود، گرید
    // (هر مقدارِ ناشناخته برای رندرکننده یعنی جدولِ معمولی).
    if (wordGrid) {
      return (current == 'stack' || style.contains('columnstack'))
          ? 'grid'
          : null;
    }
    final TableRowData first = rows.first;
    final bool headerRow =
        first.isHeader ||
        first.cells.every((c) => c.isHeaderCell) ||
        first.cells.every(_boldShortCell);
    if (rows.length >= 3 && headerRow) return 'stackRows';
    return 'rowFlow';
  }

  /// جدولِ واژه‌ای: دست‌کم دو ستون، همه‌ی سلول‌ها فقط متنِ کوتاه (یا خالی).
  static bool _isWordGrid(SpanData t) {
    if (t.tableRows.isEmpty) return false;
    final int cols = t.tableRows.fold(0, (m, r) => math.max(m, r.cells.length));
    if (cols <= 1) return false;
    bool any = false;
    for (final r in t.tableRows) {
      for (final c in r.cells) {
        if (!_onlyText(c)) return false;
        final String text = _cellText(c);
        if (text.length > 30) return false;
        if (text.isNotEmpty) any = true;
      }
    }
    return any;
  }

  static String _cellText(TableCellData c) => c.paragraphs
      .expand((p) => p.spans)
      .where((s) => s.type == 'text')
      .map((s) => s.content.replaceAll(RegExp(r'\{/?blk\}'), ''))
      .join(' ')
      .trim();

  static bool _onlyText(TableCellData c) => c.paragraphs.every(
    (p) => p.spans.every((s) => s.type == 'text'),
  );

  /// سلولِ سرستونِ بی‌علامت: کوتاه و تماماً بولد.
  static bool _boldShortCell(TableCellData c) {
    if (!_onlyText(c)) return false;
    final String t = _cellText(c);
    if (t.isEmpty || t.length > 40) return false;
    return c.paragraphs
        .expand((p) => p.spans)
        .where((s) => s.content.trim().isNotEmpty)
        .every((s) => s.markers.contains('b'));
  }
}
