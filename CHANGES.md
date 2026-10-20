# تغییرات — بسته شدنِ ناوبر بعد از انتخابِ مهارت (N-15)

فایل‌های تغییرکرده:
- `lib/features/reader/presentation/book_outline_navigator.dart`: دکمه‌ی مهارت بعد از پرش `_setCollapsed(true)`
- `RULES-rendering.md` (N-15)

## چه شد
- لمسِ یک مهارت (Reading، Writing، Listening، Speaking) در ناوبرِ کتاب، بعد از پرش به آن بخش، ناوبر را
  می‌بندد.
- انتخابِ یک Unit از منوی بالای ناوبر (که به Readingِ همان Unit می‌پرد) ناوبر را باز نگه می‌دارد تا
  بشود بلافاصله مهارتِ دیگری را انتخاب کرد.
