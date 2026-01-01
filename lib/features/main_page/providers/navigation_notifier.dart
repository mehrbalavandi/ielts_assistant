// @freezed
// class NavigationState with _$NavigationState {
//   const factory NavigationState({
//     Book? selectedBook,
//     Unit? selectedUnit,
//     Topic? selectedTopic,
//     PageContent? selectedPage,
//     FinalTopic? selectedFinalTopic,
//   }) = _NavigationState;
// }

// @riverpod
// class NavigationNotifier extends _$NavigationNotifier {
//   @override
//   NavigationState build() => const NavigationState();

//   void selectBook(Book book) => state = NavigationState(selectedBook: book);
  
//   void selectUnit(Unit unit) => state = state.copyWith(
//     selectedUnit: unit, 
//     selectedTopic: null, 
//     selectedPage: null, 
//     selectedFinalTopic: null
//   );

//   void selectTopic(Topic topic) => state = state.copyWith(
//     selectedTopic: topic, 
//     selectedPage: null, 
//     selectedFinalTopic: null
//   );

//   void selectPage(PageContent page) => state = state.copyWith(
//     selectedPage: page, 
//     selectedFinalTopic: null
//   );

//   void selectFinalTopic(FinalTopic finalTopic) => state = state.copyWith(
//     selectedFinalTopic: finalTopic
//   );
// }