import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/app/app.dart';

/// نقطه‌ی ورودِ برنامه — فقط راه‌اندازیِ اولیه.
/// 🌟 خودِ ویجتِ ریشه به app/app.dart منتقل شد: main.dart جای «چه چیزی قبل از
/// بالاآمدنِ اپ باید آماده باشد» است، نه جای تعریفِ تم و صفحه‌ی شروع.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(const ProviderScope(child: IeltsAssistantApp()));
}
