# تغییرات — آیکون‌های تک‌رنگِ اعلان و دکمه‌ی × (AU-10)

فایل‌های تغییرکرده:
- `android/app/src/main/res/drawable/ic_stat_notification.xml` (تازه): آیکونِ نوارِ وضعیت (هدفون)
- `android/app/src/main/res/drawable/ic_notification_close.xml` (تازه): ×ِ «بستن»
- `android/app/src/main/res/raw/keep.xml` (تازه): این دو در نسخه‌ی release حذف نشوند
- `lib/features/audio/data/media_session_service.dart`: آیکونِ اعلان، دکمه‌ی بستن، تصویرِ مهارت بی‌نوشته
- `RULES-rendering.md` (AU-10)

## چه شد
- آیکونِ اعلان در نوارِ وضعیت و نشانِ کوچکِ روی تصویرِ اعلان، هدفونِ سفید است، نه مربع.
- مربعِ سفیدِ سمتِ چپِ دکمه‌ها (دکمه‌ی «توقف» با آیکونِ مربع) حالا × است و پلیر را می‌بندد.
- روی تصویرِ اعلان فقط آیکونِ مهارت، وسط؛ نوشته‌ی «SPEAKING» زیرِ نشانِ برنامه می‌رفت.

برنامه را دوباره بسازید (منابعِ اندروید عوض شده‌اند؛ Hot Restart کافی نیست).
