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

// ۲. مدل پاراگراف (غنی شده با هوش مصنوعی و Shading)
// ۲. مدل پاراگراف (غنی شده با هوش مصنوعی و Shading)
// ۲. مدل پاراگراف (غنی شده با هوش مصنوعی و Shading)
class ParagraphData {
  final List<SpanData> spans;
  final String direction;
  final String alignment;
  final String? fillColor;

  // --- فیلدهای حاشیه ---
  final String? hasBorders;
  final String? borderColor;
  final String? borderStyle;

  final double spaceBefore;
  final double spaceAfter;
  final double? indentLeft;
  final double? indentRight;
  final double? indentFirstLine;

  // 🌟 فیلدهای زمان‌بندی صوتی و نام فایل (Karaoke)
  final int? startMs;
  final int? endMs;
  final String? audioTrackName; // 🌟 این خط باعث رفع خطای شما می‌شود

  final String? translationFa;
  final String? translationAr;
  final List<InteractiveWord> interactives;

  ParagraphData({
    required this.spans,
    this.direction = "LTR",
    this.alignment = "L",
    this.fillColor,
    this.hasBorders,
    this.borderColor,
    this.borderStyle,
    this.spaceBefore = 0.0,
    this.spaceAfter = 0.0,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.startMs,
    this.endMs,
    this.audioTrackName, // 🌟 اضافه شد
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
      hasBorders: json['HasBorders'],
      borderColor: json['BorderColor'],
      borderStyle: json['BorderStyle'],
      spaceBefore: (json['SpaceBefore'] as num?)?.toDouble() ?? 0.0,
      spaceAfter: (json['SpaceAfter'] as num?)?.toDouble() ?? 0.0,
      indentLeft: json['IndentLeft']?.toDouble(),
      indentRight: json['IndentRight']?.toDouble(),
      indentFirstLine: json['IndentFirstLine']?.toDouble(),
      startMs: json['StartMs'] as int?,
      endMs: json['EndMs'] as int?,
      audioTrackName: json['AudioTrackName'] as String?, // 🌟 مپ کردن از JSON
      translationFa: json['translationFa'],
      translationAr: json['translationAr'],
      interactives: interactivesList
          .map((e) => InteractiveWord.fromJson(e))
          .toList(),
      spans: spansList.map((e) => SpanData.fromJson(e)).toList(),
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

  factory PageData.fromJson(Map<String, dynamic> json) {
    var interactivesList = json['Interactives'] as List? ?? [];
    var parasList = json['Paragraphs'] as List? ?? [];

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
}

class BorderDetail {
  final double? width;
  final String? color;
  final String? val;

  BorderDetail({this.width, this.color, this.val});

  factory BorderDetail.fromJson(Map<String, dynamic> json) {
    return BorderDetail(
      width: json['Width']?.toDouble(),
      color: json['Color'],
      val: json['Val'],
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
      top: json['Top'] != null ? BorderDetail.fromJson(json['Top']) : null,
      bottom: json['Bottom'] != null
          ? BorderDetail.fromJson(json['Bottom'])
          : null,
      left: json['Left'] != null ? BorderDetail.fromJson(json['Left']) : null,
      right: json['Right'] != null
          ? BorderDetail.fromJson(json['Right'])
          : null,
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
    );
  }
}

// ۵. مدل اسپن
class SpanData {
  final String type;
  final String content;
  final String? url;
  final List<String> markers;
  final List<TableRowData> tableRows;
  final List<SpanData> innerSpans; // 🌟 اضافه شد برای استایل‌های داخل جای‌خالی

  // فیلدهای استایل متن و جدول
  final String? fillColor;
  final String? textColor;
  final String? borderColor;
  final String? borderStyle;
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
    required this.markers,
    this.tableRows = const [],
    this.innerSpans = const [], // 🌟 مقدار اولیه
    this.fillColor,
    this.textColor,
    this.borderColor,
    this.borderStyle,
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
    var innerList = json['InnerSpans'] as List? ?? []; // 🌟 استخراج از JSON
    return SpanData(
      type: json['Type'] ?? 'text',
      content: json['Content'] ?? '',
      url: json['Url'],
      markers: List<String>.from(json['Markers'] ?? []),
      tableRows: rowsList.map((e) => TableRowData.fromJson(e)).toList(),
      innerSpans: innerList
          .map((e) => SpanData.fromJson(e))
          .toList(), // 🌟 مپ کردن
      fillColor: json['FillColor'],
      textColor: json['TextColor'],
      borderColor: json['BorderColor'],
      borderStyle: json['BorderStyle'],
      tableStyleId: json['TableStyleId'],
      tableStyleName: json['TableStyleName'],
      tableAlignment: json['TableAlignment'],
      hasBorders: json['HasBorders'],
      tableWidthPercent: (json['TableWidthPercent'] as num?)?.toDouble(),
      borderWidth: (json['BorderWidth'] as num?)?.toDouble(),
    );
  }
}
