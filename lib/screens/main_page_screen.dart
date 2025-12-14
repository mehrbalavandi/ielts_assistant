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
  final GlobalKey<CustomDropdownState> _dropdownKeybooks = GlobalKey();
  final GlobalKey<CustomDropdownState> _dropdownKeyUnits = GlobalKey();
  final GlobalKey<CustomDropdownState> _dropdownKeyMainTopics = GlobalKey();
  final GlobalKey<CustomDropdownState> _dropdownKeySubTopics = GlobalKey();
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
              final books = data.map((x) => x.name).toList();

              if (books.isEmpty) {
                return SizedBox.shrink();
              }
              final units = ref
                  .watch(unitsProvider(ref.watch(selectedBookProvider)))
                  .when(
                    data: (data) {
                      return data;
                    },
                    error: (_, _) {
                      return <Unit>[];
                    },
                    loading: () {
                      return <Unit>[];
                    },
                  );
              final mainTopics = ref
                  .watch(mainTopicsProvider(ref.watch(selectedUnitProvider)))
                  .when(
                    data: (data) {
                      return data;
                    },
                    error: (_, _) {
                      return <MainTopic>[];
                    },
                    loading: () {
                      return <MainTopic>[];
                    },
                  );
              final subTopics = ref
                  .watch(
                    subTopicsProvider(ref.watch(selectedMainTopicProvider)),
                  )
                  .when(
                    data: (data) {
                      return data;
                    },
                    error: (_, _) {
                      return <SubTopic>[];
                    },
                    loading: () {
                      return <SubTopic>[];
                    },
                  );
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton(
                      key: _dropdownKeybooks,
                      value: ref.watch(selectedBookProvider)?.name,
                      items: books
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref.read(selectedBookProvider.notifier).state = data
                              .where((x) => x.name == value)
                              .firstOrNull;
                          ref.read(selectedUnitProvider.notifier).state = null;
                          // _storageService.saveLastbook(value);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_ios, size: 16.0),
                    ),
                    DropdownButton(
                      key: _dropdownKeyUnits,
                      value: ref.watch(selectedUnitProvider)?.name,
                      items: units
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.name,
                              child: Text(x.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref.read(selectedUnitProvider.notifier).state = units
                              .where((x) => x.name == value)
                              .firstOrNull;
                          // _storageService.saveLastunit(value);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_ios, size: 16.0),
                    ),
                    DropdownButton(
                      key: _dropdownKeyMainTopics,
                      value: ref.watch(selectedMainTopicProvider)?.name,
                      items: mainTopics
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.name,
                              child: Text(x.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref
                              .read(selectedMainTopicProvider.notifier)
                              .state = mainTopics
                              .where((x) => x.name == value)
                              .firstOrNull;
                          // _storageService.saveLastunit(value);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_ios, size: 16.0),
                    ),
                    DropdownButton(
                      key: _dropdownKeySubTopics,
                      value: ref.watch(selectedSubTopicProvider)?.name,
                      items: subTopics
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.name,
                              child: Text(x.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          ref
                              .read(selectedSubTopicProvider.notifier)
                              .state = subTopics
                              .where((x) => x.name == value)
                              .firstOrNull;
                          // _storageService.saveLastunit(value);
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
          Expanded(child: _buildUnits(context, ref, asyncData, notifier)),

          // ۲. ویجت پلیر شناور (اگر hidden نباشد و مبحثی برای پخش باشد)
          if (displayMode != PlayerDisplayMode.hidden && topic != null)
            _buildPlayerWidget(ref, displayMode, topic),
        ],
      ),
    );
  }

  Widget _buildUnits(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Book>> asyncData,
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
              data: (books) {
                if (books.isEmpty) {
                  return Center(
                    child: Text(
                      notifier.rootDirectoryPath == null
                          ? 'لطفاً پوشه ریشه دوره آموزشی خود را انتخاب کنید.'
                          : 'ساختار مورد نظر یافت نشد.',
                    ),
                  );
                }
                var selectedBook = books
                    .where(
                      (x) => x.name == ref.watch(selectedBookProvider)?.name,
                    )
                    .firstOrNull;
                if (selectedBook == null) {
                  return Center(
                    child: Text('لطفاً موضوع مورد نظر را انتخاب نمائید'),
                  );
                }
                var selectedUnit = selectedBook.units
                    .where(
                      (x) => x.name == ref.watch(selectedUnitProvider)?.name,
                    )
                    .firstOrNull;
                if (selectedUnit == null) {
                  return Center(
                    child: Text('لطفاً درس مورد نظر را انتخاب نمائید'),
                  );
                }
                var units = selectedUnit.mainTopics;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: _mainTopicExpansionTile(mainTopic: units[index]),
                      );
                    },
                  ),
                );
              },
            ),
            // child: ref.watch(selectedunitProvider)?.name == null
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
            //         itemCount: books.,
            //         itemBuilder: (context, index) {
            //           return Directionality(
            //             textDirection: TextDirection.ltr,
            //             child: _bookExpansionTile(book: books[index]),
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
  // Widget _buildMainContent(
  //   BuildContext context,
  //   WidgetRef ref,
  //   AsyncValue<List<Book>> asyncData,
  //   DirectoryDataNotifier notifier,
  // ) {
  //   return Directionality(
  //     textDirection: TextDirection.rtl,
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const SizedBox(height: 8.0),
  //         Expanded(
  //           child: asyncData.when(
  //             loading: () => const Center(child: CircularProgressIndicator()),
  //             error: (error, stack) => Center(child: Text('خطا: $error')),
  //             data: (books) {
  //               if (books.isEmpty) {
  //                 return Center(
  //                   child: Text(
  //                     notifier.rootDirectoryPath == null
  //                         ? 'لطفاً پوشه ریشه دوره آموزشی خود را انتخاب کنید.'
  //                         : 'ساختار مورد نظر یافت نشد.',
  //                   ),
  //                 );
  //               }

  //               return Padding(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //                 child: ListView.builder(
  //                   itemCount: books.length,
  //                   itemBuilder: (context, index) {
  //                     return Directionality(
  //                       textDirection: TextDirection.ltr,
  //                       child: _bookExpansionTile(book: books[index]),
  //                     );
  //                   },
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // متد ساخت ویجت پلیر شناور در Stack
  Widget _buildPlayerWidget(
    WidgetRef ref,
    PlayerDisplayMode mode,
    FinalTopic mainTopic,
  ) {
    // در این ساختار، پلیر بزرگ به صورت Modal نمایش داده می‌شود و نه به عنوان یک ویجت در Stack
    // بنابراین، ما فقط حالت Minimized را در Stack قرار می‌دهیم.
    if (mode == PlayerDisplayMode.minimized) {
      return MiniPlayerWidget(mainTopic: mainTopic);
    }
    return const SizedBox.shrink();
  }
}

