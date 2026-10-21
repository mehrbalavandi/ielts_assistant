import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/app_config/app_config.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';

// 🌟 SYNC-1 (RULES-rendering.md): هر چه ادمین در پنلِ سایت عوض می‌کند، با اولین اتصال به اپ برسد —
// نه فقط با بستن و بازکردنِ دوباره‌ی برنامه.
//
// یک‌جا و با هم:
// - تنظیماتِ اپ (GET /api/app/config): روش‌های ورود، اطلاعیه، حالتِ تعمیر، پشتیبانی، پیوندها؛
// - ثبتِ دستگاه (POST /api/devices): مجوزِ آفلاینِ تازه — یعنی «اعتبارِ مجوزِ آفلاین» و «فاصله‌ی
//   جدا کردنِ دستگاه»ِ فعلیِ پنل (exp و gdِ مجوز) — و نام/موبایلِ حساب؛ همراهِ پشتیبانِ «مرورِ
//   من»/تنظیمات و «مرورِ آماده» (BK-1..3، ST-7)؛
// - فهرستِ کتاب‌ها (GET /api/books): خریدی که در سایت انجام شده، قیمت/تخفیف، نشستِ این دستگاه.
//
// کِی: بازشدنِ برنامه (ویترینِ اصلی) و برگشتن به برنامه از پس‌زمینه — حداکثر هر [minInterval]
// یک‌بار، تا رفت‌وبرگشتِ کوتاه به برنامه‌ی دیگر درخواستِ تازه نفرستد. پنجره‌ی تأییدِ خروج جدا و
// بی‌فاصله فقط مجوز را می‌گیرد (BackupNotifier.refreshLicense).
// آفلاین: هر بخش جدا شکست می‌خورد و نسخه‌ی ذخیره‌شده‌ی قبلی می‌ماند.

class ServerSync {
  ServerSync(this._ref);

  final Ref _ref;

  static const Duration minInterval = Duration(minutes: 10);

  DateTime? _last;
  Future<void>? _running;

  /// [force]: بی‌توجه به [minInterval]. [books]: فهرستِ کتاب‌ها هم (بازشدنِ برنامه خودش می‌گیرد).
  Future<void> sync({bool force = false, bool books = true}) {
    final Future<void>? running = _running;
    if (running != null) return running;
    final DateTime now = DateTime.now();
    if (!force && _last != null && now.difference(_last!) < minInterval) {
      return Future<void>.value();
    }
    _last = now;
    return _running = _run(books).whenComplete(() => _running = null);
  }

  Future<void> _run(bool books) async {
    await Future.wait<void>([
      _safe('config', () => _ref.read(appConfigProvider.notifier).refresh()),
      _safe('device', () => _ref.read(backupProvider.notifier).onAppStart()),
      if (books)
        _safe('books', () => _ref.read(booksProvider.notifier).fetchBooks()),
    ]);
  }

  static Future<void> _safe(String what, Future<Object?> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('ServerSync($what): $e');
    }
  }
}

final serverSyncProvider = Provider<ServerSync>(ServerSync.new);
