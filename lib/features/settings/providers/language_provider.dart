import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:get_storage/get_storage.dart';

/// زبانِ فعالِ اپ: 'fa' (پیش‌فرض) یا 'ar'. مقدار در GetStorage ذخیره می‌شود
/// تا بین اجراها حفظ شود.
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(GetStorage().read('app_lang') ?? 'fa');

  final _box = GetStorage();

  void set(String lang) {
    if (lang != 'fa' && lang != 'ar') return;
    state = lang;
    _box.write('app_lang', lang);
  }

  void toggle() => set(state == 'fa' ? 'ar' : 'fa');
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);

/// آیا زبانِ فعال عربی است؟
bool isArabic(String lang) => lang == 'ar';
