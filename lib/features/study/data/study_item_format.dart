import 'dart:convert';

import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🌟 ST-7: قالبِ یکسانِ «موردِ مرور» برای واژه‌ها و نکته‌های بیرون از کتاب‌ها.
//
// همان قالبی که پرامپتِ هوش مصنوعی (studyItemsPrompt) تولید می‌کند، پنلِ ادمین («مرورِ
// آماده») می‌خواند و سرور در GET /api/study/shared می‌فرستد. همتای سروری:
// App\Support\StudyItemFormat (لاراول) — هر تغییری هر دو جا. سند: STUDY-ITEMS.md.
//
//   {"format":"ielts-study-items","version":1,"items":[{...}, ...]}
//
// هر مورد: type (word|tip)، text، pos، ipa، cefr، meaningFa/Ar، pronounceFa/Ar،
// explanationFa/Ar، examples [{en,fa,ar}]، tags []، importance (1..3)، source.

class StudyImportResult {
  final List<StudyItem> items;
  final List<String> errors;

  const StudyImportResult(this.items, this.errors);
}

class StudyItemFormat {
  StudyItemFormat._();

  static const String format = 'ielts-study-items';

  static const Map<String, StudyKind> _typeAliases = {
    'word': StudyKind.word,
    'phrase': StudyKind.word,
    'idiom': StudyKind.word,
    'collocation': StudyKind.word,
    'phrasal verb': StudyKind.word,
    'phrasal_verb': StudyKind.word,
    'vocabulary': StudyKind.word,
    'expression': StudyKind.word,
    'tip': StudyKind.tip,
    'note': StudyKind.tip,
    'grammar': StudyKind.tip,
    'rule': StudyKind.tip,
    'strategy': StudyKind.tip,
  };

