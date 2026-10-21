# تغییرات — بستنِ پاپ‌آپ در اسکریپتِ صوتی پلیر را جابه‌جا نمی‌کند (AS-6)

فایل‌های تغییرکرده:
- `lib/features/reader/presentation/rendering/answer_display.dart`: `answerPopupClosedByThisTap`
- `lib/features/audio/presentation/audio_player_bar.dart`: لمسِ کلمه‌ی اسکریپت اگر همان لمس پاپ‌آپ را بسته، پرش نمی‌کند
- `RULES-rendering.md` (AS-6)

## چه شد
- در برگه‌ی پلیر، وقتی ترجمه‌ی یک پاراگراف در پاپ‌آپ باز است، لمس روی متنِ بیرونِ آن فقط پاپ‌آپ را می‌بندد؛
  پلیر به آن نقطه نمی‌رود. لمسِ بعدی مثلِ همیشه پلیر را به همان کلمه می‌برد.
