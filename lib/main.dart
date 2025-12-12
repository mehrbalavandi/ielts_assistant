import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/common/directory_state.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/lesson_content_screen.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/selection_state.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:path/path.dart' show basename;

// ایمپورت مدل‌ها و سرویس‌ها
import 'player_display_state.dart';
import 'mini_player_widget.dart'; // ویجت پلیر کوچک

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
      home: DirectoryPickerScreen(),
    );
  }
}

class DirectoryPickerScreen extends ConsumerWidget {
  final _storageBox = GetStorage(); // نمونه GetStorage
  DirectoryPickerScreen({super.key});

  Future<void> _pickDirectory(WidgetRef ref) async {
    bool existPreviousPath = false;
    String? previousPath = _storageBox.read(
      StorageVariables.lastRootDirectoryPath.name,
    );
    if (previousPath != null &&
        await Directory(
          _storageBox.read(StorageVariables.lastRootDirectoryPath.name),
        ).exists()) {
      existPreviousPath = true;
    }
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath(
          initialDirectory: existPreviousPath ? previousPath : null,
        );

    if (selectedDirectory != null) {
      if (selectedDirectory != previousPath) {
        await _storageBox.write(
          StorageVariables.lastRootDirectoryPath.name,
          selectedDirectory,
        );
      }

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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'مسیر اصلی: ${basename(notifier.rootDirectoryPath!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        return _SubjectExpansionTile(subject: subjects[index]);
                      },
                    ),
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
    SubTopic subTopic,
  ) {
    // در این ساختار، پلیر بزرگ به صورت Modal نمایش داده می‌شود و نه به عنوان یک ویجت در Stack
    // بنابراین، ما فقط حالت Minimized را در Stack قرار می‌دهیم.
    if (mode == PlayerDisplayMode.minimized) {
      return Positioned(
        top: 0, // قرارگیری در بالای Stack
        left: 0,
        right: 0,
        child: MiniPlayerWidget(subTopic: subTopic),
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

// ۱. ویجت جدید برای Parent Topic (جایگزین _TopicListTile قبلی)
class _ParentTopicExpansionTile extends StatelessWidget {
  final ParentTopic parentTopic;
  const _ParentTopicExpansionTile({required this.parentTopic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 32.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
        title: Text(
          'مبحث اصلی: ${parentTopic.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        children: parentTopic.subTopics.map((subTopic) {
          // هدایت به ویجت نهایی SubTopic (جایگزین _TopicListTile قبلی)
          return _SubTopicListTile(subTopic: subTopic);
        }).toList(),
      ),
    );
  }
}

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
        children: lesson.topics.map((parentTopic) {
          // درس شامل لیست ParentTopic است
          return _ParentTopicExpansionTile(
            parentTopic: parentTopic,
          ); // فراخوانی ویجت جدید
        }).toList(),
      ),
    );
  }
}

class _SubTopicListTile extends ConsumerWidget {
  final SubTopic subTopic;
  const _SubTopicListTile({required this.subTopic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // خواندن وضعیت آخرین انتخاب
    final SubTopic? lastSelectedTopic = ref.watch(lastSelectedTopicProvider);
    final bool isLastSelected = lastSelectedTopic?.realmId == subTopic.realmId;

    final int fileCount = subTopic.audioFilePaths.length;
    final bool hasAudio = fileCount > 0;
    final bool hasContent =
        subTopic.jsonFilePath.isNotEmpty &&
        subTopic.translationFilePath.isNotEmpty; // ✅ چک کردن وجود فایل JSON

    // ✅ مبحث فعال است اگر فایل صوتی یا فایل محتوا داشته باشد
    final bool isSelectable = hasAudio || hasContent;

    // ۱. بررسی مبحث در حال پخش: مقایسه بر اساس realmId (مسیر کامل)
    final audioNotifier = ref.read(audioPlayerProvider.notifier);
    final audioState = ref.watch(audioPlayerProvider);
    final isCurrentlyPlaying =
        audioNotifier.currentTopic?.realmId == subTopic.realmId &&
        audioState.isPlaying;

    final Color backgroundColor = isLastSelected
        ? Colors
              .yellow
              .shade100 // رنگ متمایز کننده برای آخرین انتخاب
        : Colors.transparent; // رنگ عادی

    return ListTile(
      tileColor: backgroundColor,
      contentPadding: const EdgeInsets.only(right: 32.0, left: 16.0),
      leading: Icon(
        fileCount > 0 ? Icons.music_note : Icons.music_off,
        color: fileCount > 0 ? Colors.indigo : Colors.grey,
      ),
      title: Text(
        'مبحث: ${subTopic.name}',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        fileCount > 0
            ? 'تعداد فایل‌های صوتی: $fileCount'
            : 'فایل صوتی یافت نشد.',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: isSelectable
          ? () async {
              final displayNotifier = ref.read(playerDisplayProvider.notifier);
              final currentTopicNotifier = ref.read(
                currentPlayingTopicProvider.notifier,
              );
              if (hasAudio) {
                if (!isCurrentlyPlaying) {
                  // اگر در حال پخش نیست، لود و پخش کن
                  await audioNotifier.loadPlaylist(subTopic);
                  currentTopicNotifier.state = subTopic;
                }
                displayNotifier.minimize();
              } else {
                // ب. اگر فایل صوتی ندارد (فقط محتوا دارد):

                // اگر پلیر در حال پخش هر فایل دیگری است، آن را متوقف کن
                if (audioNotifier.currentTopic != null &&
                    audioNotifier.currentTopic?.realmId != subTopic.realmId) {
                  audioNotifier.stop();
                }

                // پلیر را پنهان کن (چون چیزی برای پخش وجود ندارد)
                displayNotifier.hide();
              }
              ref.read(lastSelectedTopicProvider.notifier).state = subTopic;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LessonContentScreen(topic: subTopic),
                ),
              );
            }
          : null,
    );
  }
}
