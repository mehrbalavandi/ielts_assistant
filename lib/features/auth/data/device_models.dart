import 'package:flutter/foundation.dart';

// 🌟 DEV-2: دستگاه‌های فعالِ حساب (پاسخِ ۴۰۹ِ ورود و GET /api/devices).

@immutable
class AccountDevice {
  final int id;
  final String label;
  final String? platform;
  final String? appVersion;
  final DateTime? activatedAt;
  final DateTime? lastSeenAt;
  final bool current;

  /// 🌟 DEV-5: شناسه‌ی کوتاه (h1-… سخت‌افزاری، r1-… تصادفی) و نوعِ ساخت.
  final String shortId;
  final String? buildMode;

  const AccountDevice({
    required this.id,
    required this.label,
    this.platform,
    this.appVersion,
    this.activatedAt,
    this.lastSeenAt,
    this.current = false,
    this.shortId = '',
    this.buildMode,
  });

  /// برای نمایش: «h1-3fa9c2 · debug».
  String get idLine => [
    if (shortId.isNotEmpty) shortId,
    if (buildMode != null && buildMode != 'release') buildMode!,
  ].join(' · ');

  factory AccountDevice.fromJson(Map<dynamic, dynamic> j) => AccountDevice(
    id: (j['id'] as num).toInt(),
    label: (j['label'] ?? '').toString(),
    platform: j['platform']?.toString(),
    appVersion: j['app_version']?.toString(),
    activatedAt: DateTime.tryParse(j['activated_at']?.toString() ?? '')?.toLocal(),
    lastSeenAt: DateTime.tryParse(j['last_seen_at']?.toString() ?? '')?.toLocal(),
    current: j['current'] == true,
    shortId: (j['short_id'] ?? '').toString(),
    buildMode: j['build_mode']?.toString(),
  );
}

/// وضعیتِ دستگاه‌های حساب: فهرست، سقف، و اینکه کاربر الان می‌تواند یکی را آزاد کند یا نه.
@immutable
class DeviceRoster {
  final List<AccountDevice> devices;
  final int limit;
  final bool canRelease;
  final DateTime? nextReleaseAt;
  final int cooldownDays;

  /// فقط در پاسخِ ۴۰۹ِ ورود: اجازه می‌دهد بی‌کدِ تازه یکی جایگزین شود (۱۰ دقیقه).
  final String? ticket;
  final String message;

  const DeviceRoster({
    required this.devices,
    required this.limit,
    required this.canRelease,
    this.nextReleaseAt,
    this.cooldownDays = 30,
    this.ticket,
    this.message = '',
  });

  factory DeviceRoster.fromJson(Map<dynamic, dynamic> j) => DeviceRoster(
    devices: [
      for (final Object? d in (j['devices'] as List? ?? const []))
        if (d is Map) AccountDevice.fromJson(d),
    ],
    limit: (j['limit'] as num?)?.toInt() ?? 1,
    canRelease: j['can_release'] == true,
    nextReleaseAt: DateTime.tryParse(
      j['next_release_at']?.toString() ?? '',
    )?.toLocal(),
    cooldownDays: (j['cooldown_days'] as num?)?.toInt() ?? 30,
    ticket: j['ticket']?.toString(),
    message: (j['message'] ?? '').toString(),
  );
}

/// تاریخِ کوتاه برای پیام‌ها (میلادی، yyyy-mm-dd).
String shortDate(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
