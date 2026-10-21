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
//
// 🌟 DEV-7: «خروج از حساب» به دستِ خودِ کاربر مجوز را پاک نمی‌کند. کتاب‌های خریده‌شده‌ی
// دانلودشده تا gd روز بعد از خروج (gd داخلِ مجوزِ امضاشده = «فاصله‌ی جدا کردنِ دستگاه توسطِ
// کاربر» در پنل) و نه بیش از exp، روی همین دستگاه باز می‌مانند — مثلاً کاربری که بی‌اینترنت
// اشتباهی خارج شده. ورودِ هر حسابی مجوزِ قبلی را پاک می‌کند؛ پایانِ نشست به حکمِ سرور (دستگاه
// جدا شده، توکنِ کپی‌شده) هم مثلِ قبل همه‌چیز را پاک می‌کند.

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

  /// 🌟 DEV-7: مهلتِ بعد از خروج (روز). مجوزهای قدیمیِ بی‌gd: ۰.
  final int signedOutGraceDays;

  const LicenseInfo({
    required this.uid,
    required this.did,
    required this.books,
    required this.issuedAt,
    required this.expiresAt,
    this.signedOutGraceDays = 0,
  });
}

class LicenseService {
  LicenseService._();

  static const String _storeKey = 'device_license';
  static const String _clockKey = 'license_clock_max_ms';
  static const String _signedOutKey = 'license_signed_out'; // 🌟 DEV-7: {uid, at}

  /// تحملِ اختلافِ ساعت (تنظیمِ خودکارِ ساعت، منطقه‌ی زمانیِ اشتباه، …).
  static const Duration _clockTolerance = Duration(hours: 12);

  static final GetStorage _box = GetStorage();
  static LicenseInfo? _info;
  static int _clockMaxMs = 0;

  static bool get configured => kLicensePublicKey.trim().isNotEmpty;

  static LicenseInfo? get current => _info;

  /// 🌟 SYNC-1: با هر مجوزِ تازه (یا پاک شدنش) یکی زیاد می‌شود؛ پنجره‌ی تأییدِ خروج با همین
  /// عددهای تازه‌ی سایت را بی‌بستن و بازکردن نشان می‌دهد.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 🌟 SYNC-1: اگر همین الان خارج شود، کتاب‌های خریده‌شده تا کِی باز می‌مانند: کمترینِ «الان +
  /// gd» و exp (اعتبارِ مجوزِ آفلاین). null = بی‌مهلت (بعد از خروج قفل) یا مجوزی نیست.
  static DateTime? signedOutUntilIfNow() {
    final LicenseInfo? info = _info;
    if (info == null || info.signedOutGraceDays <= 0) return null;
    final DateTime now = DateTime.now();
    if (!now.isBefore(info.expiresAt)) return null;
    final DateTime grace = now.add(Duration(days: info.signedOutGraceDays));
    return grace.isBefore(info.expiresAt) ? grace : info.expiresAt;
  }

  /// 🌟 DEV-7: کاربرِ خارج‌شده و زمانِ خروج (null = واردشده یا مهلتی نیست).
  static String? _signedOutUid;
  static DateTime? _signedOutAt;

  /// 🌟 DEV-7: تا کِی کتاب‌های خریده‌شده بعد از خروج باز می‌مانند (null = مهلتی نیست).
  static DateTime? get signedOutUntil {
    final LicenseInfo? info = _info;
    final DateTime? at = _signedOutAt;
    if (info == null || at == null || _signedOutUid != info.uid) return null;
    if (info.signedOutGraceDays <= 0) return null;
    final DateTime grace = at.add(Duration(days: info.signedOutGraceDays));
    return grace.isBefore(info.expiresAt) ? grace : info.expiresAt;
  }

  /// 🌟 DEV-7: مهلتِ بعد از خروج هنوز باز است.
  static bool get inSignedOutGrace {
    final DateTime? until = signedOutUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// 🌟 DEV-7: «خروج از حساب» به دستِ کاربر. مجوز می‌ماند، زمانِ خروج ثبت می‌شود.
  static Future<void> markSignedOut(String? uid) async {
    if (uid == null || _info == null || _info!.uid != uid) {
      await clear();
      return;
    }
    _signedOutUid = uid;
    _signedOutAt = DateTime.now();
    await _box.write(_signedOutKey, {
      'uid': uid,
      'at': _signedOutAt!.millisecondsSinceEpoch,
    });
  }

  /// پیش از runApp (main.dart): مجوزِ ذخیره‌شده دوباره وارسی می‌شود.
  static Future<void> init() async {
    _clockMaxMs = _box.read<int>(_clockKey) ?? 0;
    final Object? raw = _box.read(_storeKey);
    _info = raw is Map ? await _verify(raw) : null;
    final Object? so = _box.read(_signedOutKey);
    if (so is Map && so['uid'] != null && so['at'] is int) {
      _signedOutUid = so['uid'].toString();
      _signedOutAt = DateTime.fromMillisecondsSinceEpoch(so['at'] as int);
    }
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
    await _clearSignedOut();
    await _box.write(_storeKey, {
      'payload': license['payload'],
      'sig': license['sig'],
    });
    _bumpClock(info.issuedAt.millisecondsSinceEpoch, force: true);
    revision.value++;
    return true;
  }

  static Future<void> clear() async {
    _info = null;
    await _box.remove(_storeKey);
    await _clearSignedOut();
    revision.value++;
  }

  static Future<void> _clearSignedOut() async {
    _signedOutUid = null;
    _signedOutAt = null;
    await _box.remove(_signedOutKey);
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
    if (uid == null) {
      // 🌟 DEV-7: خارج‌شده؛ فقط در مهلتِ بعد از خروج و فقط برای همان کاربر.
      final DateTime? until = signedOutUntil;
      if (until == null) return LicenseStatus.otherUser;
      if (nowMs >= until.millisecondsSinceEpoch) return LicenseStatus.expired;
    } else if (uid != info.uid) {
      return LicenseStatus.otherUser;
    }
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
        signedOutGraceDays: (data['gd'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('license: parse failed: $e');
      return null;
    }
  }
}
