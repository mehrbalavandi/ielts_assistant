import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/features/home/providers/navigation_provider.dart';
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
              // هدایت به صفحه تنظیمات
              Navigator.pop(context);
              // Navigator.push...
            },
          ),
        ],
      ),
    );
  }

  // ایجاد شاخه کتاب (Book)
  Widget _buildBookTile(Book book, WidgetRef ref, BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.menu_book),
      title: Text(
        book.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: book.units
          .map((unit) => _buildUnitTile(unit, book, ref, context))
          .toList(),
    );
  }

  // ایجاد شاخه واحد (Unit)
  Widget _buildUnitTile(
    Unit unit,
    Book book,
    WidgetRef ref,
    BuildContext context,
  ) {
    return ExpansionTile(
      title: Text(unit.name),
      children: unit.topics
          .map(
            (topic) => ListTile(
              contentPadding: const EdgeInsets.only(right: 32, left: 16),
              leading: const Icon(Icons.topic, size: 20),
              title: Text(topic.name, style: const TextStyle(fontSize: 13)),
              onTap: () {
                // آپدیت وضعیت ناوبری و بستن دراور
                final nav = ref.read(navigationProvider.notifier);
                nav.selectBook(book);
                nav.selectUnit(unit);
                nav.selectTopic(topic);
                Navigator.pop(context);
              },
            ),
          )
          .toList(),
    );
  }
}
