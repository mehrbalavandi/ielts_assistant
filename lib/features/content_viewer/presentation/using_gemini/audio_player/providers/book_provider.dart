import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_provider.g.dart';

// مدل ساده برای کتاب‌ها
class BookModel {
  final String id;
  final String title;
  final String jsonAssetPath;
  final String coverImage;

  BookModel({
    required this.id,
    required this.title,
    required this.jsonAssetPath,
    required this.coverImage,
  });
}

// دیتابیس فرضی کتاب‌های شما
final List<BookModel> availableBooks = [
  BookModel(
    id: 'mindset_lvl1',
    title: 'Mindset for IELTS - Level 1',
    jsonAssetPath: 'assets/data/mindset_l1.json',
    coverImage: 'assets/images/cover_l1.png',
  ),
  BookModel(
    id: 'mindset_lvl2',
    title: 'Mindset for IELTS - Level 2',
    jsonAssetPath: 'assets/data/mindset_l2.json',
    coverImage: 'assets/images/cover_l2.png',
  ),
];

@riverpod
class ActiveBook extends _$ActiveBook {
  final _box = GetStorage();

  @override
  BookModel? build() {
    // هنگام بالا آمدن اپلیکیشن، آخرین آیدی کتاب را می‌خواند
    final lastBookId = _box.read('last_opened_book_id');

    if (lastBookId != null) {
      try {
        return availableBooks.firstWhere((book) => book.id == lastBookId);
      } catch (e) {
        return null;
      }
    }
    return null; // اگر کاربری تازه وارد باشد
  }

  void setActiveBook(BookModel book) {
    _box.write('last_opened_book_id', book.id);
    state = book;
  }
}
