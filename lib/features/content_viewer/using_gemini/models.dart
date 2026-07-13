// ۱. مدل کلمات تعاملی
class InteractiveWord {
  final String exactText;
  final String translationFa;
  final String translationAr;
  final String pronounceFa;
  final String pronounceAr;
  final String explanationFa;
  final String explanationAr;
  final String cefrLevel;

  InteractiveWord({
    required this.exactText,
    required this.translationFa,
    required this.translationAr,
    required this.pronounceFa,
    required this.pronounceAr,
    required this.explanationFa,
    required this.explanationAr,
    required this.cefrLevel,
  });

  factory InteractiveWord.fromJson(Map<String, dynamic> json) {
    return InteractiveWord(
      exactText: json['exactText'] ?? '',
      translationFa: json['translationFa'] ?? '',
      translationAr: json['translationAr'] ?? '',
      pronounceFa: json['pronounceFa'] ?? '',
      pronounceAr: json['pronounceAr'] ?? '',
      explanationFa: json['explanationFa'] ?? '',
      explanationAr: json['explanationAr'] ?? '',
      cefrLevel: json['cefrLevel'] ?? '',
    );
  }
}

class ParagraphData {
  final List<SpanData> spans;
  final String direction;
  final String alignment;
  final String? fillColor;

  // 🌟 ارتقاء: استفاده از کلاس مشترک به جای ۴ فیلد مجزا
  final BorderDetail? borders;

  final double spaceBefore;
  final double spaceAfter;
  final double? indentLeft;
  final double? indentRight;
  final double? indentFirstLine;

  final int? startMs;
  final int? endMs;
  final String? audioTrackName;

  final String? translationFa;
  final String? translationAr;
  final List<InteractiveWord> interactives;

  ParagraphData({
    required this.spans,
    this.direction = "LTR",
    this.alignment = "L",
    this.fillColor,
    this.borders, // تزریق بوردر جدید
    this.spaceBefore = 0.0,
    this.spaceAfter = 0.0,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.startMs,
    this.endMs,
    this.audioTrackName,
    this.translationFa,
    this.translationAr,
    required this.interactives,
  });

  factory ParagraphData.fromJson(Map<String, dynamic> json) {
    var interactivesList = json['Interactives'] as List? ?? [];
    var spansList = json['Spans'] as List? ?? [];

    return ParagraphData(
      direction: json['Direction'] ?? 'LTR',
      alignment: json['Alignment'] ?? 'L',
      fillColor: json['FillColor'],
      // 🌟 مپ کردن مستقیم ساختار یکپارچه بوردر از JSON بک‌اندمان
      borders: json['Borders'] != null
          ? BorderDetail.fromJson(json['Borders'])
          : null,
      spaceBefore: (json['SpaceBefore'] as num?)?.toDouble() ?? 0.0,
      spaceAfter: (json['SpaceAfter'] as num?)?.toDouble() ?? 0.0,
      indentLeft: json['IndentLeft']?.toDouble(),
      indentRight: json['IndentRight']?.toDouble(),
      indentFirstLine: json['IndentFirstLine']?.toDouble(),
      startMs: json['StartMs'] as int?,
      endMs: json['EndMs'] as int?,
      audioTrackName: json['AudioTrackName'] as String?,
      translationFa: json['translationFa'],
      translationAr: json['translationAr'],
      interactives: interactivesList
          .map((e) => InteractiveWord.fromJson(e))
          .toList(),
      spans: spansList.map((e) => SpanData.fromJson(e)).toList(),
    );
  }

  // 🌟 برای جایگزینی «فقط» فیلد(های) مشخص بدون بازنویسی دستی و مستعدِ خطای
  // بقیه‌ی فیلدها؛ DocumentLoader از این برای تزریق زیرمجموعه‌ی مرتبط از
  // دیکشنری مشترک (ساختار جدید data.json) استفاده می‌کند.
  ParagraphData copyWith({
    List<SpanData>? spans,
    List<InteractiveWord>? interactives,
  }) {
    return ParagraphData(
      spans: spans ?? this.spans,
      direction: direction,
      alignment: alignment,
      fillColor: fillColor,
      borders: borders,
      spaceBefore: spaceBefore,
      spaceAfter: spaceAfter,
      indentLeft: indentLeft,
      indentRight: indentRight,
      indentFirstLine: indentFirstLine,
      startMs: startMs,
      endMs: endMs,
      audioTrackName: audioTrackName,
      translationFa: translationFa,
      translationAr: translationAr,
      interactives: interactives ?? this.interactives,
    );
  }
}

