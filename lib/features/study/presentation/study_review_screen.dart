import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';

// 🌟 ST-5: صفحه‌ی «مرورِ من» — دو زبانه (واژه‌ها؛ متن‌ها و تمرین‌ها)، فیلترِ اهمیت،
// وضعیتِ واژه و کتاب، مرتب‌سازی، و «رفتن به متن» برای کتابی که الان باز است.

/// [currentBookId]: کتابی که صفحه‌ی مطالعه‌اش پشتِ این صفحه باز است (از AppBarِ
/// کتاب). فقط برای همین کتاب «رفتن به متن» فعال است. از منوی کناریِ ویترین null.
Future<void> openStudyReview(BuildContext context, {String? currentBookId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StudyReviewScreen(currentBookId: currentBookId),
    ),
  );
}

enum _Sort { importance, recent }

class StudyReviewScreen extends ConsumerStatefulWidget {
  const StudyReviewScreen({super.key, this.currentBookId});

  final String? currentBookId;

  @override
  ConsumerState<StudyReviewScreen> createState() => _StudyReviewScreenState();
}

class _StudyReviewScreenState extends ConsumerState<StudyReviewScreen> {
  StudyImportance? _importance; // null = همه
  WordStatus? _status; // null = همه
  late bool _onlyThisBook = widget.currentBookId != null;
  _Sort _sort = _Sort.importance;

