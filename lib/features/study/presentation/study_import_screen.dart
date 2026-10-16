import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/study/data/study_item_format.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';

// 🌟 ST-7: «واردکردن از هوش مصنوعی» — سه قدم در یک صفحه:
//   ۱) کپیِ پرامپت (به زبانِ فعالِ اپ) و دادنش به ChatGPT/Claude/… همراهِ مطلبِ کانال یا سؤال؛
//   ۲) چسباندنِ خروجیِ JSON (یا انتخابِ فایلِ .json)؛
//   ۳) پیش‌نمایش، انتخاب و افزودن به «مرورِ من». تکراری‌ها (همان واژه/نکته) کنار می‌روند.

Future<void> openStudyImport(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const StudyImportScreen()),
);

class StudyImportScreen extends ConsumerStatefulWidget {
  const StudyImportScreen({super.key});

  @override
  ConsumerState<StudyImportScreen> createState() => _StudyImportScreenState();
}

class _StudyImportScreenState extends ConsumerState<StudyImportScreen> {
  final TextEditingController _input = TextEditingController();
  StudyImportResult? _result;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _parse() {
    final StudyImportResult r = StudyItemFormat.parse(_input.text);
    final Map<String, StudyItem> existing = ref.read(studyProvider);
    setState(() {
      _result = r;
      _selected
        ..clear()
        ..addAll([
          for (final StudyItem i in r.items)
            if (!existing.containsKey(i.id)) i.id,
        ]);
    });
  }

  Future<void> _pickFile() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
      withData: true,
    );
    final PlatformFile? f = picked?.files.singleOrNull;
    if (f == null) return;
    String text;
    if (f.bytes != null) {
      text = utf8.decode(f.bytes!, allowMalformed: true);
    } else if (f.path != null) {
      text = await File(f.path!).readAsString();
    } else {
      return;
    }
    _input.text = text;
    _parse();
  }

  Future<void> _paste() async {
    final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text == null) return;
    _input.text = d!.text!;
    _parse();
  }

  void _add() {
    final StudyImportResult? r = _result;
    if (r == null) return;
    final (int added, int skipped) = ref
        .read(studyProvider.notifier)
        .importItems(r.items.where((i) => _selected.contains(i.id)));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$added مورد به «مرورِ من» اضافه شد'
          '${skipped > 0 ? '، $skipped موردِ تکراری کنار رفت' : ''}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String lang = ref.watch(languageProvider);
    final Map<String, StudyItem> existing = ref.watch(studyProvider);
    final StudyImportResult? r = _result;
    final TextStyle hint = TextStyle(color: Colors.grey.shade700, height: 1.7, fontSize: 13);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('واردکردن از هوش مصنوعی')),
        bottomNavigationBar: r == null || r.items.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty ? null : _add,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: Text('افزودنِ ${_selected.length} مورد به «مرورِ من»'),
                  ),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Step(
              n: 1,
              title: 'پرامپت را کپی کنید',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'پرامپت را در ChatGPT، Claude، Gemini یا هر هوش مصنوعیِ دیگری بچسبانید و '
                    'جای «paste your text here» مطلبِ کانال، یادداشت، فهرستِ لغت یا سؤالتان را بگذارید.',
                    style: hint,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: studyItemsPrompt(lang == 'ar' ? 'ar' : 'fa')),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('پرامپت کپی شد.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('کپیِ پرامپت'),
                    ),
                  ),
                ],
              ),
            ),
            _Step(
              n: 2,
              title: 'جوابِ هوش مصنوعی را بیاورید',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _input,
                    minLines: 5,
                    maxLines: 12,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '{"format":"ielts-study-items", ...}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _result = null),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('چسباندن'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('فایلِ .json'),
                      ),
                      FilledButton.icon(
                        onPressed: _input.text.trim().isEmpty ? null : _parse,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('پیش‌نمایش'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (r != null)
              _Step(
                n: 3,
                title: r.items.isEmpty
                    ? 'موردی پیدا نشد'
                    : 'انتخاب کنید (${r.items.length} مورد)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final String e in r.errors.take(5))
                      Text('• $e', style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                    if (r.errors.length > 5)
                      Text('… و ${r.errors.length - 5} خطای دیگر', style: hint),
                    for (final StudyItem i in r.items)
                      _PreviewTile(
                        item: i,
                        arabic: lang == 'ar',
                        exists: existing.containsKey(i.id),
                        selected: _selected.contains(i.id),
                        onChanged: (v) => setState(
                          () => v ? _selected.add(i.id) : _selected.remove(i.id),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.child});

  final int n;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 12, child: Text('$n', style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.item,
    required this.arabic,
    required this.exists,
    required this.selected,
    required this.onChanged,
  });

  final StudyItem item;
  final bool arabic;
  final bool exists;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool tip = item.kind == StudyKind.tip;
    final String sub = tip
        ? item.pick(item.explanationFa, item.explanationAr, arabic: arabic)
        : item.pick(item.translationFa, item.translationAr, arabic: arabic);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected && !exists,
      onChanged: exists ? null : (v) => onChanged(v ?? false),
      secondary: Chip(
        visualDensity: VisualDensity.compact,
        label: Text(tip ? 'نکته' : 'واژه', style: const TextStyle(fontSize: 11)),
      ),
      title: Text(item.text, textDirection: TextDirection.ltr),
      subtitle: Text(
        exists ? 'از قبل در «مرورِ من» هست' : sub,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: exists ? TextStyle(color: Colors.grey.shade500) : null,
      ),
    );
  }
}