// ۳. مدل صفحه
class PageData {
  final int pageNumber;
  final List<ParagraphData> paragraphs;
  final List<InteractiveWord> interactives;

  // 🌟 رفع مشکل کندی اسکرول (بخش دوم):
  // موتور رندر متن، برای پیدا کردن کلمات دیکشنری داخل هر تکه از متن، قبلاً
  // به ازای هر موقعیت در متن، تک‌تک تمام کلمات این لیست را با
  // `String.indexOf` چک می‌کرد — یعنی برای صفحه‌ای با صدها کلمه‌ی دیکشنری
  // و پاراگراف‌های طولانی، این کار به‌شدت کند بود (O(تعداد کلمات × طول متن)
  // و حتی بدتر، چون به ازای هر match باز هم از اول روی کل لیست می‌گشت).
  // چون این لیست در طول عمر صفحه ثابت است، همینجا یک‌بار یک RegExp
  // ترکیبی (تمام کلمات را با | به هم وصل می‌کند) و یک Map برای پیدا کردن
  // سریع InteractiveWord از روی متنِ match‌شده می‌سازیم. حالا موتور رندر
  // فقط یک‌بار با این RegExp روی متن می‌گردد (خطی/O(n)) به‌جای اسکن مکرر.
  final RegExp? interactivesPattern;
  final Map<String, InteractiveWord> interactivesByText;

  PageData({
    required this.pageNumber,
    required this.paragraphs,
    required this.interactives,
    this.interactivesPattern,
    this.interactivesByText = const {},
  });

  factory PageData.fromJson(
    Map<String, dynamic> json, {
    // 🌟 اگر این‌ها داده شوند (ساختار جدید data.json با دیکشنری مشترک کل
    // کتاب)، به‌جای ساختن از کلید Interactives خودِ این صفحه، مستقیماً از
    // این‌ها استفاده می‌شود. اگر داده نشوند، رفتار قبلی (سازگار با
    // ساختار قدیم که هر صفحه Interactives خودش را دارد) حفظ می‌شود.
    List<InteractiveWord>? sharedInteractives,
    RegExp? sharedPattern,
    Map<String, InteractiveWord>? sharedByText,
  }) {
    var parasList = json['Paragraphs'] as List? ?? [];

    if (sharedInteractives != null) {
      return PageData(
        pageNumber: json['PageNumber'] ?? 1,
        paragraphs: parasList.map((e) => ParagraphData.fromJson(e)).toList(),
        interactives: sharedInteractives,
        interactivesPattern: sharedPattern,
        interactivesByText: sharedByText ?? const {},
      );
    }

    var interactivesList = json['Interactives'] as List? ?? [];

    // 🌟 رفع مشکل کندی اسکرول: قبلاً این لیست هر بار که یک تکه از متن
    // در حال رندر شدن بود (داخل TextRenderEngine) از نو مرتب می‌شد.
    // چون این لیست هیچ‌وقت در طول عمر صفحه تغییر نمی‌کند، همینجا و فقط
    // یک‌بار (در لحظه لود JSON) مرتب‌سازی می‌شود.
    final parsedInteractives =
        interactivesList.map((e) => InteractiveWord.fromJson(e)).toList()
          ..sort((a, b) => b.exactText.length.compareTo(a.exactText.length));

    // فقط کلمات غیرخالی وارد pattern می‌شوند (یک الگوی خالی هر جایی را
    // match می‌کند و باعث حلقه‌ی نادرست می‌شود)
    final nonEmptyWords = parsedInteractives
        .where((w) => w.exactText.isNotEmpty)
        .toList();

    RegExp? pattern;
    if (nonEmptyWords.isNotEmpty) {
      // چون از قبل بر اساس طول نزولی مرتب شده‌اند، در تساویِ موقعیت شروع،
      // اولین موردی که در | می‌آید (یعنی طولانی‌ترین) برنده می‌شود — دقیقاً
      // همان رفتار قبلی (leftmost, و در تساوی طولانی‌ترین کلمه).
      pattern = RegExp(
        nonEmptyWords.map((w) => RegExp.escape(w.exactText)).join('|'),
      );
    }

    final byText = <String, InteractiveWord>{
      for (final w in nonEmptyWords) w.exactText: w,
    };

    return PageData(
      pageNumber: json['PageNumber'] ?? 1,
      paragraphs: parasList.map((e) => ParagraphData.fromJson(e)).toList(),
      interactives: parsedInteractives,
      interactivesPattern: pattern,
      interactivesByText: byText,
    );
  }
}

