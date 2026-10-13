# تغییرات — ترجمه‌ی کاملِ Mindset 1، Unit 1 (متن و اسکریپت‌های صوتی)

فایل‌های تغییرکرده (فقط داده؛ کدی عوض نشد):
- `assets/data/Mindset 01/enrichment/translations.json`: از ۱۷۲ مدخل به ۶۲۱ مدخل رسید
- `assets/data/_lexicon/lexicon.json`: از ۷۴ مدخل به ۱۴۷ مدخل رسید
- `WORKFLOW.md`: روالِ «هر Unit همراهِ اسکریپت‌های صوتی‌اش» (هم‌سان با نسخه‌ی C#)

تغییرِ هم‌زمان در CustomLayoutGenerator: `enrich.py` اسکریپت‌های صوتیِ هر Unit را خودش پیدا
می‌کند.

## چه چیزی ترجمه شد
- **متنِ کتاب:** همه‌ی ۵۵۰ متنِ یکتای Unit 1 ترجمه شده است:
  - Reading (پیش‌تر تأیید شده بود)
  - Writing
  - Listening
  - Speaking
- **اسکریپت‌های صوتی:** هر ۱۳ فایلِ صوتیِ Unit 1، یعنی `Mindset_L1_02` تا `Mindset_L1_14`.
  روی‌هم ۷۱ متنِ یکتا.
- **دیکشنری:** ۷۳ مدخلِ تازه اضافه شد. هر مدخل این‌ها را دارد: تلفظ (IPA، فارسی، عربی)، معنا در
  همان بافت، توضیحِ آموزشی و سطحِ CEFR. نمونه‌ها:
  - **رایتینگ:** `process`، `stage`، `overview`، `present simple passive`،
    `sequencing expressions`، `a range of`، `involve`
  - **لیسنینگ:** `multiple-choice question`، `fully booked`، `seat up to`، `at no extra charge`
  - **اسپیکینگ:** `collocation`، `examiner`، `extend your answer`، `the baby of the family`،
    `get along`، `look forward to`

قواعدِ راهنما همه رعایت شده‌اند؛ از جمله:
- جای‌خالی‌ها با پاسخِ درست ترجمه شده‌اند.
- شماره‌ی جای خالی در ترجمه نیامده است؛ مثلاً «They are a 2 close happy family».
- در تمرین‌های گرامری و واژگانی، کلمه‌ی انگلیسیِ موضوعِ درس داخلِ پرانتز مانده است؛ مثلاً
  «اول (First)».

## برای دیدن در اپ
تا اکسترکتور دوباره اجرا نشود، ترجمه‌ها در اپ دیده نمی‌شوند:
1. `git pull`
2. با CustomLayoutGenerator، Mindset 1 را همراهِ فایلِ `*_markers.docx` دوباره استخراج کنید.
3. پیامِ پایانی تعدادِ ترجمه‌ها را نشان می‌دهد.

اگر `enrichment/pending.json` ساخته شد، push کنید تا کلیدهای جورنشده را درست کنم. احتمالاً
در جاهایی رخ می‌دهد که متنِ اکسترکتور با متنِ docx کمی فرق دارد.
