import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/content_viewer/data/models.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import '../../home/providers/navigation_provider.dart';
import '../../audio_player/presentation/widgets/mini_audio_player.dart';

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

  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هشدار'),
        content: const Text('آیا از انجام این عملیات اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تایید'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationProvider);
    final isDualPane = ref.watch(isDualPaneProvider);
    final selectedTopic = nav.selectedTopic;
    final mainTextSegments = nav.currentEnglishSegments ?? <MainTextSegment>[];
    final persianTextSegments =
        nav.currentPersianTextSegments ?? <PersianTextSegment>[];

    if (selectedTopic == null) {
      return const Scaffold(body: Center(child: Text('درسی انتخاب نشده است')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedTopic.name),
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
                  )
                : _buildOnlyEnglishLayout(mainTextSegments),
          ),
          // مینی پلیر که قابلیت باز و بسته شدن دارد
          const ExpandableMiniPlayer(),
        ],
      ),
    );
  }

  // چیدمان تک ستونه (انگلیسی بالای فارسی)
  Widget _buildOnlyEnglishLayout(List<MainTextSegment> mainTexSegments) {
    int interactiveIndex = 0;
    final List<InlineSpan> spans = mainTexSegments.map((item) {
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
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }

  // چیدمان دو ستونه (دو لیست اسکرول‌شونده مجزا)
  Widget _buildBothEnglishAndPersianLayout(
    List<MainTextSegment> mainTexSegments,
    List<PersianTextSegment> translationTextSegments,
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
        Expanded(child: _buildOnlyEnglishLayout(mainTexSegments)),
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

  Widget _buildEnglishSection(List<MainTextSegment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "English Content",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "This is the English text of the lesson. It can be very long and scrollable...",
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _showWarningDialog(context),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('عملیات حساس'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildPersianSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "متن فارسی",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "این متن ترجمه فارسی درس است که در حالت دو ستونه به صورت مجزا اسکرول می‌شود.",
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
      ],
    );
  }

  String normalizeText(String text) {
    return text.replaceAll('\\n', '\n');
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