// ۴. مدل‌های مربوط به جدول (با پشتیبانی کامل از هدر و ادغام)
class TableRowData {
  final bool isHeader;
  final List<TableCellData> cells;

  TableRowData({required this.cells, this.isHeader = false});

  factory TableRowData.fromJson(Map<String, dynamic> json) {
    var cellsList = json['Cells'] as List? ?? [];
    return TableRowData(
      isHeader: json['IsHeader'] ?? false,
      cells: cellsList.map((e) => TableCellData.fromJson(e)).toList(),
    );
  }

  TableRowData copyWith({List<TableCellData>? cells}) {
    return TableRowData(isHeader: isHeader, cells: cells ?? this.cells);
  }
}

// 🌟 کلاس‌های جدید برای پشتیبانی از ضخامت و رنگ اختصاصی هر مرز
class BorderDetail {
  final String? val;
  final double? width;
  final String? color;

  BorderDetail({this.val, this.width, this.color});

  factory BorderDetail.fromJson(Map<String, dynamic> json) {
    return BorderDetail(
      val: json['val'] ?? json['Val'],
      width: (json['width'] ?? json['Width'])?.toDouble(),
      color: json['color'] ?? json['Color'],
    );
  }
}

class CellBorders {
  final BorderDetail? top;
  final BorderDetail? bottom;
  final BorderDetail? left;
  final BorderDetail? right;

  CellBorders({this.top, this.bottom, this.left, this.right});

  factory CellBorders.fromJson(Map<String, dynamic> json) {
    return CellBorders(
      top: json['top'] != null
          ? BorderDetail.fromJson(json['top'])
          : (json['Top'] != null ? BorderDetail.fromJson(json['Top']) : null),
      bottom: json['bottom'] != null
          ? BorderDetail.fromJson(json['bottom'])
          : (json['Bottom'] != null
                ? BorderDetail.fromJson(json['Bottom'])
                : null),
      left: json['left'] != null
          ? BorderDetail.fromJson(json['left'])
          : (json['Left'] != null ? BorderDetail.fromJson(json['Left']) : null),
      right: json['right'] != null
          ? BorderDetail.fromJson(json['right'])
          : (json['Right'] != null
                ? BorderDetail.fromJson(json['Right'])
                : null),
    );
  }
}

class TableCellData {
  final double? widthPercent;
  final List<ParagraphData> paragraphs;
  final String? fillColor;
  final String? vAlign;
  final int? colSpan;
  final String? rowMerge;
  final bool isHeaderCell;
  final CellBorders? borders;
  final double? paddingTop;
  final double? paddingBottom;
  final double? paddingLeft;
  final double? paddingRight;
  final int? gridSpan;
  final String? vMerge;

  TableCellData({
    this.widthPercent,
    required this.paragraphs,
    this.fillColor,
    this.vAlign,
    this.colSpan,
    this.rowMerge,
    this.isHeaderCell = false,
    this.borders, // پیش‌فرض خالی
    this.paddingTop,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.gridSpan,
    this.vMerge,
  });

  factory TableCellData.fromJson(Map<String, dynamic> json) {
    var parasList = json['Paragraphs'] as List? ?? [];
    return TableCellData(
      widthPercent: json['WidthPercent']?.toDouble(),
      fillColor: json['FillColor'],
      vAlign: json['VAlign'],
      colSpan: json['ColSpan'],
      rowMerge: json['RowMerge'],
      isHeaderCell: json['IsHeaderCell'] ?? false,
      paragraphs: parasList.map((e) => ParagraphData.fromJson(e)).toList(),
      borders: json['Borders'] != null
          ? CellBorders.fromJson(json['Borders'])
          : null,
      paddingTop: json['PaddingTop']?.toDouble(),
      paddingBottom: json['PaddingBottom']?.toDouble(),
      paddingLeft: json['PaddingLeft']?.toDouble(),
      paddingRight: json['PaddingRight']?.toDouble(),
      gridSpan: json['gridSpan'] != null
          ? json['ColSpan'] as int
          : 1, // مقدار پیش‌فرض ۱
      vMerge: json['RowMerge'] as String?,
    );
  }

