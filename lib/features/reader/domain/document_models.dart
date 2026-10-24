enum ParaAlign { left, center, right, justify }

enum ParaDir { ltr, rtl }

// ۱. مدل کلمات تعاملی
/// 🌟 W-1 (RULES-rendering.md): الگوی ترکیبیِ کلماتِ تعاملی که **فقط کلمه‌ی کامل** را
/// تطبیق می‌دهد. قبل و بعدِ هر تطبیق حرف یا رقمِ لاتین نباید باشد؛ پس «gain» دیگر وسطِ
/// «again» تعاملی نمی‌شود. همان مرزی است که اکسترکتور هنگامِ ساختنِ فهرستِ کلمات به کار
/// می‌برد (`(?<![A-Za-z0-9])…(?![A-Za-z0-9])` در ContentEnrichment.BuildInteractives).
/// کلمات به ترتیبِ طولِ نزولی می‌آیند تا در یک موقعیت، طولانی‌ترین ترکیب برنده شود؛ اگر
/// طولانی‌تر مرزِ کلمه را رد کند، RegExp خودش کوتاه‌تر را امتحان می‌کند. null یعنی فهرست
/// خالی است (الگوی خالی هر جایی را تطبیق می‌دهد).
RegExp? buildInteractivesPattern(Iterable<InteractiveWord> words) {
  final List<String> texts =
      words.map((w) => w.exactText).where((t) => t.isNotEmpty).toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (texts.isEmpty) return null;
  return RegExp(
    '(?<![A-Za-z0-9])(?:${texts.map(RegExp.escape).join('|')})(?![A-Za-z0-9])',
  );
}

class InteractiveWord {
  final String exactText;
  final String translationFa;
  final String translationAr;
  final String pronounceFa;
  final String pronounceAr;
  final String explanationFa;
  final String explanationAr;
  final String cefrLevel;
  // 🌟 W-3: فیلدهای تازه‌ی دیکشنریِ مشترک (اکسترکتورِ G-4). خالی = JSONِ قدیمی.
  final String ipa;
  final String pos;
  final String headword;
  final String lexiconId;

  InteractiveWord({
    required this.exactText,
    required this.translationFa,
    required this.translationAr,
    required this.pronounceFa,
    required this.pronounceAr,
    required this.explanationFa,
    required this.explanationAr,
    required this.cefrLevel,
    this.ipa = '',
    this.pos = '',
    this.headword = '',
    this.lexiconId = '',
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
      ipa: json['ipa'] ?? '',
      pos: json['pos'] ?? '',
      headword: json['headword'] ?? '',
      lexiconId: json['lexiconId'] ?? '',
    );
  }
}

// 🐞 برای اسکریپتِ صوتیِ همگام‌سازی‌شده: یک فایلِ صوتی = یک AudioScriptTrack؛
// AudioTrackName فقط یک‌بار این‌جا نوشته می‌شود (نه به‌ازای هر پاراگراف/اسپن
// مثلِ قبل)، و هر پاراگراف (مطابقِ یک پاراگرافِ واقعیِ Word) می‌تواند چند
// اسپن داشته باشد که هرکدام StartMs/EndMsِ خودشان را دارند.
// 🐞 یک وقوعِ لینکِ صوتیِ داخلِ متن — سطحِ کتاب، از قبل توسطِ ابزارِ C#
// محاسبه‌شده (AudioLinksIndex در index.json) تا فلاتر مجبور نباشد برای
// ساختنِ پلی‌لیستِ کتاب، محتوای *همه‌ی* صفحات را زنده اسکن کند.
/// 🌟 یک گره از فهرستِ ساختاریِ کتاب (index.json ← Outline).
///
/// اکسترکتور آن را از «سطحِ ساختارِ» Word (Outline Level) می‌سازد — قانونِ O-4ِ
/// RULES-extraction.md. هیچ اسمِ خاصی (Unit، مهارت، فصل) این‌جا فرض نشده: سطحِ ۱
/// هرچه باشد در منوی کشویی، و سطحِ ۲ در دکمه‌ها می‌آید (قانونِ N-1ِ
/// RULES-rendering.md).
class OutlineEntry {
  final String title;
  final int level; // یک‌مبنا: ۱ = بالاترین
  final int pageNumber;
  final int paraIndex; // اندیسِ پاراگرافِ بیرونیِ صفحه (مثلِ AudioLinkEntry)
  final bool atPageTop; // true ⇒ پرش به بالای صفحه؛ false ⇒ به خودِ پاراگراف
  final List<OutlineEntry> children;

