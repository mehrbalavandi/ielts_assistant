import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';

// 🌟 قانون‌های ST-1 تا ST-6 (RULES-rendering.md): «مرورِ من» — واژه‌ها و
// متن‌ها/تمرین‌هایی که کاربر برای مرور نگه می‌دارد، با سطحِ اهمیت و یادداشت.
// هر مورد یک «عکس» از داده‌ی همان لحظه را نگه می‌دارد (ترجمه، تلفظ، گزیده‌ی متن)
// تا صفحه‌ی مرور بدونِ بازکردنِ کتاب هم کامل باشد.

/// نوعِ موردِ مرور. tip (ST-7) = نکته‌ی دستوری، نوشتاری، گفتاری، … بیرون از متنِ کتاب.
enum StudyKind {
  word,
  passage,
  tip;

  static StudyKind parse(Object? v) => StudyKind.values.firstWhere(
    (e) => e.name == v,
    orElse: () => StudyKind.passage,
  );
}

/// 🌟 ST-7: مورد از کجا آمده.
/// book = از متنِ کتاب؛ user = خودِ کاربر (دستی یا واردکردن از هوش مصنوعی)؛
/// admin = «مرورِ آماده»ِ سایت (خودکار).
enum StudySource {
  book('از کتاب', Icons.menu_book_rounded),
  user('خودم', Icons.person_rounded),
  admin('آماده', Icons.campaign_rounded);

