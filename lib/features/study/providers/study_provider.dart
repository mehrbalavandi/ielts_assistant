import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/db/app_database.dart';
import 'package:ielts_assistant/core/network/dio_provider.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/study/data/study_item_format.dart';
import 'package:ielts_assistant/features/study/data/study_rows.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';

// 🌟 ST-1: «مرورِ من» روی پایگاهِ داده‌ی محلی (drift). وضعیتِ این Notifier یک Map از
// شناسه به مورد است (در حافظه) تا هر پاراگرافِ صفحه با select فقط به موردِ خودش گوش
// دهد؛ هر تغییر هم‌زمان در پایگاهِ داده نوشته و برای پشتیبانِ سرور علامت می‌خورد
// (dirty، BK-1). حذف = سنگِ قبر، تا به سرور و دستگاه‌های دیگر هم برسد.
//
// نسخه‌ی قبلی موردها را در GetStorage (کلیدِ study_items_v1) نگه می‌داشت؛ با اولین اجرا
// همه به پایگاهِ داده منتقل و آن کلید پاک می‌شود.

class StudyNotifier extends Notifier<Map<String, StudyItem>> {
  static const String legacyStorageKey = 'study_items_v1';

  AppDatabase get _db => ref.read(appDatabaseProvider);

  // 🌟 ST-7: «مرورِ آماده»ِ سایت.
  static const String sharedEnabledKey = 'shared_study_enabled';
  static const String sharedCursorKey = 'shared_study_cursor';
  static const String sharedDismissedKey = 'shared_study_dismissed';

  /// 🌟 ST-8: عنوانِ موردهای آماده‌ی حذف‌شده (id ← متن)، برای فهرستِ «برگرداندن».
  static const String sharedDismissedTitlesKey = 'shared_study_dismissed_titles';

  final GetStorage _box = GetStorage();
  bool _sharedRunning = false;

  /// 🌟 ST-8: موردهایی که کاربر همین حالا برگردانده؛ با زمانِ «الان» و dirty نوشته می‌شوند تا
  /// بر سنگِ قبرِ قدیمی‌شان در پشتیبانِ سرور (و دستگاه‌های دیگر) غلبه کنند.
  final Set<String> _revive = {};

  @override
  Map<String, StudyItem> build() {
    Future.microtask(() async {
      await reload();
      await syncShared();
    });
    return LinkedHashMap<String, StudyItem>();
  }

  /// خواندنِ دوباره از پایگاهِ داده (بعد از همگام‌سازی با سرور هم صدا زده می‌شود).
  Future<void> reload() async {
    try {
      await _importLegacy();
      final List<StudyItemRow> rows = await _db.liveStudyItems();
      rows.sort((a, b) => a.createdMs.compareTo(b.createdMs));
      if (!ref.mounted) return;
      state = LinkedHashMap<String, StudyItem>.fromEntries(
        rows.map((r) => MapEntry(r.id, studyItemFromRow(r))),
      );
    } catch (e) {
      debugPrint('study: load failed: $e');
    }
  }

  Future<void> _importLegacy() async {
    final GetStorage box = GetStorage();
    final Object? raw = box.read(legacyStorageKey);
    if (raw is! List || raw.isEmpty) return;
    await _db.transaction(() async {
      for (final Object? e in raw) {
        final StudyItem? item = StudyItem.fromJson(e);
        if (item != null) await _db.upsertStudyItem(studyItemToCompanion(item));
      }
    });
    await box.remove(legacyStorageKey);
    debugPrint('study: imported ${raw.length} items from GetStorage');
  }

  Future<void> _write(StudyItem item, {bool deleted = false}) async {
    try {
      await _db.upsertStudyItem(studyItemToCompanion(item, deleted: deleted));
    } catch (e) {
      debugPrint('study: write failed: $e');
    }
    ref.read(backupProvider.notifier).scheduleSync();
  }

  bool contains(String id) => state.containsKey(id);

