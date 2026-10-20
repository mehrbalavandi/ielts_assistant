import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/library/presentation/book_actions.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🌟 N-12 (RULES-rendering.md): در نسخه‌ی نمونه همه‌ی Unitها در ناوبر هستند؛ انتخابِ Unit
// یا صفحه‌ای که در نمونه نیست به این پیام می‌رسد — «خریداری نشده» + دکمه‌ی خرید.

/// [title]: عنوانِ گره‌ی Outline (Unit/مهارت) که انتخاب شد؛ [pageNumber]: شماره‌ای که در
/// «رفتن به صفحه» وارد شد. یکی از این دو.
Future<void> showNotInSampleDialog(
  BuildContext context,
  WidgetRef ref, {
  required BookModel book,
  SampleInfo? sample,
  String? title,
  int? pageNumber,
}) async {
  final String what = title != null
      ? '«${bidiIsolate(outlineDisplayTitle(title))}»'
      : 'صفحه‌ی ${pageNumber ?? ''}';
  final String? has = sample == null
      ? null
      : (sample.title.isNotEmpty
            ? 'نسخه‌ی نمونه فقط «${bidiIsolate(outlineDisplayTitle(sample.title))}» '
                  '(صفحه‌های ${sample.firstPage} تا ${sample.lastPage}) را دارد.'
            : 'نسخه‌ی نمونه فقط صفحه‌های ${sample.firstPage} تا ${sample.lastPage} را دارد.');
  final bool purchased = book.isPurchased;

  final bool? buy = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        icon: Icon(
          Icons.lock_outline_rounded,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('این بخش خریداری نشده است'),
        content: Text(
          [
            '$what در نسخه‌ی نمونه نیست.',
            if (has != null) has,
            purchased
                ? 'این کتاب را خریده‌اید، ولی الان نسخه‌ی نمونه باز است. برای مطالعه‌ی همه‌ی '
                      'درس‌ها نسخه‌ی کامل را از کتابخانه دریافت کنید.'
                : 'برای مطالعه‌ی همه‌ی درس‌ها کتاب را خریداری کنید.',
          ].join('\n'),
          style: const TextStyle(height: 1.6),
        ),
        actions: purchased
            ? [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('باشه'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('بعداً'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  onPressed: () => Navigator.pop(ctx, true),
                  label: const Text('خرید کتاب'),
                ),
              ],
      ),
    ),
  );

  if (buy == true && context.mounted) {
    startBookPurchase(context, ref, book);
  }
}
