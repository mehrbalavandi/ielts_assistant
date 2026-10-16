import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/db/app_database.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/settings/providers/answer_display_provider.dart';
import 'package:ielts_assistant/features/settings/providers/audio_settings_provider.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/settings/providers/reading_mode_provider.dart';
import 'package:ielts_assistant/features/settings/providers/word_card_provider.dart';
import 'package:ielts_assistant/features/study/data/study_rows.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';
import 'package:ielts_assistant/features/study/providers/study_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 🌟 BK-1..BK-3: پشتیبانِ داده‌های کاربر روی سرور (فقط وقتی وارد حساب شده).
//
// - «مرورِ من» (BK-1): همگام‌سازیِ دوطرفه و افزایشی. تغییرهای محلی (dirty، شاملِ
//   حذف‌ها) فرستاده می‌شوند و تغییرهای سرور از آخرین همگام‌سازی گرفته می‌شوند؛ در هر
//   مورد «آخرین تغییر برنده است». ۵ ثانیه بعد از هر تغییر، با بازشدنِ اپ، بعد از ورود و
//   با دکمه‌ی «پشتیبان‌گیریِ الان».
// - تنظیمات (BK-2): شیوه‌ی نمایشِ پاسخ/ترجمه، شروعِ صدا، زبان، جای مطالعه‌ی هر کتاب.
//   بارِ اولِ هر حساب روی یک دستگاه: اگر سرور نسخه‌ای دارد، همان برمی‌گردد (نصبِ تازه)؛
//   از آن به بعد هر تغییر بالا می‌رود.
// - دستگاه (BK-3): شناسه‌ی تصادفیِ همین نصب، سکو و نسخه‌ی اپ.
//
// داده‌های محلی مالِ یک حساب‌اند: اگر حسابِ دیگری روی همین دستگاه وارد شود، «مرورِ من»ِ
// محلیِ حسابِ قبلی پاک و از سرورِ حسابِ تازه پر می‌شود. موردهای پیش از اولین ورود
// (مهمان) به اولین حسابی که وارد شود می‌پیوندند.

@immutable
class BackupState {
  final bool syncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  const BackupState({this.syncing = false, this.lastSyncAt, this.lastError});

  BackupState copyWith({
    bool? syncing,
    DateTime? lastSyncAt,
    String? Function()? lastError,
  }) => BackupState(
    syncing: syncing ?? this.syncing,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastError: lastError != null ? lastError() : this.lastError,
  );
}

class BackupNotifier extends Notifier<BackupState> {
  static const String _ownerKey = 'backup_user_id';
  static const String _lastSyncKey = 'backup_last_sync_ms';
  static const String _deviceIdKey = 'device_id';
  static const int _chunk = 400;

  final GetStorage _box = GetStorage();
  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  BackupState build() {
    ref.onDispose(() => _debounce?.cancel());
    final int? ms = _box.read<int>(_lastSyncKey);
    return BackupState(
      lastSyncAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  bool get _loggedIn => (StorageService.getToken() ?? '').isNotEmpty;

  /// ۵ ثانیه بعد از آخرین تغییر (چند تغییرِ پشتِ هم = یک درخواست).
  void scheduleSync() {
    if (!_loggedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), syncNow);
  }

  /// با بازشدنِ اپ (ویترین).
  Future<void> onAppStart() async {
    if (!_loggedIn) return;
    await _touchDevice();
    await syncNow();
  }

  /// بلافاصله بعد از ورود.
  Future<void> onLogin() async {
    await _touchDevice();
    await syncNow();
  }

  /// true اگر موفق بود.
  Future<bool> syncNow() async {
    if (!_loggedIn) return false;
    if (_running) {
      _again = true;
      return false;
    }
    _running = true;
    state = state.copyWith(syncing: true);
    try {
      final Dio dio = ref.read(dioProvider);
      final String uid = await _userId(dio);
      final AppDatabase db = ref.read(appDatabaseProvider);

      final Object? owner = _box.read(_ownerKey);
      if (owner != null && owner.toString() != uid) {
        await db.clearStudyItems();
      }
      await _box.write(_ownerKey, uid);

      final String sinceKey = 'study_since_ms_$uid';
      final int? since = _box.read<int>(sinceKey);
      final bool firstSyncForAccount = since == null;

      List<StudyItemRow> pending = await db.dirtyStudyItems();
      int? cursor;
      do {
        final List<StudyItemRow> chunk = pending.take(_chunk).toList();
        pending = pending.skip(_chunk).toList();
        final Response<dynamic> res = await dio.post(
          '/api/backup/study/sync',
          data: {
            'since_ms': since,
            'items': chunk.map(studyRowToSyncJson).toList(),
          },
        );
        // فرستاده‌ها: اگر از آن لحظه دوباره عوض نشده‌اند، تمیز (و سنگِ قبر پاک).
        for (final StudyItemRow r in chunk) {
          if (r.deleted) {
            final StudyItemRow? now = await db.studyItemById(r.id);
            if (now != null && now.deleted && now.updatedMs == r.updatedMs) {
              await db.deleteStudyItem(r.id);
            }
          } else {
            await db.markStudyItemClean(r.id, r.updatedMs);
          }
        }
        for (final Object? j in (res.data['items'] as List? ?? const [])) {
          if (j is Map) await _applyServerItem(db, Map<String, dynamic>.from(j));
        }
        cursor = (res.data['server_ms'] as num?)?.toInt() ?? cursor;
      } while (pending.isNotEmpty);
      if (cursor != null) await _box.write(sinceKey, cursor);

      await ref.read(studyProvider.notifier).reload();
      await _syncSettings(dio, uid, restoreFromServer: firstSyncForAccount);

      final DateTime now = DateTime.now();
      await _box.write(_lastSyncKey, now.millisecondsSinceEpoch);
      state = BackupState(lastSyncAt: now);
      return true;
    } catch (e) {
      debugPrint('backup: sync failed: $e');
      state = state.copyWith(
        syncing: false,
        lastError: () => e is DioException
            ? 'اتصال به سرور برقرار نشد.'
            : 'پشتیبان‌گیری ناموفق بود.',
      );
      return false;
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        scheduleSync();
      }
    }
  }

  /// موردِ سرور فقط اگر از نسخه‌ی محلی تازه‌تر است نوشته می‌شود.
  Future<void> _applyServerItem(AppDatabase db, Map<String, dynamic> j) async {
    final String? id = j['id'] as String?;
    final int updated = (j['updated'] as num?)?.toInt() ?? 0;
    if (id == null) return;
    final StudyItemRow? local = await db.studyItemById(id);
    if (local != null && local.updatedMs >= updated) {
      if (local.updatedMs == updated) await db.markStudyItemClean(id, updated);
      return;
    }
    if (j['deleted'] == true) {
      await db.deleteStudyItem(id);
      return;
    }
    final StudyItem? item = StudyItem.fromJson(j);
    if (item != null) {
      await db.upsertStudyItem(studyItemToCompanion(item, dirty: false));
    }
  }

  Future<String> _userId(Dio dio) async {
    Map<String, dynamic>? user = StorageService.getUser();
    if (user?['id'] == null) {
      // حسابِ قدیمیِ ایمیلی که پیش از این نسخه وارد شده: یک‌بار از سرور.
      final Response<dynamic> res = await dio.get('/api/me');
      user = Map<String, dynamic>.from(res.data['user'] as Map);
      await StorageService.saveUser(user);
    }
    return user!['id'].toString();
  }

  // ───────── تنظیمات (BK-2) ─────────

  static const List<String> _settingKeys = [
    'answer_display_short',
    'answer_display_long',
    'answer_popup_direction',
    'answer_popup_single',
    'translation_display',
    AudioStartNotifier.storageKey,
    'app_lang',
    'playback_mode',
    'outline_nav_collapsed',
    ReadingAppearanceNotifier.modeKey,
    ReadingAppearanceNotifier.scaleKey,
    WordCardNotifier.storageKey,
  ];

  /// جای مطالعه‌ی هر کتاب هم (scroll_page_/scroll_align_)؛ موقعیتِ فایل‌های صوتی نه،
  /// چون کلیدشان مسیرِ فایل روی همین دستگاه است.
  Map<String, dynamic> _collectSettings() {
    final SplayTreeMap<String, dynamic> out = SplayTreeMap();
    for (final String k in _settingKeys) {
      final dynamic v = _box.read(k);
      if (v != null) out[k] = v;
    }
    for (final dynamic k in _box.getKeys<Iterable<dynamic>>()) {
      final String key = k.toString();
      if (key.startsWith('scroll_page_') || key.startsWith('scroll_align_')) {
        out[key] = _box.read(key);
      }
    }
    return out;
  }

  Future<void> _syncSettings(
    Dio dio,
    String uid, {
    required bool restoreFromServer,
  }) async {
    final String pushedKey = 'settings_pushed_$uid';
    if (restoreFromServer) {
      final Response<dynamic> res = await dio.get('/api/backup/settings');
      final Object? data = res.data['data'];
      if (data is Map && data.isNotEmpty) {
        for (final MapEntry<dynamic, dynamic> e in data.entries) {
          await _box.write(e.key.toString(), e.value);
        }
        ref.invalidate(answerDisplayProvider);
        ref.invalidate(audioStartProvider);
        ref.invalidate(languageProvider);
        ref.invalidate(readingAppearanceProvider);
        ref.invalidate(wordCardProvider);
        await _box.write(pushedKey, jsonEncode(_collectSettings()));
        return;
      }
    }
    final String current = jsonEncode(_collectSettings());
    if (_box.read<String>(pushedKey) == current) return;
    await dio.put(
      '/api/backup/settings',
      data: {
        'data': jsonDecode(current),
        'updated': DateTime.now().millisecondsSinceEpoch,
      },
    );
    await _box.write(pushedKey, current);
  }

  // ───────── دستگاه (BK-3) ─────────

  String _deviceId() {
    final String? existing = _box.read<String>(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final Random r = Random.secure();
    final String id = List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _box.write(_deviceIdKey, id);
    return id;
  }

  Future<void> _touchDevice() async {
    if (kIsWeb || !_loggedIn) return;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String os = Platform.operatingSystemVersion;
      await ref.read(dioProvider).post(
        '/api/devices',
        data: {
          'device_id': _deviceId(),
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isWindows
              ? 'windows'
              : Platform.operatingSystem,
          'app_version': info.version,
          'build_number': int.tryParse(info.buildNumber),
          'os_version': os.length > 64 ? os.substring(0, 64) : os,
        },
      );
    } catch (e) {
      debugPrint('backup: device touch failed: $e');
    }
  }
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);
