// providers/selection_provider.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'book_provider.dart';
import 'lesson_provider.dart';

part 'selection_provider.g.dart';

// State ترکیبی برای UI
@freezed
class SelectionState with _$SelectionState {
  const factory SelectionState({
    Book? selectedBook,
    Lesson? selectedLesson,
    required List<Book> availableBooks,
    required List<Lesson> availableLessons,
    @Default(false) bool isLoadingBooks,
    @Default(false) bool isLoadingLessons,
    String? error,
  }) = _SelectionState;
}

// Provider اصلی برای UI
@riverpod
class SelectionManager extends _$SelectionManager {
  @override
  SelectionState build() {
    // Subscribe به changes
    ref.listen(selectedBookProvider, (previous, next) {
      _onBookChanged(next);
    });

    ref.listen(selectedLessonProvider, (previous, next) {
      _onLessonChanged(next);
    });

    // State اولیه
    return SelectionState(
      selectedBook: ref.read(selectedBookProvider),
      selectedLesson: ref.read(selectedLessonProvider),
      availableBooks: [],
      availableLessons: [],
    );
  }

  void _onBookChanged(Book? book) {
    state = state.copyWith(
      selectedBook: book,
      availableLessons: [],
      selectedLesson: null,
    );

    if (book != null) {
      // بارگذاری درس‌های کتاب جدید
      _loadLessonsForBook(book);
    }
  }

  void _onLessonChanged(Lesson? lesson) {
    state = state.copyWith(selectedLesson: lesson);
  }

  Future<void> _loadLessonsForBook(Book book) async {
    state = state.copyWith(isLoadingLessons: true);

    try {
      final lessons = await ref.read(lessonsProvider(bookId: book.id).future);
      state = state.copyWith(
        availableLessons: lessons,
        isLoadingLessons: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'خطا در بارگذاری درس‌ها: $e',
        isLoadingLessons: false,
      );
    }
  }

  Future<void> refreshBooks() async {
    state = state.copyWith(isLoadingBooks: true);

    try {
      final books = await ref.refresh(booksProvider.future);
      state = state.copyWith(availableBooks: books, isLoadingBooks: false);
    } catch (e) {
      state = state.copyWith(
        error: 'خطا در بروزرسانی کتاب‌ها: $e',
        isLoadingBooks: false,
      );
    }
  }
}
