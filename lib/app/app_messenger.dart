import 'package:flutter/material.dart';

/// پیام‌هایی که از بیرونِ یک صفحه‌ی مشخص می‌آیند (مثلاً «این دستگاه از حساب جدا شد»، DEV-1)
/// از این کلید نشان داده می‌شوند.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// برای بستنِ صفحه‌های باز (مثلاً صفحه‌ی مطالعه) پیش از پاک‌شدنِ محتوا (DEV-1).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
