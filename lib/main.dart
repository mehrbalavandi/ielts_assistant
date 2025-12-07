import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/directory_state.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:path/path.dart' show basename;
// import 'realm_service.dart'; // فرض می‌کنیم RealmService تعریف شده است

void main() {
  runApp(
    // استفاده از ProviderScope در بالاترین سطح برای Riverpod
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Course Navigator',
      debugShowCheckedModeBanner: false,
      // تنظیمات برای پشتیبانی زبان فارسی (راست به چپ)
      // locale: const Locale("fa", "IR"),
      supportedLocales: const [Locale("fa", "IR"), Locale("en", "US")],
      locale: Locale("en", "US"),
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
    // از file_picker برای انتخاب پوشه استفاده می شود
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath();

    if (selectedDirectory != null) {
      final notifier = ref.read(directoryDataProvider.notifier);
      await notifier.loadDirectoryData(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(directoryDataProvider);
    final notifier = ref.read(directoryDataProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب پوشه دوره آموزشی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: asyncData.isLoading ? null : () => _pickDirectory(ref),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, // جهت متن
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                // مدیریت حالت‌های لودینگ، خطا و داده با استفاده از asyncData.when
                child: asyncData.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('خطا: $error')),
                  data: (subjects) {
                    if (subjects.isEmpty) {
                      return Center(
                        child: Text(
                          notifier.rootDirectoryPath == null
                              ? 'لطفاً پوشه ریشه را انتخاب کنید.'
                              : 'ساختار مورد نظر یافت نشد.',
                        ),
                      );
                    }

                    // نمایش فهرست کتاب‌ها (ریاضی ۱، ۲، ...)
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
      ),
    );
  }
}

// ویجت سطح ۱: نمایش کتاب و دروس با ExpansionTile
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
        // لیست دروس (Level 2)
        children: subject.lessons.map((lesson) {
          return _LessonExpansionTile(lesson: lesson);
        }).toList(),
      ),
    );
  }
}

// ویجت سطح ۲: نمایش درس و مباحث آن با ExpansionTile
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
        // لیست مباحث (Level 3)
        children: lesson.topics.map((topic) {
          return _TopicListTile(topic: topic);
        }).toList(),
      ),
    );
  }
}

// ویجت سطح ۳: نمایش مبحث نهایی و فایل‌های آن با ListTile
class _TopicListTile extends ConsumerWidget {
  final Topic topic;
  const _TopicListTile({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 32.0, left: 16.0),
      leading: const Icon(Icons.music_note, color: Colors.indigo),
      title: Text('مبحث: ${topic.name}', style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        'فایل صوتی: ${basename(topic.audioFilePath)}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () async {
        // TODO:
        // ۱. موقعیت ذخیره شده در Realm را با استفاده از topic.realmId بخوانید.
        // ۲. یک نمونه AudioPlayer (just_audio/audioplayers) ایجاد کنید.
        // ۳. فایل صوتی را با موقعیت اولیه (از Realm) لود و پخش کنید.
        // ۴. stream موقعیت پخش را برای به‌روزرسانی Realm در پس‌زمینه گوش دهید.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('شروع پخش فایل: ${basename(topic.audioFilePath)}'),
          ),
        );
      },
    );
  }
}
