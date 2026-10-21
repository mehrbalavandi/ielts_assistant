import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart'; // افزوده شد برای شناسایی کلاس‌ها
import 'package:ielts_assistant/features/reader/data/paged_book_store.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';
import 'package:ielts_assistant/features/audio/domain/audio_skill.dart';
import 'package:ielts_assistant/shared/widgets/outline_group_widgets.dart';

class BookSearchDelegate extends SearchDelegate<SearchSession?> {
  final WidgetRef ref;

  /// 🌟 S-15: کتابِ باز — برای نشان دادنِ درس و مهارتِ هر نتیجه (فهرستِ کتاب).
  final PagedBookStore? store;

  /// 🌟 S-17: نتیجه‌ای که کاربر آخرین بار در صفحه دیده بود (برگشت از صفحه به همین فهرست): در
  /// فهرست هایلایت و به آن اسکرول می‌شود. null = جستجوی تازه.
  SearchResult? _resumeTarget;
  bool _resumeShown = false;

  /// [resume]: جلسه‌ی جستجوی در حالِ پیمایش (S-17)؛ همان عبارت و همان فهرست بی‌جستجوی دوباره.
  /// عبارت را showSearch(query: …) در کادر می‌گذارد.
  BookSearchDelegate(this.ref, {this.store, SearchSession? resume}) {
    if (resume != null && resume.query.isNotEmpty) {
      final List<SearchResult> results =
          resume.results.whereType<SearchResult>().toList();
      _debouncedQuery.value = resume.query;
      _lastSearchQuery = resume.query;
      _cachedSearchFuture = Future.value(results);
      if (resume.currentIndex >= 0 && resume.currentIndex < resume.results.length) {
        final Object? t = resume.results[resume.currentIndex];
        if (t is SearchResult) _resumeTarget = t;
      }
    }
  }

  /// S-15/S-18: درس، مهارت و صفحه‌ی هر نتیجه؛ برای نتیجه‌ی اسکریپتِ صوتی جای اولین دکمه‌ی همان
  /// فایل در کتاب.
  final Map<SearchResult, ({OutlinePlace? place, AudioSkill skill})> _places =
      {};

  ({OutlinePlace? place, AudioSkill skill}) _placeOf(SearchResult r) =>
      _places.putIfAbsent(r, () {
        final PagedBookStore? s = store;
        if (s == null || s.outline.isEmpty) {
          return (place: null, skill: AudioSkill.other);
        }
        int page = r.pageNumber;
        int para = r.paraIndex;
        if (r.audioTrackName != null) {
          final entry = s.audioLinksIndex
              .where((e) => e.fileName == r.audioTrackName)
              .firstOrNull;
          if (entry == null) return (place: null, skill: AudioSkill.other);
          page = entry.pageNumber;
          para = entry.paraIndex;
        }
        return (
          place: outlinePlaceAt(s.outline, page, para),
          skill: audioSkillAt(s.outline, page, para),
        );
      });

  Timer? _debounce;
  final ValueNotifier<String> _debouncedQuery = ValueNotifier<String>('');

  // 🌟 کَش کردن Future برای جلوگیری از اجرای تکراری جستجو با هر بار Rebuild شدن UI
  Future<List<SearchResult>>? _cachedSearchFuture;
  String _lastSearchQuery = '';
  // 🌟 اگر لیستِ کتاب‌ها هنگامِ آخرین جستجو خالی بود (هنوز از API لود نشده)،
  // آن نتیجه را «قطعی» تلقی نمی‌کنیم — وگرنه جستجوی روی صفر کتاب برای همیشه
  // کش می‌شد و حتی بعد از لود شدنِ کتاب‌ها دوباره اجرا نمی‌شد.
  bool _lastSearchWasOnEmptyBooks = false;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  final ValueNotifier<int> _retryTick = ValueNotifier<int>(0);

