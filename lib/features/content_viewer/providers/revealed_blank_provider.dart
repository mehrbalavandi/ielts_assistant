// وضعیت کل جملات را به صورت Map<index, status> نگه می‌دارد
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'revealed_blank_provider.g.dart';

enum RevealedBlankStatus { hide, show }

@riverpod
class RevealedBlankNotifier extends _$RevealedBlankNotifier {
  final _box = GetStorage();

  @override
  Map<int, RevealedBlankStatus> build(String finalTopicId) {
    // اضافه کردن topicId در اینجا کار family را انجام می‌دهد
    return _loadFromStorage();
  }

  Map<int, RevealedBlankStatus> _loadFromStorage() {
    final savedData = _box.read('sentences_$finalTopicId');
    if (savedData != null && savedData is Map) {
      return savedData.map(
        (key, value) => MapEntry(
          int.parse(key.toString()),
          RevealedBlankStatus.values[value as int],
        ),
      );
    }
    return {};
  }

  void toggleStatus(int index) {
    final currentStatus = state[index] ?? RevealedBlankStatus.hide;
    RevealedBlankStatus nextStatus;

    if (currentStatus == RevealedBlankStatus.hide) {
      nextStatus = RevealedBlankStatus.show;
    } else {
      nextStatus = RevealedBlankStatus.hide;
    }

    // بروزرسانی مپ (ایجاد یک کپی جدید برای تحریک UI)
    state = {...state, index: nextStatus};
  }
}
