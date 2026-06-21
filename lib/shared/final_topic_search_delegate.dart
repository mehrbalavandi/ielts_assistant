// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/final_topic_detail_screen.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/shared/list_item_search.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/utility_persian.dart';

// یک مدل ساده برای مشتری (شما می‌توانید از مدل پیچیده خود استفاده کنید)

// لیست نمونه مشتریان

class FinalTopicSearchDelegate extends SearchDelegate<String> {
  WidgetRef ref;
  // final Future<List<OriginalContent>> dataFuture;
  // final List<OriginalContent> data;
  List<OriginalContent>? _cachedData;

  FinalTopicSearchDelegate({
    required this.ref,
    // required this.dataFuture,
    // required this.data,
  });
  Future<List<OriginalContent>> _getFilteredData() async {
    // اگر داده‌ها قبلاً لود نشده‌اند، منتظر لود شدن می‌مانیم
    // _cachedData ??= await dataFuture;
    // _cachedData ??= await ref.read(searchListProvider);
    _cachedData = await ref.read(searchListProvider);
    // var vvCachedData = _cachedData
    //     ?.first
    //     .book
    //     .units
    //     .first
    //     .topics[0]
    //     .pageContents[0]
    //     .finalTopics
    //     .first
    //     .contentPersian
    //     .first
    //     .text;
    // حالا که داده‌ها قطعی در _cachedData هستند، فیلتر می‌کنیم
    if (query.isEmpty) {
      return _cachedData!;
    }

    // فیلتر کردن بر اساس متن جستجو
    String lowerSearchText = query.toLowerCase();
    lowerSearchText = UtilityPersian().repairNumberAndChars(lowerSearchText);
    return _cachedData!.where((s) {
      if (s.originalContent.toLowerCase().contains(lowerSearchText)) {
        return true;
      }
      return false;
    }).toList();
  }

  // final SyncClientController syncController = Get.find<SyncClientController>();
  // ----------------------------------------------------
  // متد ۱: ساخت دکمه‌های سمت چپ در نوار جستجو (مانند آیکون بستن)
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = ''; // پاک کردن متن جستجو
          showSuggestions(context); // نمایش دوباره پیشنهادات (تاریخچه)
        },
      ),
    ];
  }

  // ----------------------------------------------------
  // متد ۲: ساخت دکمه سمت راست در نوار جستجو (معمولاً آیکون بازگشت)
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, ''); // بستن صفحه جستجو و بازگشت به صفحه قبل
      },
    );
  }

  // ----------------------------------------------------
  // متد ۳: نمایش نتایج (وقتی کاربر دکمه Enter را می‌زند یا یک پیشنهاد را انتخاب می‌کند)
  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  // ----------------------------------------------------
  // متد ۴: نمایش پیشنهادات (در حین تایپ، شامل تاریخچه و نتایج زنده)
  @override
  Widget buildSuggestions(BuildContext context) {
    /*
    if (query.isNotEmpty && query != '') {
      String lowerSearchText = query.toLowerCase();
      lowerSearchText = CfPersian().repairNumberAndChars(lowerSearchText);
      List<String> tags = lowerSearchText.trim().split(' ');
      var filteredList = listOfOriginalModelClient.where((s) {
        // bool result = false;
        // //
        // for (String tag in tags) {
        //   if (s.title.toLowerCase().contains(tag) ||
        //       s.mobile.toLowerCase().contains(tag) ||
        //       s.address.toLowerCase().contains(tag) ||
        //       s.id.toString().contains(tag)) {
        //     return true;
        //   }
        // }
        // return result;
        if (s.title.contains(query) ||
            s.address.contains(query) ||
            s.mobile.contains(query) ||
            s.id.toString().contains(query)) {
          return true;
        }
        return false;
      }).toList();
      var negativeIds = filteredList.where((x) => x.id! < 0).toList();
      var positiveIds = filteredList.where((x) => x.id! >= 0).toList();

      final separatedList = <ModelClient>[];
      separatedList.addAll(negativeIds);
      separatedList.addAll(positiveIds);
      return _buildComplexCustomerList(separatedList);
    }
    return _buildComplexCustomerList(listOfOriginalModelClient);
*/
    return FutureBuilder<List<OriginalContent>>(
      future: _getFilteredData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('خطایی در بارگذاری داده‌ها رخ داد'));
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(child: Text('موردی یافت نشد'));
        }

        return _buildSearchList(results);
      },
    );
  }

  @override
  String? get searchFieldLabel => 'جستجو...'; // <--- متن راهنمای جدید

  @override
  TextStyle? get searchFieldStyle =>
      const TextStyle(fontFamily: 'YekanBakhRegular');

  // ----------------------------------------------------

  Widget _buildSearchList(List<OriginalContent> originalContents) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        itemCount: originalContents.length,
        itemBuilder: (context, index) {
          final originalContent = originalContents[index];
          return ListItemSearch(
            ref: ref,
            originalContent: originalContent,
            onTap: () async {
              ref.read(isPlayerExpandedProvider.notifier).state = false;
              bool mustBeResume = ref
                  .read(audioPlayerProvider.notifier)
                  .isPlaying();
              if (mustBeResume) {
                ref.read(audioPlayerProvider.notifier).pause();
              }
              ref
                  .read(navigationProvider.notifier)
                  .selectPageAndFinalTopicForSearchResult(
                    originalContent.finalTopic,
                  );

              await Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) {
                        return FinalTopicDetailScreen(
                          originalContent: originalContent,
                          searchText: query.toLowerCase(),
                        );
                      },
                    ),
                  )
                  .then((_) {
                    ref.read(navigationProvider.notifier).goBack();
                    if (mustBeResume) {
                      ref.read(audioPlayerProvider.notifier).resume();
                    }
                  });
            },
          );
        },
      ),
    );
  }
}

/*
class SearchResultSegments {
  List<TextSegmentEnglish> enSegments;
  List<TextSegmentPersian> faSegments;
  // List<TextSegmentPersian> noteSegments;
  SearchResultSegments({
    required this.enSegments,
    required this.faSegments,
    // required this.noteSegments,
  });
}
  */
