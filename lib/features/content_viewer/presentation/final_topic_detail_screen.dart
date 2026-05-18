import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/content_viewer/providers/revealed_blank_provider.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/add_or_edit_tempelate.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/view_tempelate.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/marker_parser.dart';
import 'package:ielts_assistant/shared/final_topic_search_delegate.dart';
import 'package:ielts_assistant/shared/list_item_text_segmentSimple.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import '../../home/providers/navigation_provider.dart';

// پرووایدر برای مدیریت حالت تک‌ستونه یا دو ستونه
final isHorizontalPaneProvider = StateProvider<bool>((ref) => true);
// final isDualPaneProviderSearchResult = StateProvider<bool>((ref) => false);

class FinalTopicDetailScreen extends ConsumerStatefulWidget {
  final OriginalContent? originalContent;
  // final SearchResultSegments? searchResultSegments;
  final String? searchText;
  const FinalTopicDetailScreen({
    super.key,
    this.originalContent,
    // this.searchResultSegments,
    this.searchText,
  });

  @override
  ConsumerState<FinalTopicDetailScreen> createState() =>
      _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<FinalTopicDetailScreen> {
  // تعریف اسکرول کنترلرها برای حفظ وضعیت اسکرول
  late ScrollController _englishController;
  late ScrollController _persianController;

  @override
  void initState() {
    super.initState();
    _englishController = ScrollController();
    _persianController = ScrollController();
  }

  @override
  void dispose() {
    _englishController.dispose();
    _persianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: Theme.of(context).platform == TargetPlatform.iOS
          ? '.AppleSystemUIFont'
          : 'sans-serif',
      fontFamilyFallback: [FontFamily.yekanBakhRegular.asText],
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      // color: Theme.of(context).textTheme.bodySmall!.color,
      fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
    );
    final isHorizontalPane = ref.watch(isHorizontalPaneProvider);
    final nav = ref.watch(navigationProvider);
    final selectedFinalTopic = nav.selectedFinalTopic;
    final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;
    if (selectedFinalTopicSearch != null) {
      final List<String> labels = [];
      if (widget.originalContent != null) {
        labels.add(
          widget.originalContent!.book.name.replaceAll('قالبهای AI', 'قالبها'),
        );
        var book = ref
            .read(allContentProvider)
            .value!
            .where((x) => x.name == widget.originalContent!.book.name)
            .first;
        if (book.units.length == 1 && book.units.first.topics.length == 1) {
        } else {
          labels.add(
            widget.originalContent!.unit.name.replaceAll('Unit ', 'U '),
          );
          labels.add(
            widget.originalContent!.page.name.replaceAll('Page ', 'P '),
          );
        }
        labels.add(
          widget.originalContent!.finalTopic.name.substring(
            selectedFinalTopicSearch.name.indexOf(' ') + 1,
          ),
        );
      }
      // استفاده از پروایدر به صورت family
      // دقت کنید که topicId را داخل پرانتز جلوی پروایدر می‌نویسیم
      final revealedBlankStates = ref.watch(
        revealedBlanksProvider(selectedFinalTopicSearch.name),
      );
      final isManualFinalTopic =
          // (widget.originalContent?.book.name.contains('قالبهای AI') ?? false) &&
          (widget.originalContent?.book.name == 'قالبهای متفرقه');
      return PopScope(
        canPop:
            true, //ref.read(isPlayerExpandedProvider.notifier).state == false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ref.read(isPlayerExpandedProvider.notifier).state = false;
            return;
          }
        },
        child: SafeArea(
          top: false,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              title: CfPublic().buildTitle(
                labels,
                textStyle,
              ), // Text(title, style: textStyle),
              actions: [
                if (!isManualFinalTopic)
                  IconButton(
                    icon: Icon(
                      isHorizontalPane ? Icons.view_stream : Icons.view_column,
                    ),
                    onPressed: () =>
                        ref.read(isHorizontalPaneProvider.notifier).state =
                            !isHorizontalPane,
                    tooltip: 'تغییر چیدمان متن',
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: isManualFinalTopic
                      ? _buildManualLayout(
                          nav,
                          selectedFinalTopicSearch.contentPersian,
                          selectedFinalTopicSearch.name,
                        )
                      : isHorizontalPane
                      ? _buildHorizontalLayout(
                          widget.originalContent?.book.name.contains(
                                'قالبهای AI',
                              ) ??
                              false,
                          selectedFinalTopicSearch.contentEnglish,
                          selectedFinalTopicSearch.contentPersian,
                          revealedBlankStates,
                          selectedFinalTopicSearch.name,
                        )
                      : _buildVerticalLayout(
                          widget.originalContent!.book.name.contains(
                            'قالبهای AI',
                          ),
                          selectedFinalTopicSearch.contentEnglish,
                          selectedFinalTopicSearch.contentPersian,
                          revealedBlankStates,
                          selectedFinalTopicSearch.name,
                        ),
                  /*
                      widget.originalContent!.book.name.contains(
                          'قالبهای AI',
                        )
                      ? _buildPersianLayout(
                          selectedFinalTopicSearch.contentPersian,
                          finalTopicId,
                        )
                      : _buildEnglishLayout(
                          selectedFinalTopicSearch.contentEnglish,
                          finalTopicId,
                        ),
                        */
                ),
              ],
            ),
          ),
        ),
      );
    } else if (selectedFinalTopic != null) {
      final selectedBook = nav.selectedBook;
      final selectedPage = nav.selectedPage;
      final textSegmentsEnglish = selectedFinalTopic.contentEnglish;
      // var temp = textSegmentsEnglish[26];
      final textSegmentsPersian = selectedFinalTopic.contentPersian;

      // final finalTopicId = selectedFinalTopic.name;
      final List<String> labels = [];

      labels.add(nav.selectedBook!.name.replaceAll('قالبهای AI', 'قالبها'));
      if (nav.selectedBook?.units.length == 1 &&
          nav.selectedBook?.units.first.topics.length == 1) {
        // labels.add('');
      } else {
        labels.add(nav.selectedUnit!.name.replaceAll('Unit ', 'U '));
      }
      if (nav.selectedBook?.units.length == 1 &&
          nav.selectedBook?.units.first.topics.length == 1 &&
          nav.selectedBook?.units.first.topics.first.pageContents.length == 1) {
        // labels.add('');
      } else {
        labels.add(nav.selectedPage!.name.replaceAll('Page ', 'P '));
      }
      labels.add(
        nav.selectedFinalTopic!.name.substring(
          selectedFinalTopic.name.indexOf(' ') + 1,
        ),
      );
      final revealedBlankStates = ref.watch(
        revealedBlanksProvider(selectedFinalTopic.name),
      );
      final isManualFinalTopic = (selectedBook!.name == 'قالبهای متفرقه');
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ref.read(isPlayerExpandedProvider.notifier).state = false;
            return;
          }
        },
        child: SafeArea(
          top: false,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              title: CfPublic().buildTitle(
                labels,
                textStyle,
              ), // Text(title, style: textStyle),
              actions: [
                //! ویجت جستجو
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: IconButton(
                    onPressed: () async {
                      var result = await showSearch(
                        context: context,
                        delegate: FinalTopicSearchDelegate(ref: ref),
                      );
                      if (result != null) {}
                    },
                    icon: Icon(Icons.search),
                  ),
                ),
                if (!isManualFinalTopic)
                  IconButton(
                    icon: Icon(
                      isHorizontalPane ? Icons.view_stream : Icons.view_column,
                    ),
                    onPressed: () =>
                        ref.read(isHorizontalPaneProvider.notifier).state =
                            !isHorizontalPane,
                    tooltip: 'تغییر چیدمان متن',
                  ),
                if (isManualFinalTopic)
                  IconButton(
                    onPressed: () async {
                      if (await CfPublic()
                              .getExternalStoragePermissionStatus() ==
                          true) {
                        if (context.mounted) {
                          _showPopupAddTempelate(
                            context,
                            ref,
                            selectedFinalTopic.name,
                          ).then((finalTopic) {
                            if (finalTopic != null) {
                              ref
                                  .read(navigationProvider.notifier)
                                  .addTempelate(finalTopic);
                            }
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: isManualFinalTopic
                      ? _buildManualLayout(
                          nav,
                          textSegmentsPersian,
                          selectedFinalTopic.name,
                        )
                      : isHorizontalPane
                      ? _buildHorizontalLayout(
                          selectedBook.name.contains('قالبهای AI'),
                          textSegmentsEnglish,
                          textSegmentsPersian,
                          revealedBlankStates,
                          selectedFinalTopic.name,
                        )
                      : _buildVerticalLayout(
                          selectedBook.name.contains('قالبهای AI'),
                          textSegmentsEnglish,
                          textSegmentsPersian,
                          revealedBlankStates,
                          selectedFinalTopic.name,
                        ),
                  /*selectedBook.name.contains('قالبهای AI')
                      ? _buildPersianLayout(textSegmentsPersian, finalTopicId)
                      : _buildEnglishLayout(textSegmentsEnglish, finalTopicId),
                      */
                ),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final int idxFinalTopic = selectedPage!.finalTopics
                                .indexOf(selectedFinalTopic);
                            final lastFinalTopicIndex =
                                selectedPage.finalTopics.length - 1;
                            if (idxFinalTopic < lastFinalTopicIndex) {
                              await ref
                                  .read(navigationProvider.notifier)
                                  .selectFinalTopic(
                                    selectedPage.finalTopics[idxFinalTopic + 1],
                                  );
                              // final books = ref.read(allContentProvider).value;
                              // if (books != null) {
                              //   Future.microtask(() {
                              //     ref
                              //         .read(navigationProvider.notifier)
                              //         .restoreLastState(books);
                              //   });
                              // }
                            } else if (idxFinalTopic == lastFinalTopicIndex) {
                              final int pageIndex = nav
                                  .selectedTopic!
                                  .pageContents
                                  .indexOf(selectedPage);
                              final lastPageIndex =
                                  nav.selectedTopic!.pageContents.length - 1;
                              if (pageIndex < lastPageIndex) {
                                await ref
                                    .read(navigationProvider.notifier)
                                    .selectPageAndFinalTopic(
                                      nav
                                          .selectedTopic!
                                          .pageContents[pageIndex + 1],
                                      nav
                                          .selectedTopic!
                                          .pageContents[pageIndex + 1]
                                          .finalTopics
                                          .first,
                                    );
                                // final books = ref.read(allContentProvider).value;
                                // if (books != null) {
                                //   Future.microtask(() {
                                //     ref
                                //         .read(navigationProvider.notifier)
                                //         .restoreLastState(books);
                                //   });
                                // }
                              }
                            }
                          },
                          icon: Icon(Icons.keyboard_arrow_right_outlined),
                          label: const Text('بعدی'),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final int idxFinalTopic = selectedPage!
                                  .finalTopics
                                  .indexOf(selectedFinalTopic);
                              if (idxFinalTopic > 0) {
                                await ref
                                    .read(navigationProvider.notifier)
                                    .selectFinalTopic(
                                      selectedPage.finalTopics[idxFinalTopic -
                                          1],
                                    );
                                // final books = ref.read(allContentProvider).value;
                                // if (books != null) {
                                //   Future.microtask(() {
                                //     ref
                                //         .read(navigationProvider.notifier)
                                //         .restoreLastState(books);
                                //   });
                                // }
                              } else if (idxFinalTopic == 0) {
                                final int pageIndex = nav
                                    .selectedTopic!
                                    .pageContents
                                    .indexOf(selectedPage);
                                if (pageIndex > 0) {
                                  await ref
                                      .read(navigationProvider.notifier)
                                      .selectPageAndFinalTopic(
                                        nav
                                            .selectedTopic!
                                            .pageContents[pageIndex - 1],
                                        nav
                                            .selectedTopic!
                                            .pageContents[pageIndex - 1]
                                            .finalTopics
                                            .last,
                                      );
                                  // final books = ref.read(allContentProvider).value;
                                  // if (books != null) {
                                  //   Future.microtask(() {
                                  //     ref
                                  //         .read(navigationProvider.notifier)
                                  //         .restoreLastState(books);
                                  //   });
                                  // }
                                }
                              }
                            },
                            icon: Icon(Icons.keyboard_arrow_left_outlined),
                            label: const Text('قبلی'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // مینی پلیر که قابلیت باز و بسته شدن دارد
                const ExpandableMiniPlayer(),
              ],
            ),
          ),
        ),
      );
    } else {
      return SafeArea(
        child: const Scaffold(
          body: Center(child: Text('درسی انتخاب نشده است')),
        ),
      );
    }
  }

  Widget _buildEnglishLayout(
    List<TextSegmentEnglish> segments,
    String finalTopicId,
  ) {
    // ۱. استخراج متن کامل برای جستجو
    String fullPlainText = segments.map((s) => s.plainText).join('');
    String searchQuery = widget.searchText ?? '';
    // ۲. پیدا کردن تمام ایندکس‌های جستجو در کل متن
    final globalMatches = searchQuery.isEmpty
        ? <SearchRange>[]
        : searchQuery
              .allMatches(fullPlainText.toLowerCase())
              .map((m) => SearchRange(m.start, m.end))
              .toList();
    String fullText = segments.map((s) => s.text).join("");
    final positioned = MarkerParser.getPositionMapEnglish(segments);
    final blocks = MarkerParser.getRawBlocks(fullText);
    final structured = MarkerParser.getStructuredItemsEnglish(
      blocks,
      positioned,
    );

    int currentGlobalOffset = 0;
    List<InlineSpan> finalSpans = [];

    // ۳. رندر کردن تک‌تک سگمنت‌ها
    for (int index = 0; index < structured.length; index++) {
      final segment = structured[index];
      debugPrint('currentGlobalOffset is: $currentGlobalOffset');
      finalSpans.add(
        _buildSpansEnglish(
          context,
          ref,
          segment,
          globalMatches,
          currentGlobalOffset,
          index: index,
        ),
      );
      currentGlobalOffset += segment.plainText.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: AlignmentGeometry.centerLeft,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText.rich(
            textAlign: TextAlign.left,
            TextSpan(children: finalSpans),
          ),
          // child: RichText(
          //   text: TextSpan(children: finalSpans),
          //   textAlign: TextAlign.left,
          // ),
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, TextSegmentEnglish data) {
    _showPopupInteractiveSegmentDetails(
      context,
      data.text.replaceAll(RegExp(r'\{.*?\}'), ''),
      data.translation!,
      data.explanation!,
      pronounce: data.pronounce,
    );
  }

  void _showPopupInteractiveSegmentDetails(
    BuildContext context,
    String text,
    String translation,
    String explanation, {
    String? pronounce,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            text,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ), //! 💡
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'ترجمه فارسی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(translation, textDirection: TextDirection.rtl),
                SizedBox(height: 16.0),
                // const Divider(height: 20),
                Text(
                  'توضیحات تکمیلی:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(explanation, textDirection: TextDirection.rtl),
                if (pronounce != null)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.0),
                        Text(
                          'تلفظ:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        Text(pronounce, textDirection: TextDirection.rtl),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'بستن',
                style: TextStyle(
                  fontFamily: FontFamily.yekanBakhBold.asText,
                  fontSize: 16.0,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersianLayout(
    List<TextSegmentPersian> segments,
    String finalTopicId,
  ) {
    // ۱. استخراج متن کامل برای جستجو
    String fullPlainText = segments.map((s) => s.plainText).join('');
    String searchQuery = widget.searchText ?? '';
    // ۲. پیدا کردن تمام ایندکس‌های جستجو در کل متن
    final globalMatches = searchQuery.isEmpty
        ? <SearchRange>[]
        : searchQuery
              .allMatches(fullPlainText.toLowerCase())
              .map((m) => SearchRange(m.start, m.end))
              .toList();

    //! New codes
    String fullText = segments.map((s) => s.text).join("");
    final positioned = MarkerParser.getPositionMapPersian(segments);
    final blocks = MarkerParser.getRawBlocks(fullText);
    final structured = MarkerParser.getStructuredItemsPersian(
      blocks,
      positioned,
    );

    int currentGlobalOffset = 0;
    List<InlineSpan> finalSpans = [];

    for (int index = 0; index < structured.length; index++) {
      final segment = structured[index];
      finalSpans.add(
        _buildSpansPersian(
          context,
          ref,
          segment,
          globalMatches,
          currentGlobalOffset,
          index: index,
        ),
      );
      currentGlobalOffset += segment.plainText.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: AlignmentGeometry.centerRight,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(children: finalSpans),
          ),
        ),
      ),
    );
  }

  // چیدمان دو ستونه (دو لیست اسکرول‌شونده مجزا)
  Widget _buildHorizontalLayout(
    bool isPersianFirst,
    List<TextSegmentEnglish> textSegmentsEnglish,
    List<TextSegmentPersian> translationTextSegments,
    Map<int, RevealedBlankStatus> revealedBlankStates,
    String finalTopicId,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // ✅ تغییر به Column برای نمایش بالا و پایین
        children: [
          // ردیف اول: متن اصلی
          isPersianFirst
              ? SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _buildPersianLayout(
                    translationTextSegments,
                    finalTopicId,
                  ),
                )
              : SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _buildEnglishLayout(textSegmentsEnglish, finalTopicId),
                ),
          const VerticalDivider(),
          // ردیف دوم: ترجمه
          isPersianFirst
              ? SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _buildEnglishLayout(textSegmentsEnglish, finalTopicId),
                )
              : SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _buildPersianLayout(
                    translationTextSegments,
                    finalTopicId,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildVerticalLayout(
    bool isPersianFirst,
    List<TextSegmentEnglish> textSegmentsEnglish,
    List<TextSegmentPersian> translationTextSegments,
    Map<int, RevealedBlankStatus> revealedBlankStates,
    String finalTopicId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        // ردیف اول: متن اصلی
        isPersianFirst
            ? Expanded(
                child: _buildPersianLayout(
                  translationTextSegments,
                  finalTopicId,
                ),
              )
            : Expanded(
                child: _buildEnglishLayout(textSegmentsEnglish, finalTopicId),
              ),
        const Divider(height: 8.0),
        // ردیف دوم: ترجمه
        isPersianFirst
            ? Expanded(
                child: _buildEnglishLayout(textSegmentsEnglish, finalTopicId),
              )
            : Expanded(
                child: _buildPersianLayout(
                  translationTextSegments,
                  finalTopicId,
                ),
              ),
      ],
    );
  }

  Widget _buildManualLayout(
    NavigationState nav,
    List<TextSegmentPersian> segments,
    String finalTopicId,
  ) {
    TextStyle textStyle = TextStyle(
      fontFamily: Theme.of(context).platform == TargetPlatform.iOS
          ? '.AppleSystemUIFont'
          : 'sans-serif',
      fontFamilyFallback: [FontFamily.zar.asText],
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,

      color: Theme.of(context).textTheme.bodySmall!.color,
      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
    );
    List<ManualTemelateData> data = <ManualTemelateData>[];
    String searchQuery = widget.searchText ?? '';

    for (var segment in segments) {
      final persianMatches = searchQuery.isEmpty
          ? <SearchRange>[]
          : searchQuery
                .allMatches(segment.plainText.toLowerCase())
                .map((m) => SearchRange(m.start, m.end))
                .toList();
      final englishMatches = (segment.translation != null)
          ? searchQuery.isEmpty
                ? <SearchRange>[]
                : searchQuery
                      .allMatches(segment.translation!.toLowerCase())
                      .map((m) => SearchRange(m.start, m.end))
                      .toList()
          : <SearchRange>[];
      List<InlineSpan> spansPersian = MarkerParser.parseWithGlobalSearch(
        textWithMarkers: segment.plainText,
        textStyle: textStyle,
        globalMatches: persianMatches,
        globalOffset: 0,
      );
      List<InlineSpan> spansEnglish = MarkerParser.parseWithGlobalSearch(
        textWithMarkers: segment.translation ?? '',
        textStyle: textStyle,
        globalMatches: englishMatches,
        globalOffset: 0,
      );
      data.add(
        ManualTemelateData(
          segment: segment,
          spansPersian: spansPersian,
          spansEnglish: spansEnglish,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentGeometry.centerRight,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onLongPressStart: (details) {
                      _showContextMenu(
                        context,
                        details.globalPosition,
                        index,
                        ref,
                        data[index].segment,
                        finalTopicId,
                      );
                    },
                    child: ListItemTextSegmentSimple(
                      ref: ref,
                      number: index + 1,
                      data: data[index], //spanList,
                      onTap: () async {
                        await _showPopupViewTempelate(
                          context,
                          ref,
                          index,
                          segments[index],
                          finalTopicId,
                        );
                      },
                      onLongPress: () {},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    int index,
    WidgetRef ref,

    TextSegmentPersian textSegmentPersian,
    String finalTopicName,
  ) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(children: [Text('ویرایش')]),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(children: [Text('حذف')]),
          ),
        ),
      ],
    );

    if (result == 'edit') {
      await _showPopupEditTempelate(
        context,
        ref,
        index,
        textSegmentPersian,
        finalTopicName,
      );
    } else if (result == 'delete') {
      String q = 'آیا از حذف این قالب اطمینان دارید؟';
      bool? response = await CfPublic().showQuestionDialog(context, q);
      if (response == null || response == false) {
        return;
      }
      await _deleteTempelate(ref, finalTopicName, index);
    }
  }

  void _updateSearchListData() {
    CfPublic()
        .getSearchListDataAsync(
          ref.read(allContentProvider).value,
          ref.read(navigationProvider),
        )
        .then((result) {
          ref.read(searchListProvider.notifier).state = result;
        });
  }

  Future<FinalTopic?> _showPopupAddTempelate(
    BuildContext context,
    WidgetRef ref,
    String finalTopicName,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            onSubmit: (textSegmentPersian) async {
              final nav = ref.watch(navigationProvider);
              final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;

              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory = (selectedFinalTopicSearch != null)
                  ? '$rootPath/${widget.originalContent!.book.name}/${widget.originalContent!.unit.name}/${widget.originalContent!.topic.name}/${widget.originalContent!.page.name}/${widget.originalContent!.finalTopic.name}'
                  : '$rootPath/${nav.selectedBook!.name}/${nav.selectedUnit!.name}/${nav.selectedTopic!.name}/${nav.selectedPage!.name}/$finalTopicName';
              if (!Directory(newTemplateDirectory).existsSync()) {
                Directory(newTemplateDirectory).createSync(recursive: true);
              }
              //! محتوای فارسی
              String faFileName = '$newTemplateDirectory/me.3.translation.json';
              if (!File(faFileName).existsSync()) {
                File(faFileName).createSync(recursive: true);
              }
              FinalTopic? result = await CfPublic()
                  .savePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    textSement: textSegmentPersian,
                  );

              if (result != null) {
                if (context.mounted) {
                  Navigator.pop(context, result);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, null);
                }
              }
            },
          ),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as FinalTopic;
    } else {
      return null;
    }
  }

  Future<bool?> _showPopupViewTempelate(
    BuildContext context,
    WidgetRef ref,
    int index,
    TextSegmentPersian textSegmentPersian,
    String finalTopicName,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ViewTempelateWidget(persianTextSegment: textSegmentPersian),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as bool;
    } else {
      return false;
    }
  }

  Future<void> _showPopupEditTempelate(
    BuildContext context,
    WidgetRef ref,
    int index,
    TextSegmentPersian textSegmentPersian,
    String finalTopicName,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            persianTextSegment: textSegmentPersian,
            onSubmit: (textSegmentPersian) async {
              final nav = ref.watch(navigationProvider);
              final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;

              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory = (selectedFinalTopicSearch != null)
                  ? '$rootPath/${widget.originalContent!.book.name}/${widget.originalContent!.unit.name}/${widget.originalContent!.topic.name}/${widget.originalContent!.page.name}/${widget.originalContent!.finalTopic.name}'
                  : '$rootPath/${nav.selectedBook!.name}/${nav.selectedUnit!.name}/${nav.selectedTopic!.name}/${nav.selectedPage!.name}/$finalTopicName';
              if (!Directory(newTemplateDirectory).existsSync()) {
                Directory(newTemplateDirectory).createSync(recursive: true);
              }
              //! محتوای فارسی
              String faFileName = '$newTemplateDirectory/me.3.translation.json';
              if (!File(faFileName).existsSync()) {
                File(faFileName).createSync(recursive: true);
              }
              final result = await CfPublic()
                  .updatePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    index: index,
                    textSegmentPersian: textSegmentPersian,
                  );
              if (result != null) {
                if (widget.originalContent != null) {
                  ref
                      .read(navigationProvider.notifier)
                      .updateTempelateForSearchResult(widget.originalContent!);
                }
                if (nav.selectedFinalTopic != null) {
                  ref
                      .read(navigationProvider.notifier)
                      .updateTempelate(nav.selectedFinalTopic!);
                }
                _updateSearchListData();
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteTempelate(
    WidgetRef ref,
    String finalTopicName,
    int index,
  ) async {
    final nav = ref.watch(navigationProvider);
    final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;

    final rootPath = ref.read(settingsProvider);
    String newTemplateDirectory = (selectedFinalTopicSearch != null)
        ? '$rootPath/${widget.originalContent!.book.name}/${widget.originalContent!.unit.name}/${widget.originalContent!.topic.name}/${widget.originalContent!.page.name}/${widget.originalContent!.finalTopic.name}'
        : '$rootPath/${nav.selectedBook!.name}/${nav.selectedUnit!.name}/${nav.selectedTopic!.name}/${nav.selectedPage!.name}/$finalTopicName';
    if (!Directory(newTemplateDirectory).existsSync()) {
      Directory(newTemplateDirectory).createSync(recursive: true);
    }
    String allTextFileName = '$newTemplateDirectory/me.1.txt';
    if (!File(allTextFileName).existsSync()) {
      File(allTextFileName).createSync(recursive: true);
    }
    //! محتوای فارسی
    String faFileName = '$newTemplateDirectory/me.3.translation.json';
    if (!File(faFileName).existsSync()) {
      File(faFileName).createSync(recursive: true);
    }
    final result = await CfPublic().deleteTempelate(faFileName, index);
    if (result != null) {
      if (widget.originalContent != null) {
        ref
            .read(navigationProvider.notifier)
            .updateTempelateForSearchResult(widget.originalContent!);
      }
      if (nav.selectedFinalTopic != null) {
        ref
            .read(navigationProvider.notifier)
            .updateTempelate(nav.selectedFinalTopic!);
      }
      _updateSearchListData();
    }
  }

  InlineSpan _buildSpansEnglish(
    BuildContext context,
    WidgetRef ref,
    TextSegmentEnglish segment,
    List<SearchRange> globalMatches,
    int globalOffset, {
    int? index,
  }) {
    final nav = ref.watch(navigationProvider);
    final selectedFinalTopic = nav.selectedFinalTopic;
    final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;
    String finalTopicId = (selectedFinalTopicSearch != null)
        ? selectedFinalTopicSearch.name
        : selectedFinalTopic!.name;
    final revealedBlankStates = ref.watch(revealedBlanksProvider(finalTopicId));

    final blankStatus = revealedBlankStates[index] ?? RevealedBlankStatus.hide;
    final bool isBlankSegment = (segment.isBlank == true) ? true : false;
    // مدیریت متن جاخالی
    TextStyle textStyle = TextStyle(
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: segment.isBold == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: segment.isItalic == true ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (segment.isUnderline == true) TextDecoration.underline,
        if (segment.isLineThrough == true) TextDecoration.lineThrough,
      ]),
      backgroundColor: selectedFinalTopic != null
          ? (isBlankSegment)
                ? Colors.grey[300]
                : (segment.highlightColor != null
                      ? Color(
                          int.parse(
                            segment.highlightColor!.replaceFirst('#', '0xff'),
                          ),
                        )
                      : null)
          : null,
      color: segment.isInteractive
          ? Theme.of(context).colorScheme.error
          : (isBlankSegment)
          ? Colors.blue[900]
          : Theme.of(context).textTheme.bodySmall!.color,
      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
    );
    TapGestureRecognizer? currentRecognizer;
    String displayText = segment.plainText;
    List<InlineSpan> childrenSpans = <InlineSpan>[];
    if (isBlankSegment) {
      if (selectedFinalTopic != null) {
        if (blankStatus == RevealedBlankStatus.hide) {
          displayText = "________";
          currentRecognizer = TapGestureRecognizer()
            ..onTap = () {
              ref
                  .read(revealedBlanksProvider(finalTopicId).notifier)
                  .toggleStatus(index!);
            };
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: displayText,
              textStyle: textStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset,
              recognizer: currentRecognizer,
            ),
          );
        } else {
          if (segment.children != null) {
            int childOffset = 0;
            for (var child in segment.children!) {
              TextStyle childTextStyle = textStyle;
              if (child.isInteractive) {
                childTextStyle = childTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                );
              }
              if (child.isBold ?? false) {
                if (child.isInteractive) {
                  childTextStyle = childTextStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  );
                } else {
                  childTextStyle = childTextStyle.copyWith(
                    color: Colors.deepOrangeAccent,
                  );
                }
                // childStyle = childStyle.copyWith(fontWeight: FontWeight.bold);
              }
              if (child.isItalic ?? false) {
                childTextStyle = childTextStyle.copyWith(
                  fontStyle: FontStyle.italic,
                );
              }
              if (child.isUnderline ?? false) {
                childTextStyle = childTextStyle.copyWith(
                  decoration: TextDecoration.underline,
                );
              }
              if (child.isLineThrough ?? false) {
                childTextStyle = childTextStyle.copyWith(
                  decoration: TextDecoration.lineThrough,
                );
              }
              TapGestureRecognizer? innerRecognizer;
              if (child.isInteractive) {
                innerRecognizer = TapGestureRecognizer()
                  ..onTap = () {
                    _showDialog(context, child);
                  };
              }
              childrenSpans.addAll(
                MarkerParser.parseWithGlobalSearch(
                  textWithMarkers: child.plainText,
                  textStyle: childTextStyle,
                  globalMatches: globalMatches,
                  globalOffset: globalOffset + childOffset,
                  recognizer: innerRecognizer,
                ),
              );
              childOffset += child.plainText.length;
            }
          } else {
            childrenSpans.addAll(
              MarkerParser.parseWithGlobalSearch(
                textWithMarkers: segment.plainText,
                textStyle: textStyle,
                globalMatches: globalMatches,
                globalOffset: globalOffset,
              ),
            );
          }
        }
      } else {
        if (segment.children != null) {
          int childOffset = 0;
          for (var child in segment.children!) {
            TapGestureRecognizer? innerRecognizer;
            if (child.isInteractive) {
              innerRecognizer = TapGestureRecognizer()
                ..onTap = () {
                  _showDialog(context, child);
                };
            }
            childrenSpans.addAll(
              MarkerParser.parseWithGlobalSearch(
                textWithMarkers: child.plainText,
                textStyle: child.isInteractive
                    ? textStyle.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      )
                    : textStyle,
                globalMatches: globalMatches,
                globalOffset: globalOffset + childOffset,
                recognizer: innerRecognizer,
              ),
            );
            childOffset += child.plainText.length;
          }
        } else {
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: segment.plainText,
              textStyle: textStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset,
            ),
          );
        }
      }
    } else {
      if (segment.children != null) {
        int childOffset = 0;
        for (var child in segment.children!) {
          TextStyle childStyle = textStyle;
          if (child.isInteractive) {
            childStyle = childStyle.copyWith(
              color: Theme.of(context).colorScheme.error,
            );
          }
          if (child.isBold ?? false) {
            if (child.isInteractive) {
              childStyle = childStyle.copyWith(fontWeight: FontWeight.bold);
            } else {
              childStyle = childStyle.copyWith(color: Colors.deepOrangeAccent);
            }
            // childStyle = childStyle.copyWith(fontWeight: FontWeight.bold);
          }
          if (child.isItalic ?? false) {
            childStyle = childStyle.copyWith(fontStyle: FontStyle.italic);
          }
          if (child.isUnderline ?? false) {
            childStyle = childStyle.copyWith(
              decoration: TextDecoration.underline,
            );
          }
          if (child.isLineThrough ?? false) {
            childStyle = childStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            );
          }
          TapGestureRecognizer? innerRecognizer;
          if (child.isInteractive) {
            innerRecognizer = TapGestureRecognizer()
              ..onTap = () {
                _showDialog(context, child);
              };
          }
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: child.plainText,
              textStyle: childStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset + childOffset,
              recognizer: innerRecognizer,
            ),
          );
          childOffset += child.plainText.length;
        }
      } else {
        childrenSpans.addAll(
          MarkerParser.parseWithGlobalSearch(
            textWithMarkers: segment.plainText,
            textStyle: textStyle,
            globalMatches: globalMatches,
            globalOffset: globalOffset,
          ),
        );
      }
    }

    return TextSpan(
      children: childrenSpans,
      // style: currentStyle,
      recognizer: currentRecognizer,
    );
  }

  InlineSpan _buildSpansPersian(
    BuildContext context,
    WidgetRef ref,
    TextSegmentPersian segment,
    List<SearchRange> globalMatches,
    int globalOffset, {
    int? index,
  }) {
    final nav = ref.watch(navigationProvider);
    final selectedFinalTopic = nav.selectedFinalTopic;
    final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;
    String finalTopicId = (selectedFinalTopicSearch != null)
        ? selectedFinalTopicSearch.name
        : selectedFinalTopic!.name;
    final revealedBlankStates = ref.watch(revealedBlanksProvider(finalTopicId));

    final blankStatus = revealedBlankStates[index] ?? RevealedBlankStatus.hide;
    final bool isBlankSegment = (segment.isBlank == true) ? true : false;
    // مدیریت متن جاخالی
    TextStyle currentStyle = TextStyle(
      fontFamily: Theme.of(context).platform == TargetPlatform.iOS
          ? '.AppleSystemUIFont'
          : 'sans-serif',
      fontFamilyFallback: [FontFamily.zar.asText],
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: segment.isBold == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: segment.isItalic == true ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (segment.isUnderline == true) TextDecoration.underline,
        if (segment.isLineThrough == true) TextDecoration.lineThrough,
      ]),
      backgroundColor: selectedFinalTopic != null
          ? (isBlankSegment)
                ? Colors.grey[300]
                : (segment.highlightColor != null
                      ? Color(
                          int.parse(
                            segment.highlightColor!.replaceFirst('#', '0xff'),
                          ),
                        )
                      : null)
          : null,
      color: (isBlankSegment)
          ? Colors.blue[900]
          : Theme.of(context).textTheme.bodySmall!.color,
      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
    );
    TapGestureRecognizer? currentRecognizer;
    String displayText = segment.plainText;
    List<InlineSpan> childrenSpans = <InlineSpan>[];
    if (isBlankSegment) {
      if (selectedFinalTopic != null) {
        if (blankStatus == RevealedBlankStatus.hide) {
          displayText = "________";
          currentRecognizer = TapGestureRecognizer()
            ..onTap = () {
              ref
                  .read(revealedBlanksProvider(finalTopicId).notifier)
                  .toggleStatus(index!);
            };
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: displayText,
              textStyle: currentStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset,
              recognizer: currentRecognizer,
            ),
          );
        } else {
          if (segment.children != null) {
            int childOffset = 0;
            for (var child in segment.children!) {
              TextStyle childStyle = currentStyle;
              if (child.isBold ?? false) {
                childStyle = childStyle.copyWith(fontWeight: FontWeight.bold);
              }
              if (child.isItalic ?? false) {
                childStyle = childStyle.copyWith(fontStyle: FontStyle.italic);
              }
              if (child.isUnderline ?? false) {
                childStyle = childStyle.copyWith(
                  decoration: TextDecoration.underline,
                );
              }
              if (child.isLineThrough ?? false) {
                childStyle = childStyle.copyWith(
                  decoration: TextDecoration.lineThrough,
                );
              }

              childrenSpans.addAll(
                MarkerParser.parseWithGlobalSearch(
                  textWithMarkers: child.plainText,
                  textStyle: childStyle,
                  globalMatches: globalMatches,
                  globalOffset: globalOffset + childOffset,
                ),
              );
              childOffset += child.plainText.length;
            }
          } else {
            childrenSpans.addAll(
              MarkerParser.parseWithGlobalSearch(
                textWithMarkers: segment.plainText,
                textStyle: currentStyle,
                globalMatches: globalMatches,
                globalOffset: globalOffset,
              ),
            );
          }
        }
      } else {
        if (segment.children != null) {
          int childOffset = 0;
          for (var child in segment.children!) {
            childrenSpans.addAll(
              MarkerParser.parseWithGlobalSearch(
                textWithMarkers: child.plainText,
                textStyle: currentStyle,
                globalMatches: globalMatches,
                globalOffset: globalOffset + childOffset,
              ),
            );
            childOffset += child.plainText.length;
          }
        } else {
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: segment.plainText,
              textStyle: currentStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset,
            ),
          );
        }
      }
    } else {
      if (segment.children != null) {
        int childOffset = 0;
        for (var child in segment.children!) {
          TextStyle childStyle = currentStyle;
          if (child.isBold ?? false) {
            childStyle = childStyle.copyWith(fontWeight: FontWeight.bold);
          }
          if (child.isItalic ?? false) {
            childStyle = childStyle.copyWith(fontStyle: FontStyle.italic);
          }
          if (child.isUnderline ?? false) {
            childStyle = childStyle.copyWith(
              decoration: TextDecoration.underline,
            );
          }
          if (child.isLineThrough ?? false) {
            childStyle = childStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            );
          }
          childrenSpans.addAll(
            MarkerParser.parseWithGlobalSearch(
              textWithMarkers: child.plainText,
              textStyle: childStyle,
              globalMatches: globalMatches,
              globalOffset: globalOffset + childOffset,
            ),
          );
          childOffset += child.plainText.length;
        }
      } else {
        childrenSpans.addAll(
          MarkerParser.parseWithGlobalSearch(
            textWithMarkers: segment.plainText,
            textStyle: currentStyle,
            globalMatches: globalMatches,
            globalOffset: globalOffset,
          ),
        );
      }
    }

    return TextSpan(
      children: childrenSpans,
      // style: currentStyle,
      recognizer: currentRecognizer,
    );
  }
}
