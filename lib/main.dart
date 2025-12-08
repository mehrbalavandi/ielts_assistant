import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ielts_assistant/common/directory_state.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:path/path.dart' show basename;

// ایمپورت مدل‌ها و سرویس‌ها
import 'player_display_state.dart';
import 'mini_player_widget.dart'; // ویجت پلیر کوچک

void main() {
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
      home: const DirectoryPickerScreen(),
    );
  }
}

class DirectoryPickerScreen extends ConsumerWidget {
  const DirectoryPickerScreen({super.key});

  Future<void> _pickDirectory(WidgetRef ref) async {
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath();

    if (selectedDirectory != null) {
      final notifier = ref.read(directoryDataProvider.notifier);
      await notifier.loadDirectoryData(selectedDirectory);
    }
  }

  // ویجت اصلی که محتوای لیست پوشه‌ها را نمایش می‌دهد
  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Subject>> asyncData,
    DirectoryDataNotifier notifier,
  ) {
    // اگر پلیر کوچک فعال است، PaddingBottom را برای جلوگیری از همپوشانی اضافه کنید
    final isMinimized =
        ref.watch(playerDisplayProvider) == PlayerDisplayMode.minimized;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          top: 16.0,
          bottom: isMinimized ? 70.0 : 16.0, // 70 پیکسل برای پلیر کوچک
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notifier.rootDirectoryPath != null)
              Text(
                'مسیر ریشه: ${basename(notifier.rootDirectoryPath!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: asyncData.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('خطا: $error')),
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Text(
                        notifier.rootDirectoryPath == null
                            ? 'لطفاً پوشه ریشه دوره آموزشی خود را انتخاب کنید.'
                            : 'ساختار مورد نظر یافت نشد.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      return _SubjectExpansionTile(subject: subjects[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // متد ساخت ویجت پلیر شناور در Stack
  Widget _buildPlayerWidget(
    WidgetRef ref,
    PlayerDisplayMode mode,
    Topic topic,
  ) {
    // در این ساختار، پلیر بزرگ به صورت Modal نمایش داده می‌شود و نه به عنوان یک ویجت در Stack
    // بنابراین، ما فقط حالت Minimized را در Stack قرار می‌دهیم.
    if (mode == PlayerDisplayMode.minimized) {
      return Positioned(
        top: 0, // قرارگیری در بالای Stack
        left: 0,
        right: 0,
        child: MiniPlayerWidget(topic: topic),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(directoryDataProvider);
    final notifier = ref.read(directoryDataProvider.notifier);
    final displayMode = ref.watch(playerDisplayProvider);
    final topic = ref.watch(currentPlayingTopicProvider); // مبحث در حال پخش

    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب پوشه دوره آموزشی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: asyncData.isLoading ? null : () => _pickDirectory(ref),
          ),
          // دکمه باز کردن پلیر کوچک اگر در حالت minimized باشد و روی صفحه نیست
          if (displayMode != PlayerDisplayMode.hidden &&
              displayMode != PlayerDisplayMode.minimized)
            IconButton(
              icon: const Icon(Icons.music_note),
              onPressed: ref.read(playerDisplayProvider.notifier).minimize,
            ),
        ],
      ),
      // استفاده از Stack برای همپوشانی محتوای اصلی و پلیر شناور
      body: Stack(
        children: [
          // ۱. محتوای اصلی صفحه
          _buildMainContent(context, ref, asyncData, notifier),

          // ۲. ویجت پلیر شناور (اگر hidden نباشد و مبحثی برای پخش باشد)
          if (displayMode != PlayerDisplayMode.hidden && topic != null)
            _buildPlayerWidget(ref, displayMode, topic),
        ],
      ),
    );
  }
}

// --- ویجت‌های پیمایش (بدون تغییر عمده) ---

class _SubjectExpansionTile extends StatelessWidget {
  final Subject subject;
  const _SubjectExpansionTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        children: subject.lessons.map((lesson) {
          return _LessonExpansionTile(lesson: lesson);
        }).toList(),
      ),
    );
  }
}

class _LessonExpansionTile extends StatelessWidget {
  final Lesson lesson;
  const _LessonExpansionTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
        title: Text(
          'درس: ${lesson.name}',
          style: const TextStyle(fontSize: 16),
        ),
        children: lesson.topics.map((topic) {
          return _TopicListTile(topic: topic);
        }).toList(),
      ),
    );
  }
}

class _TopicListTile extends ConsumerWidget {
  final Topic topic;
  const _TopicListTile({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int fileCount = topic.audioFilePaths.length;

    return ListTile(
      contentPadding: const EdgeInsets.only(right: 32.0, left: 16.0),
      leading: Icon(
        fileCount > 0 ? Icons.music_note : Icons.music_off,
        color: fileCount > 0 ? Colors.indigo : Colors.grey,
      ),
      title: Text('مبحث: ${topic.name}', style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        fileCount > 0
            ? 'تعداد فایل‌های صوتی: $fileCount'
            : 'فایل صوتی یافت نشد.',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: fileCount > 0
          ? () async {
              final audioNotifier = ref.read(audioPlayerProvider.notifier);
              final displayNotifier = ref.read(playerDisplayProvider.notifier);
              final currentTopicNotifier = ref.read(
                currentPlayingTopicProvider.notifier,
              );

              // ۱. لود لیست پخش و شروع پخش
              await audioNotifier.loadPlaylist(topic);

              // ۲. ذخیره مبحث در حال پخش
              currentTopicNotifier.state = topic;

              // ۳. تغییر حالت نمایش به کوچک و شناور
              displayNotifier.minimize();
            }
          : null,
    );
  }
}
