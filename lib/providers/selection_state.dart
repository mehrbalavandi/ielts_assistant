// در فایل selection_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/shared/models/data_models.dart';

// Provider برای نگهداری mainTopic آخرین آیتم انتخاب شده
// اگر آیتمی انتخاب نشده باشد (یا والد جمع شده باشد)، مقدار آن null است.
final lastSelectedTopicProvider = StateProvider<FinalTopic?>((ref) => null);
final lastOpenedParentIdProvider = StateProvider<String?>((ref) => null);

// final selectedBookProvider = StateProvider<Book?>((ref) => null);

final unitsProvider = FutureProvider.family<List<Unit>, Book?>((
  ref,
  book,
) async {
  if (book == null) {
    return [];
  }
  return book.units;
});

// final selectedUnitProvider = StateProvider<Unit?>((ref) => null);

final mainTopicsProvider = FutureProvider.family<List<Topic>, Unit?>((
  ref,
  unit,
) async {
  if (unit == null) {
    return [];
  }

  return unit.topics;
});

final selectedMainTopicProvider = StateProvider<Topic?>((ref) => null);

final subTopicsProvider = FutureProvider.family<List<PageContent>, Topic?>((
  ref,
  mainTopic,
) async {
  if (mainTopic == null) {
    return [];
  }
  return mainTopic.pageContents;
});

final selectedSubTopicProvider = StateProvider<PageContent?>((ref) => null);
