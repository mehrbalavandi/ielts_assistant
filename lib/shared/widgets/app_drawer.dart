import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/settings/presentation/settings_screen.dart';
import 'package:ielts_assistant/features/study/presentation/study_review_screen.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/shop/presentation/my_orders_screen.dart';
import 'package:ielts_assistant/features/settings/providers/language_provider.dart';
import 'package:ielts_assistant/features/update/app_update_provider.dart';
import 'package:ielts_assistant/features/update/app_update_ui.dart';
// مسیر را تنظیم کنید

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final update = ref.watch(appUpdateProvider);

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

          // 🌟 ST-5: «مرورِ من» برای همه‌ی کتاب‌ها (رفتن به متن فقط از داخلِ خودِ کتاب).
          ListTile(
            leading: const Icon(Icons.bookmarks_rounded),
            title: const Text("مرورِ من"),
            subtitle: const Text(
              "واژه‌ها و تمرین‌هایی که برای مرور نگه داشته‌اید",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              final NavigatorState navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const StudyReviewScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),

          // 🌟 PAY-3: وضعیتِ خریدها (به‌ویژه کارت‌به‌کارت‌های منتظرِ بررسی).
          if (ref.watch(authProvider) == AuthState.authenticated) ...[
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text("سفارش‌های من"),
              onTap: () {
                final NavigatorState navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyOrdersScreen(),
                  ),
                );
              },
            ),
            // 🌟 BK-1..3: پشتیبانِ سرور — آخرین زمان و «الان».
            Builder(
              builder: (context) {
                final BackupState b = ref.watch(backupProvider);
                final DateTime? at = b.lastSyncAt;
                final String when = at == null
                    ? 'هنوز پشتیبان‌گیری نشده'
                    : 'آخرین بار: ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} — ${at.year}/${at.month}/${at.day}';
                return ListTile(
                  leading: b.syncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          b.lastError == null
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                        ),
                  title: const Text("پشتیبان‌گیریِ الان"),
                  subtitle: Text(
                    b.lastError ?? "مرورِ من و تنظیمات روی سرور — $when",
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: b.syncing
                      ? null
                      : () => ref.read(backupProvider.notifier).syncNow(),
                );
              },
            ),
            const Divider(height: 1),
          ],

          // 🌟 U-4: به‌روزرسانیِ برنامه از سایت. با نسخه‌ی تازه: علامت و پنجره‌ی
          // دریافت؛ بدونِ آن: بررسیِ دستی و نمایشِ نسخه‌ی فعلی.
          if (AppUpdateNotifier.platformName != null) ...[
            ListTile(
              leading: Badge(
                isLabelVisible: update.updateAvailable,
                smallSize: 8,
                backgroundColor: Colors.amber,
                child: const Icon(Icons.system_update_rounded),
              ),
              title: const Text("به‌روزرسانیِ برنامه"),
              subtitle: Text(
                update.updateAvailable
                    ? "نسخه‌ی ${update.latest!.versionName} آماده‌ی دریافت است"
                    : "نسخه‌ی فعلی: ${update.currentVersion ?? '—'} — برای بررسی بزنید",
                style: TextStyle(
                  fontSize: 12,
                  color: update.updateAvailable ? Colors.amber.shade900 : null,
                  fontWeight: update.updateAvailable ? FontWeight.bold : null,
                ),
              ),
              trailing: update.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: () {
                if (update.updateAvailable) {
                  showAppUpdateDialog(context, ref);
                } else {
                  checkForAppUpdateManually(context, ref);
                }
              },
            ),
            const Divider(height: 1),
          ],

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