  /// افزودن (یا جایگزینی با همان شناسه). زمانِ تغییر همین لحظه است — حتی برای
  /// «برگرداندنِ» موردِ حذف‌شده، وگرنه سنگِ قبرِ تازه‌تر در همگام‌سازی برنده می‌شد.
  void put(StudyItem item) {
    final StudyItem stamped = item.copyWith();
    state = LinkedHashMap.of(state)..[stamped.id] = stamped;
    _write(stamped);
    if (stamped.source == StudySource.admin) _setDismissed(stamped.id, false);
  }

  void remove(String id) {
    final StudyItem? cur = state[id];
    if (cur == null) return;
    state = LinkedHashMap.of(state)..remove(id);
    _write(cur.copyWith(), deleted: true);
    // موردِ «آماده»ای که کاربر حذف کرده، با همگام‌سازیِ بعدی دوباره نیاید.
    if (cur.source == StudySource.admin) _setDismissed(id, true, title: cur.text);
  }

  // ───────── 🌟 ST-7: موردهای خودِ کاربر ─────────

  /// افزودنِ موردهای واردشده (از هوش مصنوعی یا فایل). موردی که همان شناسه را دارد (همان
  /// واژه یا همان نکته) دست نمی‌خورد. نتیجه: (افزوده، تکراری).
  (int, int) importItems(Iterable<StudyItem> items) {
    final LinkedHashMap<String, StudyItem> next = LinkedHashMap.of(state);
    final List<StudyItem> added = [];
    int skipped = 0;
    for (final StudyItem i in items) {
      if (next.containsKey(i.id)) {
        skipped++;
        continue;
      }
      final StudyItem stamped = i.copyWith();
      next[stamped.id] = stamped;
      added.add(stamped);
    }
    if (added.isEmpty) return (0, skipped);
    state = next;
    Future(() async {
      try {
        await _db.transaction(() async {
          for (final StudyItem i in added) {
            await _db.upsertStudyItem(studyItemToCompanion(i));
          }
        });
      } catch (e) {
        debugPrint('study: import write failed: $e');
      }
      ref.read(backupProvider.notifier).scheduleSync();
    });
    return (added.length, skipped);
  }

  /// ذخیره‌ی موردی که کاربر در فرم ساخته/ویرایش کرده. اگر متن (و در نتیجه شناسه) عوض شده،
  /// موردِ قبلی حذف می‌شود. false اگر شناسه‌ی تازه مالِ موردِ دیگری است.
  bool saveUserItem(StudyItem item, {String? previousId}) {
    if (item.id != previousId && state.containsKey(item.id)) return false;
    if (previousId != null && previousId != item.id) {
      final StudyItem? old = state[previousId];
      if (old != null) {
        state = LinkedHashMap.of(state)..remove(previousId);
        _write(old.copyWith(), deleted: true);
      }
    }
    put(item);
    return true;
  }

  // ───────── 🌟 ST-7: «مرورِ آماده»ِ سایت ─────────

  bool get sharedEnabled => _box.read<bool>(sharedEnabledKey) ?? true;

  Future<void> setSharedEnabled(bool on) async {
    await _box.write(sharedEnabledKey, on);
    if (on) {
      await _box.remove(sharedCursorKey); // از اول، تا موردهای قبلی هم برسند
      await syncShared();
      return;
    }
    // خاموش: موردهای «آماده»ای که کاربر دست نزده پاک می‌شوند؛ آن‌هایی که یادداشت یا
    // وضعیت گرفته‌اند می‌مانند.
    final List<StudyItem> untouched = [
      for (final StudyItem i in state.values)
        if (i.source == StudySource.admin &&
            i.note.isEmpty &&
            i.status == WordStatus.fresh)
          i,
    ];
    for (final StudyItem i in untouched) {
      await _db.deleteStudyItem(i.id);
    }
    await reload();
  }

  Set<String> get _dismissed => {
    for (final Object? e in (_box.read<List>(sharedDismissedKey) ?? const []))
      if (e != null) e.toString(),
  };

