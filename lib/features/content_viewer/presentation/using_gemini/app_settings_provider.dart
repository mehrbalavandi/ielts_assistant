import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';

// پرووایدر کلاینت Dio
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = StorageService.getBaseUrl() ?? 'https://api.yourdomain.com';

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // 🌟 مرحله ۳ (گام ۴): نگهبان دیو (Interceptor) برای تزریق خودکار توکن
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // اینجا می‌توانید هندلینگ خطای 401 (توکن منقضی شده) را مدیریت کنید
        return handler.next(e);
      },
    ),
  );

  return dio;
});
