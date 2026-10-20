import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/license/license_service.dart';
import 'package:ielts_assistant/core/storage/storage_service.dart';
import 'package:ielts_assistant/features/auth/presentation/login_screen.dart';
import 'package:ielts_assistant/features/auth/providers/auth_provider.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/presentation/reader_screen.dart';
import 'package:ielts_assistant/features/shop/data/shop_api.dart';
import 'package:ielts_assistant/features/shop/presentation/purchase_sheet.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🌟 کارهای هر کتاب (مطالعه، دانلود، مکث، به‌روزرسانی، آزادسازیِ فضا، نمونه، خرید) — یک‌جا،
// تا کارتِ ویترین و صفحه‌ی جزئیاتِ کتاب (SF-1) دقیقاً یک رفتار داشته باشند.

/// کاربر برای پرداخت به مرورگر رفته؛ ویترین با برگشت به اپ یک‌بار تازه می‌شود
/// (LibraryScreen.didChangeAppLifecycleState).
bool purchaseReturnPending = false;

/// 🌟 تنها مسیرِ رفتن به صفحه‌ی مطالعه. علتِ یک‌کاسه‌کردنش: بعد از بازگشت
/// باید ویترین رفرش شود (وضعیتِ دانلود/آپدیت/خرید ممکن است در حینِ مطالعه
/// عوض شده باشد) و قبلاً چهار جای مختلف Navigator.push می‌کردند — هر
/// کدام که یادش می‌رفت، یک مسیرِ بی‌رفرش می‌ماند.
/// await روی push لازم است: تا وقتی صفحه‌ی مطالعه باز است این Future
/// تمام نمی‌شود و درست در لحظه‌ی pop ادامه پیدا می‌کند.
Future<void> openBookForReading(
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

/// 🌟 شروعِ خریدِ یک کتاب — تنها مسیر، تا دکمه‌ی «خرید کتاب»ِ ویترین و پیامِ «خریداری نشده»ِ
/// نسخه‌ی نمونه (N-10) یک رفتار داشته باشند: کاربرِ واردنشده به صفحه‌ی ورود می‌رود؛ بقیه
/// پنجره‌ی خرید (PAY-2/3: درگاه در مرورگر یا کارت‌به‌کارت) را می‌بینند. با برگشت از مرورگر
/// ویترین تازه می‌شود (didChangeAppLifecycleState).
void startBookPurchase(BuildContext context, WidgetRef ref, BookModel book) {
  if (ref.read(authProvider) == AuthState.unauthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("برای خرید ابتدا باید وارد حساب کاربری خود شوید."),
      ),
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    return;
  }
  showPurchaseSheet(
    context,
    ref,
    book,
    onLeftForPayment: () => purchaseReturnPending = true,
  );
}

