import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/settings/providers/word_card_provider.dart';

// 🌟 W-3: انتخابِ فیلدهای پنجره‌ی دیکشنری — هم در تنظیمات و هم از دکمه‌ی کوچکِ
// «تنظیم» داخلِ خودِ پنجره. فقط فیلدهای مشترک و فیلدهای زبانِ فعال دیده می‌شوند.

Future<void> showWordCardSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: WordCardControls(showTitle: true),
        ),
      ),
    ),
  );
}

class WordCardControls extends ConsumerWidget {
  const WordCardControls({super.key, this.showTitle = false});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String lang = ref.watch(languageProvider);
    final bool ar = lang == 'ar';
    final WordCardFields fields = ref.watch(wordCardProvider);
    final notifier = ref.read(wordCardProvider.notifier);
    final TextStyle hint = TextStyle(fontSize: 12, color: Colors.grey.shade600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              ar ? 'حقول نافذة القاموس' : 'فیلدهای پنجره‌ی دیکشنری',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        Text(
          ar
              ? 'تظهر هنا الحقول المشتركة وحقول اللغة العربية فقط. لتغيير حقول الفارسية غيّر لغة التطبيق.'
              : 'فیلدهای مشترک و فیلدهای زبانِ فارسی. برای فیلدهای عربی، زبانِ اپ را عربی کنید.',
          style: hint.copyWith(height: 1.6),
        ),
        for (final WordField f in WordField.forLanguage(lang))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(f.label(lang)),
            subtitle: f.hint.isEmpty || ar ? null : Text(f.hint, style: hint),
            value: fields.shows(f),
            onChanged: (v) => notifier.toggle(f, v ?? false),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(ar ? 'إظهار الكل' : 'نمایشِ همه'),
          ),
        ),
      ],
    );
  }
}
