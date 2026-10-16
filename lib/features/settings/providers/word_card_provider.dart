import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 W-3: کدام فیلدهای کلمه‌ی تعاملی در پنجره‌ی دیکشنری نشان داده شوند.
//
// دو دسته فیلد داریم:
// - مشترک (بی‌زبان): شکلِ پایه، آوانویسی (IPA)، نوعِ کلمه، سطحِ CEFR
// - زبان‌دار: تلفظ با خطِ فارسی/عربی، معنی، توضیح — هرکدام جدا برای فارسی و عربی.
//
// قاعده‌ی دوزبانگی: در تنظیمات فقط فیلدهای زبانِ فعالِ اپ دیده و انتخاب می‌شوند (با
// فارسی گزینه‌ی عربی نیست و برعکس)؛ انتخابِ هر زبان جدا ذخیره می‌شود تا با عوض‌کردنِ
// زبان از بین نرود. پنجره هم فقط فیلدهای مشترک و فیلدهای زبانِ فعال را نشان می‌دهد.

enum WordField {
  headword('شکلِ پایه', 'الصيغة الأساسية', 'وقتی کلمه‌ی متن صرف‌شده است (missed ← miss out)'),
  ipa('آوانویسی (IPA)', 'الكتابة الصوتية (IPA)', 'تلفظِ بریتانیایی با الفبای آوانگاری'),
  pos('نوعِ کلمه', 'نوع الكلمة', 'اسم، فعل، صفت، فعلِ عبارتی و…'),
  cefr('سطحِ CEFR', 'مستوى CEFR', 'A1 تا C2'),
  pronounceFa('تلفظ با خطِ فارسی', '', ''),
  translationFa('معنی (فارسی)', '', ''),
  explanationFa('توضیح (فارسی)', '', ''),
  pronounceAr('', 'النطق بالحروف العربية', ''),
  translationAr('', 'المعنى (عربي)', ''),
  explanationAr('', 'الشرح (عربي)', '');

  const WordField(this.labelFa, this.labelAr, this.hint);
  final String labelFa;
  final String labelAr;
  final String hint;

  /// null = مشترک بینِ دو زبان؛ وگرنه 'fa' یا 'ar'.
  String? get language => switch (this) {
    WordField.pronounceFa || WordField.translationFa || WordField.explanationFa => 'fa',
    WordField.pronounceAr || WordField.translationAr || WordField.explanationAr => 'ar',
    _ => null,
  };

  String label(String lang) => lang == 'ar' && labelAr.isNotEmpty ? labelAr : labelFa;

  /// فیلدهایی که در زبانِ [lang] قابلِ انتخاب‌اند، به ترتیبِ نمایش.
  static List<WordField> forLanguage(String lang) => [
    for (final f in values)
      if (f.language == null || f.language == lang) f,
  ];
}

@immutable
class WordCardFields {
  final Set<WordField> enabled;
  const WordCardFields(this.enabled);

  bool shows(WordField f) => enabled.contains(f);

  static final WordCardFields defaults = WordCardFields(WordField.values.toSet());
}

class WordCardNotifier extends Notifier<WordCardFields> {
  static const String storageKey = 'word_card_fields';
  final GetStorage _box = GetStorage();

  @override
  WordCardFields build() {
    final Object? raw = _box.read(storageKey);
    if (raw is! List) return WordCardFields.defaults;
    final Set<WordField> set = {
      for (final Object? name in raw)
        for (final f in WordField.values)
          if (f.name == name) f,
    };
    return WordCardFields(set);
  }

  void toggle(WordField field, bool on) {
    final Set<WordField> next = {...state.enabled};
    on ? next.add(field) : next.remove(field);
    state = WordCardFields(next);
    _box.write(storageKey, [for (final f in next) f.name]);
  }

  void reset() {
    state = WordCardFields.defaults;
    _box.remove(storageKey);
  }
}

final wordCardProvider = NotifierProvider<WordCardNotifier, WordCardFields>(
  WordCardNotifier.new,
);

// ───────── نوعِ کلمه به فارسی/عربی ─────────

const Map<String, (String, String)> _posNames = {
  'noun': ('اسم', 'اسم'),
  'verb': ('فعل', 'فعل'),
  'adjective': ('صفت', 'صفة'),
  'adverb': ('قید', 'ظرف'),
  'preposition': ('حرفِ اضافه', 'حرف جرّ'),
  'conjunction': ('حرفِ ربط', 'حرف عطف'),
  'pronoun': ('ضمیر', 'ضمير'),
  'phrasal verb': ('فعلِ عبارتی', 'فعل مركّب (phrasal verb)'),
  'noun phrase': ('گروهِ اسمی', 'مركّب اسمي'),
  'verb phrase': ('گروهِ فعلی', 'مركّب فعلي'),
  'adjective phrase': ('گروهِ وصفی', 'مركّب وصفي'),
  'phrase': ('عبارت', 'عبارة'),
  'idiom': ('اصطلاح', 'تعبير اصطلاحي'),
  'proverb': ('ضرب‌المثل', 'مثل'),
  'collocation': ('هم‌آیند', 'متلازمة لفظية'),
  'linking phrase': ('عبارتِ ربط', 'عبارة ربط'),
  'determiner': ('معرّف', 'محدِّد'),
  'grammar term': ('اصطلاحِ دستوری', 'مصطلح نحوي'),
  'grammar structure': ('ساختارِ دستوری', 'تركيب نحوي'),
};

/// «verb / noun» ← «فعل / اسم»؛ «noun phrase (grammar)» ← «گروهِ اسمی (دستوری)».
/// هر چیزِ ناشناخته همان انگلیسی می‌ماند.
String localizedPos(String pos, String lang) {
  if (pos.trim().isEmpty) return '';
  final bool ar = lang == 'ar';
  String one(String p) {
    final String key = p.trim().toLowerCase();
    final (String, String)? hit = _posNames[key];
    return hit == null ? p.trim() : (ar ? hit.$2 : hit.$1);
  }

  final RegExpMatch? paren = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(pos);
  final String main = paren?.group(1) ?? pos;
  final String? note = paren?.group(2);
  final String body = main.split('/').map(one).join(' / ');
  if (note == null || note.trim().isEmpty) return body;
  final String noteText = switch (note.trim().toLowerCase()) {
    'grammar' => ar ? 'نحوي' : 'دستوری',
    'passive' => ar ? 'مبني للمجهول' : 'مجهول',
    'uncountable' => ar ? 'غير معدود' : 'غیرقابلِ شمارش',
    'plural' => ar ? 'جمع' : 'جمع',
    _ => note.trim(),
  };
  return '$body ($noteText)';
}
