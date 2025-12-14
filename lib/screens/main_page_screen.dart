import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ielts_assistant/states/directory_state.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/screens/lesson_content_screen.dart';
import 'package:ielts_assistant/models/data_models.dart';
import 'package:ielts_assistant/states/selection_state.dart';
import 'package:ielts_assistant/services/audio_player_service.dart';
import 'package:ielts_assistant/services/storage_service.dart';
import 'package:ielts_assistant/widgets/custom_dropdown.dart';
import 'package:permission_handler/permission_handler.dart';

// ایمپورت مدل‌ها و سرویس‌ها
import '../states/player_display_state.dart';
import '../widgets/mini_player_widget.dart'; // ویجت پلیر کوچ

class MainPageScreen extends ConsumerWidget {
  final _storageService = StorageService();
  final GlobalKey<CustomDropdownState> _dropdownKeySubjects = GlobalKey();
  final GlobalKey<CustomDropdownState> _dropdownKeyUnits = GlobalKey();
  MainPageScreen({super.key});

  Future<void> _pickDirectory(WidgetRef ref) async {
    try {
      var res = await Permission.manageExternalStorage.status;
      if (!res.isGranted) {
        Permission.manageExternalStorage.request().then((onValue) async {
          var res2 = await Permission.manageExternalStorage.status;
          if (res2.isGranted) {
            try {
              bool existPreviousPath = false;
              String? previousPath = _storageService.getLastDirectoryPath();
              if (previousPath != null &&
                  await Directory(previousPath).exists()) {
                existPreviousPath = true;
              }
              final String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath(
                    initialDirectory: existPreviousPath ? previousPath : null,
                  );

              if (selectedDirectory != null) {
                if (selectedDirectory != previousPath) {
                  _storageService.saveLastDirectoryPath(selectedDirectory);
                }

                final notifier = ref.read(directoryDataProvider.notifier);
                await notifier.loadDirectoryData(selectedDirectory);
              }
            } catch (exception) {
              // TODO
            }
          }
        });
      } else if (res.isGranted) {
        try {
          bool existPreviousPath = false;
          String? previousPath = _storageService.getLastDirectoryPath();
          if (previousPath != null && await Directory(previousPath).exists()) {
            existPreviousPath = true;
          }
          final String? selectedDirectory = await FilePicker.platform
              .getDirectoryPath(
                initialDirectory: existPreviousPath ? previousPath : null,
              );

          if (selectedDirectory != null) {
            if (selectedDirectory != previousPath) {
              _storageService.saveLastDirectoryPath(selectedDirectory);
            }

            final notifier = ref.read(directoryDataProvider.notifier);
            await notifier.loadDirectoryData(selectedDirectory);
          }
        } catch (exception) {}
      }
    } catch (exception) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(directoryDataProvider);
    final notifier = ref.read(directoryDataProvider.notifier);
    final displayMode = ref.watch(playerDisplayProvider);
    final topic = ref.watch(currentPlayingTopicProvider); // مبحث در حال پخش
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(
          'دستیار آیلتس',
          style: TextStyle(fontFamily: FontFamily.yekanBakhBold.asText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: asyncData.isLoading
                ? null
                : () {
                    _pickDirectory(ref);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: asyncData.isLoading
                ? null
                : () async {
                    String? previousPath = _storageService
                        .getLastDirectoryPath();
                    if (previousPath != null &&
                        await Directory(previousPath).exists()) {
                      final notifier = ref.read(directoryDataProvider.notifier);
                      await notifier.loadDirectoryData(previousPath);
                    }
                  },
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
      body: Column(
        children: [
          asyncData.when(
            data: (data) {
              final subjects = data.map((x) => x.name).toList();
              final lessons = ref
                  .watch(lessonsProvider(ref.watch(selectedSubjectProvider)))
                  .when(
                    data: (data) {
                      return data;
                    },
                    error: (_, _) {
                      return <Lesson>[];
                    },
                    loading: () {
                      return <Lesson>[];
                    },
                  );
              if (subjects.isEmpty) {
                return SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    DropdownButton(
                      key: _dropdownKeySubjects,
                      value: ref.watch(selectedSubjectProvider)?.name,
                      items: subjects
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref.read(selectedSubjectProvider.notifier).state =
                              data.where((x) => x.name == value).firstOrNull;
                          ref.read(selectedLessonProvider.notifier).state =
                              null;
                          // _storageService.saveLastSubject(value);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_ios, size: 16.0),
                    ),
                    DropdownButton(
                      key: _dropdownKeyUnits,
                      value: ref.watch(selectedLessonProvider)?.name,
                      items: lessons
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.name,
                              child: Text(x.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref.read(selectedLessonProvider.notifier).state =
                              lessons.where((x) => x.name == value).firstOrNull;
                          // _storageService.saveLastLesson(value);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => CircularProgressIndicator(),
            error: (error, stack) => Text('خطا: $error'),
          ),
          // ۱. محتوای اصلی صفحه
          Expanded(child: _buildLessons(context, ref, asyncData, notifier)),

          // ۲. ویجت پلیر شناور (اگر hidden نباشد و مبحثی برای پخش باشد)
          if (displayMode != PlayerDisplayMode.hidden && topic != null)
            _buildPlayerWidget(ref, displayMode, topic),
        ],
      ),
    );
  }

  Widget _buildLessons(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Subject>> asyncData,
    DirectoryDataNotifier notifier,
  ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8.0),
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
                var selectedSubject = subjects
                    .where(
                      (x) => x.name == ref.watch(selectedSubjectProvider)?.name,
                    )
                    .firstOrNull;
                if (selectedSubject == null) {
                  return Center(
                    child: Text('لطفاً موضوع مورد نظر را انتخاب نمائید'),
                  );
                }
                var selectedLesson = selectedSubject.lessons
                    .where(
                      (x) => x.name == ref.watch(selectedLessonProvider)?.name,
                    )
                    .firstOrNull;
                if (selectedLesson == null) {
                  return Center(
                    child: Text('لطفاً درس مورد نظر را انتخاب نمائید'),
                  );
                }
                var units = selectedLesson.parentTopics;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: _ParentTopicExpansionTile(
                          parentTopic: units[index],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // child: ref.watch(selectedLessonProvider)?.name == null
            //     ?                   Center(
            //         child: Text(
            //           notifier.rootDirectoryPath == null
            //               ? 'لطفاً پوشه ریشه دوره آموزشی خود را انتخاب کنید.'
            //               : 'ساختار مورد نظر یافت نشد.',
            //         ),
            //       )
            //     : Padding(
            //       padding: const EdgeInsets.symmetric(horizontal: 8.0),
            //       child: ListView.builder(
            //         itemCount: subjects.,
            //         itemBuilder: (context, index) {
            //           return Directionality(
            //             textDirection: TextDirection.ltr,
            //             child: _SubjectExpansionTile(subject: subjects[index]),
            //           );
            //         },
            //       ),
            //     ),
          ),
        ],
      ),
    );
  }

  // ویجت اصلی که محتوای لیست پوشه‌ها را نمایش می‌دهد
  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Subject>> asyncData,
    DirectoryDataNotifier notifier,
  ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListView.builder(
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: _SubjectExpansionTile(subject: subjects[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
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
      return MiniPlayerWidget(subTopic: subTopic);
    }
    return const SizedBox.shrink();
  }
}

// ✅ تغییر به ConsumerStatefulWidget
class _ParentTopicExpansionTile extends ConsumerStatefulWidget {
  final ParentTopic parentTopic;
  const _ParentTopicExpansionTile({required this.parentTopic});

  @override
  ConsumerState<_ParentTopicExpansionTile> createState() =>
      _ParentTopicExpansionTileState();
}

class _ParentTopicExpansionTileState
    extends ConsumerState<_ParentTopicExpansionTile> {
  // وضعیت داخلی برای باز/بسته بودن
  bool _isExpanded = false;

  String? _lastOpenedParentId;
  String? _lastSelectedTopicId;
  @override
  void initState() {
    super.initState();

    // ۱. بررسی وضعیت آخرین SubTopic انتخاب شده
    final lastSelectedTopic = ref.read(lastSelectedTopicProvider);

    if (lastSelectedTopic != null) {
      // آیا آخرین انتخاب متعلق به این والد است؟
      final isChildSelected = widget.parentTopic.subTopics.any(
        (s) => s.realmId == lastSelectedTopic.realmId,
      );

      if (isChildSelected) {
        _isExpanded = true;
      }
    }
  }

  // ✅ متد مدیریت تغییر وضعیت باز/بسته شدن
  void _handleExpansionChange(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });

    // ۲. مدیریت Provider آخرین والد باز شده
    final notifier = ref.read(lastOpenedParentIdProvider.notifier);

    if (expanded) {
      notifier.state = widget.parentTopic.realmId;
    } else {
      // اگر این والد بسته شد و شناسه آن در Provider بود، آن را حذف کن
      if (notifier.state == widget.parentTopic.realmId) {
        notifier.state = null;
      }

      /*
      final lastSelectedTopic = ref.read(lastSelectedTopicProvider);
      if (lastSelectedTopic != null &&
          widget.parentTopic.subTopics.any(
            (s) => s.realmId == lastSelectedTopic.realmId,
          )) {
        // هنگام بسته شدن لیست، آخرین انتخاب SubTopic را نیز null می‌کنیم
        ref.read(lastSelectedTopicProvider.notifier).state = null;
      }
      */
    }
  }

  @override
  void deactivate() {
    // در اینجا (deactivate) هنوز استفاده از ref ایمن است.
    final lastSelectedTopic = ref.read(lastSelectedTopicProvider);
    _lastSelectedTopicId = lastSelectedTopic?.realmId;
    _lastOpenedParentId = ref.read(lastOpenedParentIdProvider);

    super.deactivate();
  }

  // ✅ متد dispose برای ریست کردن آخرین انتخاب
  @override
  void dispose() {
    // final lastSelectedTopic = ref.read(lastSelectedTopicProvider);
    // final lastOpenedParentId = ref.read(lastOpenedParentIdProvider);

    // if (lastOpenedParentId == widget.parentTopic.realmId ||
    //     (lastSelectedTopic != null &&
    //         widget.parentTopic.subTopics.any(
    //           (s) => s.realmId == lastSelectedTopic.realmId,
    //         ))) {
    //   // ریست کردن وضعیت انتخاب و والد
    //   ref.read(lastSelectedTopicProvider.notifier).state = null;
    //   ref.read(lastOpenedParentIdProvider.notifier).state = null;
    // }

    final bool wasLastOpenedParent =
        _lastOpenedParentId == widget.parentTopic.realmId;
    final bool wasChildSelected =
        _lastSelectedTopicId != null &&
        widget.parentTopic.subTopics.any(
          (s) => s.realmId == _lastSelectedTopicId,
        );

    if (wasLastOpenedParent || wasChildSelected) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 32.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
        title: Text(
          // مبحث اصلی
          widget.parentTopic.name, // ✅ استفاده از widget.parentTopic
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: _isExpanded, // ✅ استفاده از وضعیت داخلی
        onExpansionChanged: _handleExpansionChange, // ✅ متد مدیریت تغییر
        children: widget.parentTopic.subTopics.map((subTopic) {
          // ✅ استفاده از widget.parentTopic
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
          //! درس:
          lesson.name,
          style: const TextStyle(fontSize: 16),
        ),
        children: lesson.parentTopics.map((parentTopic) {
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
    final isCurrentlyLoaded =
        audioState.currentTopic?.realmId == subTopic.realmId;
    final isCurrentlyPlaying = isCurrentlyLoaded && audioState.isPlaying;

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
        // مبحث:
        subTopic.name,
        style: const TextStyle(fontSize: 14),
      ),
      // subtitle: Text(
      //   fileCount > 0
      //       ? 'تعداد فایل‌های صوتی: $fileCount'
      //       : 'فایل صوتی یافت نشد.',
      //   style: const TextStyle(fontSize: 12),
      // ),
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
                audioNotifier.stop();
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