  void _setDismissed(String id, bool on, {String? title}) {
    final Set<String> d = _dismissed;
    if (on ? d.add(id) : d.remove(id)) {
      _box.write(sharedDismissedKey, d.toList());
    }
    final Map<String, dynamic> titles = _dismissedTitles;
    if (on && title != null) {
      titles[id] = title;
    } else if (!on) {
      titles.remove(id);
    }
    _box.write(sharedDismissedTitlesKey, titles);
  }

  Map<String, dynamic> get _dismissedTitles {
    final Object? raw = _box.read(sharedDismissedTitlesKey);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// 🌟 ST-8: موردهای آماده‌ای که کاربر حذف کرده: (شناسه، عنوان، نکته است؟). عنوانِ موردهایی
  /// که پیش از این نسخه حذف شده‌اند از خودِ شناسه ساخته می‌شود (واژه) یا «نکته».
  List<(String, String, bool)> get dismissedShared {
    final Map<String, dynamic> titles = _dismissedTitles;
    return [
      for (final String id in _dismissed)
        (
          id,
          (titles[id] as String?) ??
              (id.startsWith('w|') ? id.substring(2) : 'نکته'),
          id.startsWith('t|'),
        ),
    ]..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
  }

  /// 🌟 ST-8: برگرداندنِ موردهای آماده‌ی حذف‌شده — از فهرستِ «حذف‌شده‌ها» بیرون می‌آیند و خوراکِ
  /// سایت از اول گرفته می‌شود تا دوباره در «مرورِ من» بنشینند. نتیجه: تعدادِ برگشته، یا null
  /// اگر به سایت وصل نشد (فهرست همان‌طور می‌ماند).
  Future<int?> restoreDismissed(Iterable<String> ids) async {
    final List<String> list = ids.toList();
    if (list.isEmpty) return 0;
    if (!sharedEnabled) await _box.write(sharedEnabledKey, true);
    final Set<String> before = _dismissed;
    final Map<String, dynamic> titlesBefore = _dismissedTitles;
    for (final String id in list) {
      _setDismissed(id, false);
    }
    final int? cursor = _box.read<int>(sharedCursorKey);
    await _box.remove(sharedCursorKey);
    _revive.addAll(list);
    final int? added = await syncShared();
    _revive.removeAll(list);
    if (added == null) {
      // نشد: همه‌چیز مثلِ قبل، تا دفعه‌ی بعد دوباره امتحان شود.
      await _box.write(sharedDismissedKey, before.toList());
      await _box.write(sharedDismissedTitlesKey, titlesBefore);
      if (cursor != null) await _box.write(sharedCursorKey, cursor);
      return null;
    }
    ref.read(backupProvider.notifier).scheduleSync();
    return list.where(state.containsKey).length;
  }

  /// با شروعِ اپ، بعد از هر پشتیبان‌گیری و با «به‌روزرسانی» در صفحه‌ی مرور. فقط تغییرهای
  /// بعد از آخرین بار گرفته می‌شود (cursor). مهمان هم می‌گیرد. خطای شبکه بی‌صداست.
  /// نتیجه: تعدادِ موردهای تازه، یا null اگر انجام نشد.
  Future<int?> syncShared() async {
    if (!sharedEnabled || _sharedRunning) return null;
    _sharedRunning = true;
    int added = 0;
    try {
      final Dio dio = ref.read(dioProvider);
      bool more = true;
      int guard = 0;
      while (more && guard++ < 20) {
        final int? since = _box.read<int>(sharedCursorKey);
        final Response<dynamic> res = await dio.get(
          '/api/study/shared',
          queryParameters: {'since': ?since},
        );
        final Map<dynamic, dynamic> body = res.data as Map;
        added += await _applyShared(body['items'] as List? ?? const []);
        final int? cursor = (body['cursor'] as num?)?.toInt();
        if (cursor != null) await _box.write(sharedCursorKey, cursor);
        more = body['more'] == true && cursor != null;
      }
      await reload();
      return added;
    } catch (e) {
      debugPrint('study: shared sync failed: $e');
      return null;
    } finally {
      _sharedRunning = false;
    }
  }

  /// قاعده‌ها:
  /// - برداشته‌شده در سایت ← موردِ «آماده»ِ متناظر حذف می‌شود.
  /// - موردی که کاربر حذف کرده (dismissed) یا سنگِ قبرش هنوز به سرور نرسیده ← نمی‌آید.
  /// - همان واژه/نکته از کتاب یا از خودِ کاربر هست ← دست نمی‌خورد (تکراری نمی‌شود).
  /// - موردِ «آماده»ی موجود ← محتوایش تازه می‌شود؛ اهمیت، وضعیت و یادداشتِ کاربر می‌ماند.
  /// - تازه ← با زمانِ تغییرِ سایت (نه «الان») و dirty=false؛ پس به پشتیبانِ کاربر نمی‌رود
  ///   مگر کاربر عوضش کند، و سنگِ قبرِ تازه‌ترِ پشتیبان بر آن غلبه می‌کند.
  Future<int> _applyShared(List<dynamic> entries) async {
    final Set<String> dismissed = _dismissed;
    int added = 0;
    await _db.transaction(() async {
      for (final Object? raw in entries) {
        if (raw is! Map) continue;
        final int? sid = (raw['sid'] as num?)?.toInt();
        if (sid == null) continue;
        if (raw['deleted'] == true) {
          for (final StudyItem i in state.values) {
            if (i.source == StudySource.admin && i.sharedId == sid) {
              await _db.upsertStudyItem(
                studyItemToCompanion(i.copyWith(), deleted: true),
              );
            }
          }
          continue;
        }
        final (StudyItem? item, _) = StudyItemFormat.fromMap(
          raw['item'],
          source: StudySource.admin,
          sharedId: sid,
          changedMs: (raw['changed'] as num?)?.toInt(),
        );
        if (item == null || dismissed.contains(item.id)) continue;

        final StudyItemRow? row = await _db.studyItemById(item.id);
        if (row == null) {
          final bool revive = _revive.contains(item.id);
          await _db.upsertStudyItem(
            revive
                ? studyItemToCompanion(item.withContent(updatedAt: DateTime.now()))
                : studyItemToCompanion(item, dirty: false),
          );
          added++;
          continue;
        }
        if (row.deleted) {
          // 🌟 ST-8: سنگِ قبرِ موردی که دیگر در «حذف‌شده‌ها» نیست (کاربر برش گردانده، یا ادمین
          // دوباره منتشرش کرده) ← زنده می‌شود. زمانِ «الان» و dirty تا بر سنگِ قبرِ پشتیبانِ
          // سرور هم غلبه کند.
          await _db.upsertStudyItem(
            studyItemToCompanion(item.withContent(updatedAt: DateTime.now())),
          );
          added++;
          continue;
        }
        final StudyItem local = studyItemFromRow(row);
        if (local.source != StudySource.admin) continue;
        final StudyItem merged = local.withContent(
          text: item.text,
          translationFa: item.translationFa,
          translationAr: item.translationAr,
          pronounceFa: item.pronounceFa,
          pronounceAr: item.pronounceAr,
          explanationFa: item.explanationFa,
          explanationAr: item.explanationAr,
          cefrLevel: item.cefrLevel,
          pos: item.pos,
          ipa: item.ipa,
          examples: item.examples,
          tags: item.tags,
          origin: item.origin,
        );
        await _db.upsertStudyItem(studyItemToCompanion(merged, dirty: row.dirty));
      }
    });
    return added;
  }

  void _update(String id, StudyItem Function(StudyItem) f) {
    final StudyItem? cur = state[id];
    if (cur == null) return;
    final StudyItem next = f(cur);
    state = LinkedHashMap.of(state)..[id] = next;
    _write(next);
  }

  void setImportance(String id, StudyImportance v) =>
      _update(id, (i) => i.copyWith(importance: v));

  void setStatus(String id, WordStatus v) =>
      _update(id, (i) => i.copyWith(status: v));

  void setNote(String id, String note) =>
      _update(id, (i) => i.copyWith(note: note.trim()));
}

final studyProvider = NotifierProvider<StudyNotifier, Map<String, StudyItem>>(
  StudyNotifier.new,
);
