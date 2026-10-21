import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';
import 'package:ielts_assistant/features/audio/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/audio/domain/audio_skill.dart';
import 'package:ielts_assistant/shared/widgets/outline_group_widgets.dart';

// 🌟 AU-8 (RULES-rendering.md): تایمرِ توقفِ پلیر، مثلِ Musicolet — توقف بعد از یک مدت، بعد از
// پایانِ N فایل، یا بعد از پایانِ یک فایلِ مشخص. منطقش در AudioPlayerNotifier است؛ این‌جا دکمه و
// برگه‌ی انتخاب.

/// دکمه‌ی تایمر در نوارِ کنترل‌های پلیر. وقتی تایمری فعال است، رنگی است و زمان یا تعدادِ
/// فایل‌های مانده را کنارش نشان می‌دهد.
class SleepTimerButton extends ConsumerStatefulWidget {
  const SleepTimerButton({
    super.key,
    required this.activeColor,
    required this.idleColor,
  });

  final Color activeColor;
  final Color idleColor;

  @override
  ConsumerState<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends ConsumerState<SleepTimerButton> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// شمارشِ معکوسِ زمان هر ثانیه بازسازی می‌شود (حتی وقتی پخش مکث است).
  void _ensureTicking(bool needed) {
    if (needed && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AudioPlayerState s = ref.watch(audioPlayerProvider);
    _ensureTicking(s.sleepAt != null);
    final String? label = sleepTimerShortLabel(s);
    final bool active = s.sleepTimerActive;
    final Color c = active ? widget.activeColor : widget.idleColor;
    return Tooltip(
      message: active ? 'تایمرِ توقف: $label' : 'تایمرِ توقف',
      child: InkResponse(
        radius: 22,
        onTap: () => showSleepTimerSheet(context),
        // جمع‌وجور (آیکون و زیرش زمانِ مانده)، چون نوارِ کنترل‌ها روی گوشی جای زیادی ندارد.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                color: c,
                size: label == null ? 22 : 19,
              ),
              if (label != null)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: c,
                    fontSize: 9,
                    height: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// برچسبِ کوتاهِ تایمرِ فعال: «12:34» (زمانِ مانده)، «3 فایل»، «تا فایلِ …»؛ null = تایمری نیست.
String? sleepTimerShortLabel(AudioPlayerState s) {
  final DateTime? at = s.sleepAt;
  if (at != null) {
    final Duration left = at.difference(DateTime.now());
    return _formatLeft(left.isNegative ? Duration.zero : left);
  }
  final int? files = s.sleepAfterFiles;
  if (files != null) return files == 1 ? 'این فایل' : '$files فایل';
  if (s.sleepAfterPath != null) return 'یک فایل';
  return null;
}

String _formatLeft(Duration d) {
  final int h = d.inHours;
  final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$sec' : '$m:$sec';
}

String _fileName(String path) {
  String n = path.split('/').last.split(r'\').last;
  final int dot = n.lastIndexOf('.');
  return dot > 0 ? n.substring(0, dot) : n;
}

/// برگه‌ی انتخابِ تایمر: «توقف بعد از زمان» (۱۵ و ۳۰ دقیقه، ۱ ساعت، دلخواه)، «توقف بعد از N فایل»
/// (پایانِ همین فایل، ۳، ۵، دلخواه) و «بعد از یک فایلِ مشخص» (از پلی‌لیستِ کتاب). اگر تایمری
/// فعال است، بالای برگه با دکمه‌ی لغو.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const Directionality(
      textDirection: TextDirection.rtl,
      child: _SleepTimerSheet(),
    ),
  );
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioPlayerState s = ref.watch(audioPlayerProvider);
    final AudioPlayerNotifier n = ref.read(audioPlayerProvider.notifier);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    void done(VoidCallback f) {
      f();
      Navigator.of(context).pop();
    }

    Widget chip(String text, VoidCallback onTap) => OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(text),
    );

    Widget section(String title, IconData icon, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );

    final String? active = s.sleepTimerActive ? _activeDescription(s) : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تایمرِ توقف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (active != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        active,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    TextButton(
                      onPressed: () => done(n.cancelSleepTimer),
                      child: const Text('لغو'),
                    ),
                  ],
                ),
              ),
            ],
            section('توقف بعد از مدتی', Icons.timer_outlined, [
              chip('۱۵ دقیقه', () => done(() => n.setSleepAfterDuration(const Duration(minutes: 15)))),
              chip('۳۰ دقیقه', () => done(() => n.setSleepAfterDuration(const Duration(minutes: 30)))),
              chip('۱ ساعت', () => done(() => n.setSleepAfterDuration(const Duration(hours: 1)))),
              chip('زمانِ دلخواه…', () async {
                final Duration? d = await _askDuration(context);
                if (d != null && d > Duration.zero && context.mounted) {
                  done(() => n.setSleepAfterDuration(d));
                }
              }),
            ]),
            section('توقف بعد از چند فایل', Icons.queue_music_rounded, [
              chip('پایانِ همین فایل', () => done(() => n.setSleepAfterFiles(1))),
              chip('۳ فایل', () => done(() => n.setSleepAfterFiles(3))),
              chip('۵ فایل', () => done(() => n.setSleepAfterFiles(5))),
              chip('تعدادِ دلخواه…', () async {
                final int? count = await _askCount(context);
                if (count != null && count > 0 && context.mounted) {
                  done(() => n.setSleepAfterFiles(count));
                }
              }),
            ]),
            if (s.playlist.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('توقف بعد از یک فایلِ مشخص…'),
                    onPressed: () async {
                      final String? path = await _pickFile(context, ref);
                      if (path != null && context.mounted) {
                        done(() => n.setSleepAfterPath(path));
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'در «بعد از چند فایل»، فایل‌هایی شمرده می‌شوند که تا آخر پخش شوند؛ تکرارِ یک فایل هم یکی '
              'حساب می‌شود. وقتِ توقف، پخش مکث می‌شود.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _activeDescription(AudioPlayerState s) {
    if (s.sleepAt != null) {
      return 'پخش ${sleepTimerShortLabel(s)} دیگر متوقف می‌شود.';
    }
    final int? files = s.sleepAfterFiles;
    if (files != null) {
      return files == 1
          ? 'پخش با پایانِ همین فایل متوقف می‌شود.'
          : 'پخش بعد از پایانِ $files فایل متوقف می‌شود.';
    }
    return 'پخش بعد از پایانِ ${bidiIsolate(_fileName(s.sleepAfterPath!))} متوقف می‌شود.';
  }

  static Future<Duration?> _askDuration(BuildContext context) async {
    final TextEditingController h = TextEditingController(text: '0');
    final TextEditingController m = TextEditingController(text: '45');
    final Duration? d = await showDialog<Duration>(
      context: context,
      builder: (ctx) {
        Widget field(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
        return AlertDialog(
          title: const Text('توقف بعد از…'),
          content: Row(
            children: [
              field(h, 'ساعت'),
              const SizedBox(width: 12),
              field(m, 'دقیقه'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                Duration(
                  hours: int.tryParse(h.text) ?? 0,
                  minutes: int.tryParse(m.text) ?? 0,
                ),
              ),
              child: const Text('تنظیم'),
            ),
          ],
        );
      },
    );
    h.dispose();
    m.dispose();
    return d;
  }

  static Future<int?> _askCount(BuildContext context) async {
    final TextEditingController c = TextEditingController(text: '2');
    final int? v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('توقف بعد از چند فایل؟'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
            child: const Text('تنظیم'),
          ),
        ],
      ),
    );
    c.dispose();
    return v;
  }

  /// فهرستِ فایل‌های کتاب با درس و مهارت؛ فایلِ فعلی بالای فهرست دیده می‌شود.
  static Future<String?> _pickFile(BuildContext context, WidgetRef ref) {
    final AudioPlayerState s = ref.read(audioPlayerProvider);
    final AudioPlayerNotifier n = ref.read(audioPlayerProvider.notifier);
    final List<String> files = s.playlist;
    final int current = s.currentPath == null ? 0 : files.indexOf(s.currentPath!);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'پخش بعد از پایانِ کدام فایل متوقف شود؟',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: ScrollController(
                    initialScrollOffset: (current < 0 ? 0 : current) * 64.0,
                  ),
                  itemExtent: 64,
                  itemCount: files.length,
                  itemBuilder: (_, i) {
                    final String p = files[i];
                    final String? where = n.trackLocationLabel(p);
                    // 🌟 AU-13: همان نشانِ رنگِ مهارتِ پلی‌لیست.
                    final AudioSkill skill = n.skillOfPath(p);
                    final bool current = p == s.currentPath;
                    final Color color = current
                        ? Theme.of(ctx).colorScheme.primary
                        : (audioSkillColor(skill) ??
                              Theme.of(ctx).colorScheme.onSurfaceVariant);
                    return ListTile(
                      selected: current,
                      leading: SkillBadge(
                        skill: skill,
                        color: color,
                        size: 38,
                        icon: current ? Icons.graphic_eq_rounded : null,
                      ),
                      title: Text(
                        _fileName(p),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                      ),
                      subtitle: where == null
                          ? null
                          : Text(where, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
