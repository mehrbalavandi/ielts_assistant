import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';

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
  Future<bool> login(String username, String password) async {
    try {
      // در اینجا باید با Dio درخواست لاگین بفرستید
      // final response = await ref.read(dioProvider).post('/api/login', data: {...});
      // String token = response.data['token'];

      // شبیه‌سازی دریافت توکن از سرور:
      await Future.delayed(const Duration(seconds: 2));
      String dummyToken = "123456789_secure_token";

      await StorageService.saveToken(dummyToken);
      state = AuthState
          .authenticated; // 🌟 این خط روتر فلاتر را شوت می‌کند به صفحه کتاب‌ها!
      return true;
    } catch (e) {
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
