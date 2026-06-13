import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// مدل اطلاعات هر کتاب
class BookInfo {
  final String id;
  final String title;
  final String coverImage;
  final String jsonAssetPath;

  BookInfo({
    required this.id,
    required this.title,
    required this.coverImage,
    required this.jsonAssetPath,
  });
}

// دیتابیس فرضی کتاب‌های اپلیکیشن شما
final List<BookInfo> availableBooks = [
  BookInfo(
    id: 'mindset_l3',
    title: 'Mindset for IELTS - Level 3',
    coverImage: 'assets/images/covers/mindset_3.jpg',
    jsonAssetPath: 'assets/data/book_3.json',
  ),
  BookInfo(
    id: 'mindset_l1',
    title: 'Mindset for IELTS - Level 1',
    coverImage: 'assets/images/covers/mindset_1.jpg', // تصویر کاور دلخواه
    jsonAssetPath: 'assets/data/book_1.json',
  ),
];

// استیت پرووایدر
class LibraryState {
  final BookInfo? currentBook;
  final double lastScrollOffset;

  LibraryState({this.currentBook, this.lastScrollOffset = 0.0});
}

class LibraryNotifier extends Notifier<LibraryState> {
  final _box = GetStorage();

  @override
  LibraryState build() {
    // 🌟 هنگام باز شدن اپلیکیشن، آخرین کتاب را از حافظه می‌خوانیم
    final lastBookId = _box.read<String>('last_opened_book_id');

    if (lastBookId != null) {
      try {
        final book = availableBooks.firstWhere((b) => b.id == lastBookId);
        final offset = _box.read<double>('scroll_offset_$lastBookId') ?? 0.0;
        return LibraryState(currentBook: book, lastScrollOffset: offset);
      } catch (e) {
        return LibraryState();
      }
    }
    return LibraryState();
  }

  // انتخاب کتاب جدید
  void selectBook(BookInfo book) {
    _box.write('last_opened_book_id', book.id);
    final offset = _box.read<double>('scroll_offset_${book.id}') ?? 0.0;
    state = LibraryState(currentBook: book, lastScrollOffset: offset);
  }

  // ذخیره لحظه‌ای موقعیت اسکرول
  void saveScrollOffset(double offset) {
    if (state.currentBook != null) {
      _box.write('scroll_offset_${state.currentBook!.id}', offset);
    }
  }

  // خروج از کتاب و بازگشت به کتابخانه
  void closeBook() {
    _box.remove(
      'last_opened_book_id',
    ); // پاک کردن آخرین کتاب برای نمایش کتابخانه در اجرای بعدی
    state = LibraryState();
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
