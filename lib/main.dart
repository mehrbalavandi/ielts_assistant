import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/home/presentation/home_screen.dart';

// ایمپورت مدل‌ها و سرویس‌ها
// ویجت پلیر کوچک

Future<void> main() async {
  debugPaintSizeEnabled =
      false; // این خط برای اطمینان از مقداردهی اولیه فلاتر قبل از استفاده از get_storage است
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // مقداردهی اولیه
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Course Navigator',
      supportedLocales: const [Locale("fa", "IR"), Locale("en", "US")],
      locale: Locale("en", "US"),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo),
        //rtl
      ),
      home: ReadingCanvasScreen(documentParagraphs: []),
    );
  }
}
