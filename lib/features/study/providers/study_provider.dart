import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';

// 🌟 ST-1: همه‌ی موردهای «مرورِ من» روی خودِ دستگاه (GetStorage، کلیدِ
// `study_items_v1`، فهرستِ JSON). هر تغییر بلافاصله ذخیره می‌شود. وضعیت یک Map از
// شناسه به مورد است تا هر پاراگرافِ صفحه با select فقط به موردِ خودش گوش دهد.
// (همگام‌سازی با سرور مرحله‌ی بعد است؛ updatedAt برای همان نگه داشته می‌شود.)

class StudyNotifier extends Notifier<Map<String, StudyItem>> {
  static const String storageKey = 'study_items_v1';

  @override
  Map<String, StudyItem> build() {
    final LinkedHashMap<String, StudyItem> out = LinkedHashMap();
    try {
      final Object? raw = GetStorage().read(storageKey);
      if (raw is List) {
        for (final Object? e in raw) {
          final StudyItem? item = StudyItem.fromJson(e);
          if (item != null) out[item.id] = item;
        }
      }
    } catch (e) {
      debugPrint('study: read failed: $e');
    }
    return out;
  }

  void _commit(Map<String, StudyItem> next) {
    state = next;
    try {
      GetStorage().write(storageKey, [
        for (final StudyItem i in next.values) i.toJson(),
      ]);
    } catch (e) {
      debugPrint('study: write failed: $e');
    }
  }

  bool contains(String id) => state.containsKey(id);

  /// افزودن (یا جایگزینی با همان شناسه).
  void put(StudyItem item) =>
      _commit(LinkedHashMap.of(state)..[item.id] = item);

  void remove(String id) {
    if (!state.containsKey(id)) return;
    _commit(LinkedHashMap.of(state)..remove(id));
  }

  void _update(String id, StudyItem Function(StudyItem) f) {
    final StudyItem? cur = state[id];
    if (cur == null) return;
    _commit(LinkedHashMap.of(state)..[id] = f(cur));
  }

  void setImportance(String id, StudyImportance v) =>
      _update(id, (i) => i.copyWith(importance: v));

  void setStatus(String id, WordStatus v) =>
      _update(id, (i) => i.copyWith(status: v));

  void setNote(String id, String note) =>
      _update(id, (i) => i.copyWith(note: note.trim()));
}

final studyProvider =
    NotifierProvider<StudyNotifier, Map<String, StudyItem>>(StudyNotifier.new);
