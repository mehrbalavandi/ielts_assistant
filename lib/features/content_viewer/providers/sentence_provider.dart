// وضعیت کل جملات را به صورت Map<index, status> نگه می‌دارد
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'sentence_provider.g.dart';

enum SentenceStatus { hide, show }

@riverpod
class SentenceNotifier extends _$SentenceNotifier {
  final _box = GetStorage();

  @override
  Map<int, SentenceStatus> build(String finalTopicId) {
    // اضافه کردن topicId در اینجا کار family را انجام می‌دهد
    return _loadFromStorage();
  }

  Map<int, SentenceStatus> _loadFromStorage() {
    final savedData = _box.read('sentences_$finalTopicId');
    if (savedData != null && savedData is Map) {
      return savedData.map(
        (key, value) => MapEntry(
          int.parse(key.toString()),
          SentenceStatus.values[value as int],
        ),
      );
    }
    return {};
  }

  void toggleStatus(int index) {
    final currentStatus = state[index] ?? SentenceStatus.hide;
    SentenceStatus nextStatus;

    if (currentStatus == SentenceStatus.hide) {
      nextStatus = SentenceStatus.show;
    } else {
      nextStatus = SentenceStatus.hide;
    }

    // بروزرسانی مپ (ایجاد یک کپی جدید برای تحریک UI)
    state = {...state, index: nextStatus};
  }
}
