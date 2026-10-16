import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 DEV-1: شناسه‌ی این دستگاه برای محدودیتِ دستگاهِ هر حساب.
//
// - **از سخت‌افزار:** اندروید ANDROID_ID (از MainActivity.kt) و ویندوز MachineGuid (رجیستری).
//   پس نصبِ دوباره‌ی اپ همان دستگاه حساب می‌شود و یک جای دیگر از سقفِ دستگاه نمی‌گیرد.
// - **کپی‌ناپذیر:** شناسه هر بار از سخت‌افزار ساخته می‌شود، نه از فایلی که بشود کپی کرد. اگر
//   فایل‌های اپ (و توکن) به دستگاهِ دیگری برده شوند، آن‌جا شناسه‌ی دیگری ساخته می‌شود و سرور
//   توکن را رد و باطل می‌کند.
// - **حریمِ خصوصی:** خودِ ANDROID_ID/MachineGuid فرستاده نمی‌شود، فقط sha256ِ آن.
// - **فال‌بک:** اگر شناسه‌ی سخت‌افزاری در دسترس نباشد، یک شناسه‌ی تصادفیِ ذخیره‌شده (r1-…).
//
// init() پیش از runApp صدا زده می‌شود (main.dart) تا هر درخواستِ شبکه هدرِ X-Device-Id را داشته باشد.

class DeviceIdentity {
  DeviceIdentity._();

  static const String header = 'X-Device-Id';
  static const MethodChannel _channel = MethodChannel('ielts_assistant/device');
  static const String _fallbackKey = 'device_id_fallback';

  /// ANDROID_IDِ معیوبِ برخی شبیه‌سازها/گوشی‌های قدیمی که میانِ دستگاه‌ها مشترک است.
  static const Set<String> _knownBadIds = {'9774d56d682e549c', '0000000000000000'};

  static String _id = '';
  static String _model = '';
  static bool _hardwareBound = false;

  /// شناسه‌ای که سرور دستگاه را با آن می‌شناسد (h1-… از سخت‌افزار، r1-… تصادفی).
  static String get id => _id;

  /// نامِ قابلِ‌فهم برای فهرستِ دستگاه‌ها (مثلاً «Samsung SM-A515F» یا نامِ کامپیوتر).
  static String get model => _model;

  static bool get hardwareBound => _hardwareBound;

  static String get platform => Platform.isAndroid
      ? 'android'
      : Platform.isWindows
      ? 'windows'
      : Platform.operatingSystem;

  /// 🌟 DEV-5: نوعِ ساخت. روی اندروید ANDROID_ID به کلیدِ امضا بسته است؛ پس اگر debug و release
  /// با دو کلیدِ متفاوت امضا شوند، یک گوشی دو دستگاه حساب می‌شود (build.gradle.kts هر دو را
  /// با کلیدِ release امضا می‌کند تا این پیش نیاید). سرور و پنل این را نشان می‌دهند.
  static String get buildMode => kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  /// شناسه‌ی کوتاه برای نمایش (همان که پنل و «دستگاه‌های من» نشان می‌دهند).
  static String get shortId => _id.length > 9 ? _id.substring(0, 9) : _id;

  /// 🌟 DEV-5: شناسه‌ی تصادفیِ قبلیِ همین دستگاه (r1-…) وقتی حالا شناسه‌ی سخت‌افزاری داریم؛
  /// سرور همان ردیف را به شناسه‌ی تازه منتقل می‌کند تا جای دیگری از سقفِ دستگاه گرفته نشود.
  static String? _previousFallback;

  /// مشخصاتی که هنگامِ ورود فرستاده می‌شود (OtpAuth/AuthController و DeviceService سرور).
  static Map<String, Object?> loginFields() => {
    'device_id': _id,
    'device_name': _model.isEmpty ? platform : _model,
    'platform': platform,
    'model': _model,
    'build_mode': buildMode,
    'previous_device_id': ?_previousFallback,
  };

  /// بعد از ورودِ موفق با شناسه‌ی سخت‌افزاری، شناسه‌ی تصادفیِ قدیمی دیگر لازم نیست.
  static void forgetPreviousFallback() {
    if (_previousFallback == null) return;
    _previousFallback = null;
    GetStorage().remove(_fallbackKey);
  }

