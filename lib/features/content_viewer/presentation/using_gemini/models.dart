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
  final String? fillColor; // <--- فیلد جدید: پس‌زمینه کل پاراگراف

  // --- فیلدهای اضافه شده توسط AI ---
  final String? translationFa;
  final String? translationAr;
  final List<InteractiveWord> interactives;

  ParagraphData({
    required this.spans,
    this.direction = "LTR",
    this.alignment = "L",
    this.fillColor,
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
  final bool isHeader; // <--- فیلد جدید
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
  final String? fillColor; // <--- رنگ اختصاصی سلول
  final String? vAlign; // <--- تراز عمودی
  final int? colSpan; // <--- ادغام ستون
  final String? rowMerge; // <--- وضعیت ادغام سطر
  final bool isHeaderCell; // <--- هدر بودن سلول

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
  final String? borderColor;
  final String? borderStyle;
  final String? tableStyleId;
  final String? tableStyleName;
  final String? tableAlignment;
  final String? hasBorders;

  SpanData({
    required this.type,
    this.content = '',
    this.url,
    required this.markers,
    this.tableRows = const [],
    this.fillColor,
    this.borderColor,
    this.borderStyle,
    this.tableStyleId,
    this.tableStyleName,
    this.tableAlignment,
    this.hasBorders,
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
      borderColor: json['BorderColor'],
      borderStyle: json['BorderStyle'],
      tableStyleId: json['TableStyleId'],
      tableStyleName: json['TableStyleName'],
      tableAlignment: json['TableAlignment'],
      hasBorders: json['HasBorders'],
    );
  }
}
