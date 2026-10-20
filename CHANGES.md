# تغییرات — جهتِ راست‌به‌چپ برای فارسی و عربی در همه‌ی اپ (UI-2)

فایل‌های تغییرکرده:
- `lib/app/app.dart`: `builder`ِ `MaterialApp` همه‌ی اپ را راست‌به‌چپ می‌کند
- `lib/core/text/text_direction.dart` (تازه): `textDirectionOf`، `AutoDirectionText`، `textAlignToStartOf`، `bidiIsolate`
- `lib/features/reader/presentation/reader_screen.dart`: `ReadingCanvas` چپ‌به‌راست؛ عنوانِ کتاب با جهتِ خودکار
- `lib/features/audio/presentation/audio_player_bar.dart`: برگه‌ی اسکریپتِ صوتی و فهرستِ پلی‌لیست چپ‌به‌راست، متن‌های فارسی‌شان راست‌به‌چپ
- `library_screen.dart`، `book_details_screen.dart`، `app_notice_banner.dart`، `my_devices_screen.dart`: عنوان، توضیح، نامِ دستگاه و اطلاعیه با جهتِ خودکار
- عنوان/نام/عبارتِ جستجو داخلِ جمله‌های فارسی با `bidiIsolate`: `book_actions`، `reader_screen`، `purchase_sheet`، `sample_lock_dialog`، `reading_canvas`، `my_devices_screen`، `device_limit_dialog`، `study_controls`، `study_review_screen`، `study_item_format`
- `RULES-rendering.md` (UI-2)

## چه شد
- همه‌ی صفحه‌ها، دیالوگ‌ها، برگه‌های پایین، پیام‌ها و منوی کناری راست‌به‌چپ‌اند؛ تا حالا هر صفحه باید خودش
  این را می‌گذاشت و ویترین، تنظیمات، منوی کناری، جزئیاتِ کتاب، دستگاه‌های من و پیام‌های پایینِ صفحه جا مانده
  بودند. صفحه یا دیالوگِ تازه هم خودکار راست‌به‌چپ است.
- خودِ کتاب، اسکریپتِ صوتی، کنترل‌های پخش و فیلدهای انگلیسی مثلِ قبل چپ‌به‌راست‌اند.
- متنی که زبانش معلوم نیست (مثلاً عنوانِ انگلیسیِ کتاب در ویترین) جهتش را از اولین حرفش می‌گیرد؛ پرانتزِ
  آخرِ «… (Student's Book)» دیگر به اولِ عنوان نمی‌پرد.

## چه چیزی را امتحان کنید
- ویترین، منوی کناری (حالا از راست باز می‌شود)، تنظیمات، جزئیاتِ کتاب، دستگاه‌های من، یک SnackBar (مثلاً
  «پشتیبان‌گیریِ الان»).
- صفحه‌ی مطالعه: متن، جدول‌های اسکرولی، ناوبر، پلیر و پاپ‌آپ‌ها باید دقیقاً مثلِ قبل باشند؛ نوارِ بالای
  صفحه (دکمه‌ی برگشت و آیکون‌ها) حالا آینه‌ای است.
- برگه‌ی اسکریپتِ صوتی و پلی‌لیست.
