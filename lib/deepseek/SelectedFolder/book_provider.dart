// providers/book_provider.dart
import 'dart:io';
import 'package:for_riverpod_generating/classes/storage_service/storage_service.dart';
import 'package:for_riverpod_generating/models/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_provider.g.dart';

// Provider برای لیست کتاب‌ها (async)
@riverpod
Future<List<Book>> books(Ref ref) async {
  final selectedFolder = ref.watch(selectedFolderProvider);

  if (selectedFolder == null) return [];

  final directory = Directory(selectedFolder);
  if (!await directory.exists()) return [];

  final entities = await directory.list().toList();
  final folders = entities.whereType<Directory>();

  return folders.map((folder) {
    return Book(
      id: folder.path,
      name: path.basename(folder.path),
      folderPath: folder.path,
    );
  }).toList();
}

// Provider برای کتاب انتخاب شده
@riverpod
class SelectedBook extends _$SelectedBook {
  @override
  Book? build() {
    // مقداردهی اولیه از حافظه
    return StorageService.getLastSelectedBook();
  }

  Future<void> selectBook(Book? book) async {
    if (book == null) {
      state = null;
    } else {
      state = book;
      await StorageService.saveLastSelectedBook(book);

      // وقتی کتاب تغییر کرد، درس مرتبط را پیدا کن
      ref.invalidate(lessonsProvider);
      await ref.read(selectedLessonProvider.notifier).onBookChanged(book);
    }
  }

  Future<void> clear() async {
    state = null;
  }
}
