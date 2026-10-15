import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/core/db/app_database.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
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

  @override
  Map<String, StudyItem> build() {
    Future.microtask(reload);
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
  }

  void remove(String id) {
    final StudyItem? cur = state[id];
    if (cur == null) return;
    state = LinkedHashMap.of(state)..remove(id);
    _write(cur.copyWith(), deleted: true);
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
