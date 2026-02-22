import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/expandable_mini_player.dart';
import 'package:ielts_assistant/features/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/final_topic_detail_screen.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/features/settings/providers/settings_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/final_topic_search_delegate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationProvider);
    final allContent = ref.watch(allContentProvider);
    final audioState = ref.watch(audioPlayerProvider);

    // گوش دادن به تغییرات محتوا برای بازیابی وضعیت قبلی
    ref.listen(allContentProvider, (previous, next) {
      next.whenData((books) {
        if (books.isNotEmpty && nav.selectedBook == null) {
          // استفاده از Future.microtask برای جلوگیری از تداخل در ساخت ویجت
          Future.microtask(() {
            ref.read(navigationProvider.notifier).restoreLastState(books);
            CfPublic()
                .getSearchListDataAsync(
                  ref.read(allContentProvider).value,
                  ref.read(navigationProvider),
                )
                .then((result) {
                  ref.read(searchListProvider.notifier).state = result;
                });
          });
        }
      });
    });
    ref.listen(navigationProvider, (previous, next) {
      if (next.selectedFinalTopic != null &&
          previous?.selectedFinalTopic == null) {
        ref.read(isPlayerExpandedProvider.notifier).state = false;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const FinalTopicDetailScreen(),
              ),
            )
            .then((_) {
              ref.read(navigationProvider.notifier).goBack();
            });
      }
      /*
       else if (next.selectedFinalTopicSearch != null &&
          previous?.selectedFinalTopicSearch == null) {
        bool mustBeResume = ref.read(audioPlayerProvider.notifier).isPlaying();
        if (mustBeResume) {
          ref.read(audioPlayerProvider.notifier).pause();
        }
        ref.read(isPlayerExpandedProvider.notifier).state = false;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const FinalTopicDetailScreen(),
              ),
            )
            .then((_) {
              ref.read(navigationProvider.notifier).goBack();
              if (mustBeResume) {
                ref.read(audioPlayerProvider.notifier).resume();
              }
            });
      }
      */
    });

    return PopScope(
      canPop: nav.selectedBook == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).goBack();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            title: Text(
              'دستیار آیلتس',
              style: TextStyle(
                fontFamily: FontFamily.yekanBakhBold.asText,
                fontSize: 20.0,
                // color: Theme.of(context).colorScheme.primary,
              ),
            ),
            actions: [
              // Directionality(
              //   textDirection: TextDirection.rtl,
              //   child: IconButton(
              //     onPressed: () async {},
              //     icon: Icon(Icons.add),
              //     tooltip: 'افزودن قالب جدید',
              //   ),
              // ),
              //! ویجت جستجو
              Directionality(
                textDirection: TextDirection.rtl,
                child: IconButton(
                  onPressed: () async {
                    var result = await showSearch(
                      context: context,
                      delegate: FinalTopicSearchDelegate(
                        ref: ref,
                        // data: ref.read(searchListProvider),
                      ),
                    );
                    if (result != null) {}
                  },
                  icon: Icon(Icons.search),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () async {
                  // await _refreshContents();
                  ref.read(allContentProvider.notifier).refresh();
                },
                tooltip: 'تازه‌سازی',
              ),
              IconButton(
                icon: Icon(Icons.folder),
                onPressed: () async {
                  String? previousPath = ref.read(settingsProvider);
                  String? selectedDirectory = await ref
                      .read(settingsProvider.notifier)
                      .pickAndSaveDirectory(previousPath);
                  if (selectedDirectory != null) {
                    await ref
                        .read(settingsProvider.notifier)
                        .updatePath(selectedDirectory);
                    // await _refreshContents(root: selectedDirectory);

                    ref.read(allContentProvider.notifier).refresh();
                  }
                },
                tooltip: 'انتخاب مسیر',
              ),
            ],
          ),
          // floatingActionButton: FloatingActionButton(
          //   heroTag: 'addNewTempelate',
          //   onPressed: () async {
          //     if (await CfPublic().getExternalStoragePermissionStatus() == true) {
          //       _showPopupAddNewTempelate();
          //     }
          //   },
          //   child: Icon(Icons.add),
          // ),
          // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          // drawer: const MainDrawer(),
          body: Column(
            children: [
              _buildBreadcrumbs(nav, allContent),
              Expanded(child: _buildMainContent(nav, allContent)),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ۲. اضافه کردن شرط نمایش مینی پلیر در صفحه اصلی
              if (nav.selectedFinalTopic == null &&
                  audioState.currentPath != null)
                ExpandableMiniPlayer(
                  onClose: () =>
                      ref.read(audioPlayerProvider.notifier).stopAndClear(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(NavigationState nav, AsyncValue allContent) {
    final List<String> labels = [];
    if (nav.selectedBook != null) labels.add(nav.selectedBook!.name);
    if (nav.selectedUnit != null) labels.add(nav.selectedUnit!.name);
    if (nav.selectedTopic != null) labels.add(nav.selectedTopic!.name);
    if (nav.selectedPage != null) labels.add(nav.selectedPage!.name);
    // if (nav.selectedFinalTopic != null) {
    //   labels.add(nav.selectedFinalTopic!.name);
    // }

    if (labels.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 45,
      width: double.infinity,
      color: Colors.blue.withOpacity(0.05),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) =>
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        itemBuilder: (_, i) => Center(
          child: GestureDetector(
            onTap: () {
              if (i == 0) {
                if (labels.length > 1) {
                  ref
                      .read(navigationProvider.notifier)
                      .selectBook(nav.selectedBook!);
                }
              } else if (i == 1) {
                if (labels.length > 2) {
                  ref
                      .read(navigationProvider.notifier)
                      .selectUnit(nav.selectedUnit!);
                }
              } else if (i == 2) {
                if (labels.length > 3) {
                  ref
                      .read(navigationProvider.notifier)
                      .selectTopic(nav.selectedTopic!);
                }
              } else if (i == 3) {
                if (labels.length > 4) {
                  ref
                      .read(navigationProvider.notifier)
                      .selectPageContent(nav.selectedPage!);
                }
              }
            },
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: i == labels.length - 1
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: i == labels.length - 1
                    ? Colors.blue[800]
                    : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(NavigationState nav, AsyncValue allContent) {
    // ۱. نمایش محتوای نهایی (Topic)
    // if (nav.selectedFinalTopic != null) {
    //   return Center(
    //     child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       children: [
    //         const Icon(Icons.audiotrack, size: 64, color: Colors.blue),
    //         const SizedBox(height: 16),
    //         Text(
    //           nav.selectedFinalTopic!.name,
    //           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    //         ),
    //         const Text('در حال پخش فایل صوتی...'),
    //       ],
    //     ),
    //   );
    // }

    // ۱. نمایش صفحه (Topic)
    if (nav.selectedPage != null) {
      return _buildGrid(
        title: 'موضوعات نهایی ${nav.selectedPage!.name}',
        items: nav.selectedPage!.finalTopics.map((e) => e.name).toList(),
        icon: Icons.description_outlined,
        onTap: (index) => ref
            .read(navigationProvider.notifier)
            .selectFinalTopic(nav.selectedPage!.finalTopics[index]),
      );
    }

    // ۱. نمایش موضوع (Topic)
    if (nav.selectedTopic != null) {
      return _buildGrid(
        title: 'صفحات ${nav.selectedTopic!.name}',
        items: nav.selectedTopic!.pageContents.map((e) => e.name).toList(),
        icon: Icons.description_outlined,
        onTap: (index) => ref
            .read(navigationProvider.notifier)
            .selectPageContent(nav.selectedTopic!.pageContents[index]),
      );
    }

    // ۲. نمایش لیست موضوعات (Topics)
    if (nav.selectedUnit != null) {
      return _buildGrid(
        title: 'موضوعات واحد ${nav.selectedUnit!.name}',
        items: nav.selectedUnit!.topics.map((e) => e.name).toList(),
        icon: Icons.description_outlined,
        onTap: (index) => ref
            .read(navigationProvider.notifier)
            .selectTopic(nav.selectedUnit!.topics[index]),
      );
    }

    // ۳. نمایش لیست واحدها (Units)
    if (nav.selectedBook != null) {
      return _buildGrid(
        title: 'واحدهای کتاب ${nav.selectedBook!.name}',
        items: nav.selectedBook!.units.map((e) => e.name).toList(),
        icon: Icons.folder_open_outlined,
        onTap: (index) {
          ref
              .read(navigationProvider.notifier)
              .selectUnit(nav.selectedBook!.units[index]);
        },
      );
    }

    // ۴. نمایش لیست کتاب‌ها
    return allContent.when(
      data: (books) {
        if (books.isEmpty) {
          return const Center(
            child: Text('هیچ کتابی در پوشه مورد نظر پیدا نشد.'),
          );
        }
        return _buildGrid(
          title: 'کتاب‌های آموزشی',
          items: books.map((e) => e.name).cast<String>().toList(),
          icon: Icons.book_outlined,
          onTap: (index) =>
              ref.read(navigationProvider.notifier).selectBook(books[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('مسیر فایل‌ها تنظیم نشده یا در دسترس نیست.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('رفتن به تنظیمات'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid({
    required String title,
    required List<String> items,
    required IconData icon,
    required Function(int) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.blue[800], size: 30),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        items[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Future<void> _refreshContents({String? root}) async {
  //   final rootPath = root ?? ref.read(settingsProvider) ?? '';
  //   if (!Directory(rootPath).existsSync()) {
  //     return;
  //   }
  //   final newBooks = await ContentService.scanRootFolder(
  //     ref.read(settingsProvider)!,
  //   );
  //   await ref.read(allContentProvider.notifier).updateBooks(newBooks);
  //   // Future.delayed(const Duration(seconds: 2)).then((onValue) {
  //   final books = ref.read(allContentProvider).value;
  //   if (books != null) {
  //     ref.read(navigationProvider.notifier).restoreLastState(books);
  //     Future.microtask(() {
  //       ref.read(navigationProvider.notifier).restoreLastState(books);
  //       CfPublic()
  //           .getSearchListDataAsync(
  //             ref.read(allContentProvider).value,
  //             ref.read(navigationProvider),
  //           )
  //           .then((result) {
  //             ref.read(searchListProvider.notifier).state = result;
  //           });
  //     });
  //   }
  // }
}
