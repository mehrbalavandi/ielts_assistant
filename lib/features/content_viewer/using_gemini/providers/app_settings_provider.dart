import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

// پرووایدر کلاینت Dio
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = StorageService.getBaseUrl() ?? 'http://10.110.198.220:8000';

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // 🌟 نگهبان دیو (Interceptor) فقط برای تزریق ایمن توکن
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // اضافه کردن توکن (در صورت وجود و لاگین بودن کاربر)
        final token = StorageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ),
  );

  return dio;
});
