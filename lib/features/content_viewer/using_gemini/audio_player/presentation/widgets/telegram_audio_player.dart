import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/audio_player/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/models.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/reading_canvas_screen.dart';
import 'package:ielts_assistant/features/content_viewer/using_gemini/text_render_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// 🐞 برای دکمه‌ی «برو به متن»: مکانیزمِ موجودِ اسکرول (در
// ReadingCanvasScreen) فقط از رویِ activeSearchProvider/SearchResult کار
// می‌کند (طراحی‌شده برای نتایجِ جستجو). به‌جای ساختِ یک مسیرِ کاملاً جدا،
// همان مکانیزمِ ثابت‌شده را با یک SearchResult مصنوعیِ تک‌عضوی دوباره
// استفاده می‌کنیم — query خالی می‌ماند تا هایلایتِ جستجو در متن فعال نشود؛
// paragraph هم یک ParagraphData خالیِ جای‌پرکن است چون در مسیرِ اسکرولِ
// فعلی اصلاً خوانده نمی‌شود (فقط pageNumber/paraIndex استفاده می‌شوند).
void _jumpToAudioLocation(WidgetRef ref, BuildContext context) {
  final playerState = ref.read(audioPlayerProvider);
  final target = playerState.targetLocation;
  if (target == null) return;
  final book = ref.read(activeBookProvider);
  if (book == null) return;

  final result = SearchResult(
    bookId: book.id,
    bookTitle: book.title,
    pageNumber: target.pageNumber,
    paraIndex: target.paraIndex,
    occurrenceIndex: 0,
    paragraph: ParagraphData(spans: const [], interactives: const []),
    matchedExcerpt: '',
    query: '',
  );
  final current = ref.read(activeSearchProvider);
  ref.read(activeSearchProvider.notifier).state = SearchSession(
    query: '',
    results: [result],
    currentIndex: 0,
    jumpTrigger: (current?.jumpTrigger ?? 0) + 1,
  );
  Navigator.of(context).pop();
}

class TelegramAudioPlayer extends ConsumerWidget {
  // final List<PageData> documentPages;
  final List<ParagraphData> audioScripts; // 🌟 به جای documentPages

  const TelegramAudioPlayer({super.key, required this.audioScripts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);

    // اگر فایلی برای پخش وجود ندارد، نوار را مخفی کن
    if (audioState.currentPath == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showFullPlayerModal(context, ref),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                audioState.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.blueAccent,
                size: 38,
              ),
              onPressed: () {
                final notifier = ref.read(audioPlayerProvider.notifier);
                audioState.isPlaying ? notifier.pause() : notifier.resume();
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: "مشاهده متن صوتی",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      AudioscriptViewerSheet(audioScripts: audioScripts),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded),
              tooltip: "پلی‌لیستِ کتاب",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _AudioPlaylistSheet(),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    audioState.currentPath!.split('/').last,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Tap to expand",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () =>
                  ref.read(audioPlayerProvider.notifier).stopAndClear(),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPlayerModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _FullPlayerBottomSheet(),
    );
  }
}

class _FullPlayerBottomSheet extends ConsumerWidget {
  const _FullPlayerBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final totalMs = state.duration.inMilliseconds.toDouble();

    // 🌟 منطق نمایش آیکون و رنگ برای دکمه رفتار پایان فایل
    IconData modeIcon;
    Color modeColor;
    String modeTooltip;

    switch (state.playbackMode) {
      case PlaybackMode.autoAdvance:
        modeIcon = Icons.playlist_play_rounded; // یا Icons.repeat
        modeColor = Colors.blueAccent;
        modeTooltip = "پخش پیوسته";
        break;
      case PlaybackMode.repeatOne:
        modeIcon = Icons.repeat_one_rounded;
        modeColor = Colors.orangeAccent;
        modeTooltip = "تکرار فایل فعلی";
        break;
      case PlaybackMode.stop:
        modeIcon = Icons.stop_circle_outlined;
        modeColor = Colors.white54;
        modeTooltip = "توقف پس از پایان";
        break;
    }

