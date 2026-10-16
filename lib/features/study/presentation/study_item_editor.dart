import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/app/app_theme.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';

// 🌟 ST-7: فرمِ افزودن/ویرایشِ واژه یا نکته‌ی بیرون از کتاب‌ها («خودم»).
// دوزبانگی: فقط فیلدهای زبانِ فعالِ اپ (فارسی یا عربی) دیده می‌شوند؛ فیلدهای زبانِ دیگر
// (اگر از واردکردن آمده‌اند) دست نمی‌خورند.

Future<void> openStudyItemEditor(
  BuildContext context, {
  StudyKind kind = StudyKind.word,
  StudyItem? item,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StudyItemEditorScreen(kind: item?.kind ?? kind, item: item),
    ),
  );
}

class StudyItemEditorScreen extends ConsumerStatefulWidget {
  const StudyItemEditorScreen({super.key, required this.kind, this.item});

  final StudyKind kind;
  final StudyItem? item;

  @override
  ConsumerState<StudyItemEditorScreen> createState() =>
      _StudyItemEditorScreenState();
}

class _StudyItemEditorScreenState extends ConsumerState<StudyItemEditorScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final bool _ar = ref.read(languageProvider) == 'ar';
  late final StudyItem? _old = widget.item;
  bool get _isTip => widget.kind == StudyKind.tip;

  late final TextEditingController _text = TextEditingController(text: _old?.text);
  late final TextEditingController _meaning = TextEditingController(
    text: _ar ? _old?.translationAr : _old?.translationFa,
  );
  late final TextEditingController _pronounce = TextEditingController(
    text: _ar ? _old?.pronounceAr : _old?.pronounceFa,
  );
  late final TextEditingController _explanation = TextEditingController(
    text: _ar ? _old?.explanationAr : _old?.explanationFa,
  );
  late final TextEditingController _pos = TextEditingController(text: _old?.pos);
  late final TextEditingController _ipa = TextEditingController(text: _old?.ipa);
  late final TextEditingController _tags = TextEditingController(
    text: _old?.tags.join('، '),
  );
  late final TextEditingController _origin = TextEditingController(text: _old?.origin);
  late final TextEditingController _note = TextEditingController(text: _old?.note);
  late String _cefr = _old?.cefrLevel ?? '';
  late StudyImportance _importance = _old?.importance ?? StudyImportance.important;
  late final List<(TextEditingController, TextEditingController)> _examples = [
    for (final StudyExample e in _old?.examples ?? const <StudyExample>[])
      (
        TextEditingController(text: e.en),
        TextEditingController(text: _ar ? e.ar : e.fa),
      ),
  ];

  @override
  void dispose() {
    for (final TextEditingController c in [
      _text, _meaning, _pronounce, _explanation, _pos, _ipa, _tags, _origin, _note,
      for (final (TextEditingController a, TextEditingController b) in _examples) ...[a, b],
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final String text = _text.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final DateTime now = DateTime.now();
    final List<StudyExample> examples = [
      for (int i = 0; i < _examples.length; i++)
        if (_examples[i].$1.text.trim().isNotEmpty)
          StudyExample(
            _examples[i].$1.text.trim(),
            fa: _ar ? _keepOther(i, ar: false) : _examples[i].$2.text.trim(),
            ar: _ar ? _examples[i].$2.text.trim() : _keepOther(i, ar: true),
          ),
    ];
    final List<String> tags = [
      for (final String t in _tags.text.split(RegExp(r'[,،]')))
        if (t.trim().isNotEmpty) t.trim(),
    ];
    String pick(TextEditingController c, String other, bool forAr) =>
        forAr == _ar ? c.text.trim() : other;

    final StudyItem base =
        _old ??
        StudyItem(
          id: '',
          kind: widget.kind,
          bookId: '',
          bookTitle: '',
          text: text,
          createdAt: now,
          updatedAt: now,
          source: StudySource.user,
        );
    final StudyItem item = StudyItem(
      id: StudyItem.idFor(widget.kind, text),
      kind: widget.kind,
      bookId: base.bookId,
      bookTitle: base.bookTitle,
      text: text,
      translationFa: _isTip ? '' : pick(_meaning, base.translationFa, false),
      translationAr: _isTip ? '' : pick(_meaning, base.translationAr, true),
      pronounceFa: _isTip ? '' : pick(_pronounce, base.pronounceFa, false),
      pronounceAr: _isTip ? '' : pick(_pronounce, base.pronounceAr, true),
      explanationFa: pick(_explanation, base.explanationFa, false),
      explanationAr: pick(_explanation, base.explanationAr, true),
      cefrLevel: _isTip ? '' : _cefr,
      importance: _importance,
      status: base.status,
      note: _note.text.trim(),
      createdAt: base.createdAt,
      updatedAt: now,
      pos: _isTip ? '' : _pos.text.trim(),
      ipa: _isTip ? '' : _ipa.text.trim(),
      examples: examples,
      tags: tags,
      source: StudySource.user,
      origin: _origin.text.trim(),
    );

    final bool ok = ref
        .read(studyProvider.notifier)
        .saveUserItem(item, previousId: _old?.id);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTip
                ? 'نکته‌ای با همین عنوان در «مرورِ من» هست.'
                : '«$text» از قبل در «مرورِ من» هست.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  /// ترجمه‌ی مثال به زبانِ دیگر (که در این فرم دیده نمی‌شود) همان قبلی بماند.
  String _keepOther(int i, {required bool ar}) {
    final List<StudyExample> old = _old?.examples ?? const [];
    if (i >= old.length || old[i].en != _examples[i].$1.text.trim()) return '';
    return ar ? old[i].ar : old[i].fa;
  }

  InputDecoration _dec(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final String lang = _ar ? 'عربی' : 'فارسی';
    const SizedBox gap = SizedBox(height: 12);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _old != null
                ? (_isTip ? 'ویرایشِ نکته' : 'ویرایشِ واژه')
                : (_isTip ? 'نکته‌ی تازه' : 'واژه‌ی تازه'),
          ),
          actions: [
            TextButton.icon(
              style: appBarTextButtonStyle, // 🌟 UI-1
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('ذخیره'),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _text,
                autofocus: _old == null,
                textDirection: TextDirection.ltr,
                decoration: _dec(
                  _isTip ? 'عنوانِ نکته (انگلیسی)' : 'واژه یا عبارت (انگلیسی)',
                  hint: _isTip ? 'used to vs. be used to' : 'mitigate',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'لازم است.' : null,
              ),
              gap,
              if (!_isTip) ...[
                TextFormField(
                  controller: _meaning,
                  decoration: _dec('معنی ($lang)'),
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pos,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('نوعِ کلمه', hint: 'verb'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _cefr,
                        decoration: _dec('سطح'),
                        items: [
                          for (final String c in const ['', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'])
                            DropdownMenuItem(value: c, child: Text(c.isEmpty ? '—' : c)),
                        ],
                        onChanged: (v) => setState(() => _cefr = v ?? ''),
                      ),
                    ),
                  ],
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ipa,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('IPA', hint: '/ˈmɪt.ɪ.ɡeɪt/'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _pronounce,
                        decoration: _dec('تلفظ با حروفِ $lang'),
                      ),
                    ),
                  ],
                ),
                gap,
              ],
              TextFormField(
                controller: _explanation,
                minLines: _isTip ? 5 : 2,
                maxLines: 12,
                decoration: _dec(_isTip ? 'توضیحِ نکته ($lang)' : 'توضیح ($lang)'),
                validator: (v) => _isTip && (v ?? '').trim().isEmpty
                    ? 'توضیحِ نکته لازم است.'
                    : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('مثال‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_examples.length < 6)
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _examples.add((TextEditingController(), TextEditingController())),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('افزودنِ مثال'),
                    ),
                ],
              ),
              for (int i = 0; i < _examples.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: _examples[i].$1,
                                textDirection: TextDirection.ltr,
                                decoration: _dec('جمله‌ی انگلیسی'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _examples[i].$2,
                                decoration: _dec('ترجمه ($lang)'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذفِ مثال',
                          onPressed: () => setState(() => _examples.removeAt(i)),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              gap,
              TextFormField(
                controller: _tags,
                decoration: _dec(
                  'برچسب‌ها',
                  hint: 'Writing، Grammar',
                  helper: 'با ویرگول جدا کنید.',
                ),
              ),
              gap,
              TextFormField(
                controller: _origin,
                decoration: _dec('منبع (اختیاری)', hint: 'مثلاً کانالِ …، ChatGPT'),
              ),
              gap,
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                decoration: _dec('یادداشتِ من'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('اهمیت: '),
                  StudyStars(
                    value: _importance,
                    onChanged: (v) => setState(() => _importance = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('ذخیره در «مرورِ من»'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
