import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/app/app_theme.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/settings/providers/word_card_provider.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/presentation/study_controls.dart';
import 'package:ielts_assistant/features/study/presentation/study_import_screen.dart';
import 'package:ielts_assistant/features/study/presentation/study_item_editor.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';

// 🌟 ST-5: صفحه‌ی «مرورِ من» — زبانه‌های واژه‌ها، نکته‌ها (ST-7)، متن‌ها و تمرین‌ها؛ فیلترِ
// اهمیت، منبع (کتاب / خودم / آماده)، وضعیتِ واژه و کتاب، مرتب‌سازی، و «رفتن به متن» برای
// کتابی که الان باز است. 🌟 ST-7: دکمه‌ی «افزودن» (واژه، نکته، واردکردن از هوش مصنوعی) و
// منوی «مرورِ آماده»ِ سایت.

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

enum _Menu { refreshShared, toggleShared, dismissed }

class StudyReviewScreen extends ConsumerStatefulWidget {
  const StudyReviewScreen({super.key, this.currentBookId});

  final String? currentBookId;

  @override
  ConsumerState<StudyReviewScreen> createState() => _StudyReviewScreenState();
}

class _StudyReviewScreenState extends ConsumerState<StudyReviewScreen> {
  StudyImportance? _importance; // null = همه
  WordStatus? _status; // null = همه
  StudySource? _source; // null = همه (ST-7)
  late bool _onlyThisBook = widget.currentBookId != null;
  _Sort _sort = _Sort.importance;