  void _ensureRetryTimerIfBookMissing(BookModel? activeBook) {
    if (activeBook != null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempts = 0;
      return;
    }
    if (_retryTimer != null) return; // از قبل در حالِ تلاشِ مجدد است
    _retryAttempts = 0;
    _retryTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      _retryAttempts++;
      if (_retryAttempts > 15) {
        // 🌟 تا ۶ ثانیه صبر می‌کنیم؛ بعد از آن رها می‌کنیم تا کاربر خودش دوباره تایپ کند
        t.cancel();
        _retryTimer = null;
        return;
      }
      _retryTick.value++; // 🌟 باعثِ rebuild و تلاشِ دوباره‌ی جستجو می‌شود
    });
  }

  void _scheduleSearch() {
    if (query.trim() == _debouncedQuery.value)
      return; // جلوگیری از تریگر تکراری

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _debouncedQuery.value = query.trim();
    });
  }

  @override
  String get searchFieldLabel => 'جستجو در کتاب‌ها...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 3) {
      return const Center(child: Text('حداقل ۳ حرف وارد کنید.'));
    }
    _scheduleSearch();
    return _buildDebouncedResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // S-17: برگشت به فهرست ← بی‌صفحه‌کلید، مستقیم فهرستِ نتایج (یک‌بار).
    if (_resumeTarget != null && !_resumeShown) {
      _resumeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showResults(context);
      });
    }
    if (query.trim().length < 3) return const SizedBox.shrink();
    _scheduleSearch();
    return _buildDebouncedResults();
  }

  Widget _buildDebouncedResults() {
    return ValueListenableBuilder<String>(
      valueListenable: _debouncedQuery,
      builder: (context, debouncedQ, _) {
        final bool isPending = debouncedQ != query.trim();
        return Stack(
          children: [
            if (debouncedQ.length >= 3)
              // 🌟 با این ValueListenableBuilder، هر تیکِ retryِ ناشی از خالی‌بودنِ
              // لیستِ کتاب‌ها باعثِ rebuild می‌شود، پس وقتی booksProvider پر شود
              // (که ممکن است بعد از باز شدنِ جستجو از API برسد)، جستجو خودکار
              // دوباره اجرا می‌شود — قبلاً این تیک هیچ‌جا watch نمی‌شد.
              ValueListenableBuilder<int>(
                valueListenable: _retryTick,
                builder: (context, _, __) => _buildSearchResults(debouncedQ),
              ),
            if (isPending)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(String debouncedQuery) {
    final activeBook = ref.read(activeBookProvider);
    _ensureRetryTimerIfBookMissing(activeBook);

    final bool shouldResearch =
        _cachedSearchFuture == null ||
        _lastSearchQuery != debouncedQuery ||
        (_lastSearchWasOnEmptyBooks && activeBook != null);

    if (shouldResearch) {
      _lastSearchQuery = debouncedQuery;
      _lastSearchWasOnEmptyBooks = activeBook == null;
      _cachedSearchFuture = BookSearchEngine.searchAllBooks(
        debouncedQuery,
        activeBook == null ? const [] : [activeBook],
      );
    }

    return FutureBuilder<List<SearchResult>>(
      future: _cachedSearchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطا در جستجو: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('نتیجه‌ای یافت نشد.'));
        }

        final results = snapshot.data!;
        return _buildResultList(context, results, debouncedQuery);
      },
    );
  }

  /// 🌟 S-18: نتیجه‌ها زیرِ سرعنوانِ درس (به ترتیبِ کتاب؛ نتیجه‌های اسکریپتِ صوتی زیرِ درسِ همان
  /// فایل)، هر نتیجه با نشانِ مهارت، بخش و صفحه، و گزیده‌ای که عبارتِ یافته‌شده در آن پررنگ است.
  /// ترتیبِ پیمایشِ «بعدی/قبلی» در صفحه همان ترتیبِ موتورِ جستجوست (SearchSession).
  Widget _buildResultList(
    BuildContext context,
    List<SearchResult> results,
    String debouncedQuery,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // مرتب‌سازیِ پایدار بر اساسِ درس؛ بی‌درس آخر.
    final List<int> order = List<int>.generate(results.length, (i) => i);
    int unitKey(int i) => _placeOf(results[i]).place?.unitIndex ?? 1 << 20;
    if (store?.outline.isNotEmpty ?? false) {
      order.sort((a, b) {
        final int c = unitKey(a).compareTo(unitKey(b));
        return c != 0 ? c : a.compareTo(b);
      });
    }

    // ردیف‌ها: null = خلاصه‌ی بالا؛ (header) = سرعنوانِ درس؛ (result) = نتیجه.
    final List<({int? result, OutlinePlace? header, int count})> rows = [
      (result: null, header: null, count: -1),
    ];
    final bool grouped = store?.outline.isNotEmpty ?? false;
    int? lastUnit;
    int headerRow = -1;
    for (final int i in order) {
      final OutlinePlace? place = _placeOf(results[i]).place;
      final int u = place?.unitIndex ?? -1;
      if (grouped && (headerRow < 0 || u != lastUnit)) {
        lastUnit = u;
        headerRow = rows.length;
        rows.add((result: null, header: place, count: 0));
      }
      rows.add((result: i, header: null, count: 0));
      if (headerRow >= 0) {
        final r = rows[headerRow];
        rows[headerRow] = (result: null, header: r.header, count: r.count + 1);
      }
    }

    // S-17: برگشت از صفحه ← آخرین نتیجه‌ی دیده‌شده وسطِ فهرست و هایلایت‌شده.
    final int focusResult = _resumeTarget == null
        ? -1
        : results.indexWhere((r) => identical(r, _resumeTarget));
    final int focusRow = focusResult < 0
        ? -1
        : rows.indexWhere((r) => r.result == focusResult);

    final Set<String> books = {for (final r in results) r.bookTitle};

    // 🐞 S-17: ScrollablePositionedList نتیجه‌ی دیده‌شده را حتی وقتی بالای فهرست است در ۳۰٪ِ
    // ارتفاع می‌نشاند و بالایش جای خالی می‌ماند (فهرستِ کوتاه یا نتیجه‌ی اول). بعد از اولین
    // فریم: اگر اولین ردیف دیده می‌شود و پایین‌تر از لبه‌ی بالاست، فهرست به بالا می‌چسبد.
    final ItemScrollController scroll = ItemScrollController();
    final ItemPositionsListener positions = ItemPositionsListener.create();
    if (focusRow > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ItemPosition? first = positions.itemPositions.value
            .where((p) => p.index == 0)
            .firstOrNull;
        if (first != null && first.itemLeadingEdge > 0.001 && scroll.isAttached) {
          scroll.jumpTo(index: 0);
        }
      });
    }

    return ScrollablePositionedList.builder(
      itemScrollController: scroll,
      itemPositionsListener: positions,
      itemCount: rows.length,
      initialScrollIndex: focusRow < 0 ? 0 : focusRow,
      initialAlignment: focusRow <= 0 ? 0 : 0.3,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.result == null && row.count < 0) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${results.length} نتیجه',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' برای «${bidiIsolate(debouncedQuery)}»'),
                  if (books.length == 1)
                    TextSpan(text: ' در ${bidiIsolate(books.first)}'),
                ],
              ),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          );
        }
        if (row.result == null) {
          return UnitGroupHeader(
            place: row.header,
            countLabel: '${row.count} نتیجه',
            accent: cs.primary,
            textColor: cs.onSurface,
            mutedColor: cs.onSurfaceVariant,
          );
        }
        final SearchResult result = results[row.result!];
        return _resultTile(
          context,
          result,
          highlighted: index == focusRow,
          showBook: books.length > 1,
          onTap: () {
            final bookResults = results
                .where((r) => r.bookId == result.bookId)
                .toList();
            close(
              context,
              SearchSession(
                // 🐞 S-13: همان عبارتی که واقعاً جستجو شد (بی‌فاصله‌ی اضافه)، نه متنِ خامِ
                // کادر — وگرنه هایلایتِ نارنجی با نتیجه‌ها هم‌خوان نبود.
                query: debouncedQuery,
                results: bookResults,
                currentIndex: bookResults.indexOf(result),
              ),
            );
          },
        );
      },
    );
  }

  Widget _resultTile(
    BuildContext context,
    SearchResult result, {
    required bool highlighted,
    required bool showBook,
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isAudio = result.audioTrackName != null;
    final info = _placeOf(result);
    final Color skillColor = audioSkillColor(info.skill) ?? cs.primary;
    final String section =
        info.place?.sectionTitle ??
        (info.skill == AudioSkill.other ? '' : audioSkillName(info.skill));
    final TextStyle muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 12);

    // جایِ نتیجه: «Reading · صفحه‌ی 19» یا «Listening · اسکریپتِ Mindset_L1_35».
    final List<InlineSpan> where = [
      if (section.isNotEmpty)
        TextSpan(
          text: bidiIsolate(section),
          style: TextStyle(color: skillColor, fontWeight: FontWeight.w600),
        ),
      if (section.isNotEmpty) const TextSpan(text: '  ·  '),
      TextSpan(
        text: isAudio
            ? 'اسکریپتِ ${bidiIsolate(_stem(result.audioTrackName!))}'
            : 'صفحه‌ی ${result.pageNumber}',
      ),
      if (showBook) TextSpan(text: '  ·  ${bidiIsolate(result.bookTitle)}'),
    ];

    final String excerpt = result.matchedExcerpt;
    final int ms = result.excerptMatchStart;
    final int me = result.excerptMatchEnd;
    final bool canMark = ms >= 0 && me > ms && me <= excerpt.length;
    final TextStyle base = TextStyle(
      color: cs.onSurface,
      fontSize: 14,
      height: 1.45,
    );
    final TextStyle mark = TextStyle(
      fontWeight: FontWeight.bold,
      color: cs.onSurface,
      backgroundColor: Colors.amber.withOpacity(0.45),
    );

    return Material(
      color: highlighted ? cs.primary.withOpacity(0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: highlighted
              ? BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: cs.primary, width: 3),
                  ),
                )
              : null,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkillBadge(
                skill: info.skill,
                color: skillColor,
                size: 38,
                // نتیجه‌ی اسکریپتِ صوتی: نشانِ پخش (لمس ← پلیر باز می‌شود).
                icon: isAudio ? Icons.play_arrow_rounded : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: where),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                        if (result.matchInHiddenAnswer)
                          _chip(context, 'در پاسخِ پنهان', Icons.visibility_off_outlined),
                        if (result.hiddenMatchCount > 1)
                          _chip(context, '${result.hiddenMatchCount} مورد', null),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      canMark
                          ? TextSpan(
                              children: [
                                TextSpan(text: excerpt.substring(0, ms)),
                                TextSpan(text: excerpt.substring(ms, me), style: mark),
                                TextSpan(text: excerpt.substring(me)),
                              ],
                            )
                          : TextSpan(text: excerpt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionOf(excerpt),
                      textAlign: textAlignToStartOf(context),
                      style: base,
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

  static Widget _chip(BuildContext context, String text, IconData? icon) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: cs.onSecondaryContainer),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer),
          ),
        ],
      ),
    );
  }

  static String _stem(String file) {
    final int dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }

  @override
  void close(BuildContext context, SearchSession? result) {
    _debounce?.cancel();
    _retryTimer?.cancel();
    super.close(context, result);
  }
}
