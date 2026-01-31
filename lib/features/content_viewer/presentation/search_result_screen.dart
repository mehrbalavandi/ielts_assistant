import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/content_viewer/providers/sentence_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/customer_search_delegate.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/utility_persian.dart';

// پرووایدر برای مدیریت حالت تک‌ستونه یا دو ستونه
final isDualPaneProviderSearchResult = StateProvider<bool>((ref) => false);

class SearchResultScreen extends ConsumerStatefulWidget {
  final OriginalContent originalContent;
  final SearchResultSegments searchResultSegments;
  final String searchText;
  const SearchResultScreen({
    super.key,
    required this.originalContent,
    required this.searchResultSegments,
    required this.searchText,
  });

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen> {
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
    final isDualPane = ref.watch(isDualPaneProviderSearchResult);
    final String finalTopicId = widget.originalContent.finalTopic.name;

    // استفاده از پروایدر به صورت family
    // دقت کنید که topicId را داخل پرانتز جلوی پروایدر می‌نویسیم
    final sentenceStates = ref.watch(sentenceProvider(finalTopicId));
    return PopScope(
      canPop:
          true, //ref.read(isPlayerExpandedProvider.notifier).state == false,
      onPopInvokedWithResult: (didPop, result) {
        // if (didPop) {
        //   ref.read(isPlayerExpandedProvider.notifier).state = false;
        //   return;
        // }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          title: Text(
            '${widget.originalContent.book.replaceAll('قالبهای موقعیتی', 'قالبها')}>${widget.originalContent.unit.replaceAll('Unit ', 'U ')}>${widget.originalContent.page.replaceAll('Page ', 'P ')}>${widget.originalContent.finalTopic.name.substring(widget.originalContent.finalTopic.name.indexOf(' ') + 1)}',
            style: TextStyle(
              // fontFamily: FontFamily.yekanBakhBold.asText,
              fontSize: 16.0,
              // color: Theme.of(context).colorScheme.primary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(isDualPane ? Icons.view_stream : Icons.view_column),
              onPressed: () =>
                  ref.read(isDualPaneProviderSearchResult.notifier).state =
                      !isDualPane,
              tooltip: 'تغییر چیدمان متن',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: isDualPane
                  ? _buildEnglishAndPersianLayout(
                      widget.originalContent.book.contains('قالبهای موقعیتی'),
                      widget.searchResultSegments.enSegments,
                      widget.searchResultSegments.faSegments,
                      sentenceStates,
                      finalTopicId,
                    )
                  : widget.originalContent.book.contains('قالبهای موقعیتی')
                  ? _buildPersianLayout(
                      widget.searchResultSegments.faSegments,
                      finalTopicId,
                    )
                  : _buildEnglishLayout(
                      widget.searchResultSegments.enSegments,
                      sentenceStates,
                      finalTopicId,
                    ),
            ),
            // مینی پلیر که قابلیت باز و بسته شدن دارد
            // const ExpandableMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnglishLayout(
    List<TextSegmentEnglish> textSegmentsEnglish,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    // int interactiveIndex = 0;
    final microSegments = _processSegments(
      textSegmentsEnglish,
      widget.searchText,
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
                _showPopup(context, ms.text, ms.translation!, ms.explanation!);
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
          final subItemsAsMainTextSegment = ms.subItems!.map((e) {
            return TextSegmentEnglish(
              text: e['text'] as String,
              isInteractive: e['isInteractive'] as bool,
              isBold: e['isBold'] as bool?,
              isBlank: e['isBlank'] as bool?,
              hasSubItems: false,
              subItems: null,
              translation: e['translation'] as String?,
              explanation: e['explanation'] as String?,
              cerfLevel: e['cerfLevel'] as String?,
              pronounce: e['pronounce'] as String?,
              isRtl: e['isRtl'] as bool?,
            );
          }).toList();
          final List<TextSegmentEnglish> subMicroSegments = _processSegments(
            CfPublic().fillGapsInFullText(ms.text, subItemsAsMainTextSegment),
            widget.searchText,
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
                      _showPopup(
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
      bool isBold = (item.isBold != null && item.isBold == true);
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: TextStyle(
          color: isBold
              ? Colors.deepOrange
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isBold ? FontWeight.bold : null,
          fontSize: isBold ? 17.0 : 17.0,
        ),
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
    final spanss = translationTextSegments.asMap().entries.map((entry) {
      return <List<InlineSpan>>[];
    }).toList();
    final spans = translationTextSegments.map((item) {
      // ساخت یک String برای نمایش، شامل isActive (اگر null نباشد)
      bool isBold = (item.isBold != null && item.isBold == true);
      return TextSpan(
        text: item.text.replaceAll('\\n', '\n'), // اعمال استایل بر اساس status
        style: TextStyle(
          color: isBold
              ? Colors.deepOrange
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isBold ? FontWeight.bold : null,
          fontSize: isBold ? 17.0 : 17.0,
        ),
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
                child: _buildEnglishLayout(
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
                child: _buildEnglishLayout(
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

  List<TextSegmentEnglish> _processSegments(
    List<TextSegmentEnglish> segments,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      // اگر جستجویی نیست، همان segments اصلی را برگردانید.
      return segments;
    }
    // .asMap().entries.map((entry) {
    //       final index = entry.key;
    //       final status = sentenceStates[index] ?? SentenceStatus.hide;
    final fullText = segments.map((s) => s.text).join();
    final List<TextSegmentEnglish> microSegments = [];
    int currentTextIndex = 0;

    // 1. پیدا کردن تمامی تطابق‌های عبارت جستجو
    final matches = RegExp(
      searchQuery,
      caseSensitive: false,
    ).allMatches(fullText).toList();

    if (matches.isEmpty) {
      // اگر تطابقی پیدا نشد، همان segments اصلی را برگردانید.
      return segments;
    }

    // 2. تکرار بر روی segments اصلی و اعمال شکستگی
    for (final segment in segments) {
      final segmentText = segment.text;
      final originText = segment.isInteractive ? segmentText : null;
      final segmentStart = currentTextIndex;
      final segmentEnd = currentTextIndex + segmentText.length;

      int segmentCurrentPosition = 0; // پوزیشن داخلی در segmentText

      // بررسی تداخل این segment با هر یک از نتایج جستجو
      for (final match in matches) {
        final matchStart = match.start;
        final matchEnd = match.end;

        // بررسی تداخل
        if (segmentStart < matchEnd && segmentEnd > matchStart) {
          // 1. قسمت قبل از هایلایت (اگر وجود دارد)
          final nonHighlightStart = segmentStart + segmentCurrentPosition;
          final nonHighlightEnd = matchStart > segmentStart
              ? matchStart
              : segmentStart;

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
            segmentCurrentPosition = endInSegment;
          }

          // 2. قسمت هایلایت شده (بخشی از تطابق که در این segment قرار دارد)
          final highlightStart = matchStart > segmentStart
              ? matchStart
              : segmentStart;
          final highlightEnd = matchEnd < segmentEnd ? matchEnd : segmentEnd;

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
            segmentCurrentPosition = endInSegment;
          }
        }
      }

      // 3. قسمت باقی‌مانده از segment بعد از آخرین تطابق (اگر وجود دارد)
      if (segmentCurrentPosition < segmentText.length) {
        final text = segmentText.substring(segmentCurrentPosition);
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
      }

      currentTextIndex += segmentText.length;
    }

    return microSegments;
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

  void _showPopup(
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

  // ویجت رندر کننده در فلاتر
}
