import 'package:flutter/material.dart';

// 🌟 UI-1: رنگ‌های نوارِ بالای صفحه (AppBar) — آبی با نوشته و آیکونِ سفید (تمِ اپ در app.dart).

/// TabBar برای bottomِ AppBar: برچسب‌ها و خطِ زیرِ زبانه‌ی فعال سفید، بقیه سفیدِ کم‌رنگ.
/// (رنگِ پیش‌فرضِ TabBar همان آبیِ اصلیِ تم است و روی پس‌زمینه‌ی آبیِ AppBar دیده نمی‌شد.)
TabBar appBarTabBar({
  required List<Widget> tabs,
  bool isScrollable = false,
  TabAlignment? tabAlignment,
}) => TabBar(
  tabs: tabs,
  isScrollable: isScrollable,
  tabAlignment: tabAlignment,
  labelColor: Colors.white,
  unselectedLabelColor: Colors.white70,
  indicatorColor: Colors.white,
  indicatorWeight: 3,
  dividerColor: Colors.transparent,
  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
);

/// دکمه‌ی متنی داخلِ actionsِ AppBar (مثلاً «ذخیره»): سفید، نه آبی.
final ButtonStyle appBarTextButtonStyle = TextButton.styleFrom(
  foregroundColor: Colors.white,
);
