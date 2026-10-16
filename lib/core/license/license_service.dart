import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/device/device_identity.dart';
import 'package:ielts_assistant/core/license/license_public_key.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';

// 🌟 DEV-4: مجوزِ آفلاینِ امضاشده — تنها چیزی که نسخه‌ی کاملِ یک کتابِ خریده‌شده را باز می‌کند.
//
// سرور (LicenseService.php) با هر اتصالِ موفق مجوزی می‌دهد:
//   payload = base64(JSON {v, uid, did, books[], iat, exp})   sig = Ed25519(payload bytes)
// اپ فقط وقتی کتاب را باز می‌کند که:
// 1. امضا با کلیدِ عمومیِ داخلِ اپ درست باشد (پس با ویرایشِ فایلِ ذخیره قابلِ جعل نیست)،
// 2. did همین دستگاه و uid همین کاربر باشد (پس کپیِ فایل‌ها به دستگاهِ دیگر بی‌فایده است)،
// 3. شناسه‌ی کتاب در books باشد و exp نگذشته باشد،
// 4. ساعتِ دستگاه به عقب کشیده نشده باشد.
// دستگاهی که از حساب جدا شده دیگر مجوزِ تازه نمی‌گیرد؛ پس حتی اگر هرگز آنلاین نشود، بعد از
// انقضای مجوز (پیش‌فرض ۳۰ روز) قفل می‌شود.

enum LicenseStatus {
  valid,
  notConfigured,
  missing,
  expired,
  otherDevice,
  otherUser,
  clockRewound,
  notIncluded,
}

@immutable
class LicenseInfo {
  final String uid;
  final String did;
  final Set<String> books;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const LicenseInfo({
    required this.uid,
    required this.did,
    required this.books,
    required this.issuedAt,
    required this.expiresAt,
  });
}

class LicenseService {
  LicenseService._();

  static const String _storeKey = 'device_license';
  static const String _clockKey = 'license_clock_max_ms';

  /// تحملِ اختلافِ ساعت (تنظیمِ خودکارِ ساعت، منطقه‌ی زمانیِ اشتباه، …).
  static const Duration _clockTolerance = Duration(hours: 12);

  static final GetStorage _box = GetStorage();
  static LicenseInfo? _info;
  static int _clockMaxMs = 0;

  static bool get configured => kLicensePublicKey.trim().isNotEmpty;

  static LicenseInfo? get current => _info;

  /// پیش از runApp (main.dart): مجوزِ ذخیره‌شده دوباره وارسی می‌شود.
  static Future<void> init() async {
    _clockMaxMs = _box.read<int>(_clockKey) ?? 0;
    final Object? raw = _box.read(_storeKey);
    _info = raw is Map ? await _verify(raw) : null;
  }

  /// مجوزِ تازه از سرور (ورود، GET /api/books، POST /api/devices). مجوزِ نامعتبر نادیده گرفته
  /// می‌شود و مجوزِ قبلی می‌ماند.
  static Future<bool> save(Object? license) async {
    if (license is! Map) return false;
    final LicenseInfo? info = await _verify(license);
    if (info == null) {
      debugPrint('license: rejected (bad signature or format)');
      return false;
    }
    _info = info;
    await _box.write(_storeKey, {
      'payload': license['payload'],
      'sig': license['sig'],
    });
    _bumpClock(info.issuedAt.millisecondsSinceEpoch, force: true);
    return true;
  }

  static Future<void> clear() async {
    _info = null;
    await _box.remove(_storeKey);
  }

  static bool allows(String bookId) => status(bookId) == LicenseStatus.valid;

  static LicenseStatus status(String bookId) {
    if (!configured) {
      return kDebugMode ? LicenseStatus.valid : LicenseStatus.notConfigured;
    }
    final LicenseInfo? info = _info;
    if (info == null) return LicenseStatus.missing;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int tolMs = _clockTolerance.inMilliseconds;
    if (nowMs < _clockMaxMs - tolMs ||
        nowMs < info.issuedAt.millisecondsSinceEpoch - tolMs) {
      return LicenseStatus.clockRewound;
    }
    _bumpClock(nowMs);

    if (info.did != DeviceIdentity.id) return LicenseStatus.otherDevice;
    final String? uid = StorageService.getUser()?['id']?.toString();
    if (uid == null || uid != info.uid) return LicenseStatus.otherUser;
    if (nowMs >= info.expiresAt.millisecondsSinceEpoch) {
      return LicenseStatus.expired;
    }
    if (!info.books.contains(bookId)) return LicenseStatus.notIncluded;
    return LicenseStatus.valid;
  }

  /// پیامِ کاربر برای کتابی که خریده شده ولی الان باز نمی‌شود.
  static String message(LicenseStatus s) => switch (s) {
    LicenseStatus.valid => '',
    LicenseStatus.clockRewound =>
      'تاریخ و ساعتِ دستگاه عقب است. آن را درست کنید و یک‌بار به اینترنت وصل شوید.',
    LicenseStatus.otherDevice || LicenseStatus.otherUser =>
      'مجوزِ این کتاب برای این دستگاه یا این حساب نیست. دوباره وارد شوید.',
    LicenseStatus.notConfigured =>
      'مجوزِ آفلاین در این نسخه‌ی برنامه پیکربندی نشده است. با پشتیبانی تماس بگیرید.',
    LicenseStatus.missing ||
    LicenseStatus.expired ||
    LicenseStatus.notIncluded =>
      'برای ادامه‌ی مطالعه، یک‌بار با اینترنت وارد برنامه شوید تا مجوزِ این دستگاه تمدید شود.',
  };

  /// بالاترین زمانی که تا حالا دیده شده؛ برگرداندنِ ساعتِ دستگاه را آشکار می‌کند.
  /// نوشتن روی دیسک حداکثر هر ده دقیقه یک‌بار (status() در build صدا زده می‌شود).
  static void _bumpClock(int ms, {bool force = false}) {
    if (ms <= _clockMaxMs) return;
    final bool persist = force || ms - _clockMaxMs > 10 * 60 * 1000;
    _clockMaxMs = ms;
    if (persist) _box.write(_clockKey, ms);
  }

  static Future<LicenseInfo?> _verify(Map<dynamic, dynamic> raw) async {
    try {
      final List<int> payload = base64.decode(raw['payload'] as String);
      final List<int> sig = base64.decode(raw['sig'] as String);
      if (configured) {
        final SimplePublicKey pk = SimplePublicKey(
          base64.decode(kLicensePublicKey.trim()),
          type: KeyPairType.ed25519,
        );
        final bool ok = await Ed25519().verify(
          payload,
          signature: Signature(sig, publicKey: pk),
        );
        if (!ok) return null;
      }
      final Object? data = jsonDecode(utf8.decode(payload));
      if (data is! Map || data['v'] != 1) return null;
      return LicenseInfo(
        uid: data['uid'].toString(),
        did: data['did'].toString(),
        books: {for (final Object? b in (data['books'] as List? ?? const [])) b.toString()},
        issuedAt: DateTime.fromMillisecondsSinceEpoch(
          (data['iat'] as num).toInt() * 1000,
        ),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (data['exp'] as num).toInt() * 1000,
        ),
      );
    } catch (e) {
      debugPrint('license: parse failed: $e');
      return null;
    }
  }
}
