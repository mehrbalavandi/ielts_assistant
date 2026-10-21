import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';

// 🌟 TR-7 (RULES-rendering.md): ترجمه‌ی گروهیِ پاراگراف‌های کوتاهِ به‌هم‌چسبیده.
//
// سرآغازِ هر مهارت («IN THIS UNIT YOU WILL / LEARN HOW TO» + سه بولت)، صورتِ سؤالی که
// چند پاراگرافِ بی‌فاصله است، فهرستِ شماره‌دارِ سؤال‌ها یا گزینه‌ها، نکته‌ی دوخطی: در
// Word این‌ها پاراگراف‌های جدا ولی بی‌فاصله‌اند. لمسِ طولانی روی هرکدام ترجمه‌ی همه را با
// هم نشان می‌دهد و همه هایلایت می‌شوند.
//
// قاعده (داده‌محور، بی‌هیچ اسمِ فرضی):
// - **عضو:** پاراگرافِ فقط‌متنی (بدونِ جدول/عکس)، با ترجمه، بدونِ جای خالی، و کوتاه
//   (حداکثر [_maxMemberChars] نویسه) — پاراگراف‌های متنِ ریدینگ بلندترند و گروه نمی‌شوند.
// - **چسبیده:** spaceAfterِ قبلی + spaceBeforeِ بعدی ≤ [_maxGapPt] و همان زمینه/کادر.
// - **پاراگرافِ پاسخ** (کلش یک {blk}، همان آیکونِ چشمِ زیرِ هر سؤال) گروه را نمی‌شکند ولی
//   عضوش هم نیست؛ پس سؤال‌های ۱ تا ۵ با پاسخ‌های لای‌شان یک گروه‌اند و هیچ پاسخی لو نمی‌رود.
// - **پاراگرافِ با جای خالیِ داخلِ جمله** («1 value {blk}h{/blk}») عضو نمی‌شود: ترجمه‌اش جواب
//   را دارد و گروه همه‌ی جواب‌ها را یکجا لو می‌داد.
// - گروه دست‌کم ۲ عضو، حداکثر [_maxMembers] عضو و [_maxTotalChars] نویسه دارد؛ بزرگ‌تر
//   باشد، گروه نمی‌شود (هر پاراگراف مثلِ قبل جدا).
// گروه‌ها فقط داخلِ یک ظرف (پاراگراف‌های سطحِ صفحه، یا پاراگراف‌های یک سلول) ساخته می‌شوند.

const int _maxMemberChars = 300;
const int _maxTotalChars = 1200;
const int _maxMembers = 12;
const double _maxGapPt = 2.0;

/// یک گروهِ ترجمه — مشترک میانِ ویجت‌های پاراگراف‌های عضو.
class TranslationGroup {
  TranslationGroup._(this.members);

  /// پاراگراف‌های عضو، به ترتیبِ صفحه.
  final List<ParagraphData> members;

  /// دست‌کم یکی از عضوها ترجمه‌ی گروه را باز کرده است (برای هایلایتِ همه‌ی عضوها).
  final ValueNotifier<bool> anyOpen = ValueNotifier<bool>(false);

  final Map<int, BuildContext> _contexts = {};
  final Set<Object> _openOwners = {};

  /// متنِ ترجمه‌ی گروه به زبانِ انتخابی (اگر عضوی آن زبان را ندارد، زبانِ دیگرش). هر عضو
  /// یک سطر؛ عضوِ فهرست‌دار با همان نشانه‌ی فهرست (• یا 1:) شروع می‌شود.
  String translation({required bool preferAr}) {
    final List<String> lines = [];
    for (final ParagraphData m in members) {
      final String? primary = preferAr ? m.translationAr : m.translationFa;
      final String? secondary = preferAr ? m.translationFa : m.translationAr;
      final String t = ((primary?.trim().isNotEmpty ?? false)
              ? primary!
              : (secondary ?? ''))
          .trim();
      if (t.isEmpty) continue;
      final String marker = m.listMarker?.trim() ?? '';
      lines.add(marker.isEmpty ? t : '$marker $t');
    }
    return lines.join('\n');
  }

