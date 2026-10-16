import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/device/device_identity.dart';
import 'package:ielts_assistant/core/network/session_events.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';

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

  // 🌟 نگهبان دیو (Interceptor): توکن + شناسه‌ی دستگاه، و خبرِ پایانِ نشست.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // 🌟 DEV-1: سرور توکن را فقط از همان دستگاهی می‌پذیرد که به آن گره خورده.
        // همه‌ی درخواست‌ها (حتی مهمان) این را دارند؛ هیچ درخواستی نباید از Dioِ دیگری برود.
        if (DeviceIdentity.id.isNotEmpty) {
          options.headers[DeviceIdentity.header] = DeviceIdentity.id;
        }
        // اضافه کردن توکن (در صورت وجود و لاگین بودن کاربر)
        final token = StorageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // 🌟 DEV-1: ۴۰۱ با دلیل ← SessionGuard خارج می‌شود (و برای دستگاهِ جداشده محتوا را پاک می‌کند).
        final Object? data = e.response?.data;
        final bool hadToken =
            e.requestOptions.headers.containsKey('Authorization');
        if (e.response?.statusCode == 401 && hadToken && data is Map) {
          SessionEvents.emit(
            (data['reason'] ?? 'unauthenticated').toString(),
            data['message']?.toString(),
          );
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
