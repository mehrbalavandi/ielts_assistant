import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  LoginScreen({Key? key}) : super(key: key);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // گوش دادن به وضعیت احراز هویت
    final authState = ref.watch(authProvider);

    // مانیتور کردن خطاها به صورت پاپ‌آپ (SnackBar)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'خطا'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (next.status == AuthStatus.authenticated) {
        // هدایت به صفحه اصلی (ویترین کتاب‌ها)
        Navigator.pushReplacementNamed(context, '/books_screen');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('ورود به حساب')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        key: const Key('login_form'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'ایمیل'),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'رمز عبور'),
              obscureText: true,
            ),
            const SizedBox(height: 30),

            // نمایش لودینگ یا دکمه بر اساس وضعیت
            authState.status == AuthStatus.loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      ref
                          .read(authProvider.notifier)
                          .login(
                            _emailController.text.trim(),
                            _passwordController.text.trim(),
                          );
                    },
                    child: const Text('ورود'),
                  ),
          ],
        ),
      ),
    );
  }
}
