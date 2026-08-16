# معماری ielts_assistant (اپِ فلاتر)

> برای وقتی که مدتی از پروژه دور بوده‌اید. وضعیت مخزن: کامیت `e257278`،
> ۲۳ فایلِ دارت، ساختارِ بازچینش‌شده‌ی ۲۰۲۶-۰۸.

## این اپ چه‌کار می‌کند

کتاب‌های آیلتس را از سرور می‌گیرد و JSONِ تولیدشده توسط استخراج‌کننده‌ی
سی‌شارپ را با وفاداری به سندِ ورد رندر می‌کند: متنِ قالب‌بندی‌شده، جدول،
عکس، جای‌خالی‌های قابلِ‌فاش‌شدن، دیکشنریِ درون‌متنی، جستجو، و پخشِ صوت با
هایلایتِ کلمه‌به‌کلمه.

**اصلِ حاکم:** اپ تصمیمِ ظاهری نمی‌گیرد؛ فقط داده‌ی JSON را اجرا می‌کند.
اگر چیزی غلط دیده می‌شود، اول JSON را نگاه کنید.

## نقشه‌ی پوشه‌ها

```
lib/
  main.dart                    فقط bootstrap (GetStorage + runApp)
  app/app.dart                 ویجتِ ریشه: تم، زبان‌ها، صفحه‌ی شروع
  core/                        بی‌طرف نسبت به فیچرها، بدونِ وابستگی به UI
    network/dio_provider.dart      نمونه‌ی Dio + baseURL
    storage/storage_service.dart   GetStorage: توکن، آدرس سرور، آخرین کتاب
    text/document_text_utils.dart  استخراج و نرمال‌سازیِ متن + TextSearchMapper
  features/
    auth/       ورود
    library/    ویترین + مدلِ کتاب + دانلود/حذف
    reader/     صفحه‌ی مطالعه (بزرگ‌ترین بخش)
    audio/      پخش‌کننده و شیت‌ها
    search/     موتورِ جستجو + دلیگیتِ UI
    settings/   تنظیمات + زبانِ محتوا
  shared/widgets/app_drawer.dart
```

قاعده‌ی تصمیم برای فایلِ جدید: متعلق به یک فیچر ⇒ `features/<name>/`؛
مشترک و بی‌وابستگی به UI ⇒ `core/`؛ ویجتِ مشترکِ بی‌دامنه ⇒ `shared/widgets/`.

---

## هسته‌ها به‌ترتیبِ اهمیت

### `reader/data/paged_book_store.dart` (582)
**مرکزِ ثقلِ داده‌ی مطالعه.** یک کتابِ بازشده را نمایندگی می‌کند.

- `ensureManifestLoaded()` — `index.json` را می‌خواند و نگاشت‌ها را می‌سازد.
  اگر شکلِ فایل قدیمی بود، به `DocumentLoader` فالبک می‌کند.
- `getPage(index)` / `peekPage` / `prewarmAround` — بارگذاریِ تنبل با کش و
  eviction. صفحات هیچ‌وقت یک‌جا در حافظه نیستند.
- `_DecodeWorker` — **یک** آیزولتِ ماندگار برای `jsonDecode`. تلهٔ مهم:
  `Isolate.run`/`compute` به‌ازای هر فراخوانی یک آیزولت می‌سازد و می‌بندد
  (ده‌ها میلی‌ثانیه) — هرگز داخلِ حلقه استفاده نشود.
- نگاشت‌های شماره‌ی صفحه: `indexForPageNumber` / `pageNumberForIndex` /
  `firstPageNumber` / `lastPageNumber`. **شماره‌ی صفحه ≠ ایندکسِ لیست**،
  چون استخراج‌کننده می‌تواند از هر عددی شروع کند.
- `audioLinksIndex` — منبعِ حقیقت برای «هر فایلِ صوتی اولین بار کجای متن
  ظاهر می‌شود».

### `reader/presentation/reading_canvas.dart` (3993)
**بزرگ‌ترین فایلِ پروژه.** چهار چیزِ مستقل داخلش است:

