# تغییرات — تکرارِ درس/مهارت/کتاب (AU-5)، اعلانِ رسانه و صفحه‌ی قفل (AU-6)، درس در پلی‌لیست (AU-7)

فایل‌های تغییرکرده:
- `pubspec.yaml`: `audio_service` (اعلانِ رسانه)
- `android/app/src/main/AndroidManifest.xml`: مجوزهای پخشِ پس‌زمینه، سرویسِ `AudioService` و گیرنده‌ی `MediaButtonReceiver`
- `android/app/src/main/kotlin/.../MainActivity.kt`: از `AudioServiceActivity` (کانالِ شناسه‌ی دستگاه دست‌نخورده)
- `lib/features/audio/data/media_session_service.dart` (تازه): جلسه‌ی رسانه و دکمه‌های اعلان
- `lib/features/audio/providers/audio_player_provider.dart`: سه حالتِ تکرارِ تازه، `setPlaybackMode`، `setBookContext`، همگام‌سازیِ اعلان
- `lib/features/audio/presentation/audio_player_bar.dart`: منوی رفتارِ پایانِ فایل؛ درس و مهارت در پلی‌لیست
- `lib/features/reader/presentation/reading_canvas.dart`: فهرست، نام و جلدِ کتاب به پلیر داده می‌شود
- `lib/features/reader/domain/document_models.dart`: `outlineIndicesAt` (مشترکِ جستجو، تکرار و پلی‌لیست)
- `lib/main.dart`: `MediaSessionService.init()`
- `RULES-rendering.md` (AU-5، AU-6، AU-7)

## پیش از اجرا
`flutter pub get`، بعد ساختنِ دوباره‌ی کاملِ اپِ اندروید (`flutter run` از نو؛ Hot Restart کافی نیست، چون
MainActivity و AndroidManifest عوض شده‌اند).

## چه شد
- دکمه‌ی تکرارِ پلیر حالا منوی شش‌گزینه‌ای است: توقف، تکرارِ همین فایل، پخشِ پیوسته تا آخرِ کتاب، تکرارِ
  فایل‌های همین مهارت (درسِ فعلی)، تکرارِ فایل‌های همین درس، تکرارِ کلِ کتاب.
- تا پلیر فایلی دارد، اعلانِ رسانه و کنترل‌های صفحه‌ی قفل هست: قبلی، پخش/مکث، بعدی، بستن، نوارِ پیشرفت؛ با
  نامِ فایل، درس و مهارت و جلدِ کتاب. دکمه‌های هدفون و بلوتوث هم کار می‌کنند.
- پلی‌لیستِ کتاب زیرِ نامِ هر فایل درس و مهارتش را دارد.

## چه چیزی را امتحان کنید
- «تکرارِ فایل‌های همین مهارت» روی آخرین فایلِ Listeningِ یک درس: بعد از پایان باید به اولین فایلِ همان
  Listening برگردد.
- قفلِ گوشی هنگامِ پخش؛ مکث و پخش و بعدی از صفحه‌ی قفل؛ × در اعلان.
- آیکونِ کوچکِ اعلان در نوارِ وضعیت: فعلاً همان آیکونِ برنامه است؛ اندروید آیکونِ رنگی را سفید و تک‌رنگ
  نشان می‌دهد. اگر شکلش خوب نبود، یک آیکونِ تک‌رنگ لازم است.
