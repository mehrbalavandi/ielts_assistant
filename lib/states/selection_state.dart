// در فایل selection_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';

// Provider برای نگهداری mainTopic آخرین آیتم انتخاب شده
// اگر آیتمی انتخاب نشده باشد (یا والد جمع شده باشد)، مقدار آن null است.
final lastSelectedTopicProvider = StateProvider<FinalTopic?>((ref) => null);
final lastOpenedParentIdProvider = StateProvider<String?>((ref) => null);

final selectedbookProvider = StateProvider<Book?>((ref) => null);
final unitsProvider = FutureProvider.family<List<Unit>, Book?>((
  ref,
  book,
) async {
  if (book == null) {
    return [];
  }
  return book.units;
});

final selectedunitProvider = StateProvider<Unit?>((ref) => null);
