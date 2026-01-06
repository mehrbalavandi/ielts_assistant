import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
    final topic = nav.selectedTopic;

    if (topic == null) {
      return const Scaffold(body: Center(child: Text('درسی انتخاب نشده است')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.name),
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
          Expanded(child: isDualPane ? _buildDualPane() : _buildSinglePane()),
          // مینی پلیر که قابلیت باز و بسته شدن دارد
          const ExpandableMiniPlayer(),
        ],
      ),
    );
  }

  // چیدمان تک ستونه (انگلیسی بالای فارسی)
  Widget _buildSinglePane() {
    return ListView(
      controller: _englishController, // استفاده از کنترلر مشترک برای حفظ موقعیت
      padding: const EdgeInsets.all(16),
      children: [
        _buildEnglishSection(),
        const Divider(height: 40),
        _buildPersianSection(),
      ],
    );
  }

  // چیدمان دو ستونه (دو لیست اسکرول‌شونده مجزا)
  Widget _buildDualPane() {
    return Row(
      children: [
        Expanded(
          child: ListView(
            controller: _englishController,
            padding: const EdgeInsets.all(16),
            children: [_buildEnglishSection()],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListView(
            controller: _persianController,
            padding: const EdgeInsets.all(16),
            children: [_buildPersianSection()],
          ),
        ),
      ],
    );
  }

  Widget _buildEnglishSection() {
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
}
