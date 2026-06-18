import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';

// ۱. پرووایدر برای نگهداری آدرس سرور
final baseUrlProvider = StateProvider<String?>((ref) {
  final box = GetStorage();
  return box.read('base_url');
});

// ۲. پرووایدر کلاینت Dio (با تنظیم خودکار Base URL)
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // در صورت نیاز می‌توانید Interceptor ها را اینجا اضافه کنید
  return dio;
});
