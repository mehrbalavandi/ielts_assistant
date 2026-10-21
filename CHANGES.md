# تغییرات — پاسخ در ترجمه هم پنهان است (TR-8)

فایل‌های تغییرکرده:
- `assets/data/Mindset 01/enrichment/translations.json`: در ترجمه‌ی ۵۴۹ پاراگرافِ با جای خالیِ وسطِ جمله
  (درس‌های ۱ تا ۸)، بخشِ پاسخ بینِ `{blk}…{/blk}` است
- `lib/features/reader/presentation/rendering/translatable_content.dart`: `_TranslationText` بخشِ پنهان را
  با آیکونِ چشم نشان می‌دهد؛ داخلِ پنجره‌ی پاسخ نشانه‌ها برداشته می‌شوند
- `lib/features/reader/presentation/rendering/text_render_engine.dart`: ترجمه‌ی پنجره‌ی پاسخ بی‌نشانه
- `lib/features/reader/presentation/rendering/translation_groups.dart`: پاراگرافِ با جای خالیِ وسطِ جمله
  هم عضوِ گروه می‌شود، وقتی ترجمه‌اش نشانه دارد
- `lib/features/study/presentation/study_controls.dart`: عکسِ ترجمه در «مرورِ من» با «____»
- `lib/core/text/document_text_utils.dart`: `stripBlankMarkers`، `maskBlankParts`
- `RULES-rendering.md` (TR-7، TR-8)
- مخزنِ CustomLayoutGenerator: `ENRICHMENT-GUIDE.md` (قاعده‌ی ۵)، `enrich.py` (بررسیِ merge)، `RULES-extraction.md` (G-9)

## چه شد
- ترجمه‌ی لمسِ طولانیِ پاراگرافی مثلِ «1 value h» دیگر جواب را لو نمی‌دهد: «ارزش قائل شدن: 👁». لمسِ چشم
  جواب را نشان می‌دهد، لمسِ دوباره پنهانش می‌کند.
- فهرست‌هایی که جوابشان داخلِ جمله است (مثلاً واژه‌های ۱ تا ۸ و معنی‌های a تا h) حالا هم با یک لمسِ طولانی
  با هم ترجمه می‌شوند (TR-7)، با همه‌ی جواب‌ها پنهان.
- پنجره‌ی خودِ پاسخ (بعد از بازکردنِ چشمِ متن) ترجمه را کامل نشان می‌دهد.
- اکسترکتور تغییری لازم نداشت: ترجمه را با همین نشانه‌ها در JSON می‌گذارد. بعد از pull، کتاب را دوباره
  استخراج کنید.

## چه چیزی را امتحان کنید
- Mindset 1 ص۲ (VOCABULARY، تمرینِ ۰۳): لمسِ طولانی روی «1 value» — ترجمه‌ی گروه با چشم‌های پنهان.
- یک جمله‌ی True/False/Not Given با جوابِ داخلِ جمله، و یک یادداشتِ لیسنینگ (مثلاً درس ۸ قورباغه‌ی گاوی).
- پنجره‌ی پاسخِ یک جای خالیِ وسطِ جمله: ترجمه بی‌چشم و کامل.