1. `ReadingCanvas` / `_ReadingCanvasState` — لیستِ صفحات
   (`ScrollablePositionedList`)، ناوبریِ جستجو، نشانِ شماره‌ی صفحه، زوم.
2. `_LazyPage` — placeholder تا وقتی `getPage()` برگردد.
3. `_buildParagraph` — تبدیلِ یک `ParagraphData` به ویجت: هم‌ترازی، تورفتگی،
   شماره‌ی لیست، عکس، و ارسالِ متن به موتورِ رندر.
4. `_buildTable` + `_HScrollBox` (~۱۹۰۰ خط) — کلِ رندرِ جدول.

**نکته‌ی حیاتیِ `_buildTable`:** دو شاخه‌ی رندرِ کاملاً جدا دارد — مسیرِ
«استکی/باریک» و مسیرِ `Table`/عریض. **اصلاح روی یکی به دیگری نمی‌رسد**، و
یک باگ ممکن است فقط به این دلیل «حل‌نشده» به‌نظر برسد که تست در آن‌طرفِ
شکستِ ۶۰۰px انجام شده.

زوم: `InteractiveViewer` با `scaleFactor: 1e9` (خنثی‌کردنِ زومِ چرخِ ماوس)
به‌علاوه‌ی `_zoomBy` دستی برای Ctrl+چرخ، Ctrl +/−/0 و دکمه‌های دسکتاپ.

### `reader/presentation/rendering/text_render_engine.dart` (1593)
یک کلاسِ تماماً static (عملاً یک namespace) که متن را به `InlineSpan`
تبدیل می‌کند:

- `buildInteractiveText` — ورودیِ اصلی.
- `applySpanStyle` — نگاشتِ `Markers` و فیلدهای رنگ/زیرخط/فاصله به `TextStyle`.
- `_processDictionaryWords` + `_sliceInteractiveWord` — واژه‌های دیکشنری.
- `InteractiveBlankWord` — آیکونِ چشم و مودالِ فاش‌کردن.
- `decorationStyleFromWord` / `hexToColor` — هلپرهای مشترک.

⚠️ **دو مسیرِ استایل موازی وجود دارد:** `applySpanStyle` (مودال/بنر) و
`baseStyle` داخلِ `reading_canvas.dart` (متنِ بدنه). هر ویژگیِ تازه باید در
**هر دو** اعمال شود.

⚠️ `TextStyle.copyWith(x: null)` مقدارِ قبلی را **نگه می‌دارد**، پاک نمی‌کند.
برای پاک‌کردن باید مقدارِ صریح داد (مثلاً `const <FontFeature>[]` یا `0.0`).

### `library/providers/books_provider.dart` (1134)
سه مسئولیت در یک فایل (بدهیِ فنیِ شناخته‌شده):

- `BookModel` — مدلِ کتاب + وضعیتِ دانلود/نسخه.
- `BooksNotifier` — `fetchBooks`، به‌روزرسانیِ وضعیت.
- سرویسِ ZIP — `downloadBookZip` (با Range برای ادامه‌ی دانلود)،
  `pauseZipDownload`/`resumeZipDownload`، `_extractBookZip`،
  `deleteDownloadedBook`.
- `SearchSession` + `activeSearchProvider` هم این‌جاست، که جایش نیست.

### `audio/`
- `providers/audio_player_provider.dart` — `AudioPlayerNotifier` روی
  `just_audio`: پلی‌لیست، حالتِ تکرار، نقاطِ A/B، `AudioLocation`.
- `presentation/audio_player_bar.dart` (1193) — نوارِ کوچکِ بالای صفحه،
  `CombinedAudioSheet` (کنترل + متنِ همگام)، `_AudioPlaylistSheet`، و
  `openAudioSearchResult` که **تنها** نقطه‌ی بازکردنِ مودال از مسیرِ جستجوست.

