import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';

// 🌟 SITE-7: تنظیماتی که ادمین در پنلِ سایت («تنظیماتِ سایت») تعیین می‌کند و اپ پیش از ورود لازم
// دارد: روش‌های ورود (موبایل/ایمیل/ثبت‌نام)، اطلاعیه، حالتِ تعمیر، پشتیبانی و پیوندِ صفحه‌ها.
// از GET /api/app/config؛ آخرین نسخه در GetStorage می‌ماند تا آفلاین هم همان دیده شود.
// سرورِ قدیمی (بی این مسیر) ← پیش‌فرض: همه‌ی روش‌ها روشن.

@immutable
class AppNotice {
  final String text;

  /// info | warning | success | maintenance
  final String level;

  const AppNotice(this.text, this.level);
}

@immutable
class AppConfig {
  final bool mobileEnabled;
  final bool emailEnabled;
  final bool registrationEnabled;
  final String mobileDisabledMessage;
  final String emailDisabledMessage;
  final String registrationClosedMessage;
  final String passwordHint;
  final AppNotice? announcement;

  /// پیامِ حالتِ تعمیر، یا null.
  final String? maintenance;
  final Map<String, String> support;
  final Map<String, String> links;

  const AppConfig({
    this.mobileEnabled = true,
    this.emailEnabled = true,
    this.registrationEnabled = true,
    this.mobileDisabledMessage = 'ورود و ثبت‌نام با شماره‌ی موبایل فعلاً فعال نیست.',
    this.emailDisabledMessage = 'ورود و ثبت‌نام با ایمیل فعلاً فعال نیست.',
    this.registrationClosedMessage = 'ثبت‌نامِ حسابِ تازه فعلاً بسته است.',
    this.passwordHint = '',
    this.announcement,
    this.maintenance,
    this.support = const {},
    this.links = const {},
  });

  factory AppConfig.fromJson(Map<dynamic, dynamic> j) {
    final Map<dynamic, dynamic> auth = j['auth'] is Map ? j['auth'] as Map : const {};
    final Map<dynamic, dynamic> msg = auth['messages'] is Map ? auth['messages'] as Map : const {};
    const AppConfig d = AppConfig();
    final Object? a = j['announcement'];
    final Object? m = j['maintenance'];
    Map<String, String> strings(Object? v) => v is Map
        ? {for (final e in v.entries) e.key.toString(): e.value.toString()}
        : const {};
    return AppConfig(
      mobileEnabled: auth['mobile'] != false,
      emailEnabled: auth['email'] != false,
      registrationEnabled: auth['registration'] != false,
      mobileDisabledMessage: (msg['mobile'] ?? d.mobileDisabledMessage).toString(),
      emailDisabledMessage: (msg['email'] ?? d.emailDisabledMessage).toString(),
      registrationClosedMessage: (msg['registration'] ?? d.registrationClosedMessage).toString(),
      passwordHint: (auth['password_hint'] ?? '').toString(),
      announcement: a is Map && (a['text'] ?? '').toString().trim().isNotEmpty
          ? AppNotice(a['text'].toString(), (a['level'] ?? 'info').toString())
          : null,
      maintenance: m is Map ? (m['message'] ?? '').toString() : null,
      support: strings(j['support']),
      links: strings(j['links']),
    );
  }
}

class AppConfigNotifier extends Notifier<AppConfig> {
  static const String _key = 'app_config';

  @override
  AppConfig build() {
    final Object? cached = GetStorage().read(_key);
    return cached is Map ? AppConfig.fromJson(cached) : const AppConfig();
  }

  /// از سرور می‌خواند؛ اگر نشد (آفلاین، سرورِ قدیمی) همان قبلی می‌ماند.
  Future<AppConfig> refresh() async {
    try {
      final Response<dynamic> res = await ref.read(dioProvider).get('/api/app/config');
      if (res.data is Map) {
        state = AppConfig.fromJson(res.data as Map);
        await GetStorage().write(_key, res.data);
      }
    } catch (e) {
      debugPrint('AppConfig: $e');
    }
    return state;
  }
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);
