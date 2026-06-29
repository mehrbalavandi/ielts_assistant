import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/app_settings_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/auth_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController.text =
        StorageService.getBaseUrl() ?? 'http://10.110.198.220:8000';
  }

  void _doLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final url = _urlController.text.trim();

    if (email.isEmpty || password.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لطفاً تمام فیلدها را پر کنید.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    await StorageService.saveBaseUrl(url);
    ref.invalidate(dioProvider);

    // 🌟 درخواست لاگین: رمز و ایمیل فقط به سرور ارسال شده و هرگز در گوشی ذخیره نمی‌شوند
    bool success = await ref.read(authProvider.notifier).login(email, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("خطا در ورود. ایمیل یا رمز عبور اشتباه است."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ورود به حساب کاربری")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_person_rounded,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: "آدرس سرور (API)",
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "نام کاربری (ایمیل)",
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "رمز عبور",
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _doLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "ورود به حساب",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
