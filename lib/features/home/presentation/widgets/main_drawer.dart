import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/home/providers/drawer_expansion_provider.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
import 'package:ielts_assistant/features/settings/presentation/settings_screen.dart';
import '../../../../../../../shared/models/content_models.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allContentAsync = ref.watch(allContentProvider);

    return Drawer(
      child: Column(
        children: [
          // سربرگ دراور
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Center(
              child: Text(
                'ساختار دروس',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),

          // لیست درختی محتوا
          Expanded(
            child: allContentAsync.when(
              data: (books) => ListView.builder(
                itemCount: books.length,
                itemBuilder: (context, index) =>
                    _buildBookTile(books[index], ref, context),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('خطا در بارگذاری: $err')),
            ),
          ),

          // دکمه تنظیمات در پایین دراور
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('تنظیمات مسیر فایل‌ها'),
            onTap: () {
              // ۱. بستن دراور
              Navigator.pop(context);

              // ۲. رفتن به صفحه تنظیمات
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookTile(Book book, WidgetRef ref, BuildContext context) {
    final expansionState = ref.watch(drawerExpansionProvider);
    final isSelected =
        ref.watch(navigationProvider).selectedBook?.name == book.name;

    return ExpansionTile(
      // استفاده از کلید برای کنترل باز و بسته شدن از بیرون
      key: Key('book_${book.name}_${expansionState['book'] == book.name}'),
      initiallyExpanded: expansionState['book'] == book.name,
      onExpansionChanged: (expanded) {
        if (expanded)
          ref.read(drawerExpansionProvider.notifier).expandBook(book.name);
      },
      title: Text(
        book.name,
        style: TextStyle(color: isSelected ? Colors.blue : Colors.black),
      ),
      children: book.units
          .map((unit) => _buildUnitTile(unit, book, ref, context))
          .toList(),
    );
  }

  Widget _buildUnitTile(
    Unit unit,
    Book book,
    WidgetRef ref,
    BuildContext context,
  ) {
    final expansionState = ref.watch(drawerExpansionProvider);
    final nav = ref.watch(navigationProvider);
    final isUnitSelected = nav.selectedUnit?.name == unit.name;

    return ExpansionTile(
      key: Key('unit_${unit.name}_${expansionState['unit'] == unit.name}'),
      initiallyExpanded: expansionState['unit'] == unit.name,
      onExpansionChanged: (expanded) {
        if (expanded)
          ref.read(drawerExpansionProvider.notifier).expandUnit(unit.name);
      },
      title: Text(
        unit.name,
        style: TextStyle(color: isUnitSelected ? Colors.blue : Colors.black87),
      ),
      children: unit.topics.map((topic) {
        final isTopicSelected = nav.selectedTopic?.name == topic.name;
        return ListTile(
          selected: isTopicSelected,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          title: Text(topic.name),
          onTap: () {
            ref.read(navigationProvider.notifier).selectBook(book);
            ref.read(navigationProvider.notifier).selectUnit(unit);
            ref.read(navigationProvider.notifier).selectTopic(topic);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}
