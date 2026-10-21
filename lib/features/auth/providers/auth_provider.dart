import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/app_config/app_config.dart';
import 'package:ielts_assistant/core/device/device_identity.dart';
import 'package:ielts_assistant/core/license/license_service.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/auth/data/device_models.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';

enum AuthState { initial, authenticated, unauthenticated }

/// 🌟 AUTH-1: نتیجه‌ی درخواستِ کد.
@immutable
class OtpRequestResult {
  final bool ok;
  final String message;

  /// شماره‌ی یکسان‌شده (09xxxxxxxxx) — همان که در مرحله‌ی دوم فرستاده می‌شود.
  final String? mobile;

  /// false = کاربرِ تازه؛ نام و نام خانوادگی هم پرسیده می‌شود.
  final bool registered;
  final int retryAfter;
  final int codeLength;

  /// فقط سرورِ توسعه (SMS_DRIVER=log) — کد را برای تست نشان می‌دهد.
  final String? debugCode;

  const OtpRequestResult({
    required this.ok,
    required this.message,
    this.mobile,
    this.registered = true,
    this.retryAfter = 0,
    this.codeLength = 5,
    this.debugCode,
  });
}

/// 🌟 AUTH-1: نتیجه‌ی ورود (کدِ پیامکی، ایمیل، یا جایگزینیِ دستگاه).
@immutable
class OtpVerifyResult {
  final bool ok;
  final String message;
  final bool needsProfile;

  /// 🌟 DEV-2: سقفِ دستگاه پر است — دستگاه‌های فعال و (اگر مجاز است) بلیتِ جایگزینی.
  final DeviceRoster? deviceLimit;

