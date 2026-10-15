import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/reader/readable/readable_transform.dart';
import 'package:ielts_assistant/features/settings/providers/reading_mode_provider.dart';

// 🌟 RM-1: انتخابِ «مطابقِ کتاب / خوانا» و اندازه‌ی متن — هم در پنجره‌ی «Aa»ِ نوارِ بالای
// کتاب (تغییر همان لحظه زیرِ پنجره دیده می‌شود) و هم در تنظیمات.

Future<void> showReadingAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // زمینه‌ی کم‌رنگ تا صفحه‌ی زیرِ پنجره (و اثرِ تغییر) دیده شود
    barrierColor: Colors.black12,
    builder: (_) => const Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ReadingAppearanceControls(),
        ),
      ),
    ),
  );
}

class ReadingAppearanceControls extends ConsumerWidget {
  const ReadingAppearanceControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReadingAppearance a = ref.watch(readingAppearanceProvider);
    final notifier = ref.read(readingAppearanceProvider.notifier);
    final TextStyle hint = TextStyle(fontSize: 12, color: Colors.grey.shade600);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ReadingMode>(
          segments: const [
            ButtonSegment(
              value: ReadingMode.book,
              icon: Icon(Icons.menu_book_rounded, size: 18),
              label: Text('مطابقِ کتاب'),
            ),
            ButtonSegment(
              value: ReadingMode.readable,
              icon: Icon(Icons.chrome_reader_mode_rounded, size: 18),
              label: Text('خوانا'),
            ),
          ],
          selected: {a.mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => notifier.setMode(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          a.readable
              ? 'متنِ درشت‌تر و یکدست با فاصله‌ی خطِ راحت؛ روی گوشی جدول‌های عریض زیرِ هم می‌آیند تا اسکرولِ افقی لازم نباشد. چیدمان با کتاب فرق می‌کند.'
              : 'دقیقاً مثلِ صفحه‌های کتاب: همان اندازه‌ها، جدول‌ها و چیدمان. برای بزرگ‌کردن، با دو انگشت زوم کنید.',
          style: hint.copyWith(height: 1.7),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('اندازه‌ی متن'),
                  const Spacer(),
                  Text('${(a.fontScale * 100).round()}٪', style: hint),
                ],
              ),
              Row(
                children: [
                  const Text('A', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: a.fontScale,
                      min: ReadingAppearanceNotifier.minScale,
                      max: ReadingAppearanceNotifier.maxScale,
                      divisions:
                          ((ReadingAppearanceNotifier.maxScale -
                                      ReadingAppearanceNotifier.minScale) /
                                  0.05)
                              .round(),
                      onChanged: notifier.setFontScale,
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 22)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Reading is to the mind what exercise is to the body.',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Source Sans 3',
                    fontSize: kReadableBodyPx * a.fontScale,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          crossFadeState: a.readable
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
