import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

// 🌟 DIAG-1 (RULES-rendering.md): خطای ساختِ ویجت در نسخه‌ی release هم دیده شود.
//
// فلاتر در release به‌جای ویجتی که هنگامِ build خطا داد فقط یک کادرِ خاکستری می‌کشد (پیامِ خطا
// پنهان است)، پس «صفحه‌ی خاکستری» هیچ سرنخی نمی‌دهد. این‌جا:
// - همان کادر با متنِ کوتاهِ خطا و دکمه‌ی «کپیِ گزارش» (خطا + ابتدای stack) جایگزین می‌شود؛
// - ۱۰ خطای آخر (هر جای برنامه: build، layout، کالبک‌ها، Futureها) در GetStorage
//   (`error_log`) می‌ماند تا بعداً هم بشود فرستاد.

class ErrorReport {
  ErrorReport._();

  static const String _key = 'error_log';
  static const int _keep = 10;

  static void install() {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      record(d.exception, d.stack, context: d.context?.toDescription());
      previous?.call(d);
    };
    final ErrorCallback? platformPrev = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object e, StackTrace st) {
      record(e, st, context: 'async');
      return platformPrev?.call(e, st) ?? false;
    };
    ErrorWidget.builder = (FlutterErrorDetails d) => _ErrorBox(details: d);
  }

  static String format(Object error, StackTrace? stack, {String? context}) {
    final String st = (stack?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(14)
        .join('\n');
    return [
      DateTime.now().toIso8601String(),
      if (context != null && context.isNotEmpty) 'context: $context',
      'error: $error',
      if (st.isNotEmpty) st,
    ].join('\n');
  }

  static void record(Object error, StackTrace? stack, {String? context}) {
    try {
      final GetStorage box = GetStorage();
      final List<dynamic> log = List<dynamic>.from(box.read<List>(_key) ?? const []);
      log.insert(0, format(error, stack, context: context));
      while (log.length > _keep) {
        log.removeLast();
      }
      box.write(_key, log);
    } catch (_) {}
  }

  static List<String> recent() {
    try {
      return [for (final Object? e in GetStorage().read<List>(_key) ?? const []) e.toString()];
    } catch (_) {
      return const [];
    }
  }
}

class _ErrorBox extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorBox({required this.details});

  @override
  Widget build(BuildContext context) {
    final String report = ErrorReport.format(
      details.exception,
      details.stack,
      context: details.context?.toDescription(),
    );
    final String short = details.exceptionAsString().split('\n').first;
    // ارتفاع/عرضِ محدود: ویجتِ خراب ممکن است در فهرستِ بی‌ارتفاع باشد.
    return Material(
      color: const Color(0xFFFFF3E0),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'این بخش به‌خاطرِ یک خطا نمایش داده نشد.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBF360C)),
                ),
                const SizedBox(height: 6),
                Text(
                  short,
                  textDirection: TextDirection.ltr,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4E342E)),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('کپیِ گزارشِ خطا'),
                  onPressed: () => Clipboard.setData(ClipboardData(text: report)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
