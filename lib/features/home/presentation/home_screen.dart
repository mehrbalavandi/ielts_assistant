import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio_player/mini_audio_player.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/shared/main_drawer.dart';

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
          _buildBreadcrumbs(nav, ref),
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
                    child: Text(f.englishText),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBreadcrumbs(NavigationState nav, WidgetRef ref) {
    // پیاده‌سازی ساده لیست افقی از نام کتاب > واحد > موضوع
    return Container(height: 40, color: Colors.grey[200]);
  }
}
