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
class ParagraphData {
  final List<SpanData> spans;
  final String direction;
  final String alignment;
  final String? fillColor;

  // --- فیلدهای حاشیه ---
  final String? hasBorders;
  final String? borderColor;
  final String? borderStyle;

  // 🌟 فیلدهای جدید برای استخراج فاصله‌های واقعی از ورد
  final double spaceBefore;
  final double spaceAfter;

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
    this.spaceBefore = 0.0, // مقدار پیش‌فرض
    this.spaceAfter = 0.0, // مقدار پیش‌فرض
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
      // 🌟 دریافت مقادیر فواصل به صورت ایمن
      spaceBefore: (json['SpaceBefore'] as num?)?.toDouble() ?? 0.0,
      spaceAfter: (json['SpaceAfter'] as num?)?.toDouble() ?? 0.0,
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

  PageData({required this.pageNumber, required this.paragraphs});

  factory PageData.fromJson(Map<String, dynamic> json) {
    var parasList = json['Paragraphs'] as List? ?? [];
    return PageData(
      pageNumber: json['PageNumber'] ?? 1,
      paragraphs: parasList.map((e) => ParagraphData.fromJson(e)).toList(),
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

class TableCellData {
  final double? widthPercent;
  final List<ParagraphData> paragraphs;
  final String? fillColor;
  final String? vAlign;
  final int? colSpan;
  final String? rowMerge;
  final bool isHeaderCell;

  TableCellData({
    this.widthPercent,
    required this.paragraphs,
    this.fillColor,
    this.vAlign,
    this.colSpan,
    this.rowMerge,
    this.isHeaderCell = false,
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
    return SpanData(
      type: json['Type'] ?? 'text',
      content: json['Content'] ?? '',
      url: json['Url'],
      markers: List<String>.from(json['Markers'] ?? []),
      tableRows: rowsList.map((e) => TableRowData.fromJson(e)).toList(),
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
