import 'package:drift/drift.dart';
import 'package:ielts_assistant/core/db/app_database.dart';
import 'package:ielts_assistant/features/study/domain/study_item.dart';

// 🌟 ST-1: تبدیلِ ردیفِ پایگاهِ داده (drift) ↔ مدلِ «مرورِ من».

StudyItem studyItemFromRow(StudyItemRow r) => StudyItem(
  id: r.id,
  kind: r.kind == 'word' ? StudyKind.word : StudyKind.passage,
  bookId: r.bookId,
  bookTitle: r.bookTitle,
  pageNumber: r.pageNumber,
  paraIndex: r.paraIndex,
  text: r.itemText,
  translationFa: r.translationFa,
  translationAr: r.translationAr,
  pronounceFa: r.pronounceFa,
  pronounceAr: r.pronounceAr,
  explanationFa: r.explanationFa,
  explanationAr: r.explanationAr,
  cefrLevel: r.cefrLevel,
  importance: StudyImportance.fromLevel(r.importance),
  status: WordStatus.parse(r.status),
  note: r.note,
  createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdMs),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedMs),
);

StudyItemsCompanion studyItemToCompanion(
  StudyItem i, {
  bool dirty = true,
  bool deleted = false,
}) => StudyItemsCompanion(
  id: Value(i.id),
  kind: Value(i.kind.name),
  bookId: Value(i.bookId),
  bookTitle: Value(i.bookTitle),
  pageNumber: Value(i.pageNumber),
  paraIndex: Value(i.paraIndex),
  itemText: Value(i.text),
  translationFa: Value(i.translationFa),
  translationAr: Value(i.translationAr),
  pronounceFa: Value(i.pronounceFa),
  pronounceAr: Value(i.pronounceAr),
  explanationFa: Value(i.explanationFa),
  explanationAr: Value(i.explanationAr),
  cefrLevel: Value(i.cefrLevel),
  importance: Value(i.importance.level),
  status: Value(i.status.name),
  note: Value(i.note),
  createdMs: Value(i.createdAt.millisecondsSinceEpoch),
  updatedMs: Value(i.updatedAt.millisecondsSinceEpoch),
  deleted: Value(deleted),
  dirty: Value(dirty),
);

/// همان JSONِ مدل (toJson) + پرچمِ حذف، برای /api/backup/study/sync (BK-1).
Map<String, dynamic> studyRowToSyncJson(StudyItemRow r) => {
  ...studyItemFromRow(r).toJson(),
  'deleted': r.deleted,
};
