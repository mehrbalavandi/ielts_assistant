import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/app/app.dart';
import 'package:ielts_assistant/features/audio/data/media_session_service.dart';
import 'package:ielts_assistant/core/device/device_identity.dart';
import 'package:ielts_assistant/core/license/license_service.dart';

/// نقطه‌ی ورودِ برنامه — فقط راه‌اندازیِ اولیه.
/// 🌟 خودِ ویجتِ ریشه به app/app.dart منتقل شد: main.dart جای «چه چیزی قبل از
/// بالاآمدنِ اپ باید آماده باشد» است، نه جای تعریفِ تم و صفحه‌ی شروع.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  // 🌟 DEV-1/4: شناسه‌ی دستگاه پیش از اولین درخواستِ شبکه، و وارسیِ مجوزِ آفلاینِ ذخیره‌شده
  // پیش از اولین نمایشِ ویترین.
  await DeviceIdentity.init();
  await LicenseService.init();
  // 🌟 AU-6: اعلانِ رسانه و کنترل از صفحه‌ی قفل (اندروید).
  await MediaSessionService.init();
  runApp(const ProviderScope(child: IeltsAssistantApp()));
}
