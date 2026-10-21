# تغییرات — رنگِ مهارت برای فایل‌های صوتی (AU-9)

فایل‌های تغییرکرده:
- `lib/features/audio/domain/audio_skill.dart` (تازه): مهارت از فهرستِ کتاب، رنگ، آیکون
- `lib/features/audio/data/media_session_service.dart`: تصویرِ اعلان به رنگِ مهارت
- `lib/features/audio/providers/audio_player_provider.dart`: `bookOutline` در state، `skillOfPath`
- `lib/features/audio/presentation/audio_player_bar.dart`: نوارِ کوچک، برگه‌ی پلیر و پلی‌لیست به رنگِ مهارت
- `lib/features/reader/presentation/reading_canvas.dart`: دکمه‌ی صوتیِ داخلِ متن به رنگِ مهارت
- `RULES-rendering.md` (AU-9)

## چه شد
- Listening بنفش و Speaking آبی (Reading نارنجی، Writing سبز اگر فایلی آن‌جا باشد) در: دکمه‌های صوتیِ متنِ درس،
  نوارِ کوچکِ پلیر، برگه‌ی پلیر (هایلایتِ کلمه‌ی در حالِ پخش)، پلی‌لیست (آیکونِ هدفون/میکروفون) و اعلانِ رسانه
  و صفحه‌ی قفل.
- نوارِ کوچکِ پلیر به جای «Tap to expand» درس و مهارتِ فایل را نشان می‌دهد.
- اعلان: اندروید رنگِ زمینه را از تصویرِ اعلان برمی‌دارد، پس برای هر مهارت یک تصویرِ رنگی (آیکون و نامِ
  مهارت) ساخته می‌شود و جای جلدِ کتاب می‌نشیند.
