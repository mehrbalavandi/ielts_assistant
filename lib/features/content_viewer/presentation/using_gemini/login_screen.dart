import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/providers/auth_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController.text =
        StorageService.getBaseUrl() ?? 'https://10.110.198.220';
  }

  void _doLogin() async {
    setState(() => _isLoading = true);
    await StorageService.saveBaseUrl(_urlController.text.trim());

    // شبیه‌سازی ورود
    await ref.read(authProvider.notifier).login("mehr@test.com", "1");
    // (هدایت به صورت خودکار توسط main.dart انجام می‌شود)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
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
                decoration: const InputDecoration(labelText: "آدرس سرور (API)"),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _doLogin,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ورود به حساب"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