  List<StudyItem> _filtered(Iterable<StudyItem> all, StudyKind kind) {
    final List<StudyItem> out = [
      for (final StudyItem i in all)
        if (i.kind == kind &&
            (_importance == null || i.importance == _importance) &&
            (kind != StudyKind.word || _status == null || i.status == _status) &&
            (!_onlyThisBook || i.bookId == widget.currentBookId))
          i,
    ];
    out.sort((a, b) {
      if (_sort == _Sort.importance) {
        final int c = b.importance.level.compareTo(a.importance.level);
        if (c != 0) return c;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, StudyItem> all = ref.watch(studyProvider);
    final List<StudyItem> words = _filtered(all.values, StudyKind.word);
    final List<StudyItem> passages = _filtered(all.values, StudyKind.passage);

    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مرورِ من'),
            actions: [
              // 🌟 BK-1: پشتیبان‌گیریِ دستی (فقط با حسابِ واردشده).
              if (ref.watch(authProvider) == AuthState.authenticated)
                Builder(
                  builder: (context) {
                    final BackupState b = ref.watch(backupProvider);
                    return IconButton(
                      tooltip: b.lastError ?? 'پشتیبان‌گیری روی سرور',
                      onPressed: b.syncing
                          ? null
                          : () async {
                              final bool ok = await ref
                                  .read(backupProvider.notifier)
                                  .syncNow();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '«مرورِ من» روی سرور ذخیره شد.'
                                        : (ref.read(backupProvider).lastError ??
                                              'پشتیبان‌گیری ناموفق بود.'),
                                  ),
                                ),
                              );
                            },
                      icon: b.syncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              b.lastError == null
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_rounded,
                            ),
                    );
                  },
                ),
              PopupMenuButton<_Sort>(
                tooltip: 'مرتب‌سازی',
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _Sort.importance,
                    child: Text('مهم‌ترین‌ها اول'),
                  ),
                  PopupMenuItem(
                    value: _Sort.recent,
                    child: Text('تازه‌ترین‌ها اول'),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(text: 'واژه‌ها (${words.length})'),
                Tab(text: 'متن‌ها و تمرین‌ها (${passages.length})'),
              ],
            ),
          ),
          body: Column(
            children: [
              _FilterBar(
                importance: _importance,
                onImportance: (v) => setState(() => _importance = v),
                showBookScope: widget.currentBookId != null,
                onlyThisBook: _onlyThisBook,
                onBookScope: (v) => setState(() => _onlyThisBook = v),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        _StatusFilter(
                          value: _status,
                          onChanged: (v) => setState(() => _status = v),
                        ),
                        Expanded(
                          child: _list(
                            words,
                            empty: all.values.any(
                                  (i) => i.kind == StudyKind.word,
                                )
                                ? 'با این فیلترها واژه‌ای نیست.'
                                : 'هنوز واژه‌ای اضافه نکرده‌اید.\nروی هر کلمه‌ی رنگی در متن بزنید و «افزودن به واژه‌های مرور» را انتخاب کنید.',
                            builder: (i) => _WordCard(item: i),
                          ),
                        ),
                      ],
                    ),
                    _list(
                      passages,
                      empty: all.values.any((i) => i.kind == StudyKind.passage)
                          ? 'با این فیلترها موردی نیست.'
                          : 'هنوز متن یا تمرینی اضافه نکرده‌اید.\nروی هر پاراگراف یا صورتِ تمرین در کتاب لمسِ طولانی کنید و «افزودن به مرور» را بزنید.',
                      builder: (i) => _PassageCard(
                        item: i,
                        showBook: !_onlyThisBook,
                        canJump:
                            widget.currentBookId != null &&
                            i.bookId == widget.currentBookId,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<StudyItem> items, {
    required String empty,
    required Widget Function(StudyItem) builder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.8),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => KeyedSubtree(
        key: ValueKey(items[i].id),
        child: builder(items[i]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.importance,
    required this.onImportance,
    required this.showBookScope,
    required this.onlyThisBook,
    required this.onBookScope,
  });

  final StudyImportance? importance;
  final ValueChanged<StudyImportance?> onImportance;
  final bool showBookScope;
  final bool onlyThisBook;
  final ValueChanged<bool> onBookScope;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('همه'),
            selected: importance == null,
            showCheckmark: false,
            onSelected: (_) => onImportance(null),
          ),
          for (final StudyImportance imp in StudyImportance.values) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              avatar: Icon(Icons.star_rounded, size: 16, color: imp.color),
              label: Text(imp.label),
              selected: importance == imp,
              showCheckmark: false,
              onSelected: (_) => onImportance(importance == imp ? null : imp),
            ),
          ],
          if (showBookScope) ...[
            const SizedBox(width: 12),
            FilterChip(
              avatar: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('فقط همین کتاب'),
              selected: onlyThisBook,
              onSelected: onBookScope,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final WordStatus? value;
  final ValueChanged<WordStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: const Text('همه‌ی وضعیت‌ها'),
            selected: value == null,
            showCheckmark: false,
            onSelected: (_) => onChanged(null),
          ),
          for (final WordStatus s in WordStatus.values) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(s.icon, size: 16),
              label: Text(s.label),
              selected: value == s,
              showCheckmark: false,
              onSelected: (_) => onChanged(value == s ? null : s),
            ),
          ],
        ],
      ),
    );
  }
}

/// کارتِ واژه: بسته — واژه، سطح، معنی؛ باز — تلفظ، توضیح، یادداشت و کنترل‌ها.
class _WordCard extends ConsumerWidget {
  const _WordCard({required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool ar = ref.watch(languageProvider) == 'ar';
    final notifier = ref.read(studyProvider.notifier);
    final String translation = item.pick(
      item.translationFa,
      item.translationAr,
      arabic: ar,
    );
    final String pronounce = item.pick(
      item.pronounceFa,
      item.pronounceAr,
      arabic: ar,
    );
    final String explanation = item.pick(
      item.explanationFa,
      item.explanationAr,
      arabic: ar,
    );
    final bool known = item.status == WordStatus.known;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: item.importance.color.withOpacity(0.35)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.bookmark_rounded, color: item.importance.color),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.text,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  decoration: known ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.grey,
                ),
              ),
            ),
            if (item.cefrLevel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.cefrLevel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          translation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Tooltip(
          message: item.status.label,
          child: Icon(item.status.icon, color: Colors.grey.shade600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pronounce.isNotEmpty)
            Text(pronounce, style: TextStyle(color: Colors.grey.shade600)),
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(translation, style: const TextStyle(fontSize: 15)),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(explanation, style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
          if (item.note.isNotEmpty) _NoteBox(note: item.note),
          const SizedBox(height: 10),
          WordStatusPicker(
            value: item.status,
            onChanged: (s) => notifier.setStatus(item.id, s),
          ),
          const SizedBox(height: 6),
          _ItemActions(item: item),
        ],
      ),
    );
  }
}

