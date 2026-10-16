import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';
import 'package:ielts_assistant/features/settings/providers/audio_settings_provider.dart';
import 'package:ielts_assistant/features/settings/presentation/reading_appearance_sheet.dart';
import 'package:ielts_assistant/features/settings/presentation/word_card_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _box = GetStorage();

  @override
  void initState() {
    super.initState();
    // لود کردن آدرس قبلی
    _urlController.text = _box.read('base_url') ?? 'http://10.110.198.220:8000';
  }

  void _saveSettings() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      StorageService.saveBaseUrl(url);
      ref.invalidate(dioProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('آدرس سرور با موفقیت ذخیره شد')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً آدرس سرور را وارد کنید')),
      );
    }
    /*
    final activeBook = ref.watch(activeBookProvider);

    if (activeBook != null) {
      // اگر کتاب فعال وجود دارد، به صفحه اصلی کتاب برو
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ReaderScreen()),
        (route) => false,
      );
    } else {
      // اگر کتاب فعال وجود ندارد، به صفحه ویترین برو
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
        (route) => false,
      );
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    final answerDisplay = ref.watch(answerDisplayProvider);
    final answerNotifier = ref.read(answerDisplayProvider.notifier);
    final audioStart = ref.watch(audioStartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("تنظیمات سیستم")),
      // 🌟 ListView به‌جای Column وسط‌چین: با بخشِ «نمایشِ پاسخ‌ها» صفحه از ارتفاعِ
      // گوشی بلندتر می‌شود.
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Icon(Icons.cloud_sync_rounded, size: 64, color: Colors.indigo),
          const SizedBox(height: 16),

          const Text(
            "آدرس سرور مرکزی",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: "مثال: http://10.110.198.220:8000",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("ذخیره آدرس سرور", style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // 🌟 RM-1: شیوه‌ی نمایشِ کتاب و اندازه‌ی متن
          const Row(
            children: [
              Icon(Icons.text_fields_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                "شیوه‌ی نمایشِ کتاب",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ReadingAppearanceControls(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // 🌟 H-5: شیوه‌ی نمایشِ جوابِ پشتِ آیکونِ چشم، جدا برای کوتاه و بلند.
          // انتخاب فوراً ذخیره و اعمال می‌شود (دکمه‌ی ذخیره لازم نیست).
          const Row(
            children: [
              Icon(Icons.visibility_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                "نمایشِ پاسخ‌ها",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "پاسخ‌های پنهان (آیکونِ چشم) کجا باز شوند؟ تغییر فوراً اعمال می‌شود.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _AnswerModePicker(
            title: "پاسخ‌های کوتاه",
            hint: "یک کلمه یا عبارتِ کوتاه (کمتر از ۴۰ حرف)",
            value: answerDisplay.short,
            onChanged: answerNotifier.setShort,
          ),
          const SizedBox(height: 20),
          _AnswerModePicker(
            title: "پاسخ‌های بلند",
            hint: "جمله و پاراگراف، فهرست، جدول و تصویر",
            value: answerDisplay.long,
            onChanged: answerNotifier.setLong,
          ),

          // 🌟 TR-1: ترجمه‌ی پاراگراف با لمسِ طولانی.
          const SizedBox(height: 32),
          const Row(
            children: [
              Icon(Icons.translate_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                "نمایشِ ترجمه",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "با لمسِ طولانی روی هر پاراگراف، ترجمه‌اش کجا باز شود؟ تا ترجمه باز است، خودِ پاراگراف رنگی می‌شود.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _AnswerModePicker(
            title: "ترجمه‌ی پاراگراف",
            hint: "داخلِ پنجره‌ی پاسخ‌ها، ترجمه همان‌جا زیرِ پاسخ باز می‌شود (دکمه‌ی ترجمه یا لمسِ طولانی).",
            value: answerDisplay.translation,
            onChanged: answerNotifier.setTranslation,
            describe: (m) => m.translationDescription,
          ),

          // 🌟 W-3: فیلدهای پنجره‌ی دیکشنری (کلماتِ تعاملی).
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                "پنجره‌ی دیکشنری",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const WordCardControls(),

          // 🌟 H-8/H-9: تنظیماتِ خودِ پاپ‌آپ (مشترک بینِ پاسخ و ترجمه). وقتی هیچ‌کدام
          // «پاپ‌آپ» نیست، کم‌رنگ می‌شود (ولی قابلِ تغییر می‌ماند تا بعداً آماده باشد).
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Opacity(
            opacity: answerDisplay.usesPopup ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "پاپ‌آپ",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "برای پاسخ‌ها و ترجمه‌ها. جهتِ بازشدن نسبت به آیکونِ چشم یا پاراگراف",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<AnswerPopupDirection>(
                  segments: [
                    for (final d in AnswerPopupDirection.values)
                      ButtonSegment<AnswerPopupDirection>(
                        value: d,
                        icon: Icon(d.icon, size: 18),
                        label: Text(d.label),
                      ),
                  ],
                  selected: {answerDisplay.popupDirection},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      answerNotifier.setPopupDirection(s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (answerDisplay.popupDirection) {
                    AnswerPopupDirection.auto =>
                      'زیر، مگر آن‌جا جا کم باشد؛ آن‌وقت بالا.',
                    AnswerPopupDirection.above =>
                      'بالا؛ فقط اگر بالا واقعاً جا نباشد (اولِ صفحه)، پایین.',
                    AnswerPopupDirection.below =>
                      'پایین؛ فقط اگر پایین واقعاً جا نباشد (تهِ صفحه)، بالا.',
                  },
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("هر بار فقط یک پاپ‌آپ"),
                  subtitle: Text(
                    answerDisplay.singlePopup
                        ? "بازکردنِ پاسخ یا ترجمه‌ی تازه، پاپ‌آپِ قبلی را می‌بندد. لمس یا کلیک هرجای بیرونِ حباب هم آن را می‌بندد."
                        : "چند پاسخ و ترجمه کنارِ هم باز می‌مانند؛ هرکدام با لمسِ دوباره‌ی آیکونش (یا لمسِ طولانیِ دوباره‌ی پاراگراف) بسته می‌شود، و دکمه‌ی «بستنِ همه‌ی پاپ‌آپ‌ها» پایینِ صفحه همه را یکجا می‌بندد.",
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: answerDisplay.singlePopup,
                  onChanged: answerNotifier.setSinglePopup,
                ),
              ],
            ),
          ),

          // 🌟 AU-1: فایلِ صوتی از ابتدا یا از آخرین نقطه.
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.headphones_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                "پخشِ فایل‌های صوتی",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "وقتی فایلی را از متن یا فهرستِ پخش باز می‌کنید، از کجا پخش شود؟ «قبلی/بعدی» و پخشِ پیوسته همیشه از ابتدای فایل است.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AudioStartMode>(
            segments: const [
              ButtonSegment<AudioStartMode>(
                value: AudioStartMode.resume,
                icon: Icon(Icons.history_rounded, size: 18),
                label: Text("از آخرین نقطه"),
              ),
              ButtonSegment<AudioStartMode>(
                value: AudioStartMode.fromStart,
                icon: Icon(Icons.replay_rounded, size: 18),
                label: Text("از ابتدا"),
              ),
            ],
            selected: {audioStart},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(audioStartProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 6),
          Text(
            audioStart.description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// انتخابِ یکی از سه شیوه‌ی نمایش + توضیحِ کوتاهِ شیوه‌ی انتخاب‌شده.
class _AnswerModePicker extends StatelessWidget {
  final String title;
  final String hint;
  final AnswerDisplayMode value;
  final ValueChanged<AnswerDisplayMode> onChanged;

  /// توضیحِ شیوه‌ی انتخاب‌شده (پیش‌فرض: توضیحِ نمایشِ پاسخ).
  final String Function(AnswerDisplayMode mode)? describe;

  const _AnswerModePicker({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.describe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        SegmentedButton<AnswerDisplayMode>(
          segments: [
            for (final mode in AnswerDisplayMode.values)
              ButtonSegment<AnswerDisplayMode>(
                value: mode,
                icon: Icon(mode.icon, size: 18),
                label: Text(mode.label),
              ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 6),
        Text(
          describe?.call(value) ?? value.description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