/// تأییدِ حذفِ محتوای دانلودشده. اگر همین کتاب همین حالا باز باشد،
/// activeBook هم پاک می‌شود تا صفحه‌ی مطالعه به فایل‌هایی که دیگر وجود
/// ندارند اشاره نکند.
Future<void> confirmDeleteBook(
  BuildContext context,
  WidgetRef ref,
  BookModel book,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف محتوای دانلودشده'),
      content: Text(
        'محتوای دانلودشده‌ی «${bidiIsolate(book.title)}» از این دستگاه پاک شود؟ '
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


/// دکمه‌های وضعیتِ یک کتاب. [fontSize] برای کارتِ کوچکِ ویترین ۱۱ و برای صفحه‌ی جزئیات بزرگ‌تر.
class BookActionSection extends ConsumerWidget {
  const BookActionSection({super.key, required this.book, this.fontSize = 11});

  final BookModel book;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider); // با ورود/خروج دکمه‌ها از نو ساخته شوند
    final double fs = fontSize;
    // --- ۱. حالت در حال دانلود ---
    if (book.isDownloading) {
      // 🐞 مقدارِ سنتینلِ -1 یعنی هنوز حجمِ آرشیو معلوم نیست (سرور دارد
      // آرشیو را آماده می‌کند) — به‌جایِ نوارِ پیشرفتِ ثابت‌روی‌صفر (که از
      // «هیچ اتفاقی نمی‌افتد» قابلِ‌تشخیص نبود و باعثِ همان حسِ «مکثِ
      // عجیب، بعد پرشدنِ ناگهانی» می‌شد)، یک اسپینرِ نامعین با برچسبِ
      // روشن نشان می‌دهیم.
      if (book.downloadProgress < 0) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("در حال آماده‌سازی…", style: TextStyle(fontSize: fs)),
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
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${(book.downloadProgress * 100).toStringAsFixed(0)}%",
                style: TextStyle(fontSize: fs),
              ),
              SizedBox(width: 6),
              // 🌟 مکث: فایلِ نیمه‌دانلودشده نگه داشته می‌شود تا بعداً از
              // همان‌جا ادامه پیدا کند، نه از صفر.
              InkWell(
                onTap: () =>
                    ref.read(booksProvider.notifier).pauseZipDownload(book),
                child: Padding(
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
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "متوقف شده • ${(book.downloadProgress * 100).toStringAsFixed(0)}%",
                style: TextStyle(fontSize: fs),
              ),
              SizedBox(width: 6),
              InkWell(
                onTap: () => ref
                    .read(booksProvider.notifier)
                    .resumeZipDownload(book, isSample: !book.isPurchased),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
              ),
              InkWell(
                onTap: () => confirmDeleteBook(context, ref, book),
                child: Padding(
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
      // 🌟 DEV-4: دانلود شده ولی مجوزِ آفلاینِ این دستگاه الان معتبر نیست.
      if (book.mainLocked) {
        return _LicenseLocked(book: book, fontSize: fs);
      }
      if (book.isJsonDownloaded) {
        // 🌟 تغییر از isDownloaded به isJsonDownloaded
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 14,
              ),
              // «کامل» در برابرِ «نمونه» بود، ولی وقتی کتاب خریداری شده کاربر
              // اصلاً نسخه‌ی دیگری نمی‌بیند که با آن مقایسه کند.
              label: Text("مطالعه کتاب", style: TextStyle(fontSize: fs)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: () => openBookForReading(context, ref, book),
            ),
            // 🌟 حذفِ محتوای دانلودشده — برای آزادکردنِ فضای دستگاه؛ خودِ
            // کتاب در کتابخانه می‌ماند و هر وقت خواستید دوباره دانلود می‌شود.
            SizedBox(height: 1.0),
            OutlinedButton.icon(
              icon: Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.red,
              ),
              // 🌟 عبارتِ قبلی توضیحِ عملیات بود، نه نتیجه‌اش — و در عرضِ
              // باریکِ کارت هم می‌شکست. «آزادسازی فضا» همان کار را از دیدِ
              // کاربر توصیف می‌کند و کوتاه‌تر است.
              label: Text(
                "آزادسازی فضا",
                style: TextStyle(fontSize: fs, color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 2),
              ),
              onPressed: () => confirmDeleteBook(context, ref, book),
            ),
            // نمایش دکمه آپدیت فقط در صورت وجود نسخه جدید برای فایل‌های اصلی
            if (book
                .hasAnyMainUpdate) // 🌟 تغییر از hasAnyUpdate به hasAnyMainUpdate
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 1.0),
                  ElevatedButton.icon(
                    icon: Icon(Icons.sync, size: 14),
                    label: Text(
                      "به‌روزرسانی محتوا",
                      style: TextStyle(fontSize: fs),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade900,
                      padding: EdgeInsets.symmetric(horizontal: 2),
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
        icon: Icon(Icons.cloud_download, size: 14),
        label: Text("دانلود کتاب", style: TextStyle(fontSize: fs)),
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
              padding: EdgeInsets.symmetric(horizontal: 2),
              side: BorderSide(color: Colors.indigo),
            ),
            onPressed: () => openBookForReading(context, ref, book),
            child: Text(
              "مطالعه نمونه",
              style: TextStyle(fontSize: fs, color: Colors.indigo),
            ),
          ),
          // نمایش آپدیت برای نسخه نمونه
          if (book.hasAnySampleUpdate) // 🌟 تشخیص آپدیت برای فایل‌های نمونه
            OutlinedButton.icon(
              icon: Icon(Icons.sync, size: 12),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 2),
                foregroundColor: Colors.orange,
              ),
              onPressed: () => ref
                  .read(booksProvider.notifier)
                  .downloadBookZip(book, isSample: true),
              // هم‌زبان با «به‌روزرسانی محتوا»ی نسخه‌ی اصلی
              label: Text(
                "به‌روزرسانی نمونه",
                style: TextStyle(fontSize: fs),
              ),
            ),
        ] else
          // 🛍️ SF-1: فقط وقتی نمونه واقعاً روی سرور هست (has_sample).
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: book.hasSample
                ? () => ref
                      .read(booksProvider.notifier)
                      .downloadBookZip(book, isSample: true)
                : null,
            child: Text(
              book.hasSample ? "دریافت نمونه" : "نمونه ندارد",
              style: TextStyle(fontSize: fs),
            ),
          ),

        SizedBox(height: 4),

        // 🛍️ SF-4: کتابی که هنوز محتوای اصلی ندارد خریدنی نیست.
        if (book.hasContent)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: () => startBookPurchase(context, ref, book),
            child: Text(
              "خرید کتاب",
              style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold),
            ),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 2),
            ),
            onPressed: null,
            icon: Icon(Icons.hourglass_top_rounded, size: fs + 2),
            label: Text(
              "در حالِ آماده‌سازی",
              style: TextStyle(fontSize: fs),
            ),
          ),
      ],
    );
  }
}

