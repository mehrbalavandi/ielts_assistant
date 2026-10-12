import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';

// 🌟 ناوبرِ ساختاریِ کتاب (قانون‌های N-1 … N-6ِ RULES-rendering.md).
//
// یک ستونِ معلق در لبه‌ی چپِ صفحه‌ی مطالعه:
//  • بالا: «کامبوباکسِ» سطحِ ۱ (در Mindset: Unit) — برچسبِ کوتاه (U1، U2، …)، با
//    لمس فهرستِ کاملِ عنوان‌ها باز می‌شود و انتخابِ هر کدام یعنی پرش به آن.
//  • زیرش: یک دکمه به‌ازای هر فرزندِ گره‌ی فعلیِ سطحِ ۱ (در Mindset: چهار مهارت).
//    دکمه‌ی بخشی که الان در حالِ خواندنش هستید روشن است.
//  • پایین: دکمه‌ی جمع‌کردن؛ جمع‌شده فقط یک زبانه‌ی باریک می‌ماند تا متن را
//    نپوشاند. وضعیت ذخیره می‌شود.
//
// هیچ اسمِ خاصی (Unit، Reading، …) فرض نشده: عنوان‌ها از Outlineِ index.json
// می‌آیند (قانونِ O-4ِ اکسترکتور). فقط برای چهار مهارتِ رایجِ آیلتس آیکونِ آشنا
// گذاشته شده؛ هر بخشِ دیگری با حرفِ اولش نشان داده می‌شود.

/// جای فعلیِ خواننده در فهرست.
class OutlinePosition {
  final int? top; // اندیسِ گره‌ی سطحِ ۱
  final int? child; // اندیسِ فرزندِ آن (سطحِ ۲)
  const OutlinePosition(this.top, this.child);
}

/// N-3: گره‌ی فعلی = آخرین گره‌ای که صفحه‌اش قبل از «خطِ خواندن» یا روی آن است.
/// مقایسه با ترتیبِ صفحه‌ها در لیست است، نه شماره‌ی چاپیِ صفحه.
OutlinePosition locateInOutline(
  List<OutlineEntry> outline,
  int? readingPageIndex,
  int? Function(int pageNumber) indexForPageNumber,
) {
  if (readingPageIndex == null || outline.isEmpty) {
    return const OutlinePosition(null, null);
  }
  int? lastAtOrBefore(List<OutlineEntry> list) {
    int? found;
    for (int i = 0; i < list.length; i++) {
      final int? idx = indexForPageNumber(list[i].pageNumber);
      if (idx == null) continue;
      if (idx <= readingPageIndex) {
        found = i;
      } else {
        break;
      }
    }
    return found;
  }

  final int? top = lastAtOrBefore(outline);
  if (top == null) return const OutlinePosition(null, null);
  return OutlinePosition(top, lastAtOrBefore(outline[top].children));
}

/// N-5: برچسبِ کوتاهِ سطحِ ۱: «UNIT/01: …» ← «U1»، «Chapter 12» ← «C12»؛ بدونِ
/// عدد ← دو حرفِ اول.
String outlineShortLabel(String title, int index) {
  final m = RegExp(
    r'^\s*([^\W\d_])\D*?0*(\d+)',
    unicode: true,
  ).firstMatch(title);
  if (m != null) return '${m.group(1)!.toUpperCase()}${m.group(2)}';
  final letters = title.replaceAll(RegExp(r'\s+'), '');
  if (letters.isEmpty) return '${index + 1}';
  return letters.substring(0, math.min(2, letters.length)).toUpperCase();
}

