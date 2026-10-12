import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';

// 🌟 قانونِ U-1 تا U-4 (RULES-rendering.md): اپ از خودِ سایت توزیع می‌شود، نه از
// فروشگاه. با هر اجرا یک‌بار از سرور (/api/app/latest) آخرین نسخه‌ی همین سکو پرسیده
// و با build numberِ خودِ اپ (عددِ بعد از «+» در pubspec.yaml) مقایسه می‌شود.

/// یک انتشارِ اپ روی سایت.
class AppReleaseInfo {
  final String versionName;
  final int buildNumber;
  final String? changelog;
  final bool isMandatory;

  /// اپی که build numberش کمتر از این است *باید* به‌روز کند (U-3).
  final int minSupportedBuild;
  final int? fileSize;
  final String? pageUrl;

  const AppReleaseInfo({
    required this.versionName,
    required this.buildNumber,
    this.changelog,
    this.isMandatory = false,
    this.minSupportedBuild = 0,
    this.fileSize,
    this.pageUrl,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) => AppReleaseInfo(
    versionName: json['version_name']?.toString() ?? '',
    buildNumber: (json['build_number'] as num?)?.toInt() ?? 0,
    changelog: (json['changelog'] as String?)?.trim(),
    isMandatory: json['is_mandatory'] == true,
    minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ?? 0,
    fileSize: (json['file_size'] as num?)?.toInt(),
    pageUrl: json['page_url'] as String?,
  );

  /// «۳۰٫۰ مگابایت» — یا null اگر سرور حجم نداد.
  String? get humanSize {
    final int? b = fileSize;
    if (b == null || b <= 0) return null;
    return b >= 1048576
        ? '${(b / 1048576).toStringAsFixed(1)} مگابایت'
        : '${(b / 1024).round()} کیلوبایت';
  }
}

class AppUpdateState {
  final String? currentVersion;
  final int? currentBuild;
  final AppReleaseInfo? latest;
  final bool checking;

  const AppUpdateState({
    this.currentVersion,
    this.currentBuild,
    this.latest,
    this.checking = false,
  });

  /// نسخه‌ی تازه‌تری روی سایت هست.
  bool get updateAvailable =>
      latest != null &&
      currentBuild != null &&
      latest!.buildNumber > currentBuild!;

  /// U-3: این نسخه دیگر پشتیبانی نمی‌شود؛ پنجره‌ی به‌روزرسانی بسته نمی‌شود.
  bool get mandatory =>
      updateAvailable && currentBuild! < latest!.minSupportedBuild;

  AppUpdateState copyWith({
    String? currentVersion,
    int? currentBuild,
    AppReleaseInfo? latest,
    bool? checking,
  }) => AppUpdateState(
    currentVersion: currentVersion ?? this.currentVersion,
    currentBuild: currentBuild ?? this.currentBuild,
    latest: latest ?? this.latest,
    checking: checking ?? this.checking,
  );
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  static const String _dismissedKey = 'update_dismissed_build';

  /// کانالِ بومیِ «نسخه‌ی اپ» (اندروید: MainActivity.kt، ویندوز: flutter_window.cpp).
  static const MethodChannel _channel = MethodChannel('ielts_assistant/app_info');

  @override
  AppUpdateState build() => const AppUpdateState();

  /// سکوی این دستگاه به اسمی که سرور می‌شناسد؛ null = این سکو از سایت توزیع نمی‌شود.
  static String? get platformName {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return null;
  }

  /// U-1: نسخه‌ی فعلی را می‌خواند و از سرور آخرین نسخه را می‌پرسد. خطای شبکه بی‌صدا
  /// نادیده گرفته می‌شود (کاربرِ آفلاین نباید پیامِ خطا ببیند). true اگر پرسش موفق بود.
  Future<bool> check() async {
    final String? platform = platformName;
    if (platform == null || state.checking) return false;
    state = state.copyWith(checking: true);
    try {
      // نسخه از کدِ بومیِ خودِ اپ (MainActivity.kt / flutter_window.cpp)، نه از
      // package_info_plus — آن پکیج Build را بدونِ دسترسی به dl.google.com می‌شکست.
      final info = await _channel.invokeMapMethod<String, dynamic>('getAppInfo');
      final String version = info?['version']?.toString() ?? '';
      final int? build = int.tryParse(info?['buildNumber']?.toString() ?? '');
      // بدونِ شماره‌ی build مقایسه بی‌معناست (هر نسخه‌ای «تازه» دیده می‌شد).
      if (build == null || build <= 0) {
        state = state.copyWith(checking: false);
        return false;
      }
      state = state.copyWith(currentVersion: version, currentBuild: build);

      final response = await ref
          .read(dioProvider)
          .get('/api/app/latest', queryParameters: {'platform': platform});
      final data = (response.data is Map) ? response.data['data'] : null;
      state = AppUpdateState(
        currentVersion: version,
        currentBuild: build,
        latest: data is Map
            ? AppReleaseInfo.fromJson(Map<String, dynamic>.from(data))
            : null,
      );
      return true;
    } catch (e) {
      debugPrint('App update check failed: $e');
      state = state.copyWith(checking: false);
      return false;
    }
  }

  /// U-2: آدرسِ صفحه‌ی دریافتِ اپ روی همان سروری که اپ به آن وصل است.
  String? get downloadPageUrl {
    final base = StorageService.getBaseUrl();
    if (base != null && base.isNotEmpty) {
      return '${base.replaceAll(RegExp(r'/+$'), '')}/app';
    }
    return state.latest?.pageUrl;
  }

  /// آیا پنجره‌ی خودکار باید نشان داده شود؟ (U-2: «بعداً» برای همان نسخه دیگر
  /// خودکار نمی‌پرسد؛ نسخه‌ی اجباری همیشه.)
  bool get shouldPrompt {
    if (!state.updateAvailable) return false;
    if (state.mandatory) return true;
    try {
      return GetStorage().read(_dismissedKey) != state.latest!.buildNumber;
    } catch (_) {
      return true;
    }
  }

  void dismissCurrent() {
    final latest = state.latest;
    if (latest == null) return;
    try {
      GetStorage().write(_dismissedKey, latest.buildNumber);
    } catch (_) {}
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);
