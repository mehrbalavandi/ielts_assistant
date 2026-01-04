import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

// تعریف پرووایدر ساده برای دسترسی به حافظه
final storageProvider = Provider((ref) => GetStorage());
