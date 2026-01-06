// وضعیت کل جملات را به صورت Map<index, status> نگه می‌دارد
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'sentence_provider.g.dart';

enum SentenceStatus { normal, red, green }

@riverpod
class SentenceNotifier extends _$SentenceNotifier {
  @override
  Map<int, SentenceStatus> build() => {};

  void toggleStatus(int index) {
    final currentStatus = state[index] ?? SentenceStatus.normal;
    SentenceStatus nextStatus;

    if (currentStatus == SentenceStatus.normal) {
      nextStatus = SentenceStatus.red;
    } else if (currentStatus == SentenceStatus.red) {
      nextStatus = SentenceStatus.green;
    } else {
      nextStatus = SentenceStatus.normal;
    }

    // بروزرسانی مپ (ایجاد یک کپی جدید برای تحریک UI)
    state = {...state, index: nextStatus};
  }
}
