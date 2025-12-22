// models/book.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
class Book with _$Book {
  const Book._();

  const factory Book({
    required String id,
    required String name,
    required String folderPath,
    @Default(0) int lastOpened,
    @Default(false) bool isFavorite,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

// models/lesson.dart
@freezed
class Lesson with _$Lesson {
  const Lesson._();

  const factory Lesson({
    required String id,
    required String bookId,
    required String name,
    required String filePath,
    @Default(0) int currentPage,
    @Default(0) int totalPages,
    @Default(Duration.zero) Duration lastPosition,
  }) = _Lesson;

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
}
