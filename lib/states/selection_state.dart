// در فایل selection_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';

// Provider برای نگهداری SubTopic آخرین آیتم انتخاب شده
// اگر آیتمی انتخاب نشده باشد (یا والد جمع شده باشد)، مقدار آن null است.
final lastSelectedTopicProvider = StateProvider<SubTopic?>((ref) => null);
final lastOpenedParentIdProvider = StateProvider<String?>((ref) => null);

final selectedSubjectProvider = StateProvider<Book?>((ref) => null);
final lessonsProvider = FutureProvider.family<List<Unit>, Book?>((
  ref,
  subject,
) async {
  if (subject == null) {
    return [];
  }
  return subject.units;
});

final selectedLessonProvider = StateProvider<Unit?>((ref) => null);
