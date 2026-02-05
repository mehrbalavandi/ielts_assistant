import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/data/content_service.dart';
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
    Topic? selectedTopic,
    PageContent? selectedPage,
    FinalTopic? selectedFinalTopic,
    FinalTopic? selectedFinalTopicSearch,
    // List<TextSegmentEnglish>? currentTextSegmentsEnglish,
    // List<TextSegmentPersian>? currentTextSegmentsPersian,
    // List<TextSegmentPersian>? currentNoteTextSegments,
    @Default(false) bool isLoading,
  }) = _NavigationState;
}

@riverpod
class NavigationNotifier extends _$NavigationNotifier {
  final _box = GetStorage();
  final _contentService = ContentService();

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

            // if (lastFinalTopicName != null) {
            //   final finalTopic = page.finalTopics.firstWhere(
            //     (t) => t.name == lastFinalTopicName,
            //   );
            //   state = state.copyWith(selectedFinalTopic: finalTopic);
            // }
          }
        }
      }
      // Future.microtask(() {
      // CfPublic()
      //     .getOriginalContentsAsync(
      //       ref.read(allContentProvider).value,
      //       ref.read(navigationProvider),
      //     )
      //     .then((result) {
      //       ref.read(originalContentListProvider.notifier).state = result;
      //     });
      // });
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
    Future.delayed(Duration.zero).then((value) async {
      updateSearchListData();
    });
  }

  void updateSearchListData() {
    CfPublic()
        .getSearchListDataAsync(ref.read(allContentProvider).value, state)
        .then((result) {
          // var vvNavigation = result[0]
          //     .book
          //     .units[0]
          //     .topics[0]
          //     .pageContents[0]
          //     .finalTopics[0]
          //     .contentPersian[0]
          //     .text;
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
      // currentTextSegmentsEnglish: CfPublic().parseEnglishContent(results[0]),
      // currentTextSegmentsPersian: CfPublic().parsePersianContent(results[1]),
      // currentNoteTextSegments: CfPublic().parsePersianContent(results[2]),
      isLoading: false,
    );
    _box.write(_kPage, pageContent.name);
    _box.write(_kFinalTopic, finalTopic.name);
    // منطق پخش خودکار صدا
    if (finalTopic.audioFileName != null &&
        finalTopic.audioFileName!.isNotEmpty) {
      final fullPath = _buildFullPath(finalTopic);
      await Future.delayed(const Duration(milliseconds: 300));
      ref.read(audioPlayerProvider.notifier).playFile(fullPath);
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
      ref.read(audioPlayerProvider.notifier).playFile(fullPath);
    }
  }

  Future<void> addTempelate(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    final books = ref.read(allContentProvider).value;
    final book = books!.firstWhereOrNull(
      (b) => b.name.contains('قالبهای موقعیتی'),
    );
    if (book != null) {
      final unit = book.units.firstWhere((u) => u.name.contains('Band 4–5'));
      final topic = unit.topics.firstWhere((t) => t.name.contains('Days'));
      final page = topic.pageContents.firstWhere((t) => t.name.contains('00'));
      updateAllContents(books, book, unit, topic, page, finalTopic);
      updateSearchListData();
    }
    state = state.copyWith(isLoading: false);
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
    // final newBooks = List<Book>.from(books);
    // int idx = books.indexOf(books.where((x) => x.name == newBook.name).first);
    // newBooks[idx] = newBook;
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

final searchListProvider = StateProvider<List<OriginalContent>>(
  (ref) => <OriginalContent>[],
);
