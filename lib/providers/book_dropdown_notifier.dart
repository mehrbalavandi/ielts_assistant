// -------------------
// Provider نگهداری آیتم انتخاب شده (باید در دسترس Notifier باشد)
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

final selectedBookProvider = StateProvider<Book?>((ref) => null);
