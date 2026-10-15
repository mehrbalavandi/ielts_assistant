import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';

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

/// 🌟 AUTH-1: نتیجه‌ی تأییدِ کد.
@immutable
class OtpVerifyResult {
  final bool ok;
  final String message;
  final bool needsProfile;

  const OtpVerifyResult({
    required this.ok,
    required this.message,
    this.needsProfile = false,
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
    if (data is Map && data['message'] is String) return data['message'] as String;
    return e.response == null ? 'اتصال به سرور برقرار نشد.' : fallback;
  }

  Future<void> _signedIn(Map<String, dynamic> data) async {
    await StorageService.saveToken(data['token'] as String);
    if (data['user'] is Map) {
      await StorageService.saveUser(Map<String, dynamic>.from(data['user']));
    }
    state = AuthState.authenticated;
    // پشتیبان: ثبتِ دستگاه، بازگرداندن/فرستادنِ «مرورِ من» و تنظیمات (BK-1..3).
    ref.read(backupProvider.notifier).onLogin();
  }

  /// 🌟 AUTH-1 مرحله‌ی ۱: پیامکِ کد.
  Future<OtpRequestResult> requestOtp(String mobile) async {
    try {
      final res = await ref
          .read(dioProvider)
          .post('/api/auth/otp/request', data: {'mobile': mobile});
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
              'device_name': defaultTargetPlatform.name,
            },
          );
      final Map<String, dynamic> d = Map<String, dynamic>.from(res.data);
      if (d['success'] == true && d['token'] is String) {
        await _signedIn(d);
        return OtpVerifyResult(ok: true, message: (d['message'] as String?) ?? '');
      }
      return OtpVerifyResult(ok: false, message: (d['message'] as String?) ?? '');
    } on DioException catch (e) {
      final Object? data = e.response?.data;
      return OtpVerifyResult(
        ok: false,
        needsProfile: data is Map && data['needs_profile'] == true,
        message: _message(e, 'ورود ممکن نشد.'),
      );
    }
  }

  // 🌟 مرحله ۲: لاگین، دریافت توکن و تغییر وضعیت (حساب‌های قدیمیِ ایمیلی)
  Future<bool> login(String email, String password) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post('/api/login', data: {'email': email, 'password': password});
      if (response.statusCode == 200 && response.data['success'] == true) {
        await _signedIn(Map<String, dynamic>.from(response.data));
        return true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      debugPrint(_message(e, 'خطایی در ورود رخ داد'));
      state = AuthState.initial;
      return false;
    }
  }

  Future<void> logout() async {
    // توکن روی سرور هم باطل می‌شود (اگر در دسترس باشد)؛ داده‌های محلی می‌مانند.
    try {
      await ref.read(dioProvider).post('/api/logout');
    } catch (_) {}
    await StorageService.removeToken();
    state = AuthState.unauthenticated;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);
