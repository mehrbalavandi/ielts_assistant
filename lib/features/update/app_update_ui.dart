import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/update/app_update_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// 🌟 قانون‌های U-2 تا U-4: پنجره‌ی «نسخه‌ی جدید» و رفتن به صفحه‌ی دریافت در سایت.

/// U-1/U-2: هنگامِ بازشدنِ ویترین — اگر نسخه‌ی تازه هست و کاربر برای همین نسخه
/// «بعداً» نزده (یا نسخه اجباری است)، پنجره نشان داده می‌شود.
Future<void> checkForAppUpdateOnStart(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(appUpdateProvider.notifier);
  final ok = await notifier.check();
  if (!ok || !context.mounted) return;
  if (notifier.shouldPrompt) await showAppUpdateDialog(context, ref);
}

/// U-4: بررسیِ دستی (از منو). نتیجه را با پیام یا همان پنجره نشان می‌دهد.
Future<void> checkForAppUpdateManually(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(appUpdateProvider.notifier).check();
  if (!context.mounted) return;
  final state = ref.read(appUpdateProvider);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('اتصال به سایت برقرار نشد؛ بعداً دوباره امتحان کنید.')),
    );
  } else if (state.updateAvailable) {
    await showAppUpdateDialog(context, ref);
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'آخرین نسخه را دارید (${state.currentVersion ?? '—'}).',
        ),
      ),
    );
  }
}

/// باز کردنِ صفحه‌ی دریافتِ اپ در مرورگرِ بیرونی.
Future<bool> openAppDownloadPage(WidgetRef ref) async {
  final url = ref.read(appUpdateProvider.notifier).downloadPageUrl;
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// U-2/U-3: پنجره‌ی نسخه‌ی جدید. اجباری ⇒ بسته نمی‌شود (نه با «بعداً»، نه با
/// لمسِ بیرون، نه با دکمه‌ی بازگشت).
Future<void> showAppUpdateDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(appUpdateProvider);
  final latest = state.latest;
  if (latest == null) return;
  final bool mandatory = state.mandatory;

  await showDialog<void>(
    context: context,
    barrierDismissible: !mandatory,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return PopScope(
        canPop: !mandatory,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            icon: Icon(Icons.system_update_rounded, color: scheme.primary, size: 36),
            title: Text('نسخه‌ی ${latest.versionName} آماده است'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'نسخه‌ی فعلیِ شما: ${state.currentVersion ?? '—'}'
                      '${latest.humanSize != null ? '  ·  حجم: ${latest.humanSize}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    if (mandatory) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'این نسخه‌ی برنامه دیگر پشتیبانی نمی‌شود؛ برای ادامه لطفاً نسخه‌ی تازه را نصب کنید.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                    if (latest.changelog?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'تغییراتِ این نسخه',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      for (final line in latest.changelog!.split('\n'))
                        if (line.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${line.trim()}', style: const TextStyle(fontSize: 13)),
                          ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'دکمه‌ی زیر صفحه‌ی دریافتِ برنامه را در مرورگر باز می‌کند؛ نسخه‌ی تازه را روی همین برنامه نصب کنید — کتاب‌ها و پیشرفتِ شما حفظ می‌شود.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () {
                    ref.read(appUpdateProvider.notifier).dismissCurrent();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('بعداً'),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('دریافت از سایت'),
                onPressed: () async {
                  final opened = await openAppDownloadPage(ref);
                  if (!opened && dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('مرورگر باز نشد؛ آدرسِ سایت را در تنظیمات بررسی کنید.')),
                    );
                  }
                  // اجباری: پنجره می‌ماند تا کاربر بعد از نصب برگردد.
                  if (!mandatory && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
