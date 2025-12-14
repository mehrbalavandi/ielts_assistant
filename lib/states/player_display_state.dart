import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/models/data_models.dart';

enum PlayerDisplayMode {
  hidden, // پلیر پنهان است (مثلاً وقتی چیزی پخش نمی‌شود)
  minimized, // پلیر کوچک و شناور است (بالای صفحه)
  maximized, // پلیر بزرگ و تمام صفحه (به صورت Modal)
}

// نوتیفایر ساده برای نگهداری حالت نمایش
class PlayerDisplayNotifier extends StateNotifier<PlayerDisplayMode> {
  PlayerDisplayNotifier() : super(PlayerDisplayMode.hidden);

  void minimize() => state = PlayerDisplayMode.minimized;
  void maximize() => state = PlayerDisplayMode.maximized;
  void hide() => state = PlayerDisplayMode.hidden;
}

final playerDisplayProvider =
    StateNotifierProvider<PlayerDisplayNotifier, PlayerDisplayMode>((ref) {
      return PlayerDisplayNotifier();
    });

// این یک Provider ساده برای نگه داشتن مبحث در حال پخش است
// اگرچه این بهتر است در audio_player_service مدیریت شود، اما برای دسترسی آسان به UI اینجا تعریف می‌شود
