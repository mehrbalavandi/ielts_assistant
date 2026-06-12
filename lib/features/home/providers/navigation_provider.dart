import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';
part 'navigation_provider.freezed.dart';

@freezed
sealed class NavigationState with _$NavigationState {
  const factory NavigationState({
    Book? selectedBook,
    Unit? selectedUnit,
    // OtherContent? selectedOtherContent,
    Topic? selectedTopic,
    PageContent? selectedPage,
    FinalTopic? selectedFinalTopic,
    FinalTopic? selectedFinalTopicSearch,
    @Default(false) bool isLoading,
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
    // final lastOtherName = _box.read(_kOtherContent);
    final lastTopicName = _box.read(_kTopic);
    final lastPageName = _box.read(_kPage);
    // final lastFinalTopicName = _box.read(_kFinalTopic);

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

          if (lastPageName != null) {
            final page = topic.pageContents.firstWhere(
              (t) => t.name == lastPageName,
            );
            state = state.copyWith(selectedPage: page);
          }
        }
      }
    } catch (_) {}
  }

  void selectBook(Book book) {
    bool mustBeUpdateSearchListData = state.selectedBook != book;
    if (book.units.length == 1 &&
        book.units.first.topics.length == 1 &&
        book.units.first.topics.first.pageContents.length == 1) {
      Unit unit = book.units.first;
      Topic topic = unit.topics.first;
      PageContent pageContent = topic.pageContents.first;
      state = state.copyWith(
        selectedBook: book,
        selectedUnit: book.units.first,
        selectedTopic: topic,
        selectedPage: pageContent,
        selectedFinalTopic: null,
      );
      _box.write(_kBook, book.name);
      _box.write(_kUnit, unit.name);
      _box.write(_kTopic, topic.name);
      _box.write(_kPage, pageContent.name);
      _box.remove(_kFinalTopic);
    } else if (book.units.length == 1 && book.units.first.topics.length == 1) {
      Unit unit = book.units.first;
      Topic topic = unit.topics.first;
      state = state.copyWith(
        selectedBook: book,
        selectedUnit: book.units.first,
        selectedTopic: topic,
        selectedPage: null,
        selectedFinalTopic: null,
      );
      _box.write(_kBook, book.name);
      _box.write(_kUnit, unit.name);
      _box.write(_kTopic, topic.name);
      _box.remove(_kPage);
      _box.remove(_kFinalTopic);
    } else {
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

    if (mustBeUpdateSearchListData) {
      Future.delayed(Duration.zero).then((value) async {
        updateSearchListData();
      });
    }
  }

  void updateSearchListData() {
    CfPublic()
        .getSearchListDataAsync(ref.read(allContentProvider).value, state)
        .then((result) {
          ref.read(searchListProvider.notifier).state = result;
        });
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

  void selectOtherContent(OtherContent otherContent) {
    state = state.copyWith(
      selectedUnit: null,
      // selectedOtherContent: otherContent,
      selectedTopic: null,
      selectedPage: null,
      selectedFinalTopic: null,
    );
    // _box.write(_kOtherContent, otherContent.name);
    _box.remove(_kUnit);
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

  Future<void> selectPageAndFinalTopic(
    PageContent pageContent,
    FinalTopic finalTopic,
  ) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    // خواندن موازی برای بهینه‌سازی زمان
    // final results = await Future.wait([
    //   _contentService.readFile(finalTopic.filePathEnglish),
    //   _contentService.readFile(finalTopic.filePathPersian),
    //   _contentService.readFile(finalTopic.notesFilePath),
    // ]);
    state = state.copyWith(
      selectedPage: pageContent,
      selectedFinalTopic: finalTopic,
      isLoading: false,
    );
    _box.write(_kPage, pageContent.name);
    _box.write(_kFinalTopic, finalTopic.name);
    // منطق پخش خودکار صدا
    if (finalTopic.audioFileName != null &&
        finalTopic.audioFileName!.isNotEmpty) {
      final fullPath = _buildFullPath(finalTopic);
      await Future.delayed(const Duration(milliseconds: 300));
      ref.read(audioPlayerProvider.notifier).playFileOldMethod(fullPath);
    }
  }

  Future<void> selectFinalTopic(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    state = state.copyWith(selectedFinalTopic: finalTopic, isLoading: false);
    _box.write(_kFinalTopic, finalTopic.name);
    // منطق پخش خودکار صدا
    if (finalTopic.audioFileName != null &&
        finalTopic.audioFileName!.isNotEmpty) {
      final fullPath = _buildFullPath(finalTopic);
      await Future.delayed(const Duration(milliseconds: 300));
      ref.read(audioPlayerProvider.notifier).playFileOldMethod(fullPath);
    }
  }

  Future<void> addTempelate(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    final books = ref.read(allContentProvider).value;
    final book = books!.firstWhereOrNull(
      (b) => b.name.contains(state.selectedBook!.name),
    );
    if (book != null) {
      final unit = book.units.firstWhere((u) => u.name.contains('unit'));
      final topic = unit.topics.firstWhere((t) => t.name.contains('topic'));
      final page = topic.pageContents.firstWhere(
        (t) => t.name.contains('منبع'),
      );
      updateAllContents(books, book, unit, topic, page, finalTopic);
      updateSearchListData();
    }
    state = state.copyWith(selectedFinalTopic: finalTopic, isLoading: false);
  }

  Future<void> updateTempelate(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    FinalTopic newFinalTopic = CfPublic().parseFinalTopic(
      Directory(finalTopic.realmId),
    );
    final books = ref.read(allContentProvider).value;
    final book = books!.firstWhereOrNull((b) => b == state.selectedBook);
    if (book != null) {
      final unit = book.units.firstWhere((u) => u == state.selectedUnit);
      final topic = unit.topics.firstWhere((t) => t == state.selectedTopic);
      final page = topic.pageContents.firstWhere(
        (t) => t == state.selectedPage,
      );
      updateAllContents(books, book, unit, topic, page, newFinalTopic);
      updateSearchListData();
    }

    state = state.copyWith(selectedFinalTopic: newFinalTopic, isLoading: false);
  }

  Future<void> selectPageAndFinalTopicForSearchResult(
    FinalTopic finalTopic,
  ) async {
    state = state.copyWith(
      selectedFinalTopicSearch: finalTopic,
      isLoading: false,
    );
  }

  Future<void> updateTempelateForSearchResult(
    OriginalContent originalContent,
  ) async {
    state = state.copyWith(isLoading: true);

    FinalTopic newFinalTopic = CfPublic().parseFinalTopic(
      Directory(originalContent.finalTopic.realmId),
    );
    final books = ref.read(allContentProvider).value;
    final book = originalContent.book;
    final unit = originalContent.unit;
    final topic = originalContent.topic;
    final page = originalContent.page;

    await updateAllContents(books!, book, unit, topic, page, newFinalTopic);
    updateSearchListData();
    state = state.copyWith(
      selectedFinalTopicSearch: newFinalTopic,
      isLoading: false,
    );
  }

  Future<void> updateAllContents(
    List<Book> books,
    Book book,
    Unit unit,
    Topic topic,
    PageContent page,
    FinalTopic finalTopic,
  ) async {
    final oldIndex = page.finalTopics.indexWhere(
      (x) => x.name == finalTopic.name,
    );
    if (oldIndex == -1) {
      return; // اگر پیدا نشد
    }

    final newFinalTopics = List<FinalTopic>.from(page.finalTopics)
      ..[oldIndex] = finalTopic;

    final newPage = page.copyWith(finalTopics: newFinalTopics);
    final newPageContents = List<PageContent>.from(topic.pageContents)
      ..[topic.pageContents.indexOf(page)] = newPage;

    final newTopic = topic.copyWith(pageContents: newPageContents);
    final newTopics = List<Topic>.from(unit.topics)
      ..[unit.topics.indexOf(topic)] = newTopic;

    final newUnit = unit.copyWith(topics: newTopics);
    final newUnits = List<Unit>.from(book.units)
      ..[book.units.indexOf(unit)] = newUnit;

    final newBook = book.copyWith(units: newUnits);
    final newBooks = List<Book>.from(books)..[books.indexOf(book)] = newBook;
    await ref.read(allContentProvider.notifier).updateBooks(newBooks);

    if (state.selectedFinalTopicSearch == null) {
      state = state.copyWith(
        selectedBook: newBook,
        selectedUnit: newUnit,
        selectedTopic: newTopic,
        selectedPage: newPage,
      );
    }
  }

  void selectPageContent(PageContent pageContent) {
    state = state.copyWith(selectedPage: pageContent, selectedFinalTopic: null);
    _box.write(_kPage, pageContent.name);
    _box.remove(_kFinalTopic);
  }

  Future<void> deleteTempelate(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    FinalTopic newFinalTopic = CfPublic().parseFinalTopic(
      Directory(finalTopic.realmId),
    );
    final books = ref.read(allContentProvider).value;
    final book = books!.firstWhereOrNull((b) => b == state.selectedBook);
    if (book != null) {
      final unit = book.units.firstWhere((u) => u == state.selectedUnit);
      final topic = unit.topics.firstWhere((t) => t == state.selectedTopic);
      final page = topic.pageContents.firstWhere(
        (t) => t == state.selectedPage,
      );
      updateAllContents(books, book, unit, topic, page, newFinalTopic);
      updateSearchListData();
    }

    state = state.copyWith(selectedFinalTopic: newFinalTopic, isLoading: false);
  }

  String _buildFullPath(FinalTopic finalTopic) {
    // این متد باید بر اساس ساختار پوشه‌بندی شما، مسیر کامل فایل mp3 را بسازد
    // final root = _box.read('audio_path') ?? '';
    final rootPath = ref.read(settingsProvider);
    return '$rootPath/${state.selectedBook!.name}/Tracks/${finalTopic.audioFileName}.mp3'; //000- English Learning/00- ielts assistant /mindset 01/Tracks
  }

  String buildFullPathForSearchResult(OriginalContent originalContent) {
    // این متد باید بر اساس ساختار پوشه‌بندی شما، مسیر کامل فایل mp3 را بسازد
    // final root = _box.read('audio_path') ?? '';
    final rootPath = ref.read(settingsProvider);
    return "$rootPath/${originalContent.book}/Tracks/${originalContent.finalTopic.audioFileName}.mp3"; //000- English Learning/00- ielts assistant /mindset 01/Tracks
  }

  void goBack() {
    if (state.selectedFinalTopicSearch != null) {
      state = state.copyWith(selectedFinalTopicSearch: null);
    } else if (state.selectedFinalTopic != null) {
      state = state.copyWith(selectedFinalTopic: null);
      _box.remove(_kFinalTopic);
    } else if (state.selectedPage != null) {
      if (state.selectedBook?.units.length == 1 &&
          state.selectedBook?.units.first.topics.length == 1 &&
          state.selectedBook?.units.first.topics.first.pageContents.length ==
              1) {
        state = state.copyWith(
          selectedPage: null,
          selectedTopic: null,
          selectedUnit: null,
          selectedBook: null,
        );
        _box.remove(_kPage);
        _box.remove(_kTopic);
        _box.remove(_kUnit);
        _box.remove(_kBook);
      } else {
        state = state.copyWith(selectedPage: null);
        _box.remove(_kPage);
      }
    } else if (state.selectedTopic != null) {
      if (state.selectedBook?.units.length == 1 &&
          state.selectedBook?.units.first.topics.length == 1) {
        state = state.copyWith(
          selectedTopic: null,
          selectedUnit: null,
          selectedBook: null,
        );
        _box.remove(_kTopic);
        _box.remove(_kUnit);
        _box.remove(_kBook);
      } else {
        state = state.copyWith(selectedTopic: null);
        _box.remove(_kTopic);
      }
    } else if (state.selectedUnit != null) {
      state = state.copyWith(selectedUnit: null);
      _box.remove(_kUnit);
    } else if (state.selectedBook != null) {
      state = state.copyWith(selectedBook: null);
      _box.remove(_kBook);
    }
  }
}

final searchListProvider = StateProvider<List<OriginalContent>>(
  (ref) => <OriginalContent>[],
);