    return Container(
      height: 300, // 🌟 کمی ارتفاع بیشتر برای جا شدن دکمه‌ها
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    state.currentPath?.split('/').last ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.targetLocation != null) ...[
                  const SizedBox(width: 8),
                  // 🐞 «برو به متن»: کاربر را به دقیقاً همان صفحه/پاراگرافی
                  // می‌برد که یا اولین وقوعِ این فایل در کتاب است (اگر با
                  // قبلی/بعدی یا لیستِ پخش به این فایل رسیده‌ایم)، یا همان
                  // نقطه‌ی دقیقی که رویِ دکمه‌ی صوتیِ داخلِ متن تپ شده.
                  IconButton(
                    icon: const Icon(
                      Icons.subject_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    tooltip: 'برو به متن',
                    onPressed: () => _jumpToAudioLocation(ref, context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (state.pointA != null && totalMs > 0)
                      Positioned(
                        left:
                            (state.pointA!.inMilliseconds / totalMs) *
                                (constraints.maxWidth - 24) +
                            12,
                        top: 10,
                        bottom: 10,
                        child: Container(width: 2, color: Colors.orange),
                      ),
                    if (state.pointB != null && totalMs > 0)
                      Positioned(
                        left:
                            (state.pointB!.inMilliseconds / totalMs) *
                                (constraints.maxWidth - 24) +
                            12,
                        top: 10,
                        bottom: 10,
                        child: Container(width: 2, color: Colors.redAccent),
                      ),
                    Slider(
                      value: state.position.inMilliseconds.toDouble().clamp(
                        0,
                        totalMs > 0 ? totalMs : 1.0,
                      ),
                      max: totalMs > 0 ? totalMs : 1.0,
                      onChanged: (v) => ref
                          .read(audioPlayerProvider.notifier)
                          .seek(Duration(milliseconds: v.toInt())),
                      activeColor: Colors.blueAccent.withOpacity(0.7),
                      inactiveColor: Colors.white12,
                    ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildSmallCircleButton(
                        label: "A",
                        isActive: state.pointA != null,
                        onTap: () =>
                            ref.read(audioPlayerProvider.notifier).setPointA(),
                      ),
                      const SizedBox(width: 12.0),
                      _buildSmallCircleButton(
                        label: "B",
                        isActive: state.pointB != null,
                        onTap: () {
                          if (state.pointA != null)
                            ref.read(audioPlayerProvider.notifier).setPointB();
                        },
                      ),
                      if (state.pointA != null)
                        IconButton(
                          icon: const Icon(
                            Icons.layers_clear_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () =>
                              ref.read(audioPlayerProvider.notifier).clearAB(),
                          tooltip: 'پاک کردن',
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<double>(
                  initialValue: state.speed,
                  offset: const Offset(0, -200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${state.speed}x",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  onSelected: (value) =>
                      ref.read(audioPlayerProvider.notifier).setSpeed(value),
                  itemBuilder: (context) => <PopupMenuEntry<double>>[
                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    const PopupMenuItem(value: 0.8, child: Text('0.8x')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    const PopupMenuItem(value: 1.2, child: Text('1.2x')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                  ],
                ),

                // 🌟 دکمه تغییر حالت با طراحی جدید
                IconButton(
                  icon: Icon(modeIcon, color: modeColor),
                  tooltip: modeTooltip,
                  onPressed: () => ref
                      .read(audioPlayerProvider.notifier)
                      .togglePlaybackMode(),
                ),

                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌟 دکمه قبلی
              IconButton(
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).playPrevious(),
              ),
              const SizedBox(width: 8),

              IconButton(
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).skip10Sec(false),
              ),
              const SizedBox(width: 8),

              IconButton(
                icon: Icon(
                  state.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                color: Colors.white,
                iconSize: 65,
                onPressed: () => state.isPlaying
                    ? ref.read(audioPlayerProvider.notifier).pause()
                    : ref.read(audioPlayerProvider.notifier).resume(),
              ),

              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).skip10Sec(true),
              ),

              const SizedBox(width: 8),
              // 🌟 دکمه بعدی
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () =>
                    ref.read(audioPlayerProvider.notifier).playNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildSmallCircleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.orangeAccent : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.orangeAccent : Colors.white54,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// 🐞 پلی‌لیستِ کتاب: تمامِ فایل‌های صوتیِ یکتای این کتاب (دیدوپلیکیت‌شده،
// از همان state.playlist/firstOccurrence که با اولین تپِ روی هر دکمه‌ی
// صوتیِ داخلِ متن پر می‌شود). تپ‌کردن روی یک آیتم آن را پخش می‌کند (منبعِ
// sequential، چون از خودِ لیستِ پخش انتخاب شده، نه یک نقطه‌ی خاص از متن) و
// به اولین وقوعش در کتاب می‌رود.
class _AudioPlaylistSheet extends ConsumerWidget {
  const _AudioPlaylistSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);

    // 🐞 رفع اخطارِ «ListTile background color or ink splashes may be
    // invisible»: قبلاً این Containerِ بیرونی یک رنگِ توپُر داشت که بینِ
    // ListTileها و نزدیک‌ترین Materialِ اجدادی‌شان (از خودِ مودال) می‌نشست؛
    // چون این Container غیرشفاف بود، افکتِ ink splash را بصری می‌پوشاند.
    // Material خودش هم color و هم borderRadius را پشتیبانی می‌کند و دقیقاً
    // میزبانِ درستِ ink splash است (نه چیزی که جلویش را بگیرد)، پس همان
    // Container بیرونی را با Material جایگزین کردیم.
    return Material(
      color: const Color(0xFF1E222D),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "پلی‌لیستِ کتاب",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 20),
            Expanded(
              child: state.playlist.isEmpty
                  ? const Center(
                      child: Text(
                        "فایلِ صوتی‌ای در این کتاب یافت نشد.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.playlist.length,
                      itemBuilder: (context, index) {
                        final path = state.playlist[index];
                        final bool isCurrent = state.currentPath == path;
                        return ListTile(
                          leading: Icon(
                            isCurrent && state.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: isCurrent
                                ? Colors.orangeAccent
                                : Colors.white54,
                          ),
                          title: Text(
                            path.split('/').last,
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            // 🐞 رفع باگِ «هدایتِ نادرست بعدِ تپ روی پلی‌لیست»:
                            // playFile برای فایلِ متفاوت یک await
                            // _player.stop() اولش دارد — یعنی state (شاملِ
                            // targetLocation) فقط *بعدِ* آن await آپدیت
                            // می‌شود. بدونِ await صدا زدنِ playFile،
                            // _jumpToAudioLocation بلافاصله بعدش
                            // targetLocationِ کهنه (مالِ فایلِ قبلی) را
                            // می‌خواند.
                            await ref
                                .read(audioPlayerProvider.notifier)
                                .playFile(
                                  path,
                                  newPlaylist: state.playlist,
                                  newFirstOccurrence: state.firstOccurrence,
                                  // 🐞 explicitLocation عمداً پاس داده نمی‌شود:
                                  // انتخاب از خودِ لیستِ پخش، sequential است —
                                  // یعنی هدف باید اولین وقوعِ همین فایل باشد،
                                  // نه یک نقطه‌ی خاص.
                                );
                            if (!context.mounted) return;
                            _jumpToAudioLocation(ref, context);
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
}

class AudioSegment {
  final int startMs;
  final int endMs;
  final ParagraphData paragraph;

  AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.paragraph,
  });
}

class AudioscriptViewerSheet extends ConsumerStatefulWidget {
  final List<ParagraphData> audioScripts; // 🌟 جایگزین شد

  const AudioscriptViewerSheet({super.key, required this.audioScripts});

  @override
  ConsumerState<AudioscriptViewerSheet> createState() =>
      _AudioscriptViewerSheetState();
}

class _AudioscriptViewerSheetState
    extends ConsumerState<AudioscriptViewerSheet> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final int currentPosMs = audioState.position.inMilliseconds;
    final currentFileName = audioState.currentPath?.split('/').last ?? '';

    List<AudioSegment> currentSegments = [];

    for (var para in widget.audioScripts) {
      if (para.startMs != null &&
          para.endMs != null &&
          para.audioTrackName == currentFileName) {
        currentSegments.add(
          AudioSegment(
            startMs: para.startMs!,
            endMs: para.endMs!,
            paragraph: para,
          ),
        );
      }
    }

    // 🌟 مهم: استفاده از < به جای <= تا جملاتِ به هم چسبیده، با هم هایلایت نشوند
    int activeIndex = currentSegments.indexWhere(
      (seg) => currentPosMs >= seg.startMs && currentPosMs < seg.endMs,
    );

    if (activeIndex != -1 && activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: activeIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.3,
          );
        }
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E222D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Audioscript (متن صوتی)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),

          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.orangeAccent,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  "برای مشاهده ترجمه، روی متن لمس طولانی (Long Press) کنید",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          Expanded(
            child: currentSegments.isEmpty
                ? const Center(
                    child: Text(
                      "هیچ متن صوتی همگام‌سازی شده‌ای برای این بخش یافت نشد.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ScrollablePositionedList.builder(
                    itemCount: currentSegments.length,
                    itemScrollController: _itemScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    itemBuilder: (context, index) {
                      final segment = currentSegments[index];
                      final bool isActive = index == activeIndex;

                      String fullContent = segment.paragraph.spans
                          .map((s) => s.content)
                          .join();

                      Widget englishContent = AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.orangeAccent.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.orangeAccent.withOpacity(0.4)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: TextRenderEngine.buildInteractiveText(
                              fullContent,
                              segment.paragraph.interactives,
                              context,
                              TextStyle(
                                color: isActive
                                    ? Colors.orangeAccent
                                    : Colors.white70,
                                fontSize: isActive ? 17 : 15,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                height: 1.6,
                              ),
                              interactiveColor: isActive
                                  ? Colors.yellowAccent
                                  : Colors.cyanAccent,
                              translationFa: segment
                                  .paragraph
                                  .translationFa, // 🌟 پاس دادن به کامپوننت مادر
                              translationAr: segment.paragraph.translationAr,
                            ),
                          ),
                          textAlign: segment.paragraph.direction == "RTL"
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      );

                      return TranslatableContentWrapper(
                        originalContent: englishContent,
                        translationFa: segment.paragraph.translationFa,
                        translationAr: segment.paragraph.translationAr,
                        isDarkMode: true,
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF161922),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      audioState.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                    ),
                    iconSize: 48,
                    color: Colors.orangeAccent,
                    onPressed: () {
                      if (audioState.isPlaying) {
                        ref.read(audioPlayerProvider.notifier).pause();
                      } else {
                        ref.read(audioPlayerProvider.notifier).resume();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