  static Future<void> init() async {
    if (_id.isNotEmpty) return;
    String? hw;
    try {
      if (Platform.isAndroid) {
        final Map<String, dynamic>? info = await _channel
            .invokeMapMethod<String, dynamic>('info');
        hw = info?['androidId'] as String?;
        final String maker = (info?['manufacturer'] as String? ?? '').trim();
        final String model = (info?['model'] as String? ?? '').trim();
        _model = model.toLowerCase().startsWith(maker.toLowerCase())
            ? model
            : '$maker $model'.trim();
      } else if (Platform.isWindows) {
        hw = _windowsMachineGuid() ?? await _windowsMachineGuidViaReg();
        _model = Platform.localHostname;
      }
    } catch (e) {
      debugPrint('DeviceIdentity: hardware id unavailable: $e');
    }

    final String norm = (hw ?? '').trim().toLowerCase();
    if (norm.length >= 8 && !_knownBadIds.contains(norm)) {
      final Digest d = sha256.convert(
        utf8.encode('ielts-assistant|device|v1|$platform|$norm'),
      );
      _id = 'h1-${d.toString().substring(0, 40)}';
      _hardwareBound = true;
      final String? stored = GetStorage().read<String>(_fallbackKey);
      if (stored != null && stored.startsWith('r1-')) _previousFallback = stored;
    } else {
      _id = _fallbackId();
      _hardwareBound = false;
    }
    if (_model.length > 100) _model = _model.substring(0, 100);
  }

  static String _fallbackId() {
    final GetStorage box = GetStorage();
    final String? existing = box.read<String>(_fallbackKey);
    if (existing != null && existing.startsWith('r1-')) return existing;
    final Random r = Random.secure();
    final String id =
        'r1-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    box.write(_fallbackKey, id);
    return id;
  }

  // ───────── ویندوز: HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid ─────────

  /// خواندنِ مستقیم با RegGetValueW (بدونِ پنجره‌ی کنسول). نمای ۶۴بیتیِ رجیستری.
  static String? _windowsMachineGuid() {
    try {
      final DynamicLibrary advapi = DynamicLibrary.open('advapi32.dll');
      final int Function(
        int,
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        Pointer<Uint32>,
        Pointer<Void>,
        Pointer<Uint32>,
      )
      regGetValue = advapi
          .lookupFunction<
            Int32 Function(
              IntPtr,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Uint32,
              Pointer<Uint32>,
              Pointer<Void>,
              Pointer<Uint32>,
            ),
            int Function(
              int,
              Pointer<Utf16>,
              Pointer<Utf16>,
              int,
              Pointer<Uint32>,
              Pointer<Void>,
              Pointer<Uint32>,
            )
          >('RegGetValueW');

      // HKEY_LOCAL_MACHINE = (HKEY)(LONG)0x80000002 — روی ۶۴بیت با گسترشِ علامت.
      const int hkeyLocalMachine = -2147483646;
      const int rrfRtRegSz = 0x00000002;
      const int rrfSubkeyWow6464Key = 0x00010000;

      final Pointer<Utf16> subKey = r'SOFTWARE\Microsoft\Cryptography'
          .toNativeUtf16(allocator: calloc);
      final Pointer<Utf16> value = 'MachineGuid'.toNativeUtf16(
        allocator: calloc,
      );
      const int capacityBytes = 512;
      final Pointer<Uint16> data = calloc<Uint16>(capacityBytes ~/ 2);
      final Pointer<Uint32> size = calloc<Uint32>()..value = capacityBytes;
      try {
        final int rc = regGetValue(
          hkeyLocalMachine,
          subKey,
          value,
          rrfRtRegSz | rrfSubkeyWow6464Key,
          nullptr,
          data.cast<Void>(),
          size,
        );
        if (rc != 0) return null;
        final String s = data.cast<Utf16>().toDartString();
        return s.trim().isEmpty ? null : s.trim();
      } finally {
        calloc.free(subKey);
        calloc.free(value);
        calloc.free(data);
        calloc.free(size);
      }
    } catch (e) {
      debugPrint('DeviceIdentity: RegGetValueW failed: $e');
      return null;
    }
  }

  /// فال‌بک: `reg query` (اگر بارگذاریِ advapi32 به هر دلیلی نشد).
  static Future<String?> _windowsMachineGuidViaReg() async {
    try {
      final ProcessResult r = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
        '/reg:64',
      ]);
      for (final String line in r.stdout.toString().split(RegExp(r'\r?\n'))) {
        if (line.contains('MachineGuid')) {
          final List<String> parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 3) return parts.last;
        }
      }
    } catch (e) {
      debugPrint('DeviceIdentity: reg query failed: $e');
    }
    return null;
  }
}
