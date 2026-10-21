# تغییرات — درس در نتایجِ جستجو (S-15)، بستنِ ناوبر بعد از «رفتن به صفحه» (N-16)

فایل‌های تغییرکرده:
- `lib/features/search/presentation/book_search_delegate.dart`: درس و مهارتِ هر نتیجه
- `lib/features/reader/presentation/book_outline_navigator.dart`: `outlineLocationLabel`؛ جمع‌شدن بعد از بسته‌شدنِ دیالوگِ صفحه
- `lib/features/reader/presentation/reader_screen.dart`: کتابِ باز به جستجو داده می‌شود
- `RULES-rendering.md` (S-15، N-16)

## چه شد
- هر نتیجه‌ی جستجو حالا می‌گوید کجای کتاب است: «درس 8: Natural World · Listening — صفحه 153»؛ نتیجه‌ی
  اسکریپتِ صوتی جای اولین دکمه‌ی همان فایل را در کتاب نشان می‌دهد.
- دیالوگِ «رفتن به صفحه» با «برو»، «انصراف»، لمسِ بیرون یا برگشت که بسته شود، ناوبرِ کتاب هم بسته می‌شود.

## یادآوری دربار‌ه‌ی TR-8 (نشانه‌های {blk} در ترجمه)
اگر `{blk}` در ترجمه دیده می‌شود، برنامه‌ی در حالِ اجرا هنوز کدِ قبلی است: `_TranslationText` از
StatelessWidget به StatefulWidget تبدیل شده و صفحه‌ها کش می‌شوند، پس Hot Reload کافی نیست. برنامه را
کامل متوقف کنید و دوباره اجرا کنید (یا دست‌کم Hot Restart).