  const StudySource(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 🌟 ST-7: جمله‌ی نمونه با ترجمه.
@immutable
class StudyExample {
  final String en;
  final String fa;
  final String ar;

  const StudyExample(this.en, {this.fa = '', this.ar = ''});

  Map<String, String> toJson() => {
    'en': en,
    if (fa.isNotEmpty) 'fa': fa,
    if (ar.isNotEmpty) 'ar': ar,
  };

  static StudyExample? fromJson(Object? raw) {
    if (raw is String) {
      return raw.trim().isEmpty ? null : StudyExample(raw.trim());
    }
    if (raw is! Map) return null;
    final String en = (raw['en'] ?? '').toString().trim();
    if (en.isEmpty) return null;
    return StudyExample(
      en,
      fa: (raw['fa'] ?? '').toString().trim(),
      ar: (raw['ar'] ?? '').toString().trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudyExample && other.en == en && other.fa == fa && other.ar == ar;

  @override
  int get hashCode => Object.hash(en, fa, ar);
}

/// سطحِ اهمیت (ST-2). عدد همان چیزی است که ذخیره می‌شود.
enum StudyImportance {
  normal(1, 'معمولی', Color(0xFF26A69A)),
  important(2, 'مهم', Color(0xFFFB8C00)),
  critical(3, 'خیلی مهم', Color(0xFFE53935));

  const StudyImportance(this.level, this.label, this.color);
  final int level;
  final String label;
  final Color color;

  static StudyImportance fromLevel(Object? v) => StudyImportance.values
      .firstWhere((e) => e.level == v, orElse: () => StudyImportance.important);
}

/// وضعیتِ یادگیریِ واژه (ST-3).
enum WordStatus {
  fresh('تازه', Icons.fiber_new_rounded),
  learning('در حالِ یادگیری', Icons.autorenew_rounded),
  known('بلدم', Icons.check_circle_rounded);

  const WordStatus(this.label, this.icon);
  final String label;
  final IconData icon;

  static WordStatus parse(Object? v) => WordStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => WordStatus.fresh,
  );
}

@immutable
class StudyItem {
  final String id;
  final StudyKind kind;
  final String bookId;
  final String bookTitle;

  /// جای متن در کتاب (برای «رفتن به متن»)؛ واژه‌ها جا ندارند.
  final int? pageNumber;
  final int? paraIndex;

  /// واژه: خودِ واژه. متن: گزیده‌ی متنِ پاراگراف (جای‌خالی‌ها «____»).
  final String text;

  // ── عکسِ ترجمه/دیکشنری ──
  final String translationFa;
  final String translationAr;
  final String pronounceFa;
  final String pronounceAr;
  final String explanationFa;
  final String explanationAr;
  final String cefrLevel;

  final StudyImportance importance;
  final WordStatus status;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── 🌟 ST-7: فیلدهای اضافه (ستونِ extra، کلیدِ «x» در JSON) ──
  final String pos;
  final String ipa;
  final List<StudyExample> examples;
  final List<String> tags;

  /// null = از روی bookId (کتاب یا خودم).
  final StudySource? _source;

  /// شناسه‌ی «مرورِ آماده» در سایت (فقط source=admin).
  final int? sharedId;

  /// منبعی که کاربر/ادمین نوشته (مثلاً «کانالِ …»).
  final String origin;

  const StudyItem({
    required this.id,
    required this.kind,
    required this.bookId,
    required this.bookTitle,
    this.pageNumber,
    this.paraIndex,
    required this.text,
    this.translationFa = '',
    this.translationAr = '',
    this.pronounceFa = '',
    this.pronounceAr = '',
    this.explanationFa = '',
    this.explanationAr = '',
    this.cefrLevel = '',
    this.importance = StudyImportance.important,
    this.status = WordStatus.fresh,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.pos = '',
    this.ipa = '',
    this.examples = const [],
    this.tags = const [],
    StudySource? source,
    this.sharedId,
    this.origin = '',
  }) : _source = source;

  StudySource get source =>
      _source ?? (bookId.isNotEmpty ? StudySource.book : StudySource.user);

  /// موردی که کاربر خودش ساخته و می‌تواند همه‌ی فیلدهایش را ویرایش کند.
  bool get editable => source == StudySource.user;

  /// شناسه‌ی واژه: خودِ واژه (کوچک‌شده)، مستقل از کتاب — یک واژه یک‌بار.
  static String wordId(String text) => 'w|${_norm(text)}';

  /// 🌟 ST-7: شناسه‌ی نکته: چکیده‌ی عنوان (کوچک‌شده) — یک نکته یک‌بار.
  static String tipId(String text) => 't|${_fnv1a(_norm(text))}';

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String idFor(StudyKind kind, String text) =>
      kind == StudyKind.tip ? tipId(text) : wordId(text);

  /// شناسه‌ی متن: کتاب + صفحه + پاراگرافِ سطحِ صفحه + چکیده‌ی متن (پاراگراف‌های داخلِ
  /// یک جدول همه یک اندیسِ پاراگراف دارند).
  static String passageId(
    String bookId,
    int pageNumber,
    int paraIndex,
    String excerpt,
  ) => 'p|$bookId|$pageNumber|$paraIndex|${_fnv1a(excerpt)}';

  factory StudyItem.fromWord(
    InteractiveWord w, {
    required String bookId,
    required String bookTitle,
  }) {
    final DateTime now = DateTime.now();
    return StudyItem(
      id: wordId(w.exactText),
      kind: StudyKind.word,
      bookId: bookId,
      bookTitle: bookTitle,
      text: w.exactText.trim(),
      translationFa: w.translationFa,
      translationAr: w.translationAr,
      pronounceFa: w.pronounceFa,
      pronounceAr: w.pronounceAr,
      explanationFa: w.explanationFa,
      explanationAr: w.explanationAr,
      cefrLevel: w.cefrLevel,
      createdAt: now,
      updatedAt: now,
      pos: w.pos,
      ipa: w.ipa,
    );
  }

  /// دوزبانه: زبانِ انتخابی، وگرنه زبانِ دیگر.
  String pick(String fa, String ar, {required bool arabic}) => arabic
      ? (ar.trim().isNotEmpty ? ar : fa)
      : (fa.trim().isNotEmpty ? fa : ar);

  StudyItem copyWith({
    StudyImportance? importance,
    WordStatus? status,
    String? note,
  }) => withContent(
    importance: importance,
    status: status,
    note: note,
    updatedAt: DateTime.now(),
  );

  /// 🌟 ST-7: نسخه‌ای با محتوای تازه (ویرایشِ موردِ خودم، به‌روزرسانیِ «مرورِ آماده»). فیلدی
  /// که داده نشود همان می‌ماند. updatedAt داده نشود ← همان قبلی.
  StudyItem withContent({
    String? text,
    String? translationFa,
    String? translationAr,
    String? pronounceFa,
    String? pronounceAr,
    String? explanationFa,
    String? explanationAr,
    String? cefrLevel,
    String? pos,
    String? ipa,
    List<StudyExample>? examples,
    List<String>? tags,
    String? origin,
    StudyImportance? importance,
    WordStatus? status,
    String? note,
    DateTime? updatedAt,
  }) => StudyItem(
    id: id,
    kind: kind,
    bookId: bookId,
    bookTitle: bookTitle,
    pageNumber: pageNumber,
    paraIndex: paraIndex,
    text: text ?? this.text,
    translationFa: translationFa ?? this.translationFa,
    translationAr: translationAr ?? this.translationAr,
    pronounceFa: pronounceFa ?? this.pronounceFa,
    pronounceAr: pronounceAr ?? this.pronounceAr,
    explanationFa: explanationFa ?? this.explanationFa,
    explanationAr: explanationAr ?? this.explanationAr,
    cefrLevel: cefrLevel ?? this.cefrLevel,
    importance: importance ?? this.importance,
    status: status ?? this.status,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pos: pos ?? this.pos,
    ipa: ipa ?? this.ipa,
    examples: examples ?? this.examples,
    tags: tags ?? this.tags,
    source: _source,
    sharedId: sharedId,
    origin: origin ?? this.origin,
  );

  /// 🌟 ST-7: فیلدهای اضافه به‌صورتِ Map (کلیدِ «x» در JSON؛ ستونِ extra در پایگاهِ داده).
  Map<String, dynamic> extraMap() => {
    if (pos.isNotEmpty) 'pos': pos,
    if (ipa.isNotEmpty) 'ipa': ipa,
    if (examples.isNotEmpty) 'ex': [for (final StudyExample e in examples) e.toJson()],
    if (tags.isNotEmpty) 'tags': tags,
    if (_source != null) 'src': _source.name,
    if (sharedId != null) 'sid': sharedId,
    if (origin.isNotEmpty) 'from': origin,
  };

  String get extraJson {
    final Map<String, dynamic> m = extraMap();
    return m.isEmpty ? '' : jsonEncode(m);
  }

  static Map<String, dynamic> decodeExtra(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final Object? m = jsonDecode(raw);
        if (m is Map) return Map<String, dynamic>.from(m);
      } catch (_) {}
    }
    return const {};
  }

  /// سازنده با فیلدهای اضافه از Map (ردیفِ پایگاهِ داده یا JSONِ سرور).
  StudyItem withExtra(Map<String, dynamic> x) => StudyItem(
    id: id,
    kind: kind,
    bookId: bookId,
    bookTitle: bookTitle,
    pageNumber: pageNumber,
    paraIndex: paraIndex,
    text: text,
    translationFa: translationFa,
    translationAr: translationAr,
    pronounceFa: pronounceFa,
    pronounceAr: pronounceAr,
    explanationFa: explanationFa,
    explanationAr: explanationAr,
    cefrLevel: cefrLevel,
    importance: importance,
    status: status,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pos: (x['pos'] ?? '').toString(),
    ipa: (x['ipa'] ?? '').toString(),
    examples: [
      for (final Object? e in (x['ex'] as List? ?? const []))
        ?StudyExample.fromJson(e),
    ],
    tags: [
      for (final Object? t in (x['tags'] as List? ?? const []))
        if (t != null && t.toString().trim().isNotEmpty) t.toString().trim(),
    ],
    source: switch (x['src']) {
      'user' => StudySource.user,
      'admin' => StudySource.admin,
      'book' => StudySource.book,
      _ => null,
    },
    sharedId: (x['sid'] as num?)?.toInt(),
    origin: (x['from'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'bookId': bookId,
    'bookTitle': bookTitle,
    if (pageNumber != null) 'page': pageNumber,
    if (paraIndex != null) 'para': paraIndex,
    'text': text,
    if (translationFa.isNotEmpty) 'tFa': translationFa,
    if (translationAr.isNotEmpty) 'tAr': translationAr,
    if (pronounceFa.isNotEmpty) 'pFa': pronounceFa,
    if (pronounceAr.isNotEmpty) 'pAr': pronounceAr,
    if (explanationFa.isNotEmpty) 'eFa': explanationFa,
    if (explanationAr.isNotEmpty) 'eAr': explanationAr,
    if (cefrLevel.isNotEmpty) 'cefr': cefrLevel,
    'imp': importance.level,
    if (kind == StudyKind.word) 'status': status.name,
    if (note.isNotEmpty) 'note': note,
    'created': createdAt.millisecondsSinceEpoch,
    'updated': updatedAt.millisecondsSinceEpoch,
    if (extraMap().isNotEmpty) 'x': extraMap(),
  };

  static StudyItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> j = Map<String, dynamic>.from(raw);
    final String? id = j['id'] as String?;
    final String? text = j['text'] as String?;
    if (id == null || text == null) return null;
    String s(String k) => (j[k] as String?) ?? '';
    DateTime t(String k) =>
        DateTime.fromMillisecondsSinceEpoch((j[k] as num?)?.toInt() ?? 0);
    return StudyItem(
      id: id,
      kind: StudyKind.parse(j['kind']),
      bookId: s('bookId'),
      bookTitle: s('bookTitle'),
      pageNumber: (j['page'] as num?)?.toInt(),
      paraIndex: (j['para'] as num?)?.toInt(),
      text: text,
      translationFa: s('tFa'),
      translationAr: s('tAr'),
      pronounceFa: s('pFa'),
      pronounceAr: s('pAr'),
      explanationFa: s('eFa'),
      explanationAr: s('eAr'),
      cefrLevel: s('cefr'),
      importance: StudyImportance.fromLevel(j['imp']),
      status: WordStatus.parse(j['status']),
      note: s('note'),
      createdAt: t('created'),
      updatedAt: t('updated'),
    ).withExtra(decodeExtra(j['x']));
  }
}

/// مشخصاتِ پاراگرافی از صفحه که می‌شود به مرور افزود (ST-4). از reading_canvas
/// به TranslatableContentWrapper داده می‌شود.
@immutable
class StudyPassageRef {
  final String bookId;
  final String bookTitle;
  final int pageNumber;
  final int paraIndex;
  final String excerpt;

  const StudyPassageRef({
    required this.bookId,
    required this.bookTitle,
    required this.pageNumber,
    required this.paraIndex,
    required this.excerpt,
  });

  String get id => StudyItem.passageId(bookId, pageNumber, paraIndex, excerpt);

  StudyItem toItem({String translationFa = '', String translationAr = ''}) {
    final DateTime now = DateTime.now();
    return StudyItem(
      id: id,
      kind: StudyKind.passage,
      bookId: bookId,
      bookTitle: bookTitle,
      pageNumber: pageNumber,
      paraIndex: paraIndex,
      text: excerpt,
      translationFa: translationFa,
      translationAr: translationAr,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// گزیده‌ی متنِ دیدنیِ پاراگراف: فقط اسپن‌های متنیِ خودش (نه جدول‌های داخلش)،
  /// شماره‌ی لیست در ابتدا، جوابِ جای‌خالی‌ها «____». null اگر متنِ واقعی ندارد.
  static String? excerptOf(ParagraphData para) {
    // هر پاراگراف یک‌بار حساب می‌شود (صفحه با هر اسکرول/تغییر دوباره ساخته می‌شود).
    final String? cached = _excerptCache[para];
    if (cached != null) return cached.isEmpty ? null : cached;
    final String? fresh = _computeExcerpt(para);
    _excerptCache[para] = fresh ?? '';
    return fresh;
  }

  static final Expando<String> _excerptCache = Expando<String>('studyExcerpt');

  static String? _computeExcerpt(ParagraphData para) {
    final StringBuffer sb = StringBuffer();
    final String marker = (para.listMarker ?? '').trim();
    if (marker.isNotEmpty) sb.write('$marker ');
    for (final SpanData span in para.spans) {
      if (span.type == 'text') sb.write(span.content);
    }
    final String text = sb
        .toString()
        .replaceAll(RegExp(r'\{blk\}.*?\{/blk\}', dotAll: true), '____')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // دست‌کم دو حرفِ لاتین (پاراگرافِ فقط‌شماره/فقط‌جای‌خالی به کار نمی‌آید).
    if (RegExp(r'[A-Za-z]').allMatches(text).length < 2) return null;
    return text;
  }
}

/// چکیده‌ی پایدارِ ۳۲ بیتی (FNV-1a) — String.hashCode بینِ اجراها تضمینی ندارد.
String _fnv1a(String s) {
  int h = 0x811c9dc5;
  for (final int c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}