/// عنوانِ تمام‌حروف‌بزرگ را برای نمایش در منو/راهنما خواناتر می‌کند
/// («READING» ← «Reading»). عنوانِ معمولی دست‌نخورده می‌ماند.
String outlineDisplayTitle(String title) {
  if (title != title.toUpperCase() || !RegExp(r'[A-Z]').hasMatch(title)) {
    return title;
  }
  return title.toLowerCase().replaceAllMapped(
    RegExp(r'(^|[\s/:(\-])([a-z])'),
    (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
  );
}

/// N-5: آیکونِ آشنا برای چهار مهارتِ آیلتس؛ برای هر بخشِ دیگر null (حرفِ اول).
IconData? outlineSectionIcon(String title) {
  final t = title.toLowerCase();
  if (t.contains('reading')) return Icons.menu_book_rounded;
  if (t.contains('writing')) return Icons.edit_note_rounded;
  if (t.contains('listening')) return Icons.headphones_rounded;
  if (t.contains('speaking')) return Icons.record_voice_over_rounded;
  return null;
}

class BookOutlineNavigator extends StatefulWidget {
  final List<OutlineEntry> outline;

  /// اندیسِ (در لیست) صفحه‌ای که «خطِ خواندن» رویش است — رجوع به N-3.
  final ValueListenable<int?> readingPageIndex;
  final int? Function(int pageNumber) indexForPageNumber;
  final void Function(OutlineEntry entry) onNavigate;

  /// N-8: شماره‌ی صفحه‌ی فعلی و آخرین صفحه (نه «تعدادِ صفحات»؛ شماره‌گذاری می‌تواند
  /// از عددِ دلخواه شروع شود) — جای نشانِ معلقِ قبلیِ «صفحه x از y».
  final int currentPage;
  final int lastPage;

  /// لمسِ شماره‌ی صفحه ← دیالوگِ «رفتن به صفحه».
  final VoidCallback onPageTap;

  /// هنگامِ اسکرول (و ۲.۵ ثانیه بعدش) شماره‌ی صفحه پررنگ‌تر است، مثلِ نشانِ قبلی.
  final bool highlightPage;

  const BookOutlineNavigator({
    super.key,
    required this.outline,
    required this.readingPageIndex,
    required this.indexForPageNumber,
    required this.onNavigate,
    required this.currentPage,
    required this.lastPage,
    required this.onPageTap,
    this.highlightPage = false,
  });

  @override
  State<BookOutlineNavigator> createState() => _BookOutlineNavigatorState();
}

class _BookOutlineNavigatorState extends State<BookOutlineNavigator> {
  static const String _collapsedKey = 'outline_nav_collapsed';
  final GetStorage _box = GetStorage();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    try {
      _collapsed = _box.read(_collapsedKey) == true;
    } catch (_) {}
  }

  void _setCollapsed(bool v) {
    setState(() => _collapsed = v);
    try {
      _box.write(_collapsedKey, v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: widget.readingPageIndex,
      builder: (context, readingIndex, _) {
        final pos = locateInOutline(
          widget.outline,
          readingIndex,
          widget.indexForPageNumber,
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(
              sizeFactor: anim,
              axis: Axis.horizontal,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: _collapsed
              ? _buildCollapsed(context, pos)
              : _buildPanel(context, pos),
        );
      },
    );
  }

  // ── جمع‌شده: زبانه‌ی باریک با آیکونِ بخشِ فعلی ───────────────────────────
  Widget _buildCollapsed(BuildContext context, OutlinePosition pos) {
    final scheme = Theme.of(context).colorScheme;
    final OutlineEntry? current = pos.top == null
        ? null
        : (pos.child == null
              ? widget.outline[pos.top!]
              : widget.outline[pos.top!].children[pos.child!]);
    final IconData? icon = current == null
        ? null
        : outlineSectionIcon(current.title);
    return Material(
      key: const ValueKey('collapsed'),
      color: scheme.primary.withOpacity(0.85),
      elevation: 3,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
      child: InkWell(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        onTap: () => _setCollapsed(false),
        child: Tooltip(
          message: 'نمایشِ فهرست — صفحه‌ی ${widget.currentPage}',
          child: SizedBox(
            width: 24,
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(icon, size: 14, color: scheme.onPrimary)
                else if (pos.top != null)
                  Text(
                    outlineShortLabel(widget.outline[pos.top!].title, pos.top!),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimary,
                    ),
                  ),
                // N-8: شماره‌ی صفحه در حالتِ جمع‌شده هم دیده می‌شود.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.currentPage}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── باز: کامبوباکسِ سطحِ ۱ + دکمه‌های سطحِ ۲ ─────────────────────────────
  Widget _buildPanel(BuildContext context, OutlinePosition pos) {
    final scheme = Theme.of(context).colorScheme;
    final List<OutlineEntry> sections = pos.top == null
        ? const []
        : widget.outline[pos.top!].children;
    return Material(
      key: const ValueKey('panel'),
      color: scheme.primary.withOpacity(0.88),
      elevation: 4,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 6, 4, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.outline.isNotEmpty) _buildTopMenu(context, pos),
            if (sections.isNotEmpty) ...[
              Container(
                width: 28,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 5),
                color: scheme.onPrimary.withOpacity(0.35),
              ),
              for (int i = 0; i < sections.length; i++)
                _SectionButton(
                  entry: sections[i],
                  index: i,
                  isCurrent: pos.child == i,
                  onTap: () => widget.onNavigate(sections[i]),
                ),
            ],
            // N-8: شماره‌ی صفحه (جای نشانِ معلقِ پایینِ صفحه).
            if (widget.outline.isNotEmpty)
              Container(
                width: 28,
                height: 1,
                margin: const EdgeInsets.only(top: 5, bottom: 4),
                color: scheme.onPrimary.withOpacity(0.35),
              ),
            _buildPageChip(context),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _setCollapsed(true),
              child: Tooltip(
                message: 'جمع‌کردنِ فهرست',
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: scheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// N-8: «۱۲ / ۱۵۹» در دو خط؛ لمس ← «رفتن به صفحه».
  Widget _buildPageChip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'صفحه ${widget.currentPage} از ${widget.lastPage} — رفتن به صفحه',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPageTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withOpacity(
                widget.highlightPage ? 0.28 : 0.12,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.currentPage}',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.1,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '/${widget.lastPage}',
                    style: TextStyle(
                      color: scheme.onPrimary.withOpacity(0.75),
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopMenu(BuildContext context, OutlinePosition pos) {
    final scheme = Theme.of(context).colorScheme;
    final String label = pos.top == null
        ? '—'
        : outlineShortLabel(widget.outline[pos.top!].title, pos.top!);
    return PopupMenuButton<int>(
      tooltip: pos.top == null
          ? 'فهرست'
          : outlineDisplayTitle(widget.outline[pos.top!].title),
      position: PopupMenuPosition.under,
      offset: const Offset(4, 0),
      constraints: const BoxConstraints(maxWidth: 320),
      onSelected: (i) => widget.onNavigate(widget.outline[i]),
      itemBuilder: (context) => [
        for (int i = 0; i < widget.outline.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: i == pos.top
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: scheme.primary,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      outlineDisplayTitle(widget.outline[i].title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: i == pos.top
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.onPrimary.withOpacity(0.16),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 14,
              color: scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// N-4: دکمه‌ی یک بخش؛ بخشِ فعلی روشن (زمینه‌ی روشن، آیکونِ رنگِ اصلی).
class _SectionButton extends StatelessWidget {
  final OutlineEntry entry;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  const _SectionButton({
    required this.entry,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final IconData? icon = outlineSectionIcon(entry.title);
    final Color fg = isCurrent
        ? scheme.primary
        : scheme.onPrimary.withOpacity(0.85);
    final String title = outlineDisplayTitle(entry.title);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: title,
        child: Semantics(
          button: true,
          selected: isCurrent,
          label: title,
          child: Material(
            color: isCurrent ? scheme.onPrimary : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, size: 20, color: fg)
                    : Text(
                        outlineShortLabel(entry.title, index),
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
