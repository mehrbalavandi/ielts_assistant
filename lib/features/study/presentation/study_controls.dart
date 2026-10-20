import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🌟 ST-2 تا ST-4: کنترل‌های «مرورِ من» که هم در صفحه (پاپ‌آپ/بنر/مودالِ لمسِ
// طولانی، پنجره‌ی دیکشنری) و هم در صفحه‌ی مرور به کار می‌روند.

/// سه ستاره = سه سطحِ اهمیت. لمسِ ستاره‌ی nام سطح را n می‌کند.
class StudyStars extends StatelessWidget {
  const StudyStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  final StudyImportance value;
  final ValueChanged<StudyImportance> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // ستاره‌ها همیشه از چپ پر می‌شوند (★★☆)، مستقل از جهتِ صفحه.
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final StudyImportance imp in StudyImportance.values)
            Tooltip(
              message: imp.label,
              child: InkResponse(
                radius: size * 0.8,
                onTap: () => onChanged(imp),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    imp.level <= value.level
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: size,
                    color: imp.level <= value.level
                        ? value.color
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// پنجره‌ی یادداشت. متنِ خالی = حذفِ یادداشت.
Future<void> showStudyNoteDialog(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final StudyItem? item = ref.read(studyProvider)[id];
  if (item == null) return;
  final TextEditingController c = TextEditingController(text: item.note);
  final String? result = await showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('یادداشت'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'نکته، اشتباهِ رایج، جمله‌ی نمونه، …',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ),
  );
  c.dispose();
  if (result != null) ref.read(studyProvider.notifier).setNote(id, result);
}

/// حذف با امکانِ «برگرداندن» (اسنک‌بار).
void removeStudyItemWithUndo(
  BuildContext context,
  WidgetRef ref,
  String id,
) {
  final StudyItem? item = ref.read(studyProvider)[id];
  if (item == null) return;
  final notifier = ref.read(studyProvider.notifier);
  notifier.remove(id);
  final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(
    SnackBar(
      content: Text(
        item.kind == StudyKind.passage
            ? 'از مرور حذف شد'
            : item.source == StudySource.admin
            // 🌟 ST-8
            ? '«${bidiIsolate(item.text)}» حذف شد. بعداً هم از منوی «مرورِ من» ← «موردهای آماده‌ی حذف‌شده» برمی‌گردد.'
            : '«${bidiIsolate(item.text)}» از مرور حذف شد',
      ),
      action: SnackBarAction(
        label: 'برگرداندن',
        onPressed: () => notifier.put(item),
      ),
    ),
  );
}

/// ST-4: نوارِ «افزودن به مرور» برای یک پاراگرافِ صفحه (داخلِ ظرفِ لمسِ طولانی).
class PassageStudyBar extends ConsumerWidget {
  const PassageStudyBar({
    super.key,
    required this.passage,
    this.translationFa,
    this.translationAr,
    required this.isDark,
  });

  final StudyPassageRef passage;
  final String? translationFa;
  final String? translationAr;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String id = passage.id;
    final StudyItem? item = ref.watch(studyProvider.select((m) => m[id]));
    final notifier = ref.read(studyProvider.notifier);
    final Color fg = isDark ? Colors.white70 : Colors.black54;

    if (item == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: isDark ? Colors.white : null,
          ),
          onPressed: () => notifier.put(
            passage.toItem(
              translationFa: translationFa ?? '',
              translationAr: translationAr ?? '',
            ),
          ),
          icon: const Icon(Icons.bookmark_add_outlined, size: 20),
          label: const Text('افزودن به مرور'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(Icons.bookmark_rounded, color: item.importance.color, size: 20),
            Text(
              'در مرور · ${item.importance.label}',
              style: TextStyle(fontSize: 12, color: fg),
            ),
            StudyStars(
              value: item.importance,
              size: 20,
              onChanged: (v) => notifier.setImportance(id, v),
            ),
            IconButton(
              tooltip: item.note.isEmpty ? 'افزودنِ یادداشت' : 'ویرایشِ یادداشت',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: fg,
              onPressed: () => showStudyNoteDialog(context, ref, id),
              icon: Icon(
                item.note.isEmpty
                    ? Icons.note_add_outlined
                    : Icons.edit_note_rounded,
              ),
            ),
            IconButton(
              tooltip: 'حذف از مرور',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: fg,
              onPressed: () => removeStudyItemWithUndo(context, ref, id),
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ],
        ),
        if (item.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              item.note,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: fg,
              ),
            ),
          ),
      ],
    );
  }
}

/// ST-3: نوارِ «افزودن به واژه‌های مرور» در پنجره‌ی دیکشنری.
class WordStudyBar extends ConsumerWidget {
  const WordStudyBar({super.key, required this.word});

  final InteractiveWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String id = StudyItem.wordId(word.exactText);
    final StudyItem? item = ref.watch(studyProvider.select((m) => m[id]));
    final notifier = ref.read(studyProvider.notifier);

    if (item == null) {
      return FilledButton.tonalIcon(
        onPressed: () {
          final BookModel? book = ref.read(activeBookProvider);
          notifier.put(
            StudyItem.fromWord(
              word,
              bookId: book?.id ?? '',
              bookTitle: book?.title ?? '',
            ),
          );
        },
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('افزودن به واژه‌های مرور'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_rounded, color: item.importance.color),
            const SizedBox(width: 6),
            // Expanded (نه Spacer): روی گوشیِ باریک متن کوتاه می‌شود، نه سرریز.
            Expanded(
              child: Text(
                'در واژه‌های مرور · ${item.importance.label}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StudyStars(
              value: item.importance,
              onChanged: (v) => notifier.setImportance(id, v),
            ),
            IconButton(
              tooltip: item.note.isEmpty ? 'افزودنِ یادداشت' : 'ویرایشِ یادداشت',
              visualDensity: VisualDensity.compact,
              onPressed: () => showStudyNoteDialog(context, ref, id),
              icon: Icon(
                item.note.isEmpty
                    ? Icons.note_add_outlined
                    : Icons.edit_note_rounded,
              ),
            ),
            IconButton(
              tooltip: 'حذف از مرور',
              visualDensity: VisualDensity.compact,
              onPressed: () => notifier.remove(id),
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ],
        ),
        const SizedBox(height: 6),
        WordStatusPicker(
          value: item.status,
          onChanged: (s) => notifier.setStatus(id, s),
        ),
        if (item.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              item.note,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// تازه / در حالِ یادگیری / بلدم.
class WordStatusPicker extends StatelessWidget {
  const WordStatusPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WordStatus value;
  final ValueChanged<WordStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final WordStatus s in WordStatus.values)
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(s.icon, size: 16),
            label: Text(s.label, style: const TextStyle(fontSize: 12)),
            selected: s == value,
            showCheckmark: false,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}