  const OtpVerifyResult({
    required this.ok,
    required this.message,
    this.needsProfile = false,
    this.deviceLimit,
  });
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 🌟 مرحله ۱: بررسی فوری استوریج در لحظه تولد کلاس
    final token = StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      return AuthState.authenticated;
    }
    return AuthState.unauthenticated;
  }

  String _message(DioException e, String fallback) {
    // سقفِ درخواستِ سرور (throttle) پیامِ انگلیسی دارد.
    if (e.response?.statusCode == 429) {
      return 'تعدادِ درخواست‌ها زیاد بود؛ چند دقیقه‌ی دیگر دوباره امتحان کنید.';
    }
    final Object? data = e.response?.data;
    // 🌟 SITE-2: روش در پنل خاموش شده/ثبت‌نام بسته است ← تنظیماتِ اپ هم تازه شود.
    if (data is Map &&
        (data['reason'] == 'method_disabled' || data['reason'] == 'registration_closed')) {
      ref.read(appConfigProvider.notifier).refresh();
    }
    // خطاهای فرم (۴۲۲ِ لاراول): اولین خطای هر فیلد، هر کدام در یک خط
    if (data is Map && data['errors'] is Map) {
      final List<String> lines = [
        for (final Object? v in (data['errors'] as Map).values)
          if (v is List && v.isNotEmpty) v.first.toString(),
      ];
      if (lines.isNotEmpty) return lines.join('\n');
    }
    if (data is Map && data['message'] is String) return data['message'] as String;
    return e.response == null ? 'اتصال به سرور برقرار نشد.' : fallback;
  }

  Future<void> _signedIn(Map<String, dynamic> data) async {
    await StorageService.saveToken(data['token'] as String);
    if (data['user'] is Map) {
      await StorageService.saveUser(Map<String, dynamic>.from(data['user']));
    }
    // 🌟 DEV-4: مجوزِ آفلاینِ همین دستگاه (کاربرِ قبلیِ این دستگاه، اگر بود، دیگر معتبر نیست).
    await LicenseService.clear();
    await LicenseService.save(data['license']);
    DeviceIdentity.forgetPreviousFallback(); // 🌟 DEV-5
    state = AuthState.authenticated;
    // پشتیبان: ثبتِ دستگاه، بازگرداندن/فرستادنِ «مرورِ من» و تنظیمات (BK-1..3).
    ref.read(backupProvider.notifier).onLogin();
  }

  /// 🌟 AUTH-1 مرحله‌ی ۱: پیامکِ کد.
  Future<OtpRequestResult> requestOtp(String mobile) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/api/auth/otp/request',
            // 🌟 DEV-1: سرور نسخه‌های بی‌شناسه‌ی دستگاه را پیش از فرستادنِ پیامک رد می‌کند.
            data: {'mobile': mobile, 'device_id': DeviceIdentity.id},
          );
      final Map<String, dynamic> d = Map<String, dynamic>.from(res.data);
      return OtpRequestResult(
        ok: d['success'] == true,
        message: (d['message'] as String?) ?? '',
        mobile: d['mobile'] as String?,
        registered: d['registered'] != false,
        retryAfter: (d['retry_after'] as num?)?.toInt() ?? 120,
        codeLength: (d['code_length'] as num?)?.toInt() ?? 5,
        debugCode: d['debug_code']?.toString(),
      );
    } on DioException catch (e) {
      final Object? data = e.response?.data;
      // 429 با retry_after: کدِ قبلی هنوز معتبر است — همان صفحه‌ی کد باز می‌ماند.
      if (e.response?.statusCode == 429 && data is Map && data['mobile'] != null) {
        return OtpRequestResult(
          ok: true,
          message: (data['message'] as String?) ?? '',
          mobile: data['mobile'] as String?,
          registered: data['registered'] != false,
          retryAfter: (data['retry_after'] as num?)?.toInt() ?? 60,
          codeLength: (data['code_length'] as num?)?.toInt() ?? 5,
        );
      }
      return OtpRequestResult(
        ok: false,
        message: _message(e, 'ارسالِ کد ممکن نشد.'),
      );
    }
  }

  /// 🌟 AUTH-1 مرحله‌ی ۲: ورود با کد (برای کاربرِ تازه با نام).
  Future<OtpVerifyResult> verifyOtp(
    String mobile,
    String code, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/api/auth/otp/verify',
            data: {
              'mobile': mobile,
              'code': code,
              if (firstName != null) 'first_name': firstName,
              if (lastName != null) 'last_name': lastName,
              // 🌟 DEV-1: ثبتِ همین دستگاه (شناسه‌ی سخت‌افزاری، نام، سکو)
              ...DeviceIdentity.loginFields(),
            },
          );
      return _loginResult(res.data);
    } on DioException catch (e) {
      return _loginError(e);
    }
  }

  /// پاسخِ موفقِ ورود (۲۰۰/۲۰۱).
  Future<OtpVerifyResult> _loginResult(Object? body) async {
    final Map<String, dynamic> d = Map<String, dynamic>.from(body as Map);
    if (d['success'] == true && d['token'] is String) {
      await _signedIn(d);
      return OtpVerifyResult(ok: true, message: (d['message'] as String?) ?? '');
    }
    return OtpVerifyResult(ok: false, message: (d['message'] as String?) ?? '');
  }

  /// خطای ورود؛ ۴۰۹ = سقفِ دستگاه (DEV-2)، ۴۲۶ = نسخه‌ی قدیمی، ۴۲۲ = نام لازم است.
  OtpVerifyResult _loginError(DioException e) {
    final Object? data = e.response?.data;
    if (e.response?.statusCode == 409 &&
        data is Map &&
        data['reason'] == 'device_limit') {
      final DeviceRoster roster = DeviceRoster.fromJson(data);
      return OtpVerifyResult(
        ok: false,
        message: roster.message,
        deviceLimit: roster,
      );
    }
    return OtpVerifyResult(
      ok: false,
      needsProfile: data is Map && data['needs_profile'] == true,
      message: _message(e, 'ورود ممکن نشد.'),
    );
  }

  /// 🌟 DEV-2: بعد از ۴۰۹، یکی از دستگاه‌های فعال آزاد و همین دستگاه وارد می‌شود.
  Future<OtpVerifyResult> replaceDevice(String ticket, int releaseDeviceId) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/api/auth/device/replace',
            data: {'ticket': ticket, 'release_device_id': releaseDeviceId},
          );
      return _loginResult(res.data);
    } on DioException catch (e) {
      return _loginError(e);
    }
  }

  // 🌟 مرحله ۲: لاگین، دریافت توکن و تغییر وضعیت (حساب‌های قدیمیِ ایمیلی)
  Future<OtpVerifyResult> login(String email, String password) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/api/login',
            data: {
              'email': email,
              'password': password,
              ...DeviceIdentity.loginFields(),
            },
          );
      return _loginResult(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const OtpVerifyResult(
          ok: false,
          message: 'ایمیل یا رمز عبور اشتباه است.',
        );
      }
      return _loginError(e);
    }
  }

  /// 🌟 SITE-2: ساختنِ حساب با ایمیل (اگر در پنلِ سایت روشن باشد).
  Future<OtpVerifyResult> registerEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/api/register',
            data: {
              'first_name': firstName,
              'last_name': lastName,
              'email': email,
              'password': password,
              ...DeviceIdentity.loginFields(),
            },
          );
      return _loginResult(response.data);
    } on DioException catch (e) {
      return _loginError(e);
    }
  }

  /// 🌟 SITE-6: لینکِ ساختنِ رمزِ تازه به ایمیل (رمز در سایت عوض می‌شود).
  Future<String> forgotPassword(String email) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post('/api/password/forgot', data: {'email': email});
      return (res.data is Map ? res.data['message'] : null)?.toString() ??
          'لینکِ ساختنِ رمزِ تازه فرستاده شد.';
    } on DioException catch (e) {
      return _message(e, 'فرستادنِ لینک ممکن نشد.');
    }
  }

  Future<void> logout() async {
    // توکن روی سرور هم باطل می‌شود (اگر در دسترس باشد)؛ داده‌های محلی می‌مانند.
    // 🌟 DEV-2: دستگاه در حساب ثبت می‌ماند (ورودِ دوباره با همین دستگاه آزاد است)؛ برای
    // جداکردنِ دستگاه از حساب «دستگاه‌های من» ← «جدا کردن».
    // 🌟 DEV-7: مجوز پاک نمی‌شود؛ کتاب‌های خریده‌شده‌ی دانلودشده تا مهلتِ بعد از خروج (gd روزِ
    // مجوز) روی همین دستگاه باز می‌مانند — حتی اگر کاربر بی‌اینترنت اشتباهی خارج شده باشد.
    final String? uid = StorageService.getUser()?['id']?.toString();
    try {
      final res = await ref.read(dioProvider).post('/api/logout');
      // 🌟 SYNC-1: مجوزِ آخر از همین لحظه و با تنظیماتِ فعلیِ پنل؛ مهلتِ بعد از خروج همان می‌شود
      // که پنجره‌ی تأیید گفت.
      final Object? body = res.data;
      if (body is Map && body['license'] != null) {
        await LicenseService.save(body['license']);
      }
    } catch (_) {}
    await endSessionLocally(keepLicenseFor: uid);
  }

  /// خروجِ محلی بی‌تماس با سرور (DEV-1: سرور خودش گفته نشست تمام است).
  /// مجوزِ آفلاین هم پاک می‌شود، پس نسخه‌ی کامل تا ورودِ دوباره باز نمی‌شود.
  /// [keepLicenseFor]: فقط برای خروج به دستِ خودِ کاربر (DEV-7).
  Future<void> endSessionLocally({String? keepLicenseFor}) async {
    await StorageService.removeToken();
    if (keepLicenseFor != null) {
      await LicenseService.markSignedOut(keepLicenseFor);
    } else {
      await LicenseService.clear();
    }
    state = AuthState.unauthenticated;
    // 🌟 DEV-6: ویترین حالتِ مهمان بگیرد (نه «خریداری شده» + «نیاز به تمدیدِ مجوز»).
    await ref.read(booksProvider.notifier).onSignedOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);
