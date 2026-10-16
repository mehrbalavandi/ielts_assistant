import 'dart:async';

import 'package:flutter/foundation.dart';

// 🌟 DEV-1: سرور گفته نشستِ این دستگاه دیگر معتبر نیست (۴۰۱ با reason، یا session.valid=false
// در GET /api/books). این‌جا فقط خبر پخش می‌شود؛ SessionGuard (features/auth) خروج و در صورتِ
// لزوم پاک‌کردنِ محتوای کامل را انجام می‌دهد. جدا نگه داشته شده تا dio_provider و
// books_provider به لایه‌ی auth وابسته نشوند.

@immutable
class SessionDenied {
  final String reason;
  final String message;

  const SessionDenied(this.reason, this.message);

  /// دستگاه از حساب جدا شده یا توکن از دستگاهِ دیگری آمده ← محتوای کاملِ کتاب‌ها پاک می‌شود.
  bool get wipesContent =>
      reason == 'device_revoked' || reason == 'device_mismatch';
}

class SessionEvents {
  SessionEvents._();

  /// دلیل‌هایی که یعنی «این نشست تمام است» (نه خطای موقتِ شبکه یا هدرِ جاافتاده).
  static const Set<String> endingReasons = {
    'device_revoked',
    'device_mismatch',
    'unbound',
    'invalid_token',
    'unauthenticated',
  };

  static final StreamController<SessionDenied> _controller =
      StreamController<SessionDenied>.broadcast();

  static Stream<SessionDenied> get stream => _controller.stream;

  static void emit(String reason, String? message) {
    if (!endingReasons.contains(reason)) return;
    _controller.add(
      SessionDenied(
        reason,
        (message == null || message.isEmpty)
            ? 'نشستِ شما معتبر نیست؛ دوباره وارد شوید.'
            : message,
      ),
    );
  }
}