/// 🛍️ SF-1: جلدِ کتاب از فایلِ ذخیره‌شده روی دستگاه (آفلاین)؛ تا وقتی جلد نرسیده یا
/// کتاب جلد ندارد، همان طرحِ ساده‌ی قبلی.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.borderRadius, this.iconSize = 50});

  final BookModel book;
  final BorderRadius? borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      color: Colors.blueGrey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded, size: iconSize, color: Colors.blueGrey),
    );
    final Widget image = book.hasLocalCover
        ? Image.file(
            File(book.localCoverPath!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : placeholder;
    return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: image);
  }
}

/// قیمت برای کارت و صفحه‌ی جزئیات: «رایگان»، یا قیمتِ نهایی (و قیمتِ قبل از تخفیف).
class BookPrice extends StatelessWidget {
  const BookPrice({super.key, required this.book, this.large = false});

  final BookModel book;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (book.isPurchased) return const SizedBox.shrink();
    final double fs = large ? 18 : 12;
    if (book.isFree) {
      return Text(
        'رایگان',
        style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.green.shade700),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        if (book.hasDiscount)
          Text(
            formatToman(book.price),
            style: TextStyle(
              fontSize: fs - 2,
              color: Colors.grey.shade600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          formatToman(book.finalPrice),
          style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
        ),
        if (book.hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${book.discount}٪',
              style: TextStyle(fontSize: fs - 3, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

/// 🌟 DEV-4: کتابِ خریده‌شده‌ای که روی دستگاه هست ولی مجوزِ آفلاینِ این دستگاه معتبر نیست
/// (مدتی آفلاین بوده، ساعت عقب است، یا از حساب خارج شده). «بررسیِ دوباره» ویترین را
/// رفرش می‌کند که مجوز را هم تمدید می‌کند.
class _LicenseLocked extends ConsumerStatefulWidget {
  const _LicenseLocked({required this.book, required this.fontSize});

  final BookModel book;
  final double fontSize;

  @override
  ConsumerState<_LicenseLocked> createState() => _LicenseLockedState();
}

class _LicenseLockedState extends ConsumerState<_LicenseLocked> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await ref.read(booksProvider.notifier).fetchBooks();
    if (!mounted) return;
    setState(() => _busy = false);
    final LicenseStatus st = LicenseService.status(widget.book.id);
    if (st != LicenseStatus.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LicenseService.message(st))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fs = widget.fontSize;
    final bool loggedOut = ref.watch(authProvider) != AuthState.authenticated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: LicenseService.message(widget.book.licenseStatus),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_clock_outlined, size: fs + 3, color: Colors.orange.shade800),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'نیاز به تمدیدِ مجوز',
                  style: TextStyle(fontSize: fs, color: Colors.orange.shade900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        if (loggedOut)
          ElevatedButton.icon(
            icon: Icon(Icons.login, size: fs + 3),
            label: Text('ورود', style: TextStyle(fontSize: fs)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          )
        else
          ElevatedButton.icon(
            icon: _busy
                ? SizedBox(
                    width: fs,
                    height: fs,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.sync, size: fs + 3),
            label: Text('بررسیِ دوباره', style: TextStyle(fontSize: fs)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 2)),
            onPressed: _busy ? null : _retry,
          ),
      ],
    );
  }
}
