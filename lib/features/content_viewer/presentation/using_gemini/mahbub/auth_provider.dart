import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/app_settings_provider.dart'
    show dioProvider;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/mahbub/dio_provider.dart'
    show storageServiceProvider;
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/mahbub/storage_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  AuthState({required this.status, this.user, this.errorMessage});

  // وضعیت اولیه (بررسی می‌کند آیا از قبل توکن داریم یا خیر)
  factory AuthState.initial(StorageService storage) {
    final token = storage.getToken();
    final user = storage.getUser();
    if (token != null && user != null) {
      return AuthState(status: AuthStatus.authenticated, user: user);
    }
    return AuthState(status: AuthStatus.unauthenticated);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final StorageService _storage;

  AuthNotifier(this._dio, this._storage) : super(AuthState.initial(_storage));

  // عملیات ورود (Login)
  Future<void> login(String email, String password) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final response = await _dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['token'];
        final userData = response.data['user'];

        // ذخیره در دیتابیس محلی GetStorage
        _storage.saveToken(token);
        _storage.saveUser(userData);

        // به‌روزرسانی وضعیت اپلیکیشن
        state = AuthState(status: AuthStatus.authenticated, user: userData);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'خطایی در ورود رخ داد';
      state = AuthState(status: AuthStatus.error, errorMessage: msg);
    }
  }

  // عملیات خروج (Logout)
  Future<void> logout() async {
    try {
      // ارسال درخواست به لاراول برای ابطال توکن (اینترسپتور خودش توکن را می‌فرستد)
      await _dio.post('/logout');
    } catch (_) {
      // حتی اگر اینترنت نبود، کاربر را از گوشی خارج می‌کنیم
    } finally {
      _storage.clearAuth();
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }
}

// ایجاد پرووایدر نهایی برای استفاده در کل UI
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(dio, storage);
});