### `search/`
- `data/book_search_engine.dart` — جستجو در یک آیزولتِ جدا؛ هم متنِ صفحات و
  هم اسکریپت‌های صوت را می‌گردد؛ `SearchResult` شاملِ موقعیت و زمانِ صوت.
- `presentation/book_search_delegate.dart` — `SearchDelegate` استاندارد.

---

## جریان‌های کلیدی (وقتی چیزی خراب است، این‌ها را دنبال کنید)

**باز کردنِ کتاب:**
`library_screen._openBookForReading` → ست‌کردنِ `activeBookProvider` →
`ReaderScreen` → `_ensureBookLoaded` می‌سازد `PagedBookStore` →
`ReadingCanvas` → `_LazyPage` → `getPage` → `_buildParagraph`/`_buildTable`

**دانلود:**
`downloadBookZip` → `zipInfo` از لاراول → استریم در `.part` →
`_extractBookZip` → `_finishZipDownload` (ثبتِ نسخه‌ها)

**جستجو:** `BookSearchDelegate` → `BookSearchEngine.searchAllBooks`
(آیزولت) → `SearchResult` → `activeSearchProvider` → ناوبری در
`ReadingCanvas` از طریقِ `indexForPageNumber`

**صوت:** لینکِ `audio:x.mp3` در متن → `playFile` → `AudioPlayerBar` →
`CombinedAudioSheet` با هایلایتِ `StartMs`/`EndMs`

## قراردادهای ریز ولی مهم

- **جلسه‌ی جستجوی «مصنوعی»:** پرشِ صوتی یک `SearchSession` با `query` خالی
  می‌سازد تا از مکانیزمِ اسکرول استفاده کند. هر چکِ «آیا جستجو فعال است؟»
  باید `query.isNotEmpty` را ببیند، نه `!= null`.
- **رسانه در زیرپوشه‌هاست** (`audio/`, `images/`)، با فالبکِ تخت برای
  کتاب‌های قدیمی.
- **`PopScope`** در `reader_screen`: اول جستجو، بعد پخش‌کننده، بعد خروج.
  نامِ درستِ کال‌بک `onPopInvokedWithResult` است.
- **`float_column`** برای متنِ دورِ عکس استفاده می‌شود؛ `IntrinsicHeight` و
  `Row` رویش کرش می‌کنند.

## بدهی‌های شناخته‌شده (به‌ترتیبِ ارزشِ رسیدگی)

1. `reading_canvas.dart` باید شکسته شود. `_buildTable`، `_buildParagraph` و
   `BookPageWidget` همگی توابعِ سطحِ‌بالا هستند و با پارامتر صدا زده
   می‌شوند، پس جداسازی‌شان «انتقال» است نه بازنویسی.
2. `books_provider.dart` باید به مدل / سرویسِ دانلود / نوتیفایر تفکیک شود.
   تنها فایلِ غیرِنمایشی است که `material.dart` را import می‌کند.
3. `audio_player_bar.dart` (1193) و `text_render_engine.dart` (1593).
4. `_openLastBook` در `library_screen` کدِ مرده است.
5. **پروژه هیچ `test/` ندارد.** چند تستِ ساده روی `document_text_utils`،
   getterهای `BookModel` و نگاشتِ `pageNumberForIndex` (همگی بدونِ UI
   قابلِ تست) بندهای ۱ و ۲ را به‌مراتب کم‌ریسک‌تر می‌کند.
6. حدود ۹۰ موردِ لینت، همگی بی‌خطر. `dart fix --apply` بیشترشان را حل
   می‌کند — به‌جز دسته‌ی `dead_code`/`dead_null_aware` که باید خوانده شوند،
   چون گاهی نشانه‌ی گاردِ اشتباه‌نوشته‌شده‌اند.

## محیطِ کار

ویندوز + PowerShell. برای اسکریپت‌های bash از `bash.exe` داخلِ
`C:\Program Files\Git\bin\` استفاده کنید، نه `git-bash.exe` (آن پنجره‌ی جدا
باز می‌کند و خطا را پنهان می‌کند).
