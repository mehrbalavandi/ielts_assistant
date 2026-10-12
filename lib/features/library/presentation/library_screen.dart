import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/auth/presentation/login_screen.dart';
import 'package:ielts_assistant/features/reader/presentation/reader_screen.dart';
import 'package:ielts_assistant/shared/widgets/app_drawer.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  /// 🗂️ قانونِ C-2: null = ویترینِ اصلی (اگر بیش از یک دسته هست، فهرستِ دسته‌ها؛
  /// وگرنه مستقیم کتاب‌ها). غیرِ null = کتاب‌های همین دسته (شناسه یا 'other').
  final String? categoryKey;

  const LibraryScreen({super.key, this.categoryKey});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  // 🌟 فقط برای حالت دیباگ: وقتی true باشد یعنی کاربر برای خرید به مرورگر
  // بیرونی فرستاده شده و منتظریم برگردد تا ویترین را دوباره fetch کنیم.
  bool _awaitingPurchaseReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _openLastBook();
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 🌟 فقط برای حالت دیباگ: وقتی از صفحه‌ی خریدِ بیرونی برمی‌گردیم (اپ
    // resume می‌شود)، یک‌بار ویترین را رفرش می‌کنیم. با فلگ گارد شده تا
    // resumeهای معمولی (مثلاً باز کردن اپ از نو) باعث فچ اضافه نشوند.
    if (state == AppLifecycleState.resumed && _awaitingPurchaseReturn) {
      _awaitingPurchaseReturn = false;
      ref.read(booksProvider.notifier).fetchBooks();
    }
  }

  // 🌟 فقط برای حالت دیباگ: هدایت به سایتِ خرید (همان base_url ذخیره‌شده در
  // StorageService) در مرورگرِ بیرونی؛ برگشت از آن توسط didChangeAppLifecycleState
  // بالا رصد و باعثِ رفرشِ ویترین می‌شود.
  Future<void> _launchPurchasePage(BuildContext context) async {
    final baseUrl = StorageService.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("آدرس سایت (base_url) هنوز تنظیم نشده است."),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("آدرس سایت نامعتبر است: $baseUrl")),
      );
      return;
    }

    _awaitingPurchaseReturn = true;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _awaitingPurchaseReturn = false;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("امکان باز کردن $baseUrl وجود نداشت.")),
      );
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
    if (book == null) return;
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
        title: Text(
          screenTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
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
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
        ],
      ),
      // در صفحه‌ی یک دسته به‌جای منو، دکمه‌ی بازگشت.
      drawer: categoryKey == null ? const AppDrawer() : null,

      body: Column(
        children: [
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
              child: Text(
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
                      bool canOpenCanvas =
                          (book.isPurchased && book.isJsonDownloaded) ||
                          (!book.isPurchased && book.isSampleDownloaded);

                      return GestureDetector(
                        onTap: canOpenCanvas
                            ? () {
                                // 🌟 انتقال به صفحه مطالعه با ضربه روی هر جای کارت (در صورت آماده بودن فایل)
                                _openBookForReading(context, ref, book);
                              }
                            : null,
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
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade100,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_rounded,
                                        size: 50,
                                        color: Colors.blueGrey,
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
                                child: Text(
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 4.0,
                                ),
                                child: _buildActionSection(
                                  context,
                                  ref,
                                  book,
                                  authState,
                                ),
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
                        Text(
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
                          Text(
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
                Text(
                  group.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (group.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
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

  /// 🌟 تنها مسیرِ رفتن به صفحه‌ی مطالعه. علتِ یک‌کاسه‌کردنش: بعد از بازگشت
  /// باید ویترین رفرش شود (وضعیتِ دانلود/آپدیت/خرید ممکن است در حینِ مطالعه
  /// عوض شده باشد) و قبلاً چهار جای مختلف Navigator.push می‌کردند — هر
  /// کدام که یادش می‌رفت، یک مسیرِ بی‌رفرش می‌ماند.
  /// await روی push لازم است: تا وقتی صفحه‌ی مطالعه باز است این Future
  /// تمام نمی‌شود و درست در لحظه‌ی pop ادامه پیدا می‌کند.
  Future<void> _openBookForReading(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
  ) async {
    StorageService.saveLastBookId(book.id);
    ref.read(activeBookProvider.notifier).state = book;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReaderScreen()),
    );

    if (!context.mounted) return;
    await ref.read(booksProvider.notifier).fetchBooks();
  }

  /// تأییدِ حذفِ محتوای دانلودشده. اگر همین کتاب همین حالا باز باشد،
  /// activeBook هم پاک می‌شود تا صفحه‌ی مطالعه به فایل‌هایی که دیگر وجود
  /// ندارند اشاره نکند.
  Future<void> _confirmDeleteBook(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف محتوای دانلودشده'),
        content: Text(
          'محتوای دانلودشده‌ی «${book.title}» از این دستگاه پاک شود؟ '
          'خودِ کتاب در کتابخانه می‌ماند و هر زمان بخواهید دوباره قابل دانلود است.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (ref.read(activeBookProvider)?.id == book.id) {
      ref.read(activeBookProvider.notifier).state = null;
    }
    await ref.read(booksProvider.notifier).deleteDownloadedBook(book);
  }

  Widget _buildActionSection(
    BuildContext context,
    WidgetRef ref,
    BookModel book,
    AuthState authState,
  ) {
    // --- ۱. حالت در حال دانلود ---
    if (book.isDownloading) {
      // 🐞 مقدارِ سنتینلِ -1 یعنی هنوز حجمِ آرشیو معلوم نیست (سرور دارد
      // آرشیو را آماده می‌کند) — به‌جایِ نوارِ پیشرفتِ ثابت‌روی‌صفر (که از
      // «هیچ اتفاقی نمی‌افتد» قابلِ‌تشخیص نبود و باعثِ همان حسِ «مکثِ
      // عجیب، بعد پرشدنِ ناگهانی» می‌شد)، یک اسپینرِ نامعین با برچسبِ
      // روشن نشان می‌دهیم.
      if (book.downloadProgress < 0) {
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("در حال آماده‌سازی…", style: TextStyle(fontSize: 11)),
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: book.downloadProgress,
            color: Colors.indigo,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${(book.downloadProgress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 6),
              // 🌟 مکث: فایلِ نیمه‌دانلودشده نگه داشته می‌شود تا بعداً از
              // همان‌جا ادامه پیدا کند، نه از صفر.
              InkWell(
                onTap: () =>
                    ref.read(booksProvider.notifier).pauseZipDownload(book),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.pause_circle_outline, size: 20),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // --- ۱.۵ حالت مکث‌شده ---
    if (book.isPaused) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: book.downloadProgress,
            color: Colors.orange,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "متوقف شده • ${(book.downloadProgress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => ref
                    .read(booksProvider.notifier)
                    .resumeZipDownload(book, isSample: !book.isPurchased),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _confirmDeleteBook(context, ref, book),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // --- ۲. حالت کتاب خریداری شده (نسخه اصلی) ---
    if (book.isPurchased) {
      if (book.isJsonDownloaded) {
        // 🌟 تغییر از isDownloaded به isJsonDownloaded
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 14,
              ),
              // «کامل» در برابرِ «نمونه» بود، ولی وقتی کتاب خریداری شده کاربر
              // اصلاً نسخه‌ی دیگری نمی‌بیند که با آن مقایسه کند.
              label: const Text("مطالعه کتاب", style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: () => _openBookForReading(context, ref, book),
            ),
            // 🌟 حذفِ محتوای دانلودشده — برای آزادکردنِ فضای دستگاه؛ خودِ
            // کتاب در کتابخانه می‌ماند و هر وقت خواستید دوباره دانلود می‌شود.
            SizedBox(height: 1.0),
            OutlinedButton.icon(
              icon: const Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.red,
              ),
              // 🌟 عبارتِ قبلی توضیحِ عملیات بود، نه نتیجه‌اش — و در عرضِ
              // باریکِ کارت هم می‌شکست. «آزادسازی فضا» همان کار را از دیدِ
              // کاربر توصیف می‌کند و کوتاه‌تر است.
              label: const Text(
                "آزادسازی فضا",
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: () => _confirmDeleteBook(context, ref, book),
            ),
            // نمایش دکمه آپدیت فقط در صورت وجود نسخه جدید برای فایل‌های اصلی
            if (book
                .hasAnyMainUpdate) // 🌟 تغییر از hasAnyUpdate به hasAnyMainUpdate
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 1.0),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text(
                      "به‌روزرسانی محتوا",
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    onPressed: () => ref
                        .read(booksProvider.notifier)
                        .downloadBookZip(
                          book,
                          isSample: false,
                        ), // 🌟 دانلودِ یکجا به‌صورت ZIP
                  ),
                ],
              ),
          ],
        );
      }
      return ElevatedButton.icon(
        icon: const Icon(Icons.cloud_download, size: 14),
        label: const Text("دانلود کتاب", style: TextStyle(fontSize: 11)),
        onPressed: () => ref
            .read(booksProvider.notifier)
            .downloadBookZip(book, isSample: false),
      );
    }

    // --- ۳. حالت مهمان / نسخه نمونه ---
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (book.isSampleDownloaded) ...[
          // 🌟 تغییر از isDownloaded به isSampleDownloaded
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              side: const BorderSide(color: Colors.indigo),
            ),
            onPressed: () => _openBookForReading(context, ref, book),
            child: const Text(
              "مطالعه نمونه",
              style: TextStyle(fontSize: 11, color: Colors.indigo),
            ),
          ),
          // نمایش آپدیت برای نسخه نمونه
          if (book.hasAnySampleUpdate) // 🌟 تشخیص آپدیت برای فایل‌های نمونه
            OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 12),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                foregroundColor: Colors.orange,
              ),
              onPressed: () => ref
                  .read(booksProvider.notifier)
                  .downloadBookZip(book, isSample: true),
              // هم‌زبان با «به‌روزرسانی محتوا»ی نسخه‌ی اصلی
              label: const Text(
                "به‌روزرسانی نمونه",
                style: TextStyle(fontSize: 11),
              ),
            ),
        ] else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: () => ref
                .read(booksProvider.notifier)
                .downloadBookZip(book, isSample: true),
            child: const Text("دریافت نمونه", style: TextStyle(fontSize: 11)),
          ),

        const SizedBox(height: 4),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 2),
          ),
          onPressed: () {
            if (authState == AuthState.unauthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "برای خرید ابتدا باید وارد حساب کاربری خود شوید.",
                  ),
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            } else if (kDebugMode) {
              // 🌟 فقط برای حالت دیباگ: هدایت به سایتِ خرید + رفرشِ خودکارِ
              // ویترین بعدِ برگشت (بالاتر، didChangeAppLifecycleState)
              _launchPurchasePage(context);
            } else {
              _launchPurchasePage(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("در حال انتقال به صفحه خرید...")),
              );
            }
          },
          child: const Text(
            "خرید کتاب",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
