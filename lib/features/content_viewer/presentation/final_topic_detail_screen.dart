import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/content_viewer/providers/sentence_provider.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/add_or_edit_tempelate.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/view_tempelate.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/final_topic_search_delegate.dart';
import 'package:ielts_assistant/shared/list_item_text_segmentSimple.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/utility_persian.dart';
import '../../home/providers/navigation_provider.dart';

// پرووایدر برای مدیریت حالت تک‌ستونه یا دو ستونه
final isDualPaneProvider = StateProvider<bool>((ref) => false);
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
    final isDualPane = ref.watch(isDualPaneProvider);
    final nav = ref.watch(navigationProvider);
    final selectedFinalTopic = nav.selectedFinalTopic;
    final selectedFinalTopicSearch = nav.selectedFinalTopicSearch;
    if (selectedFinalTopicSearch != null) {
      final String finalTopicId = selectedFinalTopicSearch.name;
      String title =
          '${widget.originalContent!.book.name.replaceAll('قالبهای موقعیتی', 'قالبها')}>${widget.originalContent!.unit.name.replaceAll('Unit ', 'U ')}>${widget.originalContent!.page.name.replaceAll('Page ', 'P ')}>${selectedFinalTopicSearch.name.substring(selectedFinalTopicSearch.name.indexOf(' ') + 1)}';
      // استفاده از پروایدر به صورت family
      // دقت کنید که topicId را داخل پرانتز جلوی پروایدر می‌نویسیم
      final sentenceStates = ref.watch(sentenceProvider(finalTopicId));
      final isManualFinalTopic =
          (widget.originalContent!.book.name.contains('قالبهای موقعیتی')) &&
          (widget.originalContent!.page.name == 'Day 00');
      return PopScope(
        canPop:
            true, //ref.read(isPlayerExpandedProvider.notifier).state == false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ref.read(isPlayerExpandedProvider.notifier).state = false;
            return;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            title: Text(
              title,
              style: TextStyle(
                // fontFamily: FontFamily.yekanBakhBold.asText,
                fontSize: 16.0,
                // color: Theme.of(context).colorScheme.primary,
              ),
            ),
            actions: [
              if (!isManualFinalTopic)
                IconButton(
                  icon: Icon(
                    isDualPane ? Icons.view_stream : Icons.view_column,
                  ),
                  onPressed: () =>
                      ref.read(isDualPaneProvider.notifier).state = !isDualPane,
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
                        isDualPane,
                        selectedFinalTopicSearch.contentEnglish,
                        selectedFinalTopicSearch.contentPersian,
                        sentenceStates,
                        finalTopicId,
                      )
                    : isDualPane
                    ? _buildEnglishAndPersianLayout(
                        widget.originalContent!.book.name.contains(
                          'قالبهای موقعیتی',
                        ),
                        selectedFinalTopicSearch.contentEnglish,
                        selectedFinalTopicSearch.contentPersian,
                        sentenceStates,
                        finalTopicId,
                      )
                    : widget.originalContent!.book.name.contains(
                        'قالبهای موقعیتی',
                      )
                    ? _buildPersianLayout(
                        selectedFinalTopicSearch.contentPersian,
                        finalTopicId,
                      )
                    : (widget.searchText == null)
                    ? _buildEnglishLayout(
                        selectedFinalTopicSearch.contentEnglish,
                        sentenceStates,
                        finalTopicId,
                      )
                    : _buildEnglishLayoutForSearch(
                        selectedFinalTopicSearch.contentEnglish,
                        sentenceStates,
                        finalTopicId,
                      ),
              ),
            ],
          ),
        ),
      );
    } else if (selectedFinalTopic != null) {
      final selectedBook = nav.selectedBook;
      final selectedTopic = nav.selectedTopic;
      final selectedUnit = nav.selectedUnit;
      final selectedPage = nav.selectedPage;
      final textSegmentsEnglish = selectedFinalTopic.contentEnglish;
      // var temp = textSegmentsEnglish[26];
      final textSegmentsPersian = selectedFinalTopic.contentPersian;

      final finalTopicId = selectedFinalTopic.name;
      String title =
          '${selectedBook!.name.replaceAll('قالبهای موقعیتی', 'قالبها')}>${selectedUnit!.name.replaceAll('Unit ', 'U ')}>${selectedPage!.name.replaceAll('Page ', 'P ')}>${selectedFinalTopic.name.substring(selectedFinalTopic.name.indexOf(' ') + 1)}';
      // استفاده از پروایدر به صورت family
      // دقت کنید که topicId را داخل پرانتز جلوی پروایدر می‌نویسیم
      final sentenceStates = ref.watch(sentenceProvider(finalTopicId));
      final isManualFinalTopic =
          ((nav.selectedBook?.name != null) &&
              selectedBook.name.contains('قالبهای موقعیتی')) &&
          (selectedPage.name == 'Day 00');
      return PopScope(
        canPop:
            true, //ref.read(isPlayerExpandedProvider.notifier).state == false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ref.read(isPlayerExpandedProvider.notifier).state = false;
            return;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            title: Text(
              title,
              style: TextStyle(
                // fontFamily: FontFamily.yekanBakhBold.asText,
                fontSize: 16.0,
                // color: Theme.of(context).colorScheme.primary,
              ),
            ),
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
                    isDualPane ? Icons.view_stream : Icons.view_column,
                  ),
                  onPressed: () =>
                      ref.read(isDualPaneProvider.notifier).state = !isDualPane,
                  tooltip: 'تغییر چیدمان متن',
                ),
              if (isManualFinalTopic)
                IconButton(
                  onPressed: () async {
                    if (await CfPublic().getExternalStoragePermissionStatus() ==
                        true) {
                      if (context.mounted) {
                        _showPopupAddTempelate(context, ref).then((finalTopic) {
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
                        isDualPane,
                        textSegmentsEnglish,
                        textSegmentsPersian,
                        // textSegmentsNote,
                        sentenceStates,
                        finalTopicId,
                      )
                    : isDualPane
                    ? _buildEnglishAndPersianLayout(
                        selectedBook.name.contains('قالبهای موقعیتی'),
                        textSegmentsEnglish,
                        textSegmentsPersian,
                        sentenceStates,
                        finalTopicId,
                      )
                    : selectedBook.name.contains('قالبهای موقعیتی')
                    ? _buildPersianLayout(textSegmentsPersian, finalTopicId)
                    : _buildEnglishLayout(
                        textSegmentsEnglish,
                        sentenceStates,
                        finalTopicId,
                      ),
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
                          final int idxFinalTopic = selectedPage.finalTopics
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
                                    nav.selectedTopic!.pageContents[pageIndex +
                                        1],
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
                            final int idxFinalTopic = selectedPage.finalTopics
                                .indexOf(selectedFinalTopic);
                            if (idxFinalTopic > 0) {
                              await ref
                                  .read(navigationProvider.notifier)
                                  .selectFinalTopic(
                                    selectedPage.finalTopics[idxFinalTopic - 1],
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
      );
    } else {
      return const Scaffold(body: Center(child: Text('درسی انتخاب نشده است')));
    }
  }

  // چیدمان تک ستونه (انگلیسی بالای فارسی)

  Widget _buildEnglishLayout(
    List<TextSegmentEnglish> textSegmentsEnglish,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    final spans = textSegmentsEnglish.asMap().entries.map((entry) {
      final index = entry.key;
      final ms = entry.value;
      final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
      TextStyle style = TextStyle(
        fontSize: (ms.isBold != null && ms.isBold == true)
            ? Theme.of(context).textTheme.titleLarge!.fontSize
            : Theme.of(context).textTheme.bodyLarge!.fontSize,
        fontWeight: (ms.isBold != null && ms.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: Theme.of(
          context,
        ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
      );

      // اعمال استایل جستجو (هایلایت پس‌زمینه زرد)
      if (ms.isAmberHighlighted != null && ms.isAmberHighlighted == true) {
        style = style.copyWith(backgroundColor: Colors.amber.shade100);
      }
      if (ms.isInteractive) {
        style = style.copyWith(color: Theme.of(context).colorScheme.error);
        debugPrint('تعاملی: ${ms.text}');
      } else if (ms.isBlank != null) {
        style = style.copyWith(color: Colors.blueAccent);
      }

      if (ms.isInteractive) {
        final formattedSpans = UtilityPersian().buildMixedTextSpans(
          ms.text.replaceAll('\\n', '\n'),
          persianStyle: style.copyWith(
            fontFamily: FontFamily.yekanBakhRegular.asText,
            fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
          ),
          normalStyle: style,
        );
        return formattedSpans.map((e) {
          return TextSpan(
            text: e.text,
            style: e.style,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showPopupInteracticeSegmentDetails(
                  context,
                  ms.text,
                  ms.translation!,
                  ms.explanation!,
                );
              },
          );
        }).toList();
      } else {
        if (ms.hasSubItems == null) {
          debugPrint('فاقد زیرمجموعه: ${ms.text}');
          if (ms.isBlank != null && ms.isBlank == true) {
            if (blankStatus == SentenceStatus.hide) {
              return [
                TextSpan(
                  text: " ________ ", // نمایش جاخالی
                  style: style,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => ref
                        .read(sentenceProvider(finalTopicId).notifier)
                        .toggleStatus(index),
                ),
              ];
            }
          } else if (ms.isLineThrough != null && ms.isLineThrough == true) {
            return [
              TextSpan(
                text: ms.text,
                style: style.copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationStyle: TextDecorationStyle.wavy,
                  decorationColor: Colors.red,
                ),
              ),
            ];
          }
          final formattedSpans = UtilityPersian().buildMixedTextSpans(
            ms.text.replaceAll('\\n', '\n'),
            persianStyle: style.copyWith(
              fontFamily: FontFamily.yekanBakhRegular.asText,
              fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
            ),
            normalStyle: style,
          );
          return formattedSpans;
          // return [
          //   TextSpan(text: ms.text.replaceAll('\\n', '\n'), style: style),
          // ];
        } else {
          debugPrint(jsonEncode(ms));
          final subItemsAsTextSegmentEnglish = ms.subItems!.map((e) {
            debugPrint('داخلی: ${jsonEncode(e)}');
            return TextSegmentEnglish(
              text: e.text, //['text'] as String,
              isInteractive: e.isInteractive, //['isInteractive'] as bool,
              isBold: e.isBold, //['isBold'] as bool?,
              isBlank: e.isBlank, //['isBlank'] as bool?,
              translation: e.translation, //['translation'] as String?,
              explanation: e.explanation, //['explanation'] as String?,
              cerfLevel: e.cerfLevel, //['cerfLevel'] as String?,
              pronounce: e.pronounce, //['pronounce'] as String?,
              isRtl: e.isRtl, //['isRtl'] as bool?,
            );
          }).toList();
          final List<TextSegmentEnglish> subMicroSegments = CfPublic()
              .fillGapsInFullText(ms.text, subItemsAsTextSegmentEnglish);
          final subSpans = subMicroSegments.asMap().entries.map((entry) {
            // final index = entry.key;
            final subMs = entry.value;
            // final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
            if (subMs.isInteractive) {
              final formattedSpans = UtilityPersian().buildMixedTextSpans(
                subMs.text.replaceAll('\\n', '\n'),
                persianStyle: style.copyWith(
                  fontFamily: FontFamily.yekanBakhRegular.asText,
                  fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
                ),
                normalStyle: style,
              );
              return formattedSpans.map((e) {
                return TextSpan(
                  text: e.text,
                  style: e.style,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      _showPopupInteracticeSegmentDetails(
                        context,
                        subMs.text,
                        subMs.translation!,
                        subMs.explanation!,
                      );
                    },
                );
              }).toList();
            } else {
              final formattedSpans = UtilityPersian().buildMixedTextSpans(
                subMs.text.replaceAll('\\n', '\n'),
                persianStyle: style.copyWith(
                  fontFamily: FontFamily.yekanBakhRegular.asText,
                  fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
                ),
                normalStyle: style,
              );
              return formattedSpans;
            }
          }).toList();
          return subSpans.expand((e) => e).toList();
        }
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: AlignmentGeometry.centerLeft,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RichText(
            textAlign: TextAlign.left,
            text: TextSpan(children: spans.expand((e) => e).toList()),
          ),
        ),
      ),
    );
  }

  Widget _buildPersianLayout(
    List<TextSegmentPersian> translationTextSegments,
    String finalTopicId,
  ) {
    final List<TextSpan> spans = translationTextSegments.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)
      TextStyle style = TextStyle(
        fontSize: (item.isBold != null && item.isBold == true)
            ? Theme.of(context).textTheme.titleMedium!.fontSize
            : Theme.of(context).textTheme.bodyMedium!.fontSize,
        fontWeight: (item.isBold != null && item.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: (item.isBold != null && item.isBold == true)
            ? Colors.deepOrange
            : Theme.of(
                context,
              ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
        fontFamily: FontFamily.yekanBakhRegular.asText,
      );
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: style,
      );
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: AlignmentGeometry.centerRight,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(children: spans),
          ),
        ),
      ),
    );
  }

  // چیدمان دو ستونه (دو لیست اسکرول‌شونده مجزا)
  Widget _buildEnglishAndPersianLayout(
    bool isPersianFirst,
    List<TextSegmentEnglish> textSegmentsEnglish,
    List<TextSegmentPersian> translationTextSegments,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    final List<TextSpan> spans = translationTextSegments.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)
      TextStyle style = TextStyle(
        fontSize: (item.isBold != null && item.isBold == true)
            ? Theme.of(context).textTheme.titleMedium!.fontSize
            : Theme.of(context).textTheme.bodyMedium!.fontSize,
        fontWeight: (item.isBold != null && item.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: (item.isBold != null && item.isBold == true)
            ? Colors.deepOrange
            : Theme.of(
                context,
              ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
        fontFamily: FontFamily.yekanBakhRegular.asText,
      );
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: style,
      );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        // ردیف اول: متن اصلی
        isPersianFirst
            ? Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: AlignmentGeometry.centerRight,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: RichText(
                        textAlign: TextAlign.right,
                        text: TextSpan(children: spans),
                      ),
                    ),
                  ),
                ),
              )
            : Expanded(
                child: (widget.searchText == null)
                    ? _buildEnglishLayout(
                        textSegmentsEnglish,
                        sentenceStates,
                        finalTopicId,
                      )
                    : _buildEnglishLayoutForSearch(
                        textSegmentsEnglish,
                        sentenceStates,
                        finalTopicId,
                      ),
              ),
        const Divider(height: 8.0),
        // const SizedBox(height: 40),
        // ردیف دوم: ترجمه
        isPersianFirst
            ? Expanded(
                child: (widget.searchText == null)
                    ? _buildEnglishLayout(
                        textSegmentsEnglish,
                        sentenceStates,
                        finalTopicId,
                      )
                    : _buildEnglishLayoutForSearch(
                        textSegmentsEnglish,
                        sentenceStates,
                        finalTopicId,
                      ),
              )
            : Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: AlignmentGeometry.centerRight,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: RichText(
                        textAlign: TextAlign.right,
                        text: TextSpan(children: spans),
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildManualLayout(
    NavigationState nav,
    // AsyncValue allContent,
    bool isDualPane,
    List<TextSegmentEnglish> textSegmentsEnglish,
    List<TextSegmentPersian> textSegmentsPersian,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    final List<TextSpan> faSpans = textSegmentsPersian.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)
      TextStyle style = TextStyle(
        fontSize: (item.isBold != null && item.isBold == true)
            ? Theme.of(context).textTheme.titleMedium!.fontSize
            : Theme.of(context).textTheme.bodyMedium!.fontSize,
        fontWeight: (item.isBold != null && item.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: (item.isBold != null && item.isBold == true)
            ? Colors.deepOrange
            : Theme.of(
                context,
              ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
        fontFamily: FontFamily.yekanBakhRegular.asText,
      );
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: style,
      );
    }).toList();

    final List<TextSpan> enSpans = textSegmentsEnglish.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)
      TextStyle style = TextStyle(
        fontSize: (item.isBold != null && item.isBold == true)
            ? Theme.of(context).textTheme.titleMedium!.fontSize
            : Theme.of(context).textTheme.bodyMedium!.fontSize,
        fontWeight: (item.isBold != null && item.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: (item.isBold != null && item.isBold == true)
            ? Colors.deepOrange
            : Theme.of(
                context,
              ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
      );
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: style,
      );
    }).toList();

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
                itemCount: faSpans.length,
                itemBuilder: (context, index) {
                  TextSegmentPersian textSegmentPersianTempelate =
                      TextSegmentPersian(text: faSpans[index].text ?? '');
                  final microSegments = CfPublic()
                      .processSegmentsPersianTempelate([
                        textSegmentPersianTempelate,
                      ], widget.searchText ?? '');
                  final spans = microSegments.asMap().entries.map((entry) {
                    // final index = entry.key;
                    final ms = entry.value;
                    // final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
                    TextStyle style = TextStyle(
                      fontSize: (ms.isBold != null && ms.isBold == true)
                          ? Theme.of(context).textTheme.titleLarge!.fontSize
                          : Theme.of(context).textTheme.bodyLarge!.fontSize,
                      fontWeight: (ms.isBold != null && ms.isBold == true)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
                    );

                    // اعمال استایل جستجو (هایلایت پس‌زمینه زرد)
                    if (ms.isAmberHighlighted != null &&
                        ms.isAmberHighlighted == true) {
                      style = style.copyWith(
                        backgroundColor: Colors.amber.shade100,
                      );
                    }

                    final formattedSpans = UtilityPersian().buildMixedTextSpans(
                      ms.text.replaceAll('\\n', '\n'),
                      persianStyle: style.copyWith(
                        fontFamily: FontFamily.yekanBakhRegular.asText,
                        fontSize: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.fontSize,
                      ),
                      normalStyle: style,
                    );
                    return formattedSpans;
                  }).toList();
                  final spanList = spans.expand((e) => e).toList();
                  return ListItemTextSegmentSimple(
                    ref: ref,
                    isPersianTextSegment: true,
                    number: index + 1,
                    spans: spanList,
                    onTap: () async {
                      await _showPopupViewTempelate(
                        context,
                        ref,
                        index,
                        textSegmentsPersian[index],
                      ).then((value) {
                        if (value != null && value == true) {
                          if (nav.selectedFinalTopic != null) {
                            ref
                                .read(navigationProvider.notifier)
                                .updateTempelate(nav.selectedFinalTopic!);
                          } else if (widget.originalContent != null) {
                            ref
                                .read(navigationProvider.notifier)
                                .updateTempelateForSearchResult(
                                  widget.originalContent!,
                                );
                          }
                          _updateSearchListData();
                        }
                      });
                    },
                    onEdit: () async {
                      await _showPopupEditTempelate(
                        context,
                        ref,
                        index,
                        textSegmentsPersian[index],
                        // noteSpans[index].text!,
                      ).then((value) {
                        if (value != null && value == true) {
                          if (nav.selectedFinalTopic != null) {
                            ref
                                .read(navigationProvider.notifier)
                                .updateTempelate(nav.selectedFinalTopic!);
                          } else if (widget.originalContent != null) {
                            ref
                                .read(navigationProvider.notifier)
                                .updateTempelateForSearchResult(
                                  widget.originalContent!,
                                );
                          }
                          _updateSearchListData();
                        }
                      });
                    },
                    onDelete: () async {},
                  );
                },
              ),
            ),
          ),
        ),
        /*
        if (isDualPane)
          const Divider(height: 12.0, color: Colors.grey, thickness: 6.0),
        if (isDualPane)
          Expanded(
            child: Align(
              alignment: AlignmentGeometry.centerRight,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ListView.builder(
                  itemCount: enSpans.length,
                  itemBuilder: (context, index) {
                    TextSegmentEnglish textSegmentEnglish = TextSegmentEnglish(
                      text: enSpans[index].text ?? '',
                      isInteractive: false,
                    );
                    final microSegments = CfPublic().processSegmentsEnglish([
                      textSegmentEnglish,
                    ], widget.searchText ?? '');
                    final spans = microSegments.asMap().entries.map((entry) {
                      // final index = entry.key;
                      final ms = entry.value;
                      // final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
                      TextStyle style = TextStyle(
                        fontSize: (ms.isBold != null && ms.isBold == true)
                            ? Theme.of(context).textTheme.titleLarge!.fontSize
                            : Theme.of(context).textTheme.bodyLarge!.fontSize,
                        fontWeight: (ms.isBold != null && ms.isBold == true)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color, // استایل شرطی isInteractive
                      );

                      // اعمال استایل جستجو (هایلایت پس‌زمینه زرد)
                      if (ms.isAmberHighlighted != null &&
                          ms.isAmberHighlighted == true) {
                        style = style.copyWith(
                          backgroundColor: Colors.amber.shade100,
                        );
                      }

                      final formattedSpans = UtilityPersian()
                          .buildMixedTextSpans(
                            ms.text.replaceAll('\\n', '\n'),
                            persianStyle: style.copyWith(
                              fontFamily: FontFamily.yekanBakhRegular.asText,
                              fontSize: Theme.of(
                                context,
                              ).textTheme.bodyMedium!.fontSize,
                            ),
                            normalStyle: style,
                          );
                      return formattedSpans;
                    }).toList();
                    final spanList = spans.expand((e) => e).toList();
                    return ListItemTextSegmentSimple(
                      ref: ref,
                      isPersianTextSegment: false,
                      number: index + 1,
                      spans: spanList,
                      onTap: () {
                        ref.read(isEditModeProvider.notifier).state = false;
                      },
                      onEdit: () {
                        updateTempelate(
                          context,
                          index,

                          textSegmentsEnglish,
                          textSegmentsPersian,
                          // noteSpans,
                          nav,
                        );
                      },
                      onDelete: () async {},
                    );
                  },
                ),
              ),
            ),
          ),
      */
      ],
    );
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

  Widget _buildEnglishLayoutForSearch(
    List<TextSegmentEnglish> textSegmentsEnglish,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    // int interactiveIndex = 0;
    final microSegments = CfPublic().processSegmentsEnglish(
      textSegmentsEnglish,
      widget.searchText!,
    );
    // List<List<InlineSpan>>
    final spans = microSegments.asMap().entries.map((entry) {
      // final index = entry.key;
      final ms = entry.value;
      // final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
      TextStyle style = TextStyle(
        fontSize: (ms.isBold != null && ms.isBold == true)
            ? Theme.of(context).textTheme.titleLarge!.fontSize
            : Theme.of(context).textTheme.bodyLarge!.fontSize,
        fontWeight: (ms.isBold != null && ms.isBold == true)
            ? FontWeight.bold
            : FontWeight.normal,
        color: Theme.of(
          context,
        ).textTheme.bodySmall!.color, // استایل شرطی isInteractive
      );

      // اعمال استایل جستجو (هایلایت پس‌زمینه زرد)
      if (ms.isAmberHighlighted != null && ms.isAmberHighlighted == true) {
        style = style.copyWith(backgroundColor: Colors.amber.shade100);
      }
      if (ms.isInteractive) {
        style = style.copyWith(color: Theme.of(context).colorScheme.error);
      } else if (ms.isBlank != null) {
        style = style.copyWith(color: Colors.blueAccent);
      }

      if (ms.isInteractive) {
        final formattedSpans = UtilityPersian().buildMixedTextSpans(
          ms.text.replaceAll('\\n', '\n'),
          persianStyle: style.copyWith(
            fontFamily: FontFamily.yekanBakhRegular.asText,
            fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
          ),
          normalStyle: style,
        );
        return formattedSpans.map((e) {
          return TextSpan(
            text: e.text,
            style: e.style,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showPopupInteracticeSegmentDetails(
                  context,
                  ms.text,
                  ms.translation!,
                  ms.explanation!,
                );
              },
          );
        }).toList();
      } else {
        // return [TextSpan(text: ms.text.replaceAll('\\n', '\n'), style: style)];
        if (ms.hasSubItems == null) {
          final formattedSpans = UtilityPersian().buildMixedTextSpans(
            ms.text.replaceAll('\\n', '\n'),
            persianStyle: style.copyWith(
              fontFamily: FontFamily.yekanBakhRegular.asText,
              fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
            ),
            normalStyle: style,
          );
          return formattedSpans;
        } else {
          final subItemsAsTextSegmentEnglish = ms.subItems!.map((e) {
            return TextSegmentEnglish(
              text: e.text, //['text'] as String,
              isInteractive: e.isInteractive, //['isInteractive'] as bool,
              isBold: e.isBold, //['isBold'] as bool?,
              isBlank: e.isBlank, //['isBlank'] as bool?,
              translation: e.translation, //['translation'] as String?,
              explanation: e.explanation, //['explanation'] as String?,
              cerfLevel: e.cerfLevel, //['cerfLevel'] as String?,
              pronounce: e.pronounce, //['pronounce'] as String?,
              isRtl: e.isRtl, //['isRtl'] as bool?,
            );
          }).toList();
          final List<TextSegmentEnglish> subMicroSegments = CfPublic()
              .processSegmentsEnglish(
                CfPublic().fillGapsInFullText(
                  ms.text,
                  subItemsAsTextSegmentEnglish,
                ),
                widget.searchText!,
              );
          final subSpans = subMicroSegments.asMap().entries.map((entry) {
            // final index = entry.key;
            final subMs = entry.value;
            // final blankStatus = sentenceStates[index] ?? SentenceStatus.hide;
            TextStyle subStyle = style;

            if (subMs.isInteractive) {
              final formattedSpans = UtilityPersian().buildMixedTextSpans(
                subMs.text.replaceAll('\\n', '\n'),
                persianStyle: style.copyWith(
                  fontFamily: FontFamily.yekanBakhRegular.asText,
                  fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
                ),
                normalStyle: style,
              );
              return formattedSpans.map((e) {
                return TextSpan(
                  text: e.text,
                  style: e.style,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      _showPopupInteracticeSegmentDetails(
                        context,
                        subMs.text,
                        subMs.translation!,
                        subMs.explanation!,
                      );
                    },
                );
              }).toList();
            } else {
              final formattedSpans = UtilityPersian().buildMixedTextSpans(
                subMs.text.replaceAll('\\n', '\n'),
                persianStyle: style.copyWith(
                  fontFamily: FontFamily.yekanBakhRegular.asText,
                  fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
                ),
                normalStyle: style,
              );
              return formattedSpans;
            }
          }).toList();
          return subSpans.expand((e) => e).toList();
        }
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: AlignmentGeometry.centerLeft,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RichText(
            textAlign: TextAlign.left,
            text: TextSpan(children: spans.expand((e) => e).toList()),
          ),
        ),
      ),
    );
  }

  List<TextSegmentEnglish> processSubSegments(
    String fullText,
    List<TextSegmentEnglish> segments,
    List<String> searchQueries,
  ) {
    // ساخت متن کامل
    final List<TextSegmentEnglish> microSegments = [];
    int currentTextIndex = 0;

    // 1️⃣ همه‌ی تطابق‌ها رو از تمام عبارت‌های جستجو پیدا می‌کنیم
    final List<Match> allMatches = [];

    for (final query in searchQueries) {
      if (query.trim().isEmpty) continue;
      final matches = RegExp(
        RegExp.escape(query),
        caseSensitive: false,
      ).allMatches(fullText);
      allMatches.addAll(matches);
    }

    // در صورتی که چند عبارت داریم، مرتبشون می‌کنیم بر اساس موقعیت در متن
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    if (allMatches.isEmpty) {
      // هیچ تطابقی وجود نداره، فقط استایل پایه رو اعمال کن
      return segments;
    }

    // 2️⃣ حالا روی segmentها پیمایش می‌کنیم مثل قبل
    for (final segment in segments) {
      final segmentText = segment.text;
      final originText = segment.isInteractive ? segmentText : null;
      final segmentStart = currentTextIndex;
      final segmentEnd = currentTextIndex + segmentText.length;

      int segmentPos = 0;

      for (final match in allMatches) {
        final matchStart = match.start;
        final matchEnd = match.end;

        if (segmentStart < matchEnd && matchStart < segmentEnd) {
          // 🔹 بخش قبل از هایلایت
          final nonHighlightStart = segmentStart + segmentPos;
          final nonHighlightEnd = matchStart.clamp(segmentStart, segmentEnd);

          if (nonHighlightEnd > nonHighlightStart) {
            final startInSegment = nonHighlightStart - segmentStart;
            final endInSegment = nonHighlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentEnglish(
                text: text,
                originText: originText,
                isInteractive: segment.isInteractive,
                isBold: segment.isBold,
                isBlank: segment.isBlank,
                hasSubItems: segment.hasSubItems,
                subItems: segment.subItems,
                translation: segment.translation,
                explanation: segment.explanation,
              ),
            );
            segmentPos = endInSegment;
          }

          // 🔹 بخش هایلایت‌شده
          final highlightStart = matchStart.clamp(segmentStart, segmentEnd);
          final highlightEnd = matchEnd.clamp(segmentStart, segmentEnd);

          if (highlightEnd > highlightStart) {
            final startInSegment = highlightStart - segmentStart;
            final endInSegment = highlightEnd - segmentStart;
            final text = segmentText.substring(startInSegment, endInSegment);
            microSegments.add(
              TextSegmentEnglish(
                text: text,
                originText: originText,
                isInteractive: segment.isInteractive,
                isBold: segment.isBold,
                isBlank: segment.isBlank,
                hasSubItems: segment.hasSubItems,
                subItems: segment.subItems,
                translation: segment.translation,
                explanation: segment.explanation,
                isAmberHighlighted: true, // اعمال هایلایت
              ),
            );
            segmentPos = endInSegment;
          }
        }
      }

      // 🔹 بخش باقیمانده بعد از آخرین تطابق
      if (segmentPos < segmentText.length) {
        microSegments.add(
          TextSegmentEnglish(
            text: segmentText.substring(segmentPos),
            originText: originText,
            isInteractive: segment.isInteractive,
            isBold: segment.isBold,
            isBlank: segment.isBlank,
            hasSubItems: segment.hasSubItems,
            subItems: segment.subItems,
            translation: segment.translation,
            explanation: segment.explanation,
          ),
        );
      }

      currentTextIndex += segmentText.length;
    }

    return microSegments;
  }

  void _showPopupInteracticeSegmentDetails(
    BuildContext context,
    String text,
    String translation,
    String explanation,
  ) {
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

  Future<FinalTopic?> _showPopupAddTempelate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            onSubmit: (textSegmentPersian) async {
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/Day 00/Content';
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
  ) async {
    ref.read(isEditModeProvider.notifier).state = false;
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ViewTempelateWidget(
            onUpdate: (textSegmentPersian) async {
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/Day 00/Content';
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
              final result = await CfPublic()
                  .updatePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    index: index,
                    textSegmentPersian: textSegmentPersian,
                  );
              if (result != null) {
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },
            onDelete: () async {
              String q = 'آیا از حذف این قالب اطمینان دارید؟';
              bool? response = await CfPublic().showQuestionDialog(context, q);
              if (response == null || response == false) {
                return;
              }
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/Day 00/Content';
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
              final result = await CfPublic().deleteTempelate(
                faFileName,
                index,
              );
              if (result != null) {
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },
            persianTextSegment: textSegmentPersian,
          ),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as bool;
    } else {
      return false;
    }
  }

  Future<bool?> _showPopupEditTempelate(
    BuildContext context,
    WidgetRef ref,
    int index,
    TextSegmentPersian textSegmentPersian,
  ) async {
    final dialogResult = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: AddOrEditTempelate(
            onSubmit: (textSegmentPersian) async {
              final rootPath = ref.read(settingsProvider);
              String newTemplateDirectory =
                  '$rootPath/قالبهای موقعیتی/Band 4–5/Days/Day 00/Content';
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
              final result = await CfPublic()
                  .updatePersianTextSegmentToExternalStorage(
                    fileName: faFileName,
                    index: index,
                    textSegmentPersian: textSegmentPersian,
                  );
              if (result != null) {
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },

            persianTextSegment: textSegmentPersian,
          ),
        );
      },
    );
    if (dialogResult != null) {
      return dialogResult as bool;
    } else {
      return false;
    }
  }
}
