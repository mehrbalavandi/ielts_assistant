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

// ۲. مدل پاراگراف (غنی شده با هوش مصنوعی)
class ParagraphData {
  final List<SpanData> spans;
  final String direction;
  final String alignment;
  // --- فیلدهای اضافه شده توسط AI ---
  final String? translationFa;
  final String? translationAr;
  final List<InteractiveWord> interactives;

  ParagraphData({
    required this.spans,
    this.direction = "LTR",
    this.alignment = "L",
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
      translationFa: json['translationFa'],
      translationAr: json['translationAr'],
      interactives: interactivesList
          .map((e) => InteractiveWord.fromJson(e))
          .toList(),
      spans: spansList.map((e) => SpanData.fromJson(e)).toList(),
    );
  }
}

// ۱. مدل صفحه
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

// ۲. مدل‌های مربوط به جدول
class TableRowData {
  final List<TableCellData> cells;
  TableRowData({required this.cells});

  factory TableRowData.fromJson(Map<String, dynamic> json) {
    var cellsList = json['Cells'] as List? ?? [];
    return TableRowData(
      cells: cellsList.map((e) => TableCellData.fromJson(e)).toList(),
    );
  }
}

class TableCellData {
  final double? widthPercent;
  final List<ParagraphData> paragraphs; // پاراگراف‌های تودرتو داخل سلول

  TableCellData({this.widthPercent, required this.paragraphs});

  factory TableCellData.fromJson(Map<String, dynamic> json) {
    var parasList = json['Paragraphs'] as List? ?? [];
    return TableCellData(
      widthPercent: json['WidthPercent']?.toDouble(),
      paragraphs: parasList.map((e) => ParagraphData.fromJson(e)).toList(),
    );
  }
}

// ۳. به‌روزرسانی اسپن برای پشتیبانی از TableRows
class SpanData {
  final String type;
  final String content;
  final String? url; // <--- فیلد جدید
  final List<String> markers;
  final List<TableRowData> tableRows; // اضافه شدن فیلد سطرهای جدول

  SpanData({
    required this.type,
    this.content = '',
    this.url,
    required this.markers,
    this.tableRows = const [],
  });

  factory SpanData.fromJson(Map<String, dynamic> json) {
    var rowsList = json['TableRows'] as List? ?? [];
    return SpanData(
      type: json['Type'] ?? 'text',
      content: json['Content'] ?? '',
      url: json['Url'], // <--- خواندن از مپ
      markers: List<String>.from(json['Markers'] ?? []),
      tableRows: rowsList.map((e) => TableRowData.fromJson(e)).toList(),
    );
  }
}
