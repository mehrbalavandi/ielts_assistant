import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/device/device_identity.dart';
import 'package:ielts_assistant/features/auth/data/device_models.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';

// 🌟 DEV-2: ورود موفق بود ولی حساب روی دستگاهِ دیگری فعال است (۴۰۹ِ سرور).
// - اگر کاربر مجاز است (هر N روز یک‌بار)، یکی از دستگاه‌ها را جدا می‌کند و همین دستگاه وارد
//   می‌شود — بی‌کدِ تازه (با بلیتِ ۱۰دقیقه‌ای که همان پاسخ داده).
// - وگرنه تاریخِ مجازِ بعدی و راهِ تماس با پشتیبانی.
// نتیجه: OtpVerifyResultِ ورود، یا null اگر کاربر منصرف شد.

Future<OtpVerifyResult?> showDeviceLimitDialog(
  BuildContext context,
  DeviceRoster roster,
) {
  return showDialog<OtpVerifyResult>(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _DeviceLimitDialog(roster: roster),
    ),
  );
}

class _DeviceLimitDialog extends ConsumerStatefulWidget {
  const _DeviceLimitDialog({required this.roster});

  final DeviceRoster roster;

  @override
  ConsumerState<_DeviceLimitDialog> createState() => _DeviceLimitDialogState();
}

class _DeviceLimitDialogState extends ConsumerState<_DeviceLimitDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _replace(AccountDevice d) async {
    final DeviceRoster r = widget.roster;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('جدا کردنِ دستگاه'),
          content: Text(
            '«${d.label}» از حسابِ شما جدا می‌شود و این دستگاه جایش را می‌گیرد.\n\n'
            '• محتوای کاملِ کتاب‌ها در اولین اتصالِ آن دستگاه از رویش پاک می‌شود.\n'
            '• تا ${r.cooldownDays} روزِ دیگر نمی‌توانید دوباره دستگاهی را جدا کنید.',
            style: const TextStyle(height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('جدا کن و وارد شو'),
            ),
          ],
        ),
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final OtpVerifyResult res = await ref
        .read(authProvider.notifier)
        .replaceDevice(r.ticket!, d.id);
    if (!mounted) return;
    if (res.ok) {
      Navigator.pop(context, res);
      return;
    }
    setState(() {
      _busy = false;
      _error = res.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final DeviceRoster r = widget.roster;
    final bool canReplace = r.canRelease && (r.ticket?.isNotEmpty ?? false);
    final TextStyle hint = TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.7);

    return AlertDialog(
      icon: const Icon(Icons.devices_other_rounded, size: 36),
      title: const Text('این حساب روی دستگاهِ دیگری فعال است'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.message, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 12),
            for (final AccountDevice d in r.devices)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    d.platform == 'windows'
                        ? Icons.laptop_windows_rounded
                        : Icons.phone_android_rounded,
                  ),
                  title: Text(d.label),
                  subtitle: Text(
                    [
                      'آخرین استفاده: ${shortDate(d.lastSeenAt)}',
                      if (d.idLine.isNotEmpty) 'شناسه: ${d.idLine}',
                    ].join('\n'),
                  ),
                  trailing: canReplace
                      ? TextButton(
                          onPressed: _busy ? null : () => _replace(d),
                          child: const Text('جدا کردن'),
                        )
                      : null,
                ),
              ),
            // 🌟 DEV-5: شناسه‌ی همین دستگاه، تا معلوم شود دستگاهِ فهرست واقعاً دیگری است یا نه.
            Text(
              'این دستگاه: ${DeviceIdentity.shortId}'
              '${DeviceIdentity.buildMode == 'release' ? '' : ' · ${DeviceIdentity.buildMode}'}',
              textDirection: TextDirection.rtl,
              style: hint,
            ),
            if (r.devices.any((d) => d.label.contains(DeviceIdentity.model) && DeviceIdentity.model.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'اگر دستگاهِ بالا همین گوشیِ شماست (مثلاً برنامه را حذف و نسخه‌ی دیگری نصب کرده‌اید)، '
                  'آن را جدا کنید تا همین نصب جایش را بگیرد.',
                  style: hint,
                ),
              ),
            const SizedBox(height: 4),
            if (canReplace)
              Text(
                'برای ورود با این دستگاه، یکی از دستگاه‌های بالا را از حساب جدا کنید. '
                'این کار هر ${r.cooldownDays} روز یک‌بار ممکن است.',
                style: hint,
              )
            else
              Text(
                'هر ${r.cooldownDays} روز فقط یک‌بار می‌توانید دستگاهی را جدا کنید'
                '${r.nextReleaseAt != null ? '؛ دفعه‌ی بعد از ${shortDate(r.nextReleaseAt)}' : ''}. '
                'اگر دستگاهِ قبلی گم شده یا خراب است، با پشتیبانی تماس بگیرید.',
                style: hint,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    );
  }
}
