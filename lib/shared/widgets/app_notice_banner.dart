import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/core/app_config/app_config.dart';

// 🌟 SITE-3/4: نوارِ «حالتِ تعمیر» یا اطلاعیه‌ی ادمین (پنلِ سایت ← اطلاعیه و تعمیر)، بالای کتابخانه.

class AppNoticeBanner extends ConsumerWidget {
  const AppNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig cfg = ref.watch(appConfigProvider);
    final String? maintenance = cfg.maintenance;
    final AppNotice? notice = maintenance != null && maintenance.isNotEmpty
        ? AppNotice(maintenance, 'maintenance')
        : cfg.announcement;
    if (notice == null) return const SizedBox.shrink();

    final (Color bg, Color fg, IconData icon) = switch (notice.level) {
      'maintenance' => (Colors.red.shade50, Colors.red.shade800, Icons.construction_rounded),
      'warning' => (Colors.amber.shade50, Colors.brown.shade800, Icons.warning_amber_rounded),
      'success' => (Colors.green.shade50, Colors.green.shade800, Icons.celebration_rounded),
      _ => (Colors.blue.shade50, Colors.blue.shade900, Icons.campaign_rounded),
    };
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(notice.text, style: TextStyle(color: fg, fontSize: 13, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
