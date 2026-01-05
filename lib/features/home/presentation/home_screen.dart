import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/mini_audio_player.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/topic_detail_screen.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/main_drawer.dart';
/*
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navigationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('آموزش هوشمند')),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildBreadcrumbs(nav),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildBody(nav, ref),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MiniAudioPlayer(),
    );
  }

  Widget _buildBody(NavigationState nav, WidgetRef ref) {
    if (nav.selectedTopic == null) {
      return const Center(child: Text('درسی انتخاب نشده'));
    }
    if (nav.selectedPage == null) {
      return ListView(
        key: const ValueKey('page_list'),
        children: nav.selectedTopic!.pageContents
            .map(
              (p) => ListTile(
                title: Text(p.name),
                onTap: () =>
                    ref.read(navigationProvider.notifier).selectPage(p),
              ),
            )
            .toList(),
      );
    }
    return ListView(
      key: const ValueKey('content_list'),
      children: nav.selectedPage!.finalTopics
          .map(
            (f) => Card(
              child: ExpansionTile(
                title: Text(f.name),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(f.jsonFilePath),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBreadcrumbs(NavigationState nav) {
    List<String> labels = [];
    if (nav.selectedBook != null) labels.add(nav.selectedBook!.name);
    if (nav.selectedUnit != null) labels.add(nav.selectedUnit!.name);
    if (nav.selectedTopic != null) labels.add(nav.selectedTopic!.name);

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[200],
      child: Row(
        children: labels.map((label) {
          bool isLast = labels.last == label;
          return Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (!isLast) const Icon(Icons.chevron_left, size: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}
*/

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

    // گوش دادن به تغییرات محتوا برای بازیابی وضعیت قبلی
    ref.listen(allContentProvider, (previous, next) {
      next.whenData((books) {
        if (books.isNotEmpty && nav.selectedBook == null) {
          // استفاده از Future.microtask برای جلوگیری از تداخل در ساخت ویجت
          Future.microtask(() {
            ref.read(navigationProvider.notifier).restoreLastState(books);
          });
        }
      });
    });
    ref.listen(navigationProvider, (previous, next) {
      if (next.selectedTopic != null && previous?.selectedTopic == null) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => const TopicDetailScreen(),
              ),
            )
            .then((_) {
              // ref.read(navigationProvider.notifier).goBack();
            });
      }
    });

    return PopScope(
      canPop: nav.selectedBook == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navigationProvider.notifier).goBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('دستیار آیلتس')),
        drawer: null, //const MainDrawer(),
        body: Column(
          children: [
            _buildBreadcrumbs(nav, allContent),
            Expanded(child: _buildMainContent(nav, allContent)),
            const MiniAudioPlayer(),
          ],
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
    if (nav.selectedFinalTopic != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              nav.selectedFinalTopic!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('در حال پخش فایل صوتی...'),
          ],
        ),
      );
    }

    // ۱. نمایش محتوای نهایی (Topic)
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

    // ۱. نمایش محتوای نهایی (Topic)
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
        onTap: (index) => ref
            .read(navigationProvider.notifier)
            .selectUnit(nav.selectedBook!.units[index]),
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
}
