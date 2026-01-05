import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';
part 'navigation_provider.freezed.dart';
/*
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
  final _box = GetStorage();

  // کلیدهای ذخیره‌سازی
  static const _kBook = 'last_book';
  static const _kUnit = 'last_unit';
  static const _kTopic = 'last_topic';

  @override
  NavigationState build() {
    // در ابتدا وضعیت خالی است.
    // بازیابی داده‌ها را در یک متد جداگانه بعد از لود شدن محتوا انجام می‌دهیم.
    return const NavigationState();
  }

  // متدی برای بازیابی وضعیت از حافظه (باید بعد از لود شدن allContentProvider فراخوانی شود)
  void restoreLastState(List<Book> allBooks) {
    final lastBookName = _box.read(_kBook);
    final lastUnitName = _box.read(_kUnit);
    final lastTopicName = _box.read(_kTopic);

    if (lastBookName == null) return;

    try {
      final book = allBooks.firstWhere((b) => b.name == lastBookName);
      state = state.copyWith(selectedBook: book);

      if (lastUnitName != null) {
        final unit = book.units.firstWhere((u) => u.name == lastUnitName);
        state = state.copyWith(selectedUnit: unit);

        if (lastTopicName != null) {
          final topic = unit.topics.firstWhere((t) => t.name == lastTopicName);
          state = state.copyWith(selectedTopic: topic);
        }
      }
    } catch (e) {
      // اگر ساختار فایل‌ها عوض شده بود و پیدا نشد، خطا را نادیده بگیر
      print("Could not restore state: $e");
    }
  }

  void selectBook(Book book) {
    state = state.copyWith(
      selectedBook: book,
      selectedUnit: null,
      selectedTopic: null,
      selectedPage: null,
    );
    _box.write(_kBook, book.name);
    _box.remove(_kUnit);
    _box.remove(_kTopic);
  }

  void selectUnit(Unit unit) {
    state = state.copyWith(
      selectedUnit: unit,
      selectedTopic: null,
      selectedPage: null,
    );
    _box.write(_kUnit, unit.name);
    _box.remove(_kTopic);
  }

  void selectTopic(Topic topic) {
    state = state.copyWith(selectedTopic: topic, selectedPage: null);
    _box.write(_kTopic, topic.name);
  }

  void selectPage(PageContent page) {
    state = state.copyWith(selectedPage: page);
  }

  void reset() {
    state = const NavigationState();
    _box.remove(_kBook);
    _box.remove(_kUnit);
    _box.remove(_kTopic);
  }
}
*/
// lib/features/home/providers/navigation_provider.dart

@freezed
sealed class NavigationState with _$NavigationState {
  const factory NavigationState({
    Book? selectedBook,
    Unit? selectedUnit,
    Topic? selectedTopic,
    PageContent? selectedPage,
    FinalTopic? selectedFinalTopic,
  }) = _NavigationState;
}

@riverpod
class NavigationNotifier extends _$NavigationNotifier {
  final _box = GetStorage();
  static const _kBook = 'last_book';
  static const _kUnit = 'last_unit';
  static const _kTopic = 'last_topic';
  static const _kPage = 'last_page';
  static const _kFinalTopic = 'last_final_topic';

  @override
  NavigationState build() => const NavigationState();

  void restoreLastState(List<Book> allBooks) {
    final lastBookName = _box.read(_kBook);
    final lastUnitName = _box.read(_kUnit);
    final lastTopicName = _box.read(_kTopic);

    if (lastBookName == null) return;

    try {
      final book = allBooks.firstWhere((b) => b.name == lastBookName);
      state = state.copyWith(selectedBook: book);

      if (lastUnitName != null) {
        final unit = book.units.firstWhere((u) => u.name == lastUnitName);
        state = state.copyWith(selectedUnit: unit);

        if (lastTopicName != null) {
          final topic = unit.topics.firstWhere((t) => t.name == lastTopicName);
          state = state.copyWith(selectedTopic: topic);
        }
      }
    } catch (_) {}
  }

  void selectBook(Book book) {
    state = state.copyWith(
      selectedBook: book,
      selectedUnit: null,
      selectedTopic: null,
      selectedPage: null,
      selectedFinalTopic: null,
    );
    _box.write(_kBook, book.name);
    _box.remove(_kUnit);
    _box.remove(_kTopic);
    _box.remove(_kPage);
    _box.remove(_kFinalTopic);
  }

  void selectUnit(Unit unit) {
    state = state.copyWith(
      selectedUnit: unit,
      selectedTopic: null,
      selectedPage: null,
      selectedFinalTopic: null,
    );
    _box.write(_kUnit, unit.name);
    _box.remove(_kTopic);
    _box.remove(_kPage);
    _box.remove(_kFinalTopic);
  }

  void selectTopic(Topic topic) {
    state = state.copyWith(
      selectedTopic: topic,
      selectedPage: null,
      selectedFinalTopic: null,
    );
    _box.write(_kTopic, topic.name);
    _box.remove(_kPage);
    _box.remove(_kFinalTopic);
  }

  void selectPageContent(PageContent pageContent) {
    state = state.copyWith(selectedPage: pageContent, selectedFinalTopic: null);
    _box.write(_kPage, pageContent.name);
    _box.remove(_kFinalTopic);
  }

  void selectFinalTopic(FinalTopic finalTopic) {
    state = state.copyWith(selectedFinalTopic: finalTopic);
    _box.write(_kFinalTopic, finalTopic.name);
    // منطق پخش خودکار صدا
    if (finalTopic.audioFilePath != null &&
        finalTopic.audioFilePath!.isNotEmpty) {
      final fullPath = _buildFullPath(finalTopic);
      ref.read(audioPlayerProvider.notifier).playFile(fullPath);
    }
  }

  String _buildFullPath(FinalTopic finalTopic) {
    // این متد باید بر اساس ساختار پوشه‌بندی شما، مسیر کامل فایل mp3 را بسازد
    final root = _box.read('audio_path') ?? '';
    return "$root/${state.selectedBook!.name}/${state.selectedUnit!.name}/${finalTopic.name}/${finalTopic.audioFilePath}";
  }

  void goBack() {
    if (state.selectedFinalTopic != null) {
      state = state.copyWith(selectedFinalTopic: null);
      _box.remove(_kFinalTopic);
    } else if (state.selectedPage != null) {
      state = state.copyWith(selectedPage: null);
      _box.remove(_kPage);
    } else if (state.selectedTopic != null) {
      state = state.copyWith(selectedTopic: null);
      _box.remove(_kTopic);
    } else if (state.selectedUnit != null) {
      state = state.copyWith(selectedUnit: null);
      _box.remove(_kUnit);
    } else if (state.selectedBook != null) {
      state = state.copyWith(selectedBook: null);
      _box.remove(_kBook);
    }
  }
}
