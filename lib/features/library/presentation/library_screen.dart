import 'package:flutter/material.dart';
import 'package:ielts_assistant/app/app_messenger.dart';
import 'package:ielts_assistant/core/license/license_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/app_config/app_config.dart';
import 'package:ielts_assistant/shared/widgets/app_notice_banner.dart';
import 'package:ielts_assistant/features/auth/presentation/login_screen.dart';
import 'package:ielts_assistant/features/backup/backup_service.dart';
import 'package:ielts_assistant/features/library/presentation/book_actions.dart';
import 'package:ielts_assistant/features/library/presentation/book_details_screen.dart';
import 'package:ielts_assistant/features/reader/presentation/reader_screen.dart';
import 'package:ielts_assistant/shared/widgets/app_drawer.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/update/app_update_provider.dart';
import 'package:ielts_assistant/features/update/app_update_ui.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  /// 🗂️ قانونِ C-2: null = ویترینِ اصلی (اگر بیش از یک دسته هست، فهرستِ دسته‌ها؛
  /// وگرنه مستقیم کتاب‌ها). غیرِ null = کتاب‌های همین دسته (شناسه یا 'other').
  final String? categoryKey;

  const LibraryScreen({super.key, this.categoryKey});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver, RouteAware {
  // 🌟 فقط برای حالت دیباگ: وقتی true باشد یعنی کاربر برای خرید به مرورگر
  // بیرونی فرستاده شده و منتظریم برگردد تا ویترین را دوباره fetch کنیم.
  // (پرچمش حالا purchaseReturnPending در book_actions.dart است تا صفحه‌ی جزئیات هم آن را بگذارد.)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🌟 U-1: یک‌بار در هر اجرا (فقط ویترینِ اصلی، نه صفحه‌ی هر دسته) نسخه‌ی تازه‌ی
    // اپ روی سایت بررسی می‌شود.
    if (widget.categoryKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) checkForAppUpdateOnStart(context, ref);
        // 🌟 BK-1..3: با هر بازشدنِ اپ — ثبتِ دستگاه و پشتیبانِ «مرورِ من»/تنظیمات.
        if (mounted) ref.read(backupProvider.notifier).onAppStart();
        // 🌟 SITE-3/4/7: اطلاعیه، حالتِ تعمیر و روش‌های ورود از پنلِ سایت
        if (mounted) ref.read(appConfigProvider.notifier).refresh();
      });
    }

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _openLastBook();
    // });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  /// 🌟 C-6: از هر صفحه‌ای (مطالعه، جزئیات، تنظیمات، ورود، خرید، …) که به ویترین برگردیم،
  /// فهرستِ کتاب‌ها یک‌بار دیگر از سرور گرفته می‌شود.
  @override
  void didPopNext() {
    ref.read(booksProvider.notifier).fetchBooks();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 🌟 فقط برای حالت دیباگ: وقتی از صفحه‌ی خریدِ بیرونی برمی‌گردیم (اپ
    // resume می‌شود)، یک‌بار ویترین را رفرش می‌کنیم. با فلگ گارد شده تا
    // resumeهای معمولی (مثلاً باز کردن اپ از نو) باعث فچ اضافه نشوند.
    if (state == AppLifecycleState.resumed && purchaseReturnPending) {
      purchaseReturnPending = false;
      ref.read(booksProvider.notifier).fetchBooks();
    }
  }

  Future<void> _openLastBook() async {
    final lastBookId = StorageService.getLastBookId();
    if (lastBookId == null) return;
    // کمی صبر می‌کنیم تا fetchBooks انجام شود
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final books = ref.read(booksProvider);
    final book = books.where((e) => e.id == lastBookId).firstOrNull;
    // 🌟 DEV-4: کتابی که الان باز نمی‌شود (مثلاً مجوزِ آفلاینش تمام شده) خودکار باز نشود.
    if (book == null || !book.canOpenReader) return;
    ref.read(activeBookProvider.notifier).state = book;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReaderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allBooks = ref.watch(booksProvider);
    final authState = ref.watch(authProvider);

    // 🗂️ C-2: دسته‌ها (به ترتیبِ شماره‌ی ردیفِ دسته) و کتاب‌های هر دسته (به ترتیبِ
    // شماره‌ی ردیفِ کتاب). با فقط یک دسته (یا سرورِ قدیمیِ بی‌دسته) لایه‌ی دسته
    // اصلاً نشان داده نمی‌شود — یک لمسِ بی‌فایده کمتر.
    final groups = groupBooksForCatalog(allBooks);
    final String? categoryKey = widget.categoryKey;
    final BookCategoryGroup? openGroup = categoryKey == null
        ? null
        : groups.where((g) => g.key == categoryKey).firstOrNull;
    final bool showCategories = categoryKey == null && groups.length > 1;
    final List<BookModel> books = categoryKey != null
        ? (openGroup?.books ?? const [])
        : (groups.length == 1 ? groups.first.books : allBooks);
    final BookCategoryGroup? singleGroup =
        (categoryKey == null &&
            groups.length == 1 &&
            groups.first.key != 'other')
        ? groups.first
        : null;
    final String screenTitle = categoryKey == null
        ? "ویترین کتاب‌ها"
        : (openGroup?.title ?? "کتاب‌ها");
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = switch (width) {
      < 300 => 1,
      < 600 => 2,
      < 900 => 3,
      < 1200 => 4,
      _ => 5,
    };
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: AutoDirectionText(
          screenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 🌟 U-4: تا وقتی نسخه‌ی تازه‌ای روی سایت هست، این دکمه دیده می‌شود.
          if (ref.watch(
            appUpdateProvider.select((s) => s.updateAvailable),
          ))
            IconButton(
              tooltip: "نسخه‌ی جدیدِ برنامه",
              onPressed: () => showAppUpdateDialog(context, ref),
              icon: Badge(
                smallSize: 8,
                backgroundColor: Colors.amber,
                child: const Icon(Icons.system_update_rounded),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(booksProvider.notifier).fetchBooks(),
          ),
          if (authState == AuthState.unauthenticated)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: "ورود / ثبت‌نام",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "خروج از حساب",
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                // 🌟 AUTH-2: پیش از خروج تأیید (همراهِ آنچه بعد از خروج می‌ماند).
                if (!await confirmSignOut(context)) return;
                if (!context.mounted) return;
                await ref.read(authProvider.notifier).logout();
                // 🌟 DEV-7: کتاب‌های خریده‌شده‌ی دانلودشده تا مهلتِ بعد از خروج باز می‌مانند.
                final DateTime? until = LicenseService.signedOutUntil;
                if (until != null && DateTime.now().isBefore(until)) {
                  final int days = (until.difference(DateTime.now()).inHours / 24)
                      .ceil();
                  messenger.showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 6),
                      content: Text(
                        'از حساب خارج شدید. کتاب‌های خریداری‌شده‌ای که دانلود کرده‌اید تا $days '
                        'روزِ دیگر روی همین دستگاه باز می‌شوند؛ برای ادامه دوباره وارد شوید.',
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      // در صفحه‌ی یک دسته به‌جای منو، دکمه‌ی بازگشت.
      drawer: categoryKey == null ? const AppDrawer() : null,

      body: Column(
        children: [
          // 🌟 SITE-3/4: حالتِ تعمیر یا اطلاعیه‌ی ادمین
          if (categoryKey == null) const AppNoticeBanner(),
          // 🌟 نوار هشدار وضعیت مهمان / آفلاین
          if (authState == AuthState.unauthenticated)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepOrange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "شما در حالت مهمان/آفلاین هستید. برای بروزرسانی لیست و دسترسی به کتاب‌های خریداری شده، وارد حساب خود شوید.",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 🗂️ C-3: با فقط یک دسته، لایه‌ی دسته‌ها نشان داده نمی‌شود ولی نامِ همان
          // دسته (و توضیحش) بالای کتاب‌ها می‌آید تا دسته‌بندی دیده شود.
          if (singleGroup != null)
            _buildCategoryHeader(context, singleGroup)
          else if (openGroup?.description?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: AutoDirectionText(
                openGroup!.description!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),

          Expanded(
            child: allBooks.isEmpty
                ? const Center(
                    child: Text("درحال همگام‌سازی یا لیست خالی است..."),
                  )
                : showCategories
                ? _buildCategoryList(context, groups)
                : books.isEmpty
                ? const Center(child: Text("این دسته فعلاً کتابی ندارد."))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];

                      // 🌟 بررسی اینکه آیا کاربر اصلاً شرایط رفتن به بوم نقاشی را دارد یا خیر
                      // 🌟 DEV-4: نسخه‌ی کامل فقط با مجوزِ معتبرِ این دستگاه (BookModel.canOpenReader).
                      bool canOpenCanvas = book.canOpenReader;

                      return GestureDetector(
                        // 🌟 کتابِ آماده ← مطالعه؛ وگرنه ← صفحه‌ی جزئیات (SF-1)، تا کاربر
                        // پیش از دانلودِ نمونه یا خرید کتاب را بشناسد.
                        onTap: canOpenCanvas
                            ? () => openBookForReading(context, ref, book)
                            : () => _openDetails(context, book),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 🛍️ SF-1: جلد از فایلِ ذخیره‌شده روی دستگاه (آفلاین)
                                    BookCover(
                                      book: book,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    // 🛍️ جزئیاتِ کتاب، حتی وقتی لمسِ کارت کتاب را باز می‌کند
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Material(
                                        color: Colors.black38,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _openDetails(context, book),
                                          child: const Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Icon(
                                              Icons.info_outline_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (book.isPurchased)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            "خریداری شده",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: AutoDirectionText(
                                  book.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!book.isPurchased)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: BookPrice(book: book),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 4.0,
                                ),
                                child: BookActionSection(book: book),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 🗂️ C-2: فهرستِ دسته‌ها. هر کارت: عنوان، توضیح، تعدادِ کتاب‌ها و (اگر هست)
  /// تعدادِ کتاب‌های خریده‌شده؛ لمس ← صفحه‌ی همان دسته.
  Widget _buildCategoryList(
    BuildContext context,
    List<BookCategoryGroup> groups,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        final int purchased = group.books.where((b) => b.isPurchased).length;
        return Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LibraryScreen(categoryKey: group.key),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.collections_bookmark_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoDirectionText(
                          group.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group.description?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 4),
                          AutoDirectionText(
                            group.description!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _countChip(
                              context,
                              "${group.books.length} کتاب",
                              scheme.primary,
                            ),
                            if (purchased > 0)
                              _countChip(
                                context,
                                "$purchased خریداری‌شده",
                                Colors.green.shade700,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🗂️ C-3: سربرگِ دسته وقتی فقط یک دسته هست.
  Widget _buildCategoryHeader(BuildContext context, BookCategoryGroup group) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.collections_bookmark_rounded,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoDirectionText(
                  group.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (group.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  AutoDirectionText(
                    group.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _countChip(context, "${group.books.length} کتاب", scheme.primary),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailsScreen(bookId: book.id)),
    );
  }

  Widget _countChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 🌟 AUTH-2: «خروج از حساب» تأیید می‌خواهد. پنجره می‌گوید با چه حسابی واردید و بعد از خروج چه
/// می‌ماند: کتاب‌های خریداری‌شده‌ی دانلودشده تا مهلتِ مجوز (DEV-7) و «مرورِ من» روی همین دستگاه.
Future<bool> confirmSignOut(BuildContext context) async {
  final Map<String, dynamic>? user = StorageService.getUser();
  final Object? fullName =
      user?['name'] ??
      [user?['first_name'], user?['last_name']]
          .whereType<Object>()
          .join(' ')
          .trim();
  final String who = [
    fullName,
    user?['mobile'] ?? user?['email'],
  ].whereType<Object>().map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(' — ');
  final int grace = LicenseService.current?.signedOutGraceDays ?? 0;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('خروج از حساب'),
      content: Text(
        [
          who.isEmpty
              ? 'از حساب خارج می‌شوید؟'
              : 'از حسابِ ${bidiIsolate(who)} خارج می‌شوید؟',
          if (grace > 0)
            'کتاب‌های خریداری‌شده‌ای که دانلود کرده‌اید تا $grace روزِ دیگر روی همین دستگاه باز می‌مانند؛ '
                'بعد از آن برای مطالعه باید دوباره وارد شوید.'
          else
            'کتاب‌های خریداری‌شده تا ورودِ دوباره به‌طورِ کامل باز نمی‌شوند.',
          '«مرورِ من» و تنظیمات روی همین دستگاه می‌مانند.',
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('خروج'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