  const OutlineEntry({
    required this.title,
    required this.level,
    required this.pageNumber,
    required this.paraIndex,
    this.atPageTop = false,
    this.children = const [],
  });

  factory OutlineEntry.fromJson(Map<String, dynamic> json) {
    return OutlineEntry(
      title: (json['Title'] as String? ?? '').trim(),
      level: (json['Level'] as num?)?.toInt() ?? 1,
      pageNumber: (json['PageNumber'] as num?)?.toInt() ?? 0,
      paraIndex: (json['ParaIndex'] as num?)?.toInt() ?? 0,
      atPageTop: json['AtPageTop'] == true,
      children: ((json['Children'] as List?) ?? const [])
          .map((e) => OutlineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 🌟 جای یک نقطه از کتاب در فهرست (Outline): اندیسِ عنوانِ سطحِ ۱ (درس) و اندیسِ فرزندِ آن
/// (مهارت) که این نقطه زیرشان است؛ -1 = پیش از اولین عنوان / بی‌مهارت. فهرست به ترتیبِ صفحه است.
/// (S-15 در فهرستِ جستجو، AU-5 دامنه‌ی تکرارِ پلیر، AU-7 پلی‌لیست.)
({int unit, int section}) outlineIndicesAt(
  List<OutlineEntry> outline,
  int pageNumber,
  int paraIndex,
) {
  bool covers(OutlineEntry e) =>
      e.pageNumber < pageNumber ||
      (e.pageNumber == pageNumber && (e.atPageTop || e.paraIndex <= paraIndex));
  int unit = -1;
  for (int i = 0; i < outline.length; i++) {
    if (!covers(outline[i])) break;
    unit = i;
  }
  int section = -1;
  if (unit >= 0) {
    final List<OutlineEntry> kids = outline[unit].children;
    for (int i = 0; i < kids.length; i++) {
      if (!covers(kids[i])) break;
      section = i;
    }
  }
  return (unit: unit, section: section);
}

/// 🌟 N-12: بخشِ «Sample»ِ index.jsonِ نسخه‌ی نمونه (قانونِ SM-5ِ اکسترکتور): نمونه کدام
/// Unit است و کلِ کتاب از کدام صفحه تا کدام صفحه است. index.jsonِ نمونه فقط صفحه‌های همان
/// Unit را دارد، ولی Outlineِ کامل را — پس ناوبر همه‌ی Unitها را نشان می‌دهد و برای بقیه
/// پیامِ «خریداری نشده» می‌دهد.
class SampleInfo {
  final String title;
  final int firstPage;
  final int lastPage;
  final int bookFirstPage;
  final int bookLastPage;

  const SampleInfo({
    required this.title,
    required this.firstPage,
    required this.lastPage,
    required this.bookFirstPage,
    required this.bookLastPage,
  });

  static SampleInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    int n(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    final int first = n(json['FirstPage'], 0);
    final int last = n(json['LastPage'], first);
    return SampleInfo(
      title: (json['Title'] ?? '').toString().trim(),
      firstPage: first,
      lastPage: last,
      bookFirstPage: n(json['BookFirstPage'], first),
      bookLastPage: n(json['BookLastPage'], last),
    );
  }

  /// این شماره‌ی صفحه جزءِ کتاب هست ولی جزءِ نمونه نیست.
  bool isLockedPage(int pageNumber) =>
      pageNumber >= bookFirstPage &&
      pageNumber <= bookLastPage &&
      (pageNumber < firstPage || pageNumber > lastPage);
}

class AudioLinkEntry {
  final int pageNumber;
  final int paraIndex;
  final String fileName;

  AudioLinkEntry({
    required this.pageNumber,
    required this.paraIndex,
    required this.fileName,
  });

  factory AudioLinkEntry.fromJson(Map<String, dynamic> json) {
    return AudioLinkEntry(
      pageNumber: (json['PageNumber'] as num?)?.toInt() ?? 0,
      paraIndex: (json['ParaIndex'] as num?)?.toInt() ?? 0,
      fileName: json['FileName'] ?? '',
    );
  }
}

// 🐞 برای فیلدِ جدیدِ «AudioScripts» در index.json: حالا فقط یک اشاره‌گر
// است (مثلِ Pages)، نه محتوای کاملِ پاراگراف‌ها — چون پاراگراف‌های
// اسکریپتِ صوتی هم باید مثلِ صفحاتِ سندِ اصلی به‌صورتِ page-like نوشته
// شوند (در پوشه‌ی audio_scripts/، نه pages/) تا پایپلاینِ ترجمه‌ی
// هوش‌مصنوعی آن‌ها را هم پردازش کند. AudioScriptTrackِ کامل (با
// paragraphs) با خواندنِ فایلِ اشاره‌شده ساخته می‌شود، نه مستقیم از رویِ
// index.json.
class AudioScriptTrackPointer {
  final String audioTrackName;
  final String file;

  AudioScriptTrackPointer({required this.audioTrackName, required this.file});

  factory AudioScriptTrackPointer.fromJson(Map<String, dynamic> json) {
    return AudioScriptTrackPointer(
      audioTrackName: json['AudioTrackName'] ?? '',
      file: json['File'] ?? '',
    );
  }
}

class AudioScriptTrack {
  final String audioTrackName;
  final List<ParagraphData> paragraphs;

  AudioScriptTrack({required this.audioTrackName, required this.paragraphs});

  factory AudioScriptTrack.fromJson(Map<String, dynamic> json) {
    final rawParagraphs = json['Paragraphs'] as List? ?? [];
    return AudioScriptTrack(
      audioTrackName: json['AudioTrackName'] ?? '',
      paragraphs: rawParagraphs
          .map((e) => ParagraphData.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  // 🌟 TR-5 (G-8ِ اکسترکتور): ترجمه‌ی پاسخِ هر جای خالی، به ترتیبِ {blk}ها در متنِ
  // پاراگراف. رشته‌ی خالی = آن پاسخ ترجمه ندارد. null = داده‌ای نیست.
  final List<String>? blanksFa;
  final List<String>? blanksAr;
  final List<InteractiveWord> interactives;
  // 🌟 لیست‌ها (numbering که در C# به مارکر آماده تبدیل شده)
  final String? listType; // "ordered" | "bullet"  (null اگر لیست نباشد)
  final int listLevel; // 0 = سطح اول
  final String? listMarker; // متن نهایی مارکر: "1." , "a)" , "•"
  // 🐞 شماره‌ی لیست بولد است؟ (از rPr سطحِ numbering در C#). null/false = عادی.
  final bool listMarkerBold;
  final String? listMarkerColor; // 🐞 رنگِ نشانگرِ خودکارِ لیست (هگز بدونِ #)
  // 🐞 پس‌زمینه و کادرِ دورِ شماره (قاعده‌ی Word: سطحِ numbering ← نشانه‌ی پایانِ
  // پاراگراف ← استایلِ کاراکتریِ آن). null یعنی بدونِ پس‌زمینه/کادر.
  final String? listMarkerFill;
  final BorderDetail? listMarkerBorder;
  // 🐞 هندسه‌ی شماره مثلِ Word (تورفتگیِ درستِ متنِ خطِ اول):
  final double? listMarkerSize; // اندازه‌ی فونتِ شماره (pt)؛ null = از اولین اسپن
  final double? listMarkerScale; // فشردگیِ افقی (w:w)؛ null = ۱
  final String? listMarkerAlign; // "right" | "center"؛ null = left
  final String? listSuffix; // "space" | "nothing"؛ null = tab
  // 🌟 AS-7 (A-4ِ اکسترکتور): فقط در اسکریپتِ صوتی — بازه‌ی شماره‌ی خودکارِ لیست (وقتی گوینده
  // «One.» را می‌گوید). مثلِ متنِ گفته‌نشده: هایلایت نمی‌شود، بند در این بازه فعال است و لمسِ
  // شماره پلیر را به listMarkerEndMs (شروعِ سطر) می‌برد. null = سندِ بی‌مارکرِ سرِ بند.
  final int? listMarkerStartMs;
  final int? listMarkerEndMs;
  final double? listTabStop; // فاصله‌ی tab stopهای پیش‌فرض (pt)؛ null = ۳۶
  // 🐞 BlankWord3: شماره‌ی لیست بیرونِ {blk} دیده شود و فقط متن مخفی شود.
  final bool keepListMarkerVisible;
  final double? lineSpacing; // 🌟 ضریبِ فاصله‌ی خطوط (1.0 = تک، 1.5، ...)
  // 🌟 B-8 (T-25): این پاراگراف یک جدولِ سطحِ صفحه است و فاصله‌ی بالایش (spaceBefore)
  // از خودِ سند آمده (پاراگراف‌های خالیِ فاصله‌اندازِ Word)؛ پس رندرکننده حاشیه‌ی
  // پیش‌فرضِ ۱۲px بالا/پایینِ جدول را اضافه نمی‌کند. false = JSONِ قدیمی.
  final bool tableSpacingFromDoc;

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
    this.blanksFa,
    this.blanksAr,
    required this.interactives,
    this.listType, // 🌟
    this.listLevel = 0, // 🌟
    this.listMarker, // 🌟
    this.listMarkerBold = false, // 🐞
    this.listMarkerColor, // 🐞
    this.listMarkerFill, // 🐞
    this.listMarkerBorder, // 🐞
    this.listMarkerSize, // 🐞
    this.listMarkerScale, // 🐞
    this.listMarkerAlign, // 🐞
    this.listSuffix, // 🐞
    this.listMarkerStartMs, // 🌟 AS-7
    this.listMarkerEndMs,
    this.listTabStop, // 🐞
    this.keepListMarkerVisible = false, // 🐞
    this.lineSpacing, // 🌟
    this.tableSpacingFromDoc = false,
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
      blanksFa: (json['blanksFa'] as List?)?.map((e) => '${e ?? ''}').toList(),
      blanksAr: (json['blanksAr'] as List?)?.map((e) => '${e ?? ''}').toList(),
      interactives: interactivesList
          .map((e) => InteractiveWord.fromJson(e))
          .toList(),
      spans: spansList.map((e) => SpanData.fromJson(e)).toList(),
      lineSpacing: (json['LineSpacing'] as num?)?.toDouble(), // 🌟
      listType: json['ListType'], // 🌟
      listLevel: json['ListLevel'] ?? 0, // 🌟
      listMarker: json['ListMarker'], // 🌟
      listMarkerBold:
          json['ListMarkerBold'] == true, // 🐞 (null یا نبود = false)
      listMarkerColor: json['ListMarkerColor'], // 🐞
      listMarkerFill: json['ListMarkerFill'], // 🐞
      listMarkerBorder: json['ListMarkerBorder'] != null
          ? BorderDetail.fromJson(json['ListMarkerBorder']) // 🐞
          : null,
      listMarkerSize: (json['ListMarkerSize'] as num?)?.toDouble(), // 🐞
      listMarkerScale: (json['ListMarkerScale'] as num?)?.toDouble(), // 🐞
      listMarkerAlign: json['ListMarkerAlign'], // 🐞
      listSuffix: json['ListSuffix'], // 🐞
      listMarkerStartMs: (json['ListMarkerStartMs'] as num?)?.toInt(), // 🌟 AS-7
      listMarkerEndMs: (json['ListMarkerEndMs'] as num?)?.toInt(),
      listTabStop: (json['ListTabStop'] as num?)?.toDouble(), // 🐞
      keepListMarkerVisible: json['KeepListMarkerVisible'] == true, // 🐞
      tableSpacingFromDoc: json['TableSpacingFromDoc'] == true,
    );
  }

  // 🌟 برای جایگزینی «فقط» فیلد(های) مشخص بدون بازنویسی دستی و مستعدِ خطای
  // بقیه‌ی فیلدها؛ DocumentLoader از این برای تزریق زیرمجموعه‌ی مرتبط از
  // دیکشنری مشترک (ساختار جدید data.json) استفاده می‌کند.
  ParagraphData copyWith({
    List<SpanData>? spans,
    List<InteractiveWord>? interactives,
    double? indentLeft, // 🌟 برای حذفِ تورفتگیِ پایه‌ی جواب در مودال
    // 🌟 RM-2: حالتِ «خوانا» فاصله‌ها و اندازه‌ها را عوض می‌کند
    double? indentRight,
    double? indentFirstLine,
    double? spaceBefore,
    double? spaceAfter,
    double? lineSpacing,
    double? listMarkerSize,
  }) {
    return ParagraphData(
      spans: spans ?? this.spans,
      direction: direction,
      alignment: alignment,
      fillColor: fillColor,
      borders: borders,
      spaceBefore: spaceBefore ?? this.spaceBefore,
      spaceAfter: spaceAfter ?? this.spaceAfter,
      indentLeft: indentLeft ?? this.indentLeft,
      indentRight: indentRight ?? this.indentRight,
      indentFirstLine: indentFirstLine ?? this.indentFirstLine,
      startMs: startMs,
      endMs: endMs,
      audioTrackName: audioTrackName,
      translationFa: translationFa,
      translationAr: translationAr,
      blanksFa: blanksFa,
      blanksAr: blanksAr,
      interactives: interactives ?? this.interactives,
      lineSpacing: lineSpacing ?? this.lineSpacing, // 🌟
      listType: listType, // 🌟
      listLevel: listLevel, // 🌟
      listMarker: listMarker, // 🌟
      listMarkerBold: listMarkerBold, // 🐞
      listMarkerColor: listMarkerColor, // 🐞
      listMarkerFill: listMarkerFill, // 🐞
      listMarkerBorder: listMarkerBorder, // 🐞
      listMarkerSize: listMarkerSize ?? this.listMarkerSize, // 🐞
      listMarkerScale: listMarkerScale, // 🐞
      listMarkerAlign: listMarkerAlign, // 🐞
      listSuffix: listSuffix, // 🐞
      listMarkerStartMs: listMarkerStartMs, // 🌟 AS-7
      listMarkerEndMs: listMarkerEndMs,
      listTabStop: listTabStop, // 🐞
      keepListMarkerVisible: keepListMarkerVisible, // 🐞
      tableSpacingFromDoc: tableSpacingFromDoc,
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
      pattern = buildInteractivesPattern(nonEmptyWords); // W-1: کلمه‌ی کامل
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
  final double? widthPt; // 🐞 CommonTable: عرضِ مطلقِ سلول به point (=px منطقی)
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
    this.widthPt,
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
      widthPt: json['WidthPt']?.toDouble(),
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

  TableCellData copyWith({List<ParagraphData>? paragraphs, double? widthPt}) {
    return TableCellData(
      widthPercent: widthPercent,
      widthPt: widthPt ?? this.widthPt,
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
  // 🌟 محتوای غنیِ جای‌خالی (مودالِ آیکونِ چشم): پاراگراف‌های اصلیِ سند با همه‌ی
  // جزئیات — جدول، عکس، لیست، رنگ — وقتی جوابِ مخفی چیزی جز متن هم دارد.
  // null یعنی جای‌خالیِ فقط‌متنی (رفتارِ قبلیِ مودال با innerSpans).
  final List<ParagraphData>? hiddenParagraphs;

  final String? fillColor;
  final String? textColor;

  // 🌟 جزئیاتِ زیرخط از سند ورد. مارکرِ "u" فقط می‌گوید زیرخط هست؛ این سه
  // می‌گویند چه‌جور زیرخطی. نگاشتِ مقادیرِ ورد در سی‌شارپ انجام شده، پس
  // مقدارها همان واژگانِ فلاتر هستند: solid/double/dotted/dashed/wavy.
  // همه nullable — کتاب‌های قبلاً استخراج‌شده این فیلدها را ندارند و باید
  // مثلِ قبل، زیرخطِ ساده‌ی هم‌رنگِ متن بگیرند.
  // 🌟 فاصله‌ی بینِ حروف از ورد (w:spacing در rPr)، به پوینت. null یعنی عادی.
  final double? letterSpacing;

  final String? underlineStyle;
  final double? underlineThickness;
  final String? underlineColor;

  // 🌟 ارتقاء: افزودن کادر مشترک به سطح متن
  final BorderDetail? borders;

  final String? tableStyleId;
  final String? tableStyleName;
  final String? tableAlignment;
  final String? hasBorders;
  final String? floatPosition;
  final double? tableWidthPercent;
  final double? borderWidth;
  final String?
  responsiveStrategy; // "horizontalScroll" | "collapseToCards" | "stack"
  final String? layoutDirection;
  final String? layoutReflow;
  // 🐞 مدلِ صریح و توسعه‌پذیرِ نمایشِ جدول — طرفِ سی‌شارپِ همین فیلدها
  // (Responsivelowering.cs). اگر خالی/null باشند یعنی این کتاب هنوز با
  // ابزارِ جدید استخراج نشده؛ رندرِ جدول به رفتارِ قدیمیِ مبتنی‌بر نامِ
  // استایل رجوع می‌کند.
  final String?
  borderMode; // "all" | "outer" | "inner" | "none" | "firstRowOuter"
  final String? widthMode; // "content" | "equal" | "proportional" | "fill"
  // 🐞 برای هایلایتِ همگام‌سازی‌شده در سطحِ اسپن (کلمه‌به‌کلمه یا هر
  // دانه‌بندیِ دیگری که در سندِ Word با مارکرهای [میلی‌ثانیه] بین کلمات
  // مشخص شده باشد) — از AudioScripts (نه محتوای معمولیِ صفحات) می‌آید.
  final int? startMs;
  final int? endMs;
  // 🌟 AS-5 (A-2ِ اکسترکتور): در فایلِ صوتی خوانده نمی‌شود (برچسبِ گوینده، استایلِ
  // NotSpoken). زمانش هست ولی هیچ‌وقت هایلایت نمی‌شود.
  final bool unspoken;

  SpanData({
    required this.type,
    this.content = '',
    this.url,
    this.imageWidth,
    this.imageHeight,
    required this.markers,
    this.tableRows = const [],
    this.innerSpans = const [],
    this.hiddenParagraphs,
    this.fillColor,
    this.textColor,
    this.letterSpacing,
    this.underlineStyle,
    this.underlineThickness,
    this.underlineColor,
    this.borders, // کادر متنی
    this.tableStyleId,
    this.tableStyleName,
    this.tableAlignment,
    this.hasBorders,
    this.floatPosition,
    this.tableWidthPercent,
    this.borderWidth,
    this.responsiveStrategy,
    this.layoutDirection,
    this.layoutReflow,
    this.borderMode,
    this.widthMode,
    this.startMs,
    this.endMs,
    this.unspoken = false,
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
      hiddenParagraphs: (json['HiddenParagraphs'] as List?)
          ?.map((e) => ParagraphData.fromJson(e as Map<String, dynamic>))
          .toList(),
      fillColor: json['FillColor'],
      textColor: json['TextColor'],
      letterSpacing: (json['LetterSpacing'] as num?)?.toDouble(),
      underlineStyle: json['UnderlineStyle'],
      underlineThickness: (json['UnderlineThickness'] as num?)?.toDouble(),
      underlineColor: json['UnderlineColor'],
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
      responsiveStrategy: json['ResponsiveStrategy'],
      layoutDirection: json['LayoutDirection'],
      layoutReflow: json['LayoutReflow'],
      borderMode: json['BorderMode'],
      widthMode: json['WidthMode'],
      startMs: json['StartMs'] as int?,
      endMs: json['EndMs'] as int?,
      unspoken: json['Unspoken'] == true,
    );
  }

  // 🌟 برای بازنویسیِ فقط tableRows (وقتی پاراگراف‌های داخل سلول‌های جدول
  // هم باید دیکشنری مشترک‌شان تزریق شود) بدون کپی دستیِ مستعدِ خطای بقیه‌ی
  // فیلدها.
  SpanData copyWith({
    List<TableRowData>? tableRows,
    List<ParagraphData>? hiddenParagraphs,
    // 🌟 RM-2: حالتِ «خوانا»
    List<String>? markers,
    List<SpanData>? innerSpans,
    String? responsiveStrategy,
  }) {
    return SpanData(
      hiddenParagraphs: hiddenParagraphs ?? this.hiddenParagraphs,
      type: type,
      content: content,
      url: url,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      markers: markers ?? this.markers,
      tableRows: tableRows ?? this.tableRows,
      innerSpans: innerSpans ?? this.innerSpans,
      fillColor: fillColor,
      textColor: textColor,
      letterSpacing: letterSpacing,
      underlineStyle: underlineStyle,
      underlineThickness: underlineThickness,
      underlineColor: underlineColor,
      borders: borders,
      tableStyleId: tableStyleId,
      tableStyleName: tableStyleName,
      tableAlignment: tableAlignment,
      hasBorders: hasBorders,
      floatPosition: floatPosition,
      tableWidthPercent: tableWidthPercent,
      borderWidth: borderWidth,
      responsiveStrategy: responsiveStrategy ?? this.responsiveStrategy,
      layoutDirection: layoutDirection,
      layoutReflow: layoutReflow,
      borderMode: borderMode,
      widthMode: widthMode,
      startMs: startMs,
      endMs: endMs,
      unspoken: unspoken,
    );
  }
}
