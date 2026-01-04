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

  void selectTopic(Book b, Unit u, Topic t) => state = NavigationState(
    selectedBook: b,
    selectedUnit: u,
    selectedTopic: t,
  );
  void selectPage(PageContent p) => state = state.copyWith(selectedPage: p);
  void goBack() => state = state.copyWith(selectedPage: null);
}
