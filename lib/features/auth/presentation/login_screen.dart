import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/auth/presentation/device_limit_dialog.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';

// 🌟 AUTH-1: ورود/ثبت‌نام با شماره‌ی موبایل و کدِ پیامکی، در دو مرحله:
//   ۱) شماره ← «دریافتِ کد»
//   ۲) کد (و برای کاربرِ تازه نام و نام خانوادگی) ← «ورود»
// ورودِ قدیمی با ایمیل/رمز برای حساب‌های قبلی و ادمین‌ها پایینِ صفحه می‌ماند.
// آدرسِ سرور (برای توسعه) داخلِ «تنظیماتِ سرور» است.

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { mobile, code, email }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _lastController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  _Step _step = _Step.mobile;
  bool _busy = false;
  String? _error;
  String? _info;
  String? _mobile; // شماره‌ی یکسان‌شده از سرور
  bool _registered = true;
  int _codeLength = 5;
  String? _debugCode;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _urlController.text =
        StorageService.getBaseUrl() ?? 'http://10.110.198.220:8000';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _urlController,
      _mobileController,
      _codeController,
      _firstController,
      _lastController,
      _emailController,
      _passwordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _applyServerUrl() async {
    final String url = _urlController.text.trim();
    if (url.isNotEmpty && url != StorageService.getBaseUrl()) {
      await StorageService.saveBaseUrl(url);
      ref.invalidate(dioProvider);
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _requestCode() async {
    final String raw = _mobileController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'شماره‌ی موبایل را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _applyServerUrl();
    final OtpRequestResult r = await ref
        .read(authProvider.notifier)
        .requestOtp(raw);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok && r.mobile != null) {
        _mobile = r.mobile;
        _registered = r.registered;
        _codeLength = r.codeLength;
        _debugCode = r.debugCode;
        _info = r.message;
        _step = _Step.code;
        _codeController.clear();
      } else {
        _error = r.message;
      }
    });
    if (r.ok) _startCountdown(r.retryAfter);
  }

  Future<void> _verify() async {
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'کدِ پیامک‌شده را وارد کنید.');
      return;
    }
    if (!_registered &&
        (_firstController.text.trim().isEmpty ||
            _lastController.text.trim().isEmpty)) {
      setState(() => _error = 'نام و نام خانوادگی را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    OtpVerifyResult r = await ref
        .read(authProvider.notifier)
        .verifyOtp(
          _mobile!,
          code,
          firstName: _registered ? null : _firstController.text.trim(),
          lastName: _registered ? null : _lastController.text.trim(),
        );
    if (!mounted) return;
    // 🌟 DEV-2: حساب روی دستگاهِ دیگری فعال است ← جدا کردنِ یکی و ورود (یا توضیح).
    if (r.deviceLimit != null) {
      r = await _resolveDeviceLimit(r);
      if (!mounted) return;
    }
    if (r.ok) {
      ref.read(booksProvider.notifier).fetchBooks();
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.message)));
      return;
    }
    setState(() {
      _busy = false;
      _error = r.message;
      // سرور می‌گوید حساب تازه است (مثلاً حذف شده بود) ← فیلدهای نام.
      if (r.needsProfile) _registered = false;
    });
  }

  Future<void> _emailLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'ایمیل و رمز را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _applyServerUrl();
    // 🌟 رمز و ایمیل فقط به سرور ارسال شده و هرگز در گوشی ذخیره نمی‌شوند
    OtpVerifyResult r = await ref
        .read(authProvider.notifier)
        .login(email, password);
    if (!mounted) return;
    if (r.deviceLimit != null) {
      r = await _resolveDeviceLimit(r);
      if (!mounted) return;
    }
    if (r.ok) {
      ref.read(booksProvider.notifier).fetchBooks();
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = r.message.isEmpty ? 'ورود ممکن نشد.' : r.message;
      });
    }
  }

  /// 🌟 DEV-2: پنجره‌ی «این حساب روی دستگاهِ دیگری فعال است». اگر کاربر دستگاهی را جدا کرد،
  /// نتیجه‌ی ورودِ موفق برمی‌گردد؛ وگرنه همان پیامِ سقفِ دستگاه به‌عنوانِ خطا.
  Future<OtpVerifyResult> _resolveDeviceLimit(OtpVerifyResult r) async {
    final OtpVerifyResult? replaced = await showDeviceLimitDialog(
      context,
      r.deviceLimit!,
    );
    return replaced ?? OtpVerifyResult(ok: false, message: r.message);
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _primaryButton(String label, VoidCallback onPressed) => FilledButton(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: _busy ? null : onPressed,
    child: _busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, style: const TextStyle(fontSize: 16)),
  );

  List<Widget> _mobileStep() => [
    const Text(
      'شماره‌ی موبایلتان را وارد کنید تا کدِ ورود برایتان پیامک شود. اگر حساب ندارید، همین‌جا ساخته می‌شود.',
      style: TextStyle(height: 1.8),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [LengthLimitingTextInputFormatter(14)],
      decoration: _decoration('شماره‌ی موبایل', hint: '09121234567'),
      onSubmitted: (_) => _requestCode(),
    ),
    const SizedBox(height: 20),
    _primaryButton('دریافتِ کد', _requestCode),
  ];

  List<Widget> _codeStep() => [
    Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'کد به '),
                TextSpan(
                  text: _mobile,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' پیامک شد.'),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _Step.mobile;
                  _error = null;
                }),
          child: const Text('تغییرِ شماره'),
        ),
      ],
    ),
    if (_debugCode != null)
      Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'سرورِ توسعه — کد: $_debugCode',
          style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
        ),
      ),
    const SizedBox(height: 16),
    TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      autofocus: true,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: _codeLength,
      style: const TextStyle(fontSize: 22, letterSpacing: 8),
      decoration: _decoration('کدِ تأیید').copyWith(counterText: ''),
      onSubmitted: (_) => _verify(),
    ),
    if (!_registered) ...[
      const SizedBox(height: 8),
      const Text(
        'حسابِ تازه — نام و نام خانوادگی:',
        style: TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _firstController,
              textInputAction: TextInputAction.next,
              decoration: _decoration('نام'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _lastController,
              decoration: _decoration('نام خانوادگی'),
              onSubmitted: (_) => _verify(),
            ),
          ),
        ],
      ),
    ],
    const SizedBox(height: 20),
    _primaryButton(_registered ? 'ورود' : 'ساختِ حساب و ورود', _verify),
    const SizedBox(height: 8),
    Center(
      child: TextButton(
        onPressed: (_busy || _resendIn > 0) ? null : _requestCode,
        child: Text(
          _resendIn > 0
              ? 'ارسالِ دوباره تا $_resendIn ثانیه‌ی دیگر'
              : 'ارسالِ دوباره‌ی کد',
        ),
      ),
    ),
  ];

  List<Widget> _emailStep() => [
    const Text(
      'برای حساب‌هایی که پیش‌تر با ایمیل ساخته شده‌اند. بعد از ورود می‌توانید شماره‌ی موبایل را هم به حساب وصل کنید.',
      style: TextStyle(height: 1.8),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      decoration: _decoration('ایمیل'),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _passwordController,
      obscureText: true,
      textDirection: TextDirection.ltr,
      decoration: _decoration('رمز عبور'),
      onSubmitted: (_) => _emailLogin(),
    ),
    const SizedBox(height: 20),
    _primaryButton('ورود', _emailLogin),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ورود یا ثبت‌نام')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _step == _Step.email
                        ? Icons.alternate_email_rounded
                        : Icons.phone_iphone_rounded,
                    size: 64,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    _Banner(text: _error!, color: Colors.red),
                  if (_error == null && _info != null && _step == _Step.code)
                    _Banner(text: _info!, color: Colors.green),
                  ...(switch (_step) {
                    _Step.mobile => _mobileStep(),
                    _Step.code => _codeStep(),
                    _Step.email => _emailStep(),
                  }),
                  const SizedBox(height: 24),
                  const Divider(),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _error = null;
                            _step = _step == _Step.email
                                ? _Step.mobile
                                : _Step.email;
                          }),
                    child: Text(
                      _step == _Step.email
                          ? 'ورود با شماره‌ی موبایل'
                          : 'حسابِ قدیمیِ ایمیلی دارم',
                    ),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'تنظیماتِ سرور',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      TextField(
                        controller: _urlController,
                        textDirection: TextDirection.ltr,
                        decoration: _decoration('آدرسِ سرور (API)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, height: 1.6)),
    );
  }
}
