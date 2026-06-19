import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

// پرووایدر سرویس حافظه
final storageServiceProvider = Provider((ref) => StorageService());

// پرووایدر اختصاصی دیو
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(storageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.110.198.220:8000/api', // آدرس معتبر شما
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // اضافه کردن اینترسپتور برای تزریق خودکار توکن Sanctum
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options); // عبور درخواست
      },
      onError: (DioException e, handler) {
        // 💡 ایده: اگر سرور خطای 401 (توکن منقضی شده) داد، می‌توانید کاربر را خودکار لوپ‌اوت کنید
        return handler.next(e);
      },
    ),
  );

  return dio;
});
