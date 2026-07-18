import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

enum AuthState { initial, authenticated, unauthenticated }

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 🌟 مرحله ۱: بررسی فوری استوریج در لحظه تولد کلاس
    final token = StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      return AuthState.authenticated;
    }
    return AuthState.unauthenticated;
  }

  // 🌟 مرحله ۲: لاگین، دریافت توکن و تغییر وضعیت
  Future<bool> login(String email, String password) async {
    try {
      // در اینجا باید با Dio درخواست لاگین بفرستید
      final response = await ref
          .read(dioProvider)
          .post('/api/login', data: {'email': email, 'password': password});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['token'];

        // ذخیره در دیتابیس محلی GetStorage
        StorageService.saveToken(token);
        state = AuthState.authenticated;
        return true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'خطایی در ورود رخ داد';
      debugPrint(msg);
      state = AuthState.initial;
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.removeToken();
    state = AuthState.unauthenticated;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);
