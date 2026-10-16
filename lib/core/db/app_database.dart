import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

// 🌟 پایگاهِ داده‌ی محلیِ اپ (drift، روی sqlite). فعلاً فقط «مرورِ من» (ST-1)؛ جدول‌های
// بعدی (پیشرفتِ مطالعه، فلش‌کارت، …) همین‌جا اضافه می‌شوند و schemaVersion بالا می‌رود.
//
// بعد از هر تغییر در جدول‌ها:
//   dart run build_runner build -d
// (فایلِ app_database.g.dart را می‌سازد.)

/// یک موردِ «مرورِ من» (واژه یا متن/تمرین). حذف = سنگِ قبر (deleted) تا همگام‌سازی
/// به سرور هم برسد؛ dirty = هنوز به سرور فرستاده نشده (BK-1).
@DataClassName('StudyItemRow')
class StudyItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // word | passage | tip
  TextColumn get bookId => text().withDefault(const Constant(''))();
  TextColumn get bookTitle => text().withDefault(const Constant(''))();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get paraIndex => integer().nullable()();
  // «text» نامِ متدِ سازنده‌ی ستون در Table است؛ پس getter نامِ دیگری دارد.
  TextColumn get itemText => text().named('text')();
  TextColumn get translationFa => text().withDefault(const Constant(''))();
  TextColumn get translationAr => text().withDefault(const Constant(''))();
  TextColumn get pronounceFa => text().withDefault(const Constant(''))();
  TextColumn get pronounceAr => text().withDefault(const Constant(''))();
  TextColumn get explanationFa => text().withDefault(const Constant(''))();
  TextColumn get explanationAr => text().withDefault(const Constant(''))();
  TextColumn get cefrLevel => text().withDefault(const Constant(''))();
  IntColumn get importance => integer().withDefault(const Constant(2))();
  TextColumn get status => text().withDefault(const Constant('fresh'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  // 🌟 ST-7 (schema 2): فیلدهای اضافه به‌صورتِ JSON — نوعِ کلمه، IPA، مثال‌ها، برچسب‌ها،
  // منبع (کتاب/خودم/آماده) و شناسه‌ی «مرورِ آماده». یک ستونِ JSON به‌جای چند ستون، تا
  // فیلدِ تازه بی‌مهاجرتِ پایگاهِ داده اضافه شود (StudyItem.extraJson).
  TextColumn get extra => text().withDefault(const Constant(''))();
  IntColumn get createdMs => integer()();
  IntColumn get updatedMs => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [StudyItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ielts_assistant'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 1 ← 2: ستونِ extra (ST-7).
      if (from < 2) await m.addColumn(studyItems, studyItems.extra);
    },
  );

  // ───────── «مرورِ من» ─────────

  /// موردهای زنده (بدونِ سنگِ قبرها).
  Future<List<StudyItemRow>> liveStudyItems() =>
      (select(studyItems)..where((t) => t.deleted.equals(false))).get();

  /// تغییرهایی که هنوز به سرور نرسیده‌اند (شاملِ حذف‌ها).
  Future<List<StudyItemRow>> dirtyStudyItems() =>
      (select(studyItems)..where((t) => t.dirty.equals(true))).get();

  Future<StudyItemRow?> studyItemById(String id) =>
      (select(studyItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> studyItemCount() async =>
      (await select(studyItems).get()).length;

  Future<void> upsertStudyItem(StudyItemsCompanion row) =>
      into(studyItems).insertOnConflictUpdate(row);

  Future<int> deleteStudyItem(String id) =>
      (delete(studyItems)..where((t) => t.id.equals(id))).go();

  /// بعد از ارسالِ موفق: فقط اگر از آن لحظه دوباره عوض نشده، «تمیز» شود.
  Future<int> markStudyItemClean(String id, int updatedMs) =>
      (update(studyItems)
            ..where((t) => t.id.equals(id) & t.updatedMs.equals(updatedMs)))
          .write(const StudyItemsCompanion(dirty: Value(false)));

  Future<int> clearStudyItems() => delete(studyItems).go();
}

/// یک نمونه برای کلِ اپ.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