// ✅ تغییر به ConsumerStatefulWidget
class _mainTopicExpansionTile extends ConsumerStatefulWidget {
  final MainTopic mainTopic;
  const _mainTopicExpansionTile({required this.mainTopic});

  @override
  ConsumerState<_mainTopicExpansionTile> createState() =>
      _mainTopicExpansionTileState();
}

class _mainTopicExpansionTileState
    extends ConsumerState<_mainTopicExpansionTile> {
  // وضعیت داخلی برای باز/بسته بودن
  bool _isExpanded = false;

  String? _lastOpenedParentId;
  String? _lastSelectedTopicId;
  @override
  void initState() {
    super.initState();

    // ۱. بررسی وضعیت آخرین mainTopic انتخاب شده
    final lastSelectedTopic = ref.read(lastSelectedTopicProvider);

    if (lastSelectedTopic != null) {
      // آیا آخرین انتخاب متعلق به این والد است؟
      final isChildSelected = widget.mainTopic.subTopics.any(
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
      notifier.state = widget.mainTopic.realmId;
    } else {
      // اگر این والد بسته شد و شناسه آن در Provider بود، آن را حذف کن
      if (notifier.state == widget.mainTopic.realmId) {
        notifier.state = null;
      }

      /*
      final lastSelectedTopic = ref.read(lastSelectedTopicProvider);
      if (lastSelectedTopic != null &&
          widget.mainTopic.mainTopics.any(
            (s) => s.realmId == lastSelectedTopic.realmId,
          )) {
        // هنگام بسته شدن لیست، آخرین انتخاب mainTopic را نیز null می‌کنیم
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

    // if (lastOpenedParentId == widget.mainTopic.realmId ||
    //     (lastSelectedTopic != null &&
    //         widget.mainTopic.mainTopics.any(
    //           (s) => s.realmId == lastSelectedTopic.realmId,
    //         ))) {
    //   // ریست کردن وضعیت انتخاب و والد
    //   ref.read(lastSelectedTopicProvider.notifier).state = null;
    //   ref.read(lastOpenedParentIdProvider.notifier).state = null;
    // }

    final bool wasLastOpenedParent =
        _lastOpenedParentId == widget.mainTopic.realmId;
    final bool wasChildSelected =
        _lastSelectedTopicId != null &&
        widget.mainTopic.subTopics.any(
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
          widget.mainTopic.name, // ✅ استفاده از widget.mainTopic
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: _isExpanded, // ✅ استفاده از وضعیت داخلی
        onExpansionChanged: _handleExpansionChange, // ✅ متد مدیریت تغییر
        children: widget.mainTopic.subTopics.map((mainTopic) {
          // ✅ استفاده از widget.mainTopic
          return _mainTopicListTile(finalTopic: mainTopic.finalTopics.first);
        }).toList(),
      ),
    );
  }
}

class _bookExpansionTile extends StatelessWidget {
  final Book book;
  const _bookExpansionTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          book.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        children: book.units.map((unit) {
          return _unitExpansionTile(unit: unit);
        }).toList(),
      ),
    );
  }
}

class _unitExpansionTile extends StatelessWidget {
  final Unit unit;
  const _unitExpansionTile({required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
        title: Text(
          //! درس:
          unit.name,
          style: const TextStyle(fontSize: 16),
        ),
        children: unit.mainTopics.map((mainTopic) {
          // درس شامل لیست mainTopic است
          return _mainTopicExpansionTile(
            mainTopic: mainTopic,
          ); // فراخوانی ویجت جدید
        }).toList(),
      ),
    );
  }
}

class _mainTopicListTile extends ConsumerWidget {
  final FinalTopic finalTopic;
  const _mainTopicListTile({required this.finalTopic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // خواندن وضعیت آخرین انتخاب
    final FinalTopic? lastSelectedTopic = ref.watch(lastSelectedTopicProvider);
    final bool isLastSelected =
        lastSelectedTopic?.realmId == finalTopic.realmId;

    final int fileCount = finalTopic.audioFilePaths.length;
    final bool hasAudio = fileCount > 0;
    final bool hasContent =
        finalTopic.jsonFilePath.isNotEmpty &&
        finalTopic.translationFilePath.isNotEmpty; // ✅ چک کردن وجود فایل JSON

    // ✅ مبحث فعال است اگر فایل صوتی یا فایل محتوا داشته باشد
    final bool isSelectable = hasAudio || hasContent;

    // ۱. بررسی مبحث در حال پخش: مقایسه بر اساس realmId (مسیر کامل)
    final audioNotifier = ref.read(audioPlayerProvider.notifier);
    final audioState = ref.watch(audioPlayerProvider);
    final isCurrentlyLoaded =
        audioState.currentTopic?.realmId == finalTopic.realmId;
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
        finalTopic.name,
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
                  await audioNotifier.loadPlaylist(finalTopic);
                  currentTopicNotifier.state = finalTopic;
                }
                displayNotifier.minimize();
              } else {
                audioNotifier.stop();
                // پلیر را پنهان کن (چون چیزی برای پخش وجود ندارد)
                displayNotifier.hide();
              }
              ref.read(lastSelectedTopicProvider.notifier).state = finalTopic;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => unitContentScreen(topic: finalTopic),
                ),
              );
            }
          : null,
    );
  }
}