  /// ویجتِ عضوِ شماره‌ی [index] (برای کادرِ کلِ گروه هنگامِ جای‌دادنِ پاپ‌آپ).
  void attach(int index, BuildContext context) => _contexts[index] = context;

  void detach(int index, BuildContext context) {
    if (identical(_contexts[index], context)) _contexts.remove(index);
  }

  /// کادرِ همه‌ی عضوها در مختصاتِ [target] (null اگر هنوز layout نشده‌اند).
  Rect? boundsIn(RenderBox target) {
    Rect? union;
    for (final BuildContext c in _contexts.values) {
      final RenderObject? ro = c.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final Rect r = MatrixUtils.transformRect(
        ro.getTransformTo(target),
        Offset.zero & ro.size,
      );
      union = union == null ? r : union.expandToInclude(r);
    }
    return union;
  }

  /// عضوهایی (state) که الان ترجمه‌ی گروه را باز دارند.
  Iterable<Object> get openOwners => _openOwners;

  void report(Object owner, bool open) {
    if (open) {
      _openOwners.add(owner);
    } else {
      _openOwners.remove(owner);
    }
    anyOpen.value = _openOwners.isNotEmpty;
  }
}

/// متنِ پاراگراف بدونِ مارکرهای {blk}/{/blk} (فقط اسپن‌های متنی).
String _rawText(ParagraphData p) {
  final StringBuffer sb = StringBuffer();
  for (final SpanData s in p.spans) {
    if (s.type == 'text') sb.write(s.content);
  }
  return sb.toString();
}

bool _hasBlock(ParagraphData p) => p.spans.any((s) => s.type != 'text');

/// پاراگرافِ «فقط پاسخ»: کلِ متنش یک {blk}…{/blk} است (آیکونِ چشمِ زیرِ سؤال).
bool isWholeBlankAnswer(ParagraphData p) {
  if (_hasBlock(p)) return false;
  final String t = _rawText(p).trim();
  return t.startsWith('{blk}') &&
      t.endsWith('{/blk}') &&
      '{blk}'.allMatches(t).length == 1;
}

bool _isMember(ParagraphData p) {
  if (_hasBlock(p)) return false;
  final String t = _rawText(p);
  if (t.trim().isEmpty || t.contains('{blk}')) return false;
  if (t.length > _maxMemberChars) return false;
  return (p.translationFa?.trim().isNotEmpty ?? false) ||
      (p.translationAr?.trim().isNotEmpty ?? false);
}

String _boxKey(ParagraphData p) {
  final BorderDetail? b = p.borders;
  return '${p.fillColor}|${b?.val}|${b?.width}|${b?.color}';
}

bool _touching(ParagraphData a, ParagraphData b) =>
    a.spaceAfter + b.spaceBefore <= _maxGapPt && _boxKey(a) == _boxKey(b);

/// برای هر پاراگرافِ [paras] گروهش را برمی‌گرداند (null = بی‌گروه، مثلِ قبل).
List<TranslationGroup?> planTranslationGroups(List<ParagraphData> paras) {
  final List<TranslationGroup?> out = List<TranslationGroup?>.filled(
    paras.length,
    null,
  );
  final List<int> run = [];

  void flush() {
    if (run.length >= 2 && run.length <= _maxMembers) {
      final int total = run.fold(0, (n, i) => n + _rawText(paras[i]).length);
      if (total <= _maxTotalChars) {
        final TranslationGroup g = TranslationGroup._([
          for (final int i in run) paras[i],
        ]);
        for (final int i in run) {
          out[i] = g;
        }
      }
    }
    run.clear();
  }

  for (int i = 0; i < paras.length; i++) {
    final ParagraphData p = paras[i];
    if (isWholeBlankAnswer(p)) continue; // نه عضو، نه شکننده
    if (!_isMember(p)) {
      flush();
      continue;
    }
    if (run.isNotEmpty && !_touching(paras[run.last], p)) flush();
    run.add(i);
  }
  flush();
  return out;
}

/// اندیسِ [para] در گروهش (برای `TranslationGroup.attach`).
int translationGroupIndexOf(TranslationGroup group, ParagraphData para) =>
    group.members.indexWhere((m) => identical(m, para));
