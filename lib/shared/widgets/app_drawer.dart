import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/settings/presentation/settings_screen.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
// مسیر را تنظیم کنید

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo,
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            child: const Column(
              children: [
                Icon(Icons.library_books, size: 60, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  "IELTS Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 🌟 تعویضِ زبانِ محتوا (فارسی ↔ عربی). قبلاً یک IconButton در
          // AppBarِ صفحه‌ی مطالعه بود با آیکونِ تک‌حرفیِ «ع/ف» — که هم جای
          // دائمی در نوارِ بالا می‌گرفت و هم معنایش معلوم نبود. این‌جا
          // subtitle صریحاً می‌گوید الان روی چه زبانی هستیم و زدنِ آن چه
          // می‌کند.
          //
          // عمداً بعد از toggle دراور را نمی‌بندیم: subtitle بلافاصله
          // به‌روز می‌شود و کاربر نتیجه‌ی کارش را همان‌جا می‌بیند.
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text("زبان محتوا"),
            subtitle: Text(
              lang == 'fa'
                  ? "فارسی — برای تغییر به عربی بزنید"
                  : "عربی — برای تغییر به فارسی بزنید",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.swap_horiz),
            onTap: () => ref.read(languageProvider.notifier).toggle(),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("تنظیمات"),
            onTap: () {
              Navigator.pop(context); // بستن دراور
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          // 🌟 دکمه مخفی که فقط در حالت Debug نمایش داده می‌شود
          if (kDebugMode) ...[
            const Divider(color: Colors.redAccent),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن متن اصلی (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref.read(booksProvider.notifier).resetOfflinelocalJsonVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ورژن متن اصلی روی ۰ تنظیم شد!'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن فایل‌های صوتی (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref
                    .read(booksProvider.notifier)
                    .resetOfflinelocalAudioVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('ورژن فایل‌های صوتی روی ۰ تنظیم شد!'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن فایل‌های تصویری (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref
                    .read(booksProvider.notifier)
                    .resetOfflinelocalImagesVersion();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'ورژن فایل‌های تصویری روی ۰ تنظیم شد!',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8.0),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.redAccent),
              title: const Text(
                'ریست ورژن محتواها (دیباگ)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                ref.read(booksProvider.notifier).resetOfflineVersions();

                // بستن منوی کشویی
                if (context.mounted) {
                  Navigator.pop(context);

                  // نمایش اسنک‌بار موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'ورژن فایل‌های اصلی و دمو روی ۰ تنظیم شد!',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
