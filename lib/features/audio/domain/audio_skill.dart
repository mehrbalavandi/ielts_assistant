import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';

// 🌟 AU-9 (RULES-rendering.md): رنگِ مهارت برای همه‌چیزِ صوتی — دکمه‌ی فایلِ صوتی در متنِ درس،
// پلی‌لیست، پلیر، تصویرِ اعلانِ رسانه/صفحه‌ی قفل، کادرِ صفحه و ناوبرِ فهرست. مثلِ خودِ کتاب
// (رنگِ عنوان‌ها و کادرهای Mindset): Listening سرخابی (AC0C6C)، Speaking آبیِ روشن، Reading سبزِ لیمویی،
// Writing نارنجی. مهارت از جای فایل
// در فهرستِ کتاب (سطحِ ۲ِ Outline) خوانده می‌شود؛ هیچ اسمِ فایلی فرض نمی‌شود.

enum AudioSkill { listening, speaking, reading, writing, other }

/// مهارت از روی عنوانِ بخش («LISTENING»، «Speaking Part 2»، …).
AudioSkill audioSkillFromTitle(String title) {
  final String t = title.toLowerCase();
  if (t.contains('listening')) return AudioSkill.listening;
  if (t.contains('speaking')) return AudioSkill.speaking;
  if (t.contains('reading')) return AudioSkill.reading;
  if (t.contains('writing')) return AudioSkill.writing;
  return AudioSkill.other;
}

/// مهارتِ نقطه‌ای از کتاب: عنوانِ مهارتی که این نقطه زیرش است (اگر نبود، عنوانِ خودِ درس).
AudioSkill audioSkillAt(
  List<OutlineEntry> outline,
  int pageNumber,
  int paraIndex,
) {
  if (outline.isEmpty) return AudioSkill.other;
  final pos = outlineIndicesAt(outline, pageNumber, paraIndex);
  if (pos.unit < 0) return AudioSkill.other;
  final OutlineEntry unit = outline[pos.unit];
  if (pos.section >= 0) {
    final AudioSkill s = audioSkillFromTitle(unit.children[pos.section].title);
    if (s != AudioSkill.other) return s;
  }
  return audioSkillFromTitle(unit.title);
}

/// رنگِ مهارت. [onDark]: روی زمینه‌ی تیره (پلیر) روشن‌تر؛ روی صفحه‌ی سفیدِ کتاب پررنگ.
/// null = مهارتِ نامعلوم (رنگِ قبلیِ همان‌جا می‌ماند).
Color? audioSkillColor(AudioSkill skill, {bool onDark = false}) {
  switch (skill) {
    case AudioSkill.listening:
      return onDark ? const Color(0xFFF48FB1) : const Color(0xFFAC0C6C);
    case AudioSkill.speaking:
      return onDark ? const Color(0xFF81D4FA) : const Color(0xFF0288D1);
    case AudioSkill.reading:
      return onDark ? const Color(0xFFC5E1A5) : const Color(0xFF689F38);
    case AudioSkill.writing:
      return onDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00);
    case AudioSkill.other:
      return null;
  }
}

/// رنگِ پرِ مهارت برای پس‌زمینه‌ی تصویرِ اعلان (اشباع و تیره، تا متنِ سفید رویش خوانا باشد).
Color audioSkillDeepColor(AudioSkill skill) {
  switch (skill) {
    case AudioSkill.listening:
      return const Color(0xFF880E4F);
    case AudioSkill.speaking:
      return const Color(0xFF01579B);
    case AudioSkill.reading:
      return const Color(0xFF33691E);
    case AudioSkill.writing:
      return const Color(0xFFBF360C);
    case AudioSkill.other:
      return const Color(0xFF283593);
  }
}

IconData audioSkillIcon(AudioSkill skill) {
  switch (skill) {
    case AudioSkill.listening:
      return Icons.headphones_rounded;
    case AudioSkill.speaking:
      return Icons.record_voice_over_rounded;
    case AudioSkill.reading:
      return Icons.menu_book_rounded;
    case AudioSkill.writing:
      return Icons.edit_note_rounded;
    case AudioSkill.other:
      return Icons.music_note_rounded;
  }
}

String audioSkillName(AudioSkill skill) {
  switch (skill) {
    case AudioSkill.listening:
      return 'Listening';
    case AudioSkill.speaking:
      return 'Speaking';
    case AudioSkill.reading:
      return 'Reading';
    case AudioSkill.writing:
      return 'Writing';
    case AudioSkill.other:
      return '';
  }
}
