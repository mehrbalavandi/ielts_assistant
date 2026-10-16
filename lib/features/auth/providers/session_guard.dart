import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/app/app_messenger.dart';
import 'package:ielts_assistant/core/network/session_events.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';

// 🌟 DEV-1: وقتی سرور می‌گوید نشستِ این دستگاه تمام است (SessionEvents):
// - همیشه: خروجِ محلی (توکن، کاربر، مجوزِ آفلاین).
// - دستگاه از حساب جدا شده (device_revoked) یا توکنش از دستگاهِ دیگری آمده (device_mismatch):
//   صفحه‌های باز بسته و محتوای کاملِ کتاب‌های خریده‌شده از این دستگاه پاک می‌شود (نمونه‌ها
//   می‌مانند). این همان «آزادسازیِ دستگاه» از دیدِ دستگاهِ قدیمی است.
// - پیامِ سرور به کاربر نشان داده می‌شود.
// IeltsAssistantApp آن را watch می‌کند تا از شروعِ اپ گوش بدهد.

class SessionGuard extends Notifier<int> {
  bool _handling = false;

  @override
  int build() {
    final StreamSubscription<SessionDenied> sub = SessionEvents.stream.listen(
      _onDenied,
    );
    ref.onDispose(sub.cancel);
    return 0;
  }

  Future<void> _onDenied(SessionDenied e) async {
    final String? token = StorageService.getToken();
    if (_handling || token == null || token.isEmpty) return;
    _handling = true;
    try {
      await ref.read(authProvider.notifier).endSessionLocally();
      if (e.wipesContent) {
        appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
        ref.read(activeBookProvider.notifier).state = null;
        await ref.read(booksProvider.notifier).wipePurchasedContent();
      }
      state++;
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 8),
        ),
      );
      // ویترین با وضعیتِ مهمان تازه شود (خریدها دیگر «خریده‌شده» نشان داده نشوند).
      unawaited(ref.read(booksProvider.notifier).fetchBooks());
    } finally {
      _handling = false;
    }
  }
}

final sessionGuardProvider = NotifierProvider<SessionGuard, int>(
  SessionGuard.new,
);
