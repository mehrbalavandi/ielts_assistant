import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio_player/presentation/widgets/mini_audio_player.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/features/home/presentation/widgets/main_drawer.dart';

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
