import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/content_viewer/providers/sentence_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import '../../home/providers/navigation_provider.dart';

// پرووایدر برای مدیریت حالت تک‌ستونه یا دو ستونه
final isDualPaneProvider = StateProvider<bool>((ref) => false);

class TopicDetailScreen extends ConsumerStatefulWidget {
  const TopicDetailScreen({super.key});

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
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
    final nav = ref.watch(navigationProvider);
    final isDualPane = ref.watch(isDualPaneProvider);
    final selectedFinalTopic = nav.selectedTopic;
    final mainTextSegments = nav.currentEnglishSegments ?? <MainTextSegment>[];
    final persianTextSegments =
        nav.currentPersianTextSegments ?? <PersianTextSegment>[];

    if (selectedFinalTopic == null) {
      return const Scaffold(body: Center(child: Text('درسی انتخاب نشده است')));
    }
    final String finalTopicId = selectedFinalTopic.name;

    // استفاده از پروایدر به صورت family
    // دقت کنید که topicId را داخل پرانتز جلوی پروایدر می‌نویسیم
    final sentenceStates = ref.watch(sentenceProvider(finalTopicId));
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedFinalTopic.name),
        actions: [
          IconButton(
            icon: Icon(isDualPane ? Icons.view_stream : Icons.view_column),
            onPressed: () =>
                ref.read(isDualPaneProvider.notifier).state = !isDualPane,
            tooltip: 'تغییر چیدمان متن',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isDualPane
                ? _buildBothEnglishAndPersianLayout(
                    mainTextSegments,
                    persianTextSegments,
                    sentenceStates,
                    finalTopicId,
                  )
                : _buildOnlyEnglishLayout(
                    mainTextSegments,
                    sentenceStates,
                    finalTopicId,
                  ),
          ),
          // مینی پلیر که قابلیت باز و بسته شدن دارد
          const ExpandableMiniPlayer(),
        ],
      ),
    );
  }

  // چیدمان تک ستونه (انگلیسی بالای فارسی)
  Widget _buildOnlyEnglishLayout(
    List<MainTextSegment> mainTexSegments,
    Map<int, SentenceStatus> sentenceStates,
    String finalTopicId,
  ) {
    int interactiveIndex = 0;
    final List<List<InlineSpan>> spans = mainTexSegments.asMap().entries.map((
      entry,
    ) {
      final index = entry.key;
      final item = entry.value;

      // وضعیت رنگ این جمله خاص
      final status = sentenceStates[index] ?? SentenceStatus.hide;
      if (item.isInteractive) {
        return [
          TextSpan(
            text: '(${++interactiveIndex})${item.text}'.replaceAll(
              '\\n',
              '\n',
            ), // اعمال استایل بر اساس status
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showPopup(
                  context,
                  item.text,
                  item.translation!,
                  item.explanation!,
                );
                ref
                    .read(sentenceProvider(finalTopicId).notifier)
                    .toggleStatus(index);
              },
          ),
        ];
      } else if (item.isBlank != null && item.isBlank == true) {
        if (status == SentenceStatus.hide) {
          return [
            TextSpan(
              text: " ________ ", // نمایش جاخالی
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                backgroundColor:
                    Colors.black12, // هایلایت ملایم برای مشخص بودن جای کلیک
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => ref
                    .read(sentenceProvider(finalTopicId).notifier)
                    .toggleStatus(index),
            ),
          ];
        } else if (item.hasSubItems != null && item.hasSubItems == true) {
          if (item.subItems != null) {
            final List<dynamic> jsonFormat = jsonDecode(item.subItems!);
            final subSegments = jsonFormat
                .map(
                  (json) =>
                      MainTextSegment.fromJson(json as Map<String, dynamic>),
                )
                .toList();
            if (subSegments.isNotEmpty) {
              final List<InlineSpan> subSpans = subSegments.map((item) {
                if (item.isInteractive) {
                  return TextSpan(
                    text: '(${++interactiveIndex})${item.text}'.replaceAll(
                      '\\n',
                      '\n',
                    ), // اعمال استایل بر اساس status
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _showPopup(
                          context,
                          item.text,
                          item.translation!,
                          item.explanation!,
                        );
                      },
                  );
                } else {
                  return TextSpan(
                    text: item.text.replaceAll(
                      '\\n',
                      '\n',
                    ), // اعمال استایل بر اساس status
                    style: (item.isBold != null && item.isBold == true)
                        ? TextStyle(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            // fontStyle: FontStyle.italic,
                            fontSize: 20.0,
                          )
                        : TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20.0,
                          ),
                  );
                }
              }).toList();
              return subSpans;
            }
          }
        }
        return [TextSpan(text: '')];
      } else {
        return [
          TextSpan(
            text: item.text.replaceAll(
              '\\n',
              '\n',
            ), // اعمال استایل بر اساس status
            style: (item.isBold != null && item.isBold == true)
                ? TextStyle(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    // fontStyle: FontStyle.italic,
                    fontSize: 20.0,
                  )
                : TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20.0,
                  ),
          ),
        ];
      }
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(children: spans.expand((e) => e).toList()),
        ),
      ),
    );
  }

  // چیدمان دو ستونه (دو لیست اسکرول‌شونده مجزا)
  Widget _buildBothEnglishAndPersianLayout(
    List<MainTextSegment> mainTexSegments,
    List<PersianTextSegment> translationTextSegments,
    Map<int, SentenceStatus> sentenceStates,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // ✅ تغییر به Column برای نمایش بالا و پایین
      children: [
        // ردیف اول: متن اصلی
        Expanded(
          child: _buildOnlyEnglishLayout(
            mainTexSegments,
            sentenceStates,
            finalTopicId,
          ),
        ),
        const Divider(height: 20),
        // ردیف دوم: ترجمه
        Expanded(
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
}
