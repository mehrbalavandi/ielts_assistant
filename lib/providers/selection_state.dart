import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

final lastSelectedTopicProvider = StateProvider<FinalTopic?>((ref) => null);
final lastOpenedParentIdProvider = StateProvider<String?>((ref) => null);

final unitsProvider = FutureProvider.family<List<Unit>, Book?>((
  ref,
  book,
) async {
  if (book == null) {
    return [];
  }
  return book.units;
});

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
