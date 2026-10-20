import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/license/license_service.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/network/session_events.dart';
import 'package:ielts_assistant/features/auth/data/device_models.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🌟 DEV-2: «دستگاه‌های من» — دستگاه‌هایی که این حساب رویشان فعال است، سقفِ دستگاه، و جدا
// کردنِ یک دستگاه (مثلاً گوشیِ قبلی). جدا کردن هر N روز یک‌بار ممکن است (سرور). جدا کردنِ
// همین دستگاه = خروج و پاک‌شدنِ محتوای کاملِ کتاب‌ها از همین‌جا (SessionGuard).

class MyDevicesScreen extends ConsumerStatefulWidget {
  const MyDevicesScreen({super.key});

  @override
  ConsumerState<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends ConsumerState<MyDevicesScreen> {
  late Future<DeviceRoster> _roster = _load();
  bool _busy = false;

  Future<DeviceRoster> _load() async {
    final Response<dynamic> res = await ref.read(dioProvider).get('/api/devices');
    return DeviceRoster.fromJson(res.data as Map);
  }

  Future<void> _refresh() async {
    final Future<DeviceRoster> f = _load();
    setState(() => _roster = f);
    await f.then((_) {}, onError: (_) {});
  }

  String _error(Object e) {
    if (e is DioException) {
      final Object? d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
      if (e.response == null) return 'اتصال به سرور برقرار نشد.';
    }
    return 'خطا در دریافتِ فهرست.';
  }

  Future<void> _release(AccountDevice d, DeviceRoster r) async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.current ? 'جدا کردنِ همین دستگاه' : 'جدا کردنِ دستگاه'),
        content: Text(
          d.current
              ? 'از حساب خارج می‌شوید و محتوای کاملِ کتاب‌ها از همین دستگاه پاک می‌شود '
                    '(نمونه‌ها می‌مانند). جای این دستگاه برای دستگاهِ تازه خالی می‌شود.\n\n'
                    'تا ${r.cooldownDays} روزِ دیگر نمی‌توانید دوباره دستگاهی را جدا کنید.'
              : '«${bidiIsolate(d.label)}» از حساب جدا می‌شود و محتوای کاملِ کتاب‌ها در اولین اتصالش از '
                    'رویش پاک می‌شود. اگر آنلاین نشود، با تمام‌شدنِ مجوزِ آفلاین قفل می‌شود.\n\n'
                    'تا ${r.cooldownDays} روزِ دیگر نمی‌توانید دوباره دستگاهی را جدا کنید.',
          style: const TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('جدا کن'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final Response<dynamic> res = await ref
          .read(dioProvider)
          .delete('/api/devices/${d.id}');
      if (!mounted) return;
      final Map<dynamic, dynamic> body = res.data as Map;
      if (body['current_released'] == true) {
        // SessionGuard: خروج، پاک‌کردنِ محتوای کامل و بستنِ همه‌ی صفحه‌ها.
        SessionEvents.emit('device_revoked', body['message']?.toString());
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((body['message'] ?? '').toString())),
      );
      setState(() => _busy = false);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? licenseExp = LicenseService.current?.expiresAt;
    return Scaffold(
      appBar: AppBar(title: const Text('دستگاه‌های من')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DeviceRoster>(
          future: _roster,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_error(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(onPressed: _refresh, child: const Text('دوباره')),
                  ),
                ],
              );
            }
            final DeviceRoster r = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  r.limit == 1
                      ? 'حسابِ شما فقط روی یک دستگاه کار می‌کند.'
                      : 'حسابِ شما حداکثر روی ${r.limit} دستگاه کار می‌کند.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  r.canRelease
                      ? 'برای استفاده روی دستگاهِ تازه، دستگاهِ قبلی را جدا کنید. این کار هر '
                            '${r.cooldownDays} روز یک‌بار ممکن است.'
                      : 'دفعه‌ی بعد که می‌توانید دستگاهی را جدا کنید: ${shortDate(r.nextReleaseAt)}. '
                            'اگر دستگاهِ قبلی گم شده یا خراب است، با پشتیبانی تماس بگیرید.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.7),
                ),
                if (licenseExp != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'مجوزِ آفلاینِ این دستگاه تا ${shortDate(licenseExp)} معتبر است و با هر اتصال تمدید می‌شود.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.7),
                  ),
                ],
                const SizedBox(height: 16),
                for (final AccountDevice d in r.devices)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        d.platform == 'windows'
                            ? Icons.laptop_windows_rounded
                            : Icons.phone_android_rounded,
                        color: d.current ? Colors.indigo : null,
                      ),
                      title: AutoDirectionText(d.label),
                      subtitle: Text(
                        [
                          if (d.current) 'همین دستگاه',
                          'فعال از ${shortDate(d.activatedAt)}',
                          'آخرین استفاده ${shortDate(d.lastSeenAt)}',
                          if (d.appVersion != null) 'نسخه‌ی ${d.appVersion}',
                          if (d.idLine.isNotEmpty) d.idLine,
                        ].join(' • '),
                      ),
                      trailing: r.canRelease
                          ? TextButton(
                              onPressed: _busy ? null : () => _release(d, r),
                              child: Text(
                                'جدا کردن',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            )
                          : null,
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }
}