  static const Set<String> _cefr = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};

  /// متنِ کامل (خروجیِ هوش مصنوعی یا فایلِ .json) ← موردهای سالم + خطاها.
  /// [source]: user (واردکردنِ خودِ کاربر) یا admin (خوراکِ سایت).
  static StudyImportResult parse(
    String raw, {
    StudySource source = StudySource.user,
  }) {
    final Object? data = _decode(raw);
    if (data == null) {
      return const StudyImportResult([], [
        'متن JSONِ معتبر نیست. خروجیِ هوش مصنوعی را کامل کپی کنید.',
      ]);
    }
    final List<Object?> list = switch (data) {
      {'items': final List<Object?> items} => items,
      final List<Object?> l => l,
      _ => [data],
    };

    final List<StudyItem> items = [];
    final List<String> errors = [];
    final Set<String> seen = {};
    for (int i = 0; i < list.length; i++) {
      final (StudyItem? item, String? error) = fromMap(list[i], source: source);
      if (item == null) {
        errors.add('مورد ${i + 1}: $error');
        continue;
      }
      if (seen.add(item.id)) items.add(item);
    }
    return StudyImportResult(items, errors);
  }

  static Object? _decode(String raw) {
    String s = raw.trim().replaceAll(RegExp(r'^```[a-zA-Z]*\s*|\s*```$', multiLine: true), '');
    final int start = s.indexOf(RegExp(r'[\[{]'));
    if (start < 0) return null;
    s = s.substring(start);
    try {
      return jsonDecode(s);
    } catch (_) {
      final int end = [s.lastIndexOf('}'), s.lastIndexOf(']')].reduce((a, b) => a > b ? a : b);
      if (end <= 0) return null;
      try {
        return jsonDecode(s.substring(0, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  /// یک مورد از قالبِ یکسان. [sharedId]/[changedMs] فقط برای خوراکِ سایت.
  static (StudyItem?, String?) fromMap(
    Object? raw, {
    StudySource source = StudySource.user,
    int? sharedId,
    int? changedMs,
  }) {
    if (raw is! Map) return (null, 'مورد باید یک شیء باشد.');
    String str(String k, [List<String> alts = const []]) {
      for (final String key in [k, ...alts]) {
        final Object? v = raw[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      return '';
    }

    final StudyKind? kind =
        _typeAliases[(raw['type'] ?? 'word').toString().trim().toLowerCase()];
    if (kind == null) {
      return (null, 'نوعِ «${bidiIsolate('${raw['type']}')}» شناخته نیست (word یا tip).');
    }
    final String text = str('text', ['word', 'title']).replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return (null, 'فیلدِ text خالی است.');
    if (text.length > 300) return (null, 'text بیش از ۳۰۰ حرف است.');

    String cefr = str('cefr').toUpperCase();
    if (!_cefr.contains(cefr)) cefr = '';
    final int imp = (raw['importance'] as num?)?.toInt() ?? 2;
    final DateTime now = changedMs != null
        ? DateTime.fromMillisecondsSinceEpoch(changedMs)
        : DateTime.now();

    final StudyItem item = StudyItem(
      id: StudyItem.idFor(kind, text),
      kind: kind,
      bookId: '',
      bookTitle: '',
      text: text,
      translationFa: str('meaningFa', ['fa', 'translationFa']),
      translationAr: str('meaningAr', ['ar', 'translationAr']),
      pronounceFa: str('pronounceFa'),
      pronounceAr: str('pronounceAr'),
      explanationFa: str('explanationFa'),
      explanationAr: str('explanationAr'),
      cefrLevel: cefr,
      importance: StudyImportance.fromLevel(imp.clamp(1, 3)),
      createdAt: DateTime.now(),
      updatedAt: now,
      pos: str('pos'),
      ipa: str('ipa'),
      examples: [
        for (final Object? e in (raw['examples'] as List? ?? const []).take(6))
          ?StudyExample.fromJson(e),
      ],
      tags: [
        for (final Object? t in (raw['tags'] as List? ?? const []).take(8))
          if (t != null && t.toString().trim().isNotEmpty) t.toString().trim(),
      ],
      source: source,
      sharedId: sharedId,
      origin: str('source'),
    );
    return (item, null);
  }

  /// موردِ مرور ← قالبِ یکسان (برای «اشتراک‌گذاری»/پشتیبانِ دستی؛ همان کلیدهای پرامپت).
  static Map<String, dynamic> toMap(StudyItem i) => {
    'type': i.kind == StudyKind.tip ? 'tip' : 'word',
    'text': i.text,
    if (i.pos.isNotEmpty) 'pos': i.pos,
    if (i.ipa.isNotEmpty) 'ipa': i.ipa,
    if (i.cefrLevel.isNotEmpty) 'cefr': i.cefrLevel,
    if (i.translationFa.isNotEmpty) 'meaningFa': i.translationFa,
    if (i.translationAr.isNotEmpty) 'meaningAr': i.translationAr,
    if (i.pronounceFa.isNotEmpty) 'pronounceFa': i.pronounceFa,
    if (i.pronounceAr.isNotEmpty) 'pronounceAr': i.pronounceAr,
    if (i.explanationFa.isNotEmpty) 'explanationFa': i.explanationFa,
    if (i.explanationAr.isNotEmpty) 'explanationAr': i.explanationAr,
    if (i.examples.isNotEmpty)
      'examples': [for (final StudyExample e in i.examples) e.toJson()],
    if (i.tags.isNotEmpty) 'tags': i.tags,
    'importance': i.importance.level,
    if (i.origin.isNotEmpty) 'source': i.origin,
  };

  static String encode(Iterable<StudyItem> items) =>
      const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'version': 1,
        'items': [
          for (final StudyItem i in items)
            if (i.kind != StudyKind.passage) toMap(i),
        ],
      });
}

/// 🌟 ST-7: پرامپتِ هوش مصنوعی. [langs]: fa | ar | both — زبانِ توضیح‌ها.
/// همان متنِ StudyItemFormat::prompt() در لاراول؛ هر تغییری هر دو جا.
String studyItemsPrompt(String langs) {
  final bool fa = langs != 'ar';
  final bool ar = langs != 'fa';
  String l(String faPart, String arPart, [String sep = ', ']) =>
      [if (fa) faPart, if (ar) arPart].join(sep);
  String ex(String en, String faT, String arT) =>
      '{"en":"$en",${l('"fa":"$faT"', '"ar":"$arT"', ',')}}';

  final String langLine = switch (langs) {
    'fa' => 'Persian (Farsi) only — do not add any Arabic field',
    'ar' => 'Arabic only — do not add any Persian field',
    _ => 'BOTH Persian (Farsi) and Arabic — fill every Fa field and its Ar twin',
  };

  final String word =
      '{"type":"word",\n'
      ' "text":"mitigate",\n'
      ' "pos":"verb",\n'
      ' "ipa":"/ˈmɪt.ɪ.ɡeɪt/",\n'
      ' "cefr":"C1",\n'
      ' ${l('"meaningFa":"کاهش دادن، تخفیف دادن (شدت یا اثرِ چیزی)"', '"meaningAr":"يُخفِّف، يُقلِّل من حدّة"')},\n'
      ' ${l('"pronounceFa":"میتیگِیت"', '"pronounceAr":"ميتيغيت"')},\n'
      ' ${l('"explanationFa":"…"', '"explanationAr":"…"')},\n'
      ' "examples":[${ex('Planting trees can mitigate the effects of air pollution.', '…', '…')}],\n'
      ' "tags":["Writing","Environment"],\n'
      ' "importance":2}';
  final String tip =
      '{"type":"tip",\n'
      ' "text":"used to + verb vs. be used to + verb-ing",\n'
      ' ${l('"explanationFa":"…"', '"explanationAr":"…"')},\n'
      ' "examples":[${ex('I used to live in Shiraz.', '…', '…')},${ex('I am used to getting up early.', '…', '…')}],\n'
      ' "tags":["Grammar"],\n'
      ' "importance":3}';
  final String pron = l(
    '"pronounceFa": how the English word sounds, written in Persian letters',
    '"pronounceAr": how the English word sounds, written in Arabic letters',
    '; ',
  );
  final String exLangs = l('Persian', 'Arabic', ' and ');

  return '''You are an expert IELTS teacher. Turn the material at the end of this message (notes, a language channel post, another AI's answer, a word list, or just a question) into review items for a study app.

Output ONLY valid JSON — no explanation before or after, no Markdown code fence, no comments — in exactly this shape:

{"format":"ielts-study-items","version":1,"items":[ ... ]}

Each item is one of two types.

1) A word, phrase, phrasal verb, idiom or collocation:
$word

2) A tip: a grammar point, a writing/speaking technique, a common mistake, a pronunciation point or an exam strategy:
$tip

Rules:
- Explanation language: $langLine.
- "text": English. For words use the base/dictionary form (verbs without "to"); for tips a short English title or pattern.
- "pos": noun, verb, adjective, adverb, phrasal verb, idiom, collocation, phrase, linking phrase …
- "ipa": British pronunciation between slashes. "cefr": A1, A2, B1, B2, C1 or C2.
- $pron.
- "meaning…": the meaning(s) used in the material, short. "explanation…": short and practical — usage, register (formal/informal), difference from similar words, common mistakes, why it matters for IELTS. Tips may be several lines.
- "examples": 1–3 natural English sentences, preferably in IELTS contexts, each with its $exLangs translation.
- "tags": 1–3 of: Reading, Listening, Writing, Speaking, Grammar, Vocabulary, Pronunciation, plus a topic if useful (Environment, Education, Technology, Health …).
- "importance": 1 = useful, 2 = important, 3 = essential for IELTS.
- One item per word or tip; no duplicates. Correct any spelling or factual mistakes in the material instead of copying them.
- If the material is only a list of words or a question, complete every field yourself, accurately.
- Leave out a field you are not sure about instead of guessing; never output empty strings.

Material:
<<<
(paste your text here)
>>>''';
}