/// کارتِ متن/تمرین: صفحه، گزیده‌ی متن، ترجمه (با لمس)، یادداشت و «رفتن به متن».
class _PassageCard extends ConsumerStatefulWidget {
  const _PassageCard({
    required this.item,
    required this.showBook,
    required this.canJump,
  });

  final StudyItem item;
  final bool showBook;
  final bool canJump;

  @override
  ConsumerState<_PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends ConsumerState<_PassageCard> {
  bool _expanded = false;

  void _jump() {
    final StudyItem item = widget.item;
    if (item.pageNumber == null || item.paraIndex == null) return;
    final result = SearchResult(
      bookId: item.bookId,
      bookTitle: item.bookTitle,
      pageNumber: item.pageNumber!,
      paraIndex: item.paraIndex!,
      occurrenceIndex: 0,
      paragraph: ParagraphData(spans: const [], interactives: const []),
      matchedExcerpt: '',
      query: '',
    );
    final SearchSession? current = ref.read(activeSearchProvider);
    final searchNotifier = ref.read(activeSearchProvider.notifier);
    Navigator.of(context).pop();
    // همان سازوکارِ «برو به متن»ِ پلیر: جلسه‌ی جستجوی بی‌عبارت، تک‌نتیجه (S-3).
    searchNotifier.state = SearchSession(
      query: '',
      results: [result],
      currentIndex: 0,
      jumpTrigger: (current?.jumpTrigger ?? 0) + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final StudyItem item = widget.item;
    final bool ar = ref.watch(languageProvider) == 'ar';
    final String translation = item.pick(
      item.translationFa,
      item.translationAr,
      arabic: ar,
    );
    final TextStyle meta = TextStyle(fontSize: 12, color: Colors.grey.shade600);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: item.importance.color.withOpacity(0.35)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: item.importance.color, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_rounded,
                    size: 18,
                    color: item.importance.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (item.pageNumber != null) 'صفحه‌ی ${item.pageNumber}',
                        if (widget.showBook && item.bookTitle.isNotEmpty)
                          item.bookTitle,
                      ].join(' · '),
                      style: meta,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.text,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (translation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          translation,
                          style: const TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              if (item.note.isNotEmpty) _NoteBox(note: item.note),
              const SizedBox(height: 4),
              _ItemActions(
                item: item,
                trailing: widget.canJump
                    ? FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _jump,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('رفتن به متن'),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note, style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

/// ستاره‌ها، یادداشت، حذف (و دکمه‌ی اختیاریِ انتهای ردیف).
class _ItemActions extends ConsumerWidget {
  const _ItemActions({required this.item, this.trailing});

  final StudyItem item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        StudyStars(
          value: item.importance,
          onChanged: (v) =>
              ref.read(studyProvider.notifier).setImportance(item.id, v),
        ),
        IconButton(
          tooltip: item.note.isEmpty ? 'افزودنِ یادداشت' : 'ویرایشِ یادداشت',
          onPressed: () => showStudyNoteDialog(context, ref, item.id),
          icon: Icon(
            item.note.isEmpty ? Icons.note_add_outlined : Icons.edit_note_rounded,
          ),
        ),
        IconButton(
          tooltip: 'حذف از مرور',
          onPressed: () => removeStudyItemWithUndo(context, ref, item.id),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
