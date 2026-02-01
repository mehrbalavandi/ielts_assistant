import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/data/content_service.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/customer_search_delegate.dart';
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
    List<TextSegmentEnglish>? currentEnglishSegments,
    List<TextSegmentPersian>? currentPersianTextSegments,
    List<TextSegmentPersian>? currentNoteTextSegments,
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
    final lastFinalTopicName = _box.read(_kFinalTopic);

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
      CfPublic()
          .getOriginalContentsAsync(ref.read(allContentProvider).value, state)
          .then((result) {
            ref.read(originalContentListProvider.notifier).state = result;
          });
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
    state = state.copyWith(
      currentEnglishSegments: null,
      currentPersianTextSegments: null,
      currentNoteTextSegments: null,
      isLoading: true,
    );

    // خواندن موازی برای بهینه‌سازی زمان
    final results = await Future.wait([
      _contentService.readFile(finalTopic.jsonFilePath),
      _contentService.readFile(finalTopic.translationFilePath),
    ]);
    state = state.copyWith(
      selectedPage: pageContent,
      selectedFinalTopic: finalTopic,
      currentEnglishSegments: _parseEnglishContent(results[0]),
      currentPersianTextSegments: _parsePersianContent(results[1]),
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

  Future<SearchResultSegments> selectPageAndFinalTopicForSearchResult(
    OriginalContent originalContent,
  ) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(isLoading: true);

    // خواندن موازی برای بهینه‌سازی زمان
    final results = await Future.wait([
      _contentService.readFile(originalContent.finalTopic.jsonFilePath),
      _contentService.readFile(originalContent.finalTopic.translationFilePath),
    ]);
    List<TextSegmentEnglish>? englishSegments = _parseEnglishContent(
      results[0],
    );
    List<TextSegmentPersian>? textSegmentsPersian = _parsePersianContent(
      results[1],
    );
    state = state.copyWith(isLoading: false);
    // منطق پخش خودکار صدا
    // if (originalContent.finalTopic.audioFileName != null &&
    //     originalContent.finalTopic.audioFileName!.isNotEmpty) {
    //   final fullPath = _buildFullPathForSearchResult(originalContent);
    //   await Future.delayed(const Duration(milliseconds: 300));
    //   ref.read(audioPlayerProvider.notifier).playFile(fullPath);
    // }
    return SearchResultSegments(
      enSegments: englishSegments,
      faSegments: textSegmentsPersian,
    );
  }

  void selectPageContent(PageContent pageContent) {
    state = state.copyWith(selectedPage: pageContent, selectedFinalTopic: null);
    _box.write(_kPage, pageContent.name);
    _box.remove(_kFinalTopic);
  }

  Future<void> selectFinalTopic(FinalTopic finalTopic) async {
    // ۱. پاک کردن مقادیر قبلی و نمایش حالت لودینگ
    state = state.copyWith(
      currentEnglishSegments: null,
      currentPersianTextSegments: null,
      isLoading: true,
    );

    // خواندن موازی برای بهینه‌سازی زمان
    final results = await Future.wait([
      _contentService.readFile(finalTopic.jsonFilePath),
      _contentService.readFile(finalTopic.translationFilePath),
    ]);
    state = state.copyWith(
      selectedFinalTopic: finalTopic,
      currentEnglishSegments: _parseEnglishContent(results[0]),
      currentPersianTextSegments: _parsePersianContent(results[1]),
      isLoading: false,
    );
    _box.write(_kFinalTopic, finalTopic.name);
    // منطق پخش خودکار صدا
    if (finalTopic.audioFileName != null &&
        finalTopic.audioFileName!.isNotEmpty) {
      final fullPath = _buildFullPath(finalTopic);
      await Future.delayed(const Duration(milliseconds: 300));
      ref.read(audioPlayerProvider.notifier).playFile(fullPath);

      ///storage/emulated/0/000- English Learning/00- ielts assistant/mindset 01/Tracks/66 Mindset_L1_66.sound
    }
  }

  List<TextSegmentEnglish> _parseEnglishContent(String? raw) {
    if (raw == null) {
      return <TextSegmentEnglish>[];
    }
    final List<dynamic> jsonFormat = jsonDecode(raw);
    return jsonFormat
        .map(
          (json) => TextSegmentEnglish.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  List<TextSegmentPersian> _parsePersianContent(String? raw) {
    if (raw == null) {
      return <TextSegmentPersian>[];
    }
    final List<dynamic> jsonFormat = jsonDecode(raw);
    return jsonFormat
        .map(
          (json) => TextSegmentPersian.fromJson(json as Map<String, dynamic>),
        )
        .toList();
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

final originalContentListProvider = StateProvider<List<OriginalContent>>(
  (ref) => <OriginalContent>[],
);