  TableCellData copyWith({List<ParagraphData>? paragraphs}) {
    return TableCellData(
      widthPercent: widthPercent,
      paragraphs: paragraphs ?? this.paragraphs,
      fillColor: fillColor,
      vAlign: vAlign,
      colSpan: colSpan,
      rowMerge: rowMerge,
      isHeaderCell: isHeaderCell,
      borders: borders,
      paddingTop: paddingTop,
      paddingBottom: paddingBottom,
      paddingLeft: paddingLeft,
      paddingRight: paddingRight,
      gridSpan: gridSpan,
      vMerge: vMerge,
    );
  }
}

// ۵. مدل اسپن
class SpanData {
  final String type;
  final String content;
  final String? url;
  final int? imageWidth;
  final int? imageHeight;
  final List<String> markers;
  final List<TableRowData> tableRows;
  final List<SpanData> innerSpans;

  final String? fillColor;
  final String? textColor;

  // 🌟 ارتقاء: افزودن کادر مشترک به سطح متن
  final BorderDetail? borders;

  final String? tableStyleId;
  final String? tableStyleName;
  final String? tableAlignment;
  final String? hasBorders;
  final String? floatPosition;
  final double? tableWidthPercent;
  final double? borderWidth;

  SpanData({
    required this.type,
    this.content = '',
    this.url,
    this.imageWidth,
    this.imageHeight,
    required this.markers,
    this.tableRows = const [],
    this.innerSpans = const [],
    this.fillColor,
    this.textColor,
    this.borders, // کادر متنی
    this.tableStyleId,
    this.tableStyleName,
    this.tableAlignment,
    this.hasBorders,
    this.floatPosition,
    this.tableWidthPercent,
    this.borderWidth,
  });

  factory SpanData.fromJson(Map<String, dynamic> json) {
    var rowsList = json['TableRows'] as List? ?? [];
    var innerList = json['InnerSpans'] as List? ?? [];
    return SpanData(
      type: json['Type'] ?? 'text',
      content: json['Content'] ?? '',
      url: json['Url'],
      imageWidth: json['ImageWidth'] as int?,
      imageHeight: json['ImageHeight'] as int?,
      markers: List<String>.from(json['Markers'] ?? []),
      tableRows: rowsList.map((e) => TableRowData.fromJson(e)).toList(),
      innerSpans: innerList.map((e) => SpanData.fromJson(e)).toList(),
      fillColor: json['FillColor'],
      textColor: json['TextColor'],
      // 🌟 دریافت کادر متنی پارس شده از فایل JSON
      borders: json['Borders'] != null
          ? BorderDetail.fromJson(json['Borders'])
          : null,
      tableStyleId: json['TableStyleId'],
      tableStyleName: json['TableStyleName'],
      tableAlignment: json['TableAlignment'],
      hasBorders: json['HasBorders'],
      tableWidthPercent: (json['TableWidthPercent'] as num?)?.toDouble(),
      borderWidth: (json['BorderWidth'] as num?)?.toDouble(),
    );
  }

  // 🌟 برای بازنویسیِ فقط tableRows (وقتی پاراگراف‌های داخل سلول‌های جدول
  // هم باید دیکشنری مشترک‌شان تزریق شود) بدون کپی دستیِ مستعدِ خطای بقیه‌ی
  // فیلدها.
  SpanData copyWith({List<TableRowData>? tableRows}) {
    return SpanData(
      type: type,
      content: content,
      url: url,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      markers: markers,
      tableRows: tableRows ?? this.tableRows,
      innerSpans: innerSpans,
      fillColor: fillColor,
      textColor: textColor,
      borders: borders,
      tableStyleId: tableStyleId,
      tableStyleName: tableStyleName,
      tableAlignment: tableAlignment,
      hasBorders: hasBorders,
      floatPosition: floatPosition,
      tableWidthPercent: tableWidthPercent,
      borderWidth: borderWidth,
    );
  }
}
