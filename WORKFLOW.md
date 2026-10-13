# راهنمای کار: از فایلِ Word تا اپ روی گوشی

> این فایل در دو مخزن یکسان است: **CustomLayoutGenerator** و **ielts_assistant**. اگر
> عوضش کردید، هر دو را عوض کنید. برای وقتی است که مدتی از پروژه دور بوده‌اید، یا می‌خواهید
> با هوش مصنوعیِ دیگری کار را ادامه دهید.

## نقشه‌ی پروژه‌ها

| مخزن | چه می‌کند | راهنمای اصلی |
|---|---|---|
| **ielts_assistant** (Flutter) | اپ؛ فایل‌های Word در `assets/data/` | `RULES-rendering.md`، `CHANGES.md` |
| **CustomLayoutGenerator** (C#) | تبدیلِ Word به JSON، وصلِ ترجمه‌ها و کلمات تعاملی | `ARCHITECTURE-extractor.md`، `RULES-extraction.md`، `tools/enrichment/ENRICHMENT-GUIDE.md` |
| **bookassistant-backend** (Laravel) | سایت، پنلِ ادمین، API، توزیعِ اپ | `SETUP-backend.md`، `ARCHITECTURE-backend.md`، `Changes/` |
| **AudioMarkerReview** (WPF) | گذاشتنِ مارکرهای زمانی در اسکریپت‌های صوتی | — |
| **IeltsJsonOptimizer** | ابزارِ قدیمیِ ترجمه با Gemini؛ دیگر لازم نیست و دست‌نخورده می‌ماند | — |

جای داده‌ها، در مخزنِ Flutter:
```
assets/data/_lexicon/lexicon.json            دیکشنریِ مشترکِ همه‌ی کتاب‌ها
assets/data/Mindset 01/
    Mindset1- Custom- Units 01-08.docx       متنِ کتاب
    Mindset1- Audio Scripts_markers.docx     اسکریپت‌های صوتی با مارکرِ زمانی
    enrichment/translations.json             حافظه‌ی ترجمه‌ی همین کتاب
    enrichment/pending.json                  خروجیِ اکسترکتور: متن‌های بی‌ترجمه
    (خروجیِ اکسترکتور: index.json، pages/، audio_scripts/، images/ — در گیت نیستند)
```

## بعد از مدتی دوری، اول این‌ها
1. **گرفتنِ آخرین کد:** در هر مخزن `git pull`.
2. **Flutter:**
   ```bat
   flutter clean
   flutter pub get
   flutter analyze
   ```
3. **C#:** CustomLayoutGenerator را در Visual Studio باز کنید و Build بزنید.
4. **سایت:** `composer install`، بعد `php artisan migrate`. اگر کامپیوتر تازه است، کلِ
   `SETUP-backend.md`.
5. **آخرین تغییرها:** `CHANGES.md`ِ هر مخزن و فایل‌های `Changes/`ِ سایت را بخوانید.

## ۱. ویرایشِ کتاب در Word
- **قواعدِ نوشتنِ سند:** در `RULES-extraction.md`، بخشِ «راهنمای نویسنده‌ی سند»، آمده‌اند؛ مثلِ
  استایل‌های جای‌خالی (BlkPa، BlkCh، BlkLp)، Nav 1/Nav 2 برای فهرستِ Unit و مهارت، و
  استایل‌های جدول.
- **ویرایشِ ظاهری:** تغییرِ استایل، رنگ، چیدمان و جابه‌جاییِ پاراگراف‌ها به ترجمه‌ی دوباره
  نیازی ندارد.
- **ویرایشِ متن:** فقط پاراگرافی که متنش عوض شده، دوباره ترجمه می‌خواهد.
- **اسکریپت‌های صوتی:** مارکرهای زمانی را با AudioMarkerReview بگذارید. خروجی‌اش
  `*Audio Scripts_markers.docx` است. هر فایلِ صوتی یک جدولِ دوردیفه است: ردیفِ اول نامِ
  فایل، ردیفِ دوم متن.

## ۲. استخراج (CustomLayoutGenerator)
1. برنامه را اجرا کنید و docxِ کتاب را از `assets/data/{کتاب}/` انتخاب کنید.
2. شماره‌ی صفحه‌ی شروع را بدهید.
3. به سؤالِ «اسکریپت صوتی دارید؟» بله بگویید و فایلِ `*_markers.docx` را انتخاب کنید.
4. **خروجی:** کنارِ docx ساخته می‌شود: `index.json`، `pages/`، `audio_scripts/`، `images/`.
5. **ترجمه‌ها:** در همین مرحله ترجمه‌ها از `enrichment/translations.json` و کلمات تعاملی از
   `_lexicon/lexicon.json` خودکار وصل می‌شوند. پیامِ پایانی آمار را می‌گوید.
6. **متن‌های بی‌ترجمه:** متنی که ترجمه ندارد در `enrichment/pending.json` می‌آید. کتاب
   بدونِ ترجمه‌ی آن‌ها هم کار می‌کند؛ فقط آن پاراگراف‌ها ترجمه و کلمه‌ی تعاملی ندارند.

## ۳. ترجمه و کلمات تعاملی
**با Claude:** کافی است بگویید «واحدِ X را ترجمه کن» یا «pending.json را ترجمه کن». بعد از
push، فایل‌ها را از گیت می‌خوانم.

**با هر هوش مصنوعیِ دیگر** (Gemini، ChatGPT، …): با `tools/enrichment/enrich.py` در مخزنِ
C#. جزئیاتِ کامل در `tools/enrichment/ENRICHMENT-GUIDE.md`، بخشِ ۴، است. خلاصه:
```bat
cd CustomLayoutGenerator\tools\enrichment
python enrich.py status  "…\assets\data\Mindset 01"
python enrich.py prepare "…\assets\data\Mindset 01" --unit "UNIT/02"
:: فایلِ batches\batch_001.prompt.md را به هوش مصنوعی بدهید و پاسخ را در answer.json ذخیره کنید
python enrich.py merge   "…\assets\data\Mindset 01" batch_001 answer.json
```
- **قواعد:** ترجمه و انتخابِ کلمات در خودِ پرامپت هست، پس کیفیت به حافظه‌ی آن هوش مصنوعی
  وابسته نیست.
- **بررسیِ پاسخ:** `merge` پیش از نوشتن پاسخ را بررسی می‌کند. اگر ایرادی باشد، هیچ چیزی
  خراب نمی‌شود.
- **بعد از ادغام:** دوباره استخراج کنید (مرحله‌ی ۲) و `translations.json` و `lexicon.json` را
  commit کنید.

## ۴. آپلود در سایت
1. پوشه‌ی خروجی را فشرده کنید: `index.json`، `pages/`، `audio_scripts/`، `images/` و `audio/`.
   پوشه‌ی `audio/` فایل‌های mp3ای است که نامشان با نامِ فایلِ صوتی در اسکریپت یکی است.
   `enrichment/` و docxها لازم نیستند.
2. در پنلِ ادمین، کتاب را ویرایش کنید و «آپلود محتوا» ← «آپلود محتوای اصلی (ZIP/RAR)» را
   بزنید.
3. یکی از دو حالت را انتخاب کنید:
   - **«بروزرسانی»:** فقط فایل‌های هم‌نام عوض می‌شوند. برای تغییرِ متن یا ترجمه همین کافی
     است.
   - **«جایگزینی»:** همه‌چیز پاک و از نو گذاشته می‌شود.
4. **در اپ:** فقط صفحه‌هایی که واقعاً عوض شده‌اند دوباره دانلود می‌شوند، چون نسخه‌ی هر صفحه
   هَشِ محتوای خودش است.

## ۵. آزمودن در اپ
1. `flutter run`
2. در اپ ← تنظیمات، آدرسِ سرور را بدهید: `http://IPِ‌کامپیوتر:8000`.
3. کتاب را باز کنید.
4. **لمسِ طولانی روی پاراگراف:** ترجمه را نشان می‌دهد.
5. **لمسِ کلمه‌ی آبی:** معنا، تلفظ و توضیحش را نشان می‌دهد.
6. **اسکریپت‌های صوتی:** روی نوارِ کوچکِ پلیر بزنید تا اسکریپت باز شود و همین دو کار را آن‌جا هم امتحان کنید.

## ۶. انتشارِ نسخه‌ی تازه‌ی اپ (از سایت، نه فروشگاه)
1. در `pubspec.yaml` نسخه را بالا ببرید: `version: 1.0.1+2`. عددِ بعد از `+` حتماً باید بیشتر
   شود.
2. فایلِ نصبی را بسازید:
   ```bat
   flutter build apk --release
   ```
   بدونِ `--split-per-abi`، و همیشه با **همان keystore**.
3. در پنلِ ادمین ← «نسخه‌های اپ» ← «انتشارِ نسخه‌ی تازه»:
   - نسخه: `1.0.1`
   - شماره‌ی build: `2`
   - فایلِ APK
   - فهرستِ تغییرات
   - در صورتِ نیاز: «اجباری»
4. اپ‌های نصب‌شده با باز شدن نسخه‌ی تازه را اعلام می‌کنند. قواعدِ این بخش U-1 تا U-4 در
   `RULES-rendering.md` است.

## ۷. ادامه‌ی کارِ برنامه‌نویسی با هوش مصنوعیِ دیگر
پیش از هر درخواست، این فایل‌ها را به آن هوش مصنوعی بدهید:
- **Flutter:** `RULES-rendering.md`، `CHANGES.md`، و فایلِ Dartِ مربوط.
- **C#:** `ARCHITECTURE-extractor.md`، `RULES-extraction.md`، `CHANGES.md`.
- **سایت:** `ARCHITECTURE-backend.md`، `SETUP-backend.md`، آخرین فایلِ `Changes/`.

و این قراردادها را بخواهید:
- توضیح‌های کد فارسی باشند.
- هر قانونِ تازه با شناسه‌اش (مثلاً T-17) در فایلِ RULES ثبت شود.
- برای هر تغییر، `CHANGES.md` نوشته شود. سایت فایلِ تاریخ‌دار در `Changes/` دارد.
- قبل از push، `git pull --rebase` زده شود.
- IeltsJsonOptimizer دست‌نخورده بماند.

## ۸. اگر چیزی کار نکرد
| نشانه | اول این را ببینید |
|---|---|
| Build اندروید با «Could not find … dl.google.com» شکست خورد | پکیجی اضافه شده که نسخه‌ی دیگری از ابزارِ Build اندروید می‌خواهد. همان پکیج را بردارید. `CHANGES.md`ِ Flutter، رفعِ package_info_plus، را ببینید. |
| سایت: `Table '…' doesn't exist` | `php artisan migrate` |
| بعد از استخراج، ترجمه‌ی پاراگرافی نیامد | متنش عوض شده؛ در `enrichment/pending.json` است. |
| کلمه‌ای تعاملی نشد | در `terms`ِ هیچ پاراگرافی از این کتاب نیامده، یا شکلش در `forms`ِ مدخل نیست. |
| جدول یا صفحه با Word فرق دارد | قانون‌های T و H در `RULES-rendering.md`؛ برای استخراج `RULES-extraction.md`. |
