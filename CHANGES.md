# تغییرات — ترجمه‌ی درسِ 4 کتابِ Mindset 1

فایل‌های تغییرکرده:
- `assets/data/Mindset 01/enrichment/translations.json`: ترجمه‌ی فارسی و عربی
- `assets/data/_lexicon/lexicon.json`: مدخل‌های تازه‌ی کلمات و اصطلاحاتِ تعاملی

## چه شد
- **درسِ 4 (FOOD AND DRINK):** هر 619 پاراگرافِ متنِ کتاب و هر 60 پاراگرافِ متنِ فایل‌های
  صوتیِ Mindset_L1_32 تا L1_39 ترجمه شدند، با ترجمه‌ی پاسخِ جای‌خالی‌ها (`blanks`).
- **دیکشنری:** 141 مدخلِ تازه، مثلاً `culture shock`، `junk food`، `market share`،
  `remain stable`، `distractor`، `classification task`، `task card` و `food for thought`.
- **جمله‌های نادرستِ تمرین‌های «Correct the errors»:** خودِ جمله‌ی انگلیسی می‌ماند و معنایش داخلِ
  پرانتز می‌آید، چون خطای دستوری در ترجمه دیده نمی‌شود.

## ایرادهای داده‌ی کتاب (درسِ 4)
- **ص 115:** متنِ تمرینِ جفت کردنِ آشپزها (توصیف‌های 1 تا 7) همان هفت جمله‌ی تمرینِ پاراگراف‌هاست
  که تکرار شده. توصیف‌های واقعیِ آشپزها در داده نیست.
- **ص 113:** غلطِ املایی `ccuntries` (باید `countries` باشد).
- **ص 110:** دو شاهدِ b و c در یک پاراگراف ادغام شده‌اند («... attempts were a disaster. ... A lot
  of people grow ...»).
- **ص 120:** `home animal` (دو کلمه‌ی جدا در یک خط).
- **ص 126:** دستورِ «Pictures A-G show different areas of work or study» به تمرینِ روش‌های پخت
  نمی‌خورد (احتمالاً ایرادِ خودِ کتاب).
- **ص 129:** «Which option didn't match any of the shops?» در تمرینِ رستوران‌ها تکرار شده است.
- **ص 139:** دستورِ «Listen, then read Mohammed's answers ...» دو بار آمده است.

## تست
- `enrich.py merge` هر دسته را بی‌خطا ادغام کرد و `enrich.py status` درسِ 4 را کامل نشان می‌دهد.
- **کاری که شما باید انجام دهید:** کتاب را با ابزارِ C# دوباره استخراج کنید تا ترجمه‌ها در JSON بنشینند.