  // 🌟 ST-9: جستجو در همه‌ی فیلدهای موردها (هر سه زبانه).
  bool _searching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _search.clear();
    _query = '';
  });

  List<StudyItem> _filtered(Iterable<StudyItem> all, StudyKind kind) {
    final List<StudyItem> out = [
      for (final StudyItem i in all)
        if (i.kind == kind &&
            (_importance == null || i.importance == _importance) &&
            (kind != StudyKind.word || _status == null || i.status == _status) &&
            (_source == null || i.source == _source) &&
            (!_onlyThisBook || i.bookId == widget.currentBookId) &&
            (_query.isEmpty || studySearchText(i).contains(_query)))
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

  Future<void> _onMenu(_Menu m) async {
    final StudyNotifier n = ref.read(studyProvider.notifier);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    switch (m) {
      case _Menu.refreshShared:
        if (!n.sharedEnabled) await n.setSharedEnabled(true);
        final int? added = await n.syncShared();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              added == null
                  ? 'اتصال به سایت برقرار نشد.'
                  : added == 0
                  ? 'موردِ آماده‌ی تازه‌ای نیست.'
                  : '$added موردِ آماده‌ی تازه اضافه شد.',
            ),
          ),
        );
      case _Menu.dismissed:
        await _showDismissed();
      case _Menu.toggleShared:
        final bool on = !n.sharedEnabled;
        await n.setSharedEnabled(on);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              on
                  ? 'موردهای آماده‌ی سایت خودکار دریافت می‌شوند.'
                  : 'دریافتِ خودکار خاموش شد. موردهای آماده‌ای که دست نزده بودید پاک شدند.',
            ),
          ),
        );
    }
    if (mounted) setState(() {});
  }

  /// 🌟 ST-8: فهرستِ موردهای آماده‌ای که کاربر حذف کرده، با «برگرداندن» (تکی یا همه).
  Future<void> _showDismissed() async {
    final StudyNotifier n = ref.read(studyProvider.notifier);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<String>? ids = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _DismissedSheet(items: n.dismissedShared),
    );
    if (ids == null || ids.isEmpty) return;
    final int? back = await n.restoreDismissed(ids);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          back == null
              ? 'اتصال به سایت برقرار نشد؛ دوباره امتحان کنید.'
              : back == 0
              ? 'این موردها دیگر در «مرورِ آماده»ِ سایت نیستند.'
              : '$back مورد به «مرورِ من» برگشت.',
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('واژه یا عبارتِ تازه'),
                subtitle: const Text('از کانال، فیلم، کلاس، … — بیرون از کتاب‌ها'),
                onTap: () {
                  Navigator.pop(ctx);
                  openStudyItemEditor(context, kind: StudyKind.word);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline_rounded),
                title: const Text('نکته‌ی تازه'),
                subtitle: const Text('دستوری، نوشتاری، گفتاری، تلفظ، استراتژیِ آزمون'),
                onTap: () {
                  Navigator.pop(ctx);
                  openStudyItemEditor(context, kind: StudyKind.tip);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('واردکردن از هوش مصنوعی'),
                subtitle: const Text('پرامپت را بدهید، جوابش را این‌جا بچسبانید'),
                onTap: () {
                  Navigator.pop(ctx);
                  openStudyImport(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, StudyItem> all = ref.watch(studyProvider);
    final List<StudyItem> words = _filtered(all.values, StudyKind.word);
    final List<StudyItem> tips = _filtered(all.values, StudyKind.tip);
    final List<StudyItem> passages = _filtered(all.values, StudyKind.passage);

    return DefaultTabController(
      length: 3,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'جستجو در «مرورِ من»…',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = normalizeStudyQuery(v)),
                  )
                : const Text('مرورِ من'),
            actions: _searching
                ? [
                    IconButton(
                      tooltip: 'بستنِ جستجو',
                      onPressed: _closeSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]
                : [
              IconButton(
                tooltip: 'جستجو',
                onPressed: () => setState(() => _searching = true),
                icon: const Icon(Icons.search_rounded),
              ),
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
              // 🌟 ST-7: «مرورِ آماده»ِ سایت.
              PopupMenuButton<_Menu>(
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _Menu.refreshShared,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.campaign_rounded),
                      title: Text('دریافتِ موردهای آماده‌ی سایت'),
                    ),
                  ),
                  // 🌟 ST-8: موردهای آماده‌ای که حذف شده‌اند و می‌شود برشان گرداند.
                  PopupMenuItem(
                    value: _Menu.dismissed,
                    enabled: ref.read(studyProvider.notifier).dismissedShared.isNotEmpty,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restore_from_trash_rounded),
                      title: Text(
                        'موردهای آماده‌ی حذف‌شده (${ref.read(studyProvider.notifier).dismissedShared.length})',
                      ),
                    ),
                  ),
                  CheckedPopupMenuItem(
                    value: _Menu.toggleShared,
                    checked: ref.read(studyProvider.notifier).sharedEnabled,
                    child: const Text('دریافتِ خودکارِ موردهای آماده'),
                  ),
                ],
              ),
            ],
            bottom: appBarTabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'واژه‌ها (${words.length})'),
                Tab(text: 'نکته‌ها (${tips.length})'),
                Tab(text: 'متن‌ها و تمرین‌ها (${passages.length})'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddMenu(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن'),
          ),
          body: Column(
            children: [
              _FilterBar(
                importance: _importance,
                onImportance: (v) => setState(() => _importance = v),
                source: _source,
                onSource: (v) => setState(() => _source = v),
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
                                ? (_query.isNotEmpty ? 'واژه‌ای با «${_search.text.trim()}» پیدا نشد.' : 'با این فیلترها واژه‌ای نیست.')
                                : 'هنوز واژه‌ای اضافه نکرده‌اید.\nروی هر کلمه‌ی رنگی در متن بزنید و «افزودن به واژه‌های مرور» را انتخاب کنید، یا با «افزودن» واژه‌ای از بیرونِ کتاب بنویسید.',
                            builder: (i) => _WordCard(item: i),
                          ),
                        ),
                      ],
                    ),
                    _list(
                      tips,
                      empty: all.values.any((i) => i.kind == StudyKind.tip)
                          ? (_query.isNotEmpty ? 'نکته‌ای با «${_search.text.trim()}» پیدا نشد.' : 'با این فیلترها نکته‌ای نیست.')
                          : 'نکته‌های دستوری، نوشتاری و گفتاری این‌جا جمع می‌شوند.\nبا «افزودن» یک نکته بنویسید یا جوابِ یک هوش مصنوعی را وارد کنید. نکته‌های آماده‌ی سایت هم خودکار می‌آیند.',
                      builder: (i) => _TipCard(item: i),
                    ),
                    _list(
                      passages,
                      empty: all.values.any((i) => i.kind == StudyKind.passage)
                          ? (_query.isNotEmpty ? 'موردی با «${_search.text.trim()}» پیدا نشد.' : 'با این فیلترها موردی نیست.')
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
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
    required this.source,
    required this.onSource,
    required this.showBookScope,
    required this.onlyThisBook,
    required this.onBookScope,
  });

  final StudyImportance? importance;
  final ValueChanged<StudyImportance?> onImportance;
  final StudySource? source;
  final ValueChanged<StudySource?> onSource;
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
          // 🌟 ST-7: منبع
          const SizedBox(width: 12),
          for (final StudySource src in StudySource.values) ...[
            const SizedBox(width: 6),
            FilterChip(
              avatar: Icon(src.icon, size: 16),
              label: Text(src.label),
              selected: source == src,
              showCheckmark: false,
              onSelected: (_) => onSource(source == src ? null : src),
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
          [
            if (item.pos.isNotEmpty) localizedPosShort(item.pos, ar),
            translation,
          ].where((t) => t.isNotEmpty).join(' · '),
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
          if (item.ipa.isNotEmpty || pronounce.isNotEmpty)
            Wrap(
              spacing: 12,
              children: [
                if (item.ipa.isNotEmpty)
                  Text(
                    item.ipa,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                if (pronounce.isNotEmpty)
                  Text(pronounce, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(translation, style: const TextStyle(fontSize: 15)),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(explanation, style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
          _Examples(item: item, arabic: ar),
          _MetaRow(item: item),
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

/// 🌟 ST-7: کارتِ نکته: عنوان (انگلیسی)، توضیح به زبانِ اپ، مثال‌ها، برچسب‌ها و منبع.
class _TipCard extends ConsumerWidget {
  const _TipCard({required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool ar = ref.watch(languageProvider) == 'ar';
    final String explanation = item.pick(
      item.explanationFa,
      item.explanationAr,
      arabic: ar,
    );
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
        leading: Icon(Icons.lightbulb_rounded, color: item.importance.color),
        title: Text(
          item.text,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(explanation, maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (explanation.isNotEmpty)
            SelectableText(
              explanation,
              style: const TextStyle(fontSize: 14, height: 1.8),
            ),
          _Examples(item: item, arabic: ar),
          _MetaRow(item: item),
          if (item.note.isNotEmpty) _NoteBox(note: item.note),
          const SizedBox(height: 6),
          _ItemActions(item: item),
        ],
      ),
    );
  }
}

/// 🌟 ST-7: جمله‌های نمونه با ترجمه به زبانِ اپ.
class _Examples extends StatelessWidget {
  const _Examples({required this.item, required this.arabic});

  final StudyItem item;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    if (item.examples.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final StudyExample e in item.examples) ...[
            Text(
              '• ${e.en}',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (item.pick(e.fa, e.ar, arabic: arabic).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item.pick(e.fa, e.ar, arabic: arabic),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 🌟 ST-7: منبع (خودم/آماده، نه کتاب)، برچسب‌ها و «از کجا».
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context) {
    final bool showSource = item.source != StudySource.book;
    if (!showSource && item.tags.isEmpty && item.origin.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextStyle small = TextStyle(fontSize: 11.5, color: Colors.grey.shade700);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showSource)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(item.source.icon, size: 14),
              label: Text(item.source.label, style: small),
            ),
          for (final String t in item.tags)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(t, style: small),
            ),
          if (item.origin.isNotEmpty) Text('منبع: ${item.origin}', style: small),
        ],
      ),
    );
  }
}

/// نوعِ کلمه‌ی کوتاه برای زیرنویسِ کارت (مثلاً «verb» ← «فعل»).
String localizedPosShort(String pos, bool arabic) =>
    localizedPos(pos, arabic ? 'ar' : 'fa');

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
        // 🌟 ST-7: موردِ خودم (نه کتاب، نه آماده) کامل ویرایش می‌شود.
        if (item.editable)
          IconButton(
            tooltip: 'ویرایش',
            onPressed: () => openStudyItemEditor(context, item: item),
            icon: const Icon(Icons.edit_outlined),
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

/// 🌟 ST-8: انتخابِ موردهای آماده‌ی حذف‌شده برای برگرداندن. نتیجه: شناسه‌های انتخاب‌شده.
class _DismissedSheet extends StatefulWidget {
  const _DismissedSheet({required this.items});

  final List<(String, String, bool)> items;

  @override
  State<_DismissedSheet> createState() => _DismissedSheetState();
}

class _DismissedSheetState extends State<_DismissedSheet> {
  late final Set<String> _selected = {for (final (String id, _, _) in widget.items) id};

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'موردهای آماده‌ی سایت که حذف کرده‌اید. انتخاب‌شده‌ها دوباره به «مرورِ من» برمی‌گردند '
                  '(با محتوای امروزِ سایت).',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.7, fontSize: 13),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (String id, String title, bool tip) in widget.items)
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(id),
                        onChanged: (v) => setState(
                          () => v == true ? _selected.add(id) : _selected.remove(id),
                        ),
                        secondary: Icon(
                          tip ? Icons.lightbulb_outline_rounded : Icons.translate_rounded,
                          size: 20,
                        ),
                        title: Text(title, textDirection: TextDirection.ltr),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text('برگرداندنِ ${_selected.length} مورد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── 🌟 ST-9: جستجو ─────────

/// یکسان‌سازی برای جستجو: کوچک‌حرف، ی/ک عربی ← فارسی، بی‌اعراب و نیم‌فاصله، فاصله‌های یکسان.
String normalizeStudyQuery(String s) => s
    .toLowerCase()
    .replaceAll('ي', 'ی')
    .replaceAll('ى', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[\u064B-\u065F\u0670\u200c\u200f\u200e]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// همه‌ی متن‌های قابلِ جستجوی یک مورد (هر دو زبان، مثال‌ها، برچسب‌ها، یادداشت، کتاب)؛
/// یک‌بار برای هر نسخه‌ی مورد ساخته و نگه داشته می‌شود.
String studySearchText(StudyItem i) =>
    _searchCache[i] ??= normalizeStudyQuery(
      [
        i.text,
        i.translationFa,
        i.translationAr,
        i.pronounceFa,
        i.pronounceAr,
        i.explanationFa,
        i.explanationAr,
        i.note,
        i.pos,
        i.ipa,
        i.cefrLevel,
        i.bookTitle,
        i.origin,
        ...i.tags,
        for (final StudyExample e in i.examples) ...[e.en, e.fa, e.ar],
      ].join(' \u0001 '),
    );

final Expando<String> _searchCache = Expando<String>('studySearch');
