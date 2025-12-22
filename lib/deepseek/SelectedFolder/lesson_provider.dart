// providers/lesson_provider.dart
import 'dart:io';
import 'book_provider.dart';

part 'lesson_provider.g.dart';

// Provider برای درس‌های یک کتاب خاص
@riverpod
Future<List<Lesson>> lessons(LessonsRef ref, {required String bookId}) async {
  // پیدا کردن کتاب از بین کتاب‌های موجود
  final books = await ref.watch(booksProvider.future);
  final book = books.firstWhere(
    (b) => b.id == bookId,
    orElse: () => Book(id: bookId, name: '', folderPath: ''),
  );

  final directory = Directory(book.folderPath);
  if (!await directory.exists()) return [];

  final entities = await directory.list().toList();
  final files = entities.whereType<File>();

  final supportedExtensions = ['.pdf', '.txt', '.epub', '.doc', '.docx'];

  final lessons = files
      .where((file) {
        final extension = path.extension(file.path).toLowerCase();
        return supportedExtensions.contains(extension);
      })
      .map((file) {
        return Lesson(
          id: file.path,
          bookId: bookId,
          name: path.basenameWithoutExtension(file.path),
          filePath: file.path,
        );
      })
      .toList();

  lessons.sort((a, b) => a.name.compareTo(b.name));
  return lessons;
}

// Provider برای درس انتخاب شده
@riverpod
class SelectedLesson extends _$SelectedLesson {
  @override
  Lesson? build() {
    // مقداردهی اولیه از حافظه
    return StorageService.getLastSelectedLesson();
  }

  Future<void> selectLesson(Lesson? lesson) async {
    if (lesson == null) {
      state = null;
    } else {
      state = lesson;
      await StorageService.saveLastSelectedLesson(lesson);
    }
  }

  Future<void> onBookChanged(Book newBook) async {
    final lastLesson = StorageService.getLastSelectedLesson();

    // اگر آخرین درس متعلق به کتاب جدید نبود، اولین درس را انتخاب کن
    if (lastLesson == null || lastLesson.bookId != newBook.id) {
      final bookLessons = await ref.watch(
        lessonsProvider(bookId: newBook.id).future,
      );
      if (bookLessons.isNotEmpty) {
        await selectLesson(bookLessons.first);
      }
    }
  }
}
