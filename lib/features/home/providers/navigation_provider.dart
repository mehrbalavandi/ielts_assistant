import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';
part 'navigation_provider.freezed.dart';

@freezed
sealed class NavigationState with _$NavigationState {
  const factory NavigationState({
    Book? selectedBook,
    Unit? selectedUnit,
    Topic? selectedTopic,
    PageContent? selectedPage,
  }) = _NavigationState;
}

@riverpod
class NavigationNotifier extends _$NavigationNotifier {
  @override
  NavigationState build() => const NavigationState();

  // انتخاب کتاب
  void selectBook(Book book) {
    state = state.copyWith(
      selectedBook: book,
      selectedUnit: null, // با تغییر کتاب، واحد قبلی پاک شود
      selectedTopic: null,
      selectedPage: null,
    );
  }

  // انتخاب واحد
  void selectUnit(Unit unit) {
    state = state.copyWith(
      selectedUnit: unit,
      selectedTopic: null, // با تغییر واحد، موضوع قبلی پاک شود
      selectedPage: null,
    );
  }

  // انتخاب موضوع
  void selectTopic(Topic topic) {
    state = state.copyWith(
      selectedTopic: topic,
      selectedPage: null, // با تغییر موضوع، صفحه قبلی پاک شود
    );
  }

  // انتخاب صفحه
  void selectPage(PageContent page) {
    state = state.copyWith(selectedPage: page);
  }

  // بازگشت به عقب (مثلاً از صفحه به لیست صفحات موضوع)
  void goBack() {
    if (state.selectedPage != null) {
      state = state.copyWith(selectedPage: null);
    } else if (state.selectedTopic != null) {
      state = state.copyWith(selectedTopic: null);
    }
  }

  // ریست کردن کل مسیر (بازگشت به حالت اولیه)
  void reset() {
    state = const NavigationState();
  }
}
