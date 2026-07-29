import 'package:flutter/gestures.dart';
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

// 🐞 قبلاً رنگ‌های این ویجت‌ها (پس‌زمینه، نارنجیِ هایلایت، فیروزه‌ایِ کلماتِ
// تعاملی و ...) کاملاً مستقل و ثابت بودند — هیچ ربطی به رنگِ اپ نداشتند.
// این تابع یک پالتِ تیره از رویِ همان seedColorِ خودِ اپ (که در main.dart
// تعریف شده) می‌سازد — یعنی اگر بعداً رنگِ برندِ اپ عوض شود یا کاربر
// بتواند تم انتخاب کند، همین پلیر هم خودکار هماهنگ می‌ماند، بدونِ نیاز به
// دست‌کاریِ دوباره‌ی رنگ‌های این فایل.
class _PlayerColors {
  final Color bgTop;
  final Color bgBottom;
  final Color barBg;
  final Color accent; // قبلاً Colors.orangeAccent
  final Color onAccent; // متن/آیکون روی accent
  final Color interactive; // قبلاً Colors.cyanAccent (کلماتِ تعاملی)
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  _PlayerColors({
    required this.bgTop,
    required this.bgBottom,
    required this.barBg,
    required this.accent,
    required this.onAccent,
    required this.interactive,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });
}

_PlayerColors _playerColors(BuildContext context) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Theme.of(context).colorScheme.primary,
    brightness: Brightness.dark,
  );
  return _PlayerColors(
    bgTop: Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.12)!,
    bgBottom: scheme.surface,
    barBg: scheme.surfaceContainerHighest,
    accent: scheme.tertiary,
    onAccent: scheme.onTertiary,
    interactive: scheme.secondary,
    textPrimary: scheme.onSurface,
    textSecondary: scheme.onSurface.withOpacity(0.7),
    divider: scheme.onSurface.withOpacity(0.12),
  );
}

class TelegramAudioPlayer extends ConsumerWidget {
  // final List<PageData> documentPages;
  final List<AudioScriptTrack> audioScripts; // 🌟 به جای documentPages

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
              tooltip: "مشاهده متن صوتی + کنترل‌های پخش",
              onPressed: () =>
                  showCombinedPlayerModal(context, ref, audioScripts),
            ),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded),
              tooltip: "پلی‌لیستِ کتاب",
              onPressed: () => showBookAudioPlaylist(context),
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
    showCombinedPlayerModal(context, ref, audioScripts);
  }
}

// 🐞 پلی‌لیستِ کتاب: قبلاً فقط از داخلِ نوارِ کوچکِ پلیر (که تا وقتی هیچ
// فایلی پخش نشده اصلاً نمایش داده نمی‌شد) در دسترس بود — یعنی برای دیدنِ
// پلی‌لیست، اول باید یک فایل را پخش می‌کردید. حالا این یک تابعِ سطحِ‌بالا
// و عمومی است تا از هرجایی (مثلاً یک آیکونِ همیشه‌دیده در AppBar) بشود
// صدایش زد، مستقل از این‌که چیزی در حالِ پخش هست یا نه.
void showBookAudioPlaylist(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AudioPlaylistSheet(),
  );
}

// 🐞 ادغامِ AudioscriptViewerSheet و _FullPlayerBottomSheet: قبلاً این دو
// شیتِ جدا بودند — یکی متنِ اسکریپت را نشان می‌داد، دیگری کنترل‌های کاملِ
// پخش (نوارِ پیشرفت، A/B، سرعت، حالت، قبلی/بعدی) را؛ برای دسترسی به
// کنترل‌ها موقعِ خواندنِ متن، باید یکی را می‌بستید و دیگری را باز
// می‌کردید. حالا هر دو مسیرِ ورودی (آیکونِ توضیحاتِ متن، و خودِ تپ‌کردنِ
// رویِ نوارِ کوچک) به همین یک شیتِ ادغام‌شده می‌روند.
void showCombinedPlayerModal(
  BuildContext context,
  WidgetRef ref,
  List<AudioScriptTrack> audioScripts,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CombinedAudioSheet(audioScripts: audioScripts),
  );
}

class _AudioPlaylistSheet extends ConsumerWidget {
  const _AudioPlaylistSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final colors = _playerColors(context);

    // 🐞 رفع اخطارِ «ListTile background color or ink splashes may be
    // invisible»: قبلاً این Containerِ بیرونی یک رنگِ توپُر داشت که بینِ
    // ListTileها و نزدیک‌ترین Materialِ اجدادی‌شان (از خودِ مودال) می‌نشست؛
    // چون این Container غیرشفاف بود، افکتِ ink splash را بصری می‌پوشاند.
    // Material خودش هم color و هم borderRadius را پشتیبانی می‌کند و دقیقاً
    // میزبانِ درستِ ink splash است (نه چیزی که جلویش را بگیرد)، پس همان
    // Container بیرونی را با Material جایگزین کردیم.
    return Material(
      color: colors.bgBottom,
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
                            color: isCurrent ? colors.accent : Colors.white54,
                          ),
                          title: Text(
                            path.split('/').last,
                            style: TextStyle(
                              color: isCurrent ? colors.accent : Colors.white70,
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

// 🐞 ادغامِ AudioscriptViewerSheet و _FullPlayerBottomSheet در یک ویجت:
// قبلاً برای دیدنِ متنِ اسکریپت باید یک شیت را می‌بستید تا به کنترل‌های
// کاملِ پخش (نوارِ پیشرفت، A/B، سرعت، حالت، قبلی/بعدی) در شیتِ دیگر
// برسید. حالا هر دو در همین یک ویجت‌اند — متن به‌صورتِ اسکرول‌شونده در
// وسط، و نوارِ کنترل‌های کامل همیشه پایین ثابت است.
class CombinedAudioSheet extends ConsumerStatefulWidget {
  final List<AudioScriptTrack> audioScripts;

  const CombinedAudioSheet({super.key, required this.audioScripts});

  @override
  ConsumerState<CombinedAudioSheet> createState() => _CombinedAudioSheetState();
}

class _CombinedAudioSheetState extends ConsumerState<CombinedAudioSheet> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;
  // 🐞 در build() مقداردهی می‌شود؛ چون _buildSmallCircleButton هم به آن
  // نیاز دارد (و context ندارد)، به‌عنوانِ فیلدِ کلاس نگه داشته می‌شود.
  late _PlayerColors _colors;

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
          color: isActive ? _colors.accent : Colors.transparent,
          border: Border.all(
            color: isActive ? _colors.accent : Colors.white54,
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

  @override
  Widget build(BuildContext context) {
    _colors = _playerColors(context);
    final audioState = ref.watch(audioPlayerProvider);
    final int currentPosMs = audioState.position.inMilliseconds;
    final currentFileName = audioState.currentPath?.split('/').last ?? '';
    final double totalMs = audioState.duration.inMilliseconds.toDouble();

    // 🐞 AudioTrackName حالا فقط یک‌بار در سطحِ خودِ تراک است (نه تکرارشده
    // روی هر پاراگراف/اسپن مثلِ قبل) — پس فقط باید تراکِ همین فایل را پیدا
    // کنیم، نه این‌که هر پاراگراف را جداگانه فیلتر کنیم.
    List<ParagraphData> paragraphs = const [];
    for (final track in widget.audioScripts) {
      if (track.audioTrackName == currentFileName) {
        paragraphs = track.paragraphs;
        break;
      }
    }

    // 🐞 کدام پاراگراف الان فعال است؟ یعنی حداقل یک اسپنِ داخلش بازه‌ی
    // زمانیِ StartMs تا EndMs، لحظه‌ی فعلی را در بر می‌گیرد. مهم: از < استفاده
    // می‌شود (نه <=) تا کلماتِ به‌هم‌چسبیده با هم هایلایت نشوند.
    int activeIndex = -1;
    for (int i = 0; i < paragraphs.length; i++) {
      final bool hasActiveSpan = paragraphs[i].spans.any(
        (s) =>
            s.startMs != null &&
            s.endMs != null &&
            currentPosMs >= s.startMs! &&
            currentPosMs < s.endMs!,
      );
      if (hasActiveSpan) {
        activeIndex = i;
        break;
      }
    }

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

    // 🌟 منطق نمایش آیکون و رنگ برای دکمه رفتار پایان فایل
    IconData modeIcon;
    Color modeColor;
    String modeTooltip;
    switch (audioState.playbackMode) {
      case PlaybackMode.autoAdvance:
        modeIcon = Icons.playlist_play_rounded;
        modeColor = Colors.blueAccent;
        modeTooltip = "پخش پیوسته";
        break;
      case PlaybackMode.repeatOne:
        modeIcon = Icons.repeat_one_rounded;
        modeColor = _colors.accent;
        modeTooltip = "تکرار فایل فعلی";
        break;
      case PlaybackMode.stop:
        modeIcon = Icons.stop_circle_outlined;
        modeColor = Colors.white54;
        modeTooltip = "توقف پس از پایان";
        break;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        // 🐞 پولیشِ ظاهری: به‌جای رنگِ تخت، یک گرادیانِ ملایم برای عمق و
        // حسِ بهترِ بصری.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_colors.bgTop, _colors.bgBottom],
        ),
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
                Expanded(
                  child: Text(
                    audioState.currentPath?.split('/').last ??
                        "(متن صوتی)", // = Audioscript
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (audioState.targetLocation != null)
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 20),

          // const Padding(
          //   padding: EdgeInsets.only(bottom: 8.0),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       Icon(
          //         Icons.lightbulb_outline_rounded,
          //         color: _colors.accent,
          //         size: 14,
          //       ),
          //       SizedBox(width: 4),
          //       Text(
          //         "برای مشاهده ترجمه، روی متن لمس طولانی (Long Press) کنید",
          //         style: TextStyle(color: Colors.white54, fontSize: 11),
          //       ),
          //     ],
          //   ),
          // ),
          Expanded(
            child: paragraphs.isEmpty
                ? const Center(
                    child: Text(
                      "هیچ متن صوتی همگام‌سازی شده‌ای برای این بخش یافت نشد.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ScrollablePositionedList.builder(
                    itemCount: paragraphs.length,
                    itemScrollController: _itemScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    itemBuilder: (context, index) {
                      final para = paragraphs[index];
                      final bool paraIsActive = index == activeIndex;

                      final List<InlineSpan> richSpans = [];
                      for (final span in para.spans) {
                        final bool isActiveWord =
                            paraIsActive &&
                            span.startMs != null &&
                            span.endMs != null &&
                            currentPosMs >= span.startMs! &&
                            currentPosMs < span.endMs!;

                        final TextStyle baseStyle =
                            TextRenderEngine.applySpanStyle(
                              const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.6,
                              ),
                              span,
                              true, // isDarkTheme
                            );
                        // 🐞 applySpanStyle فقط بولد/ایتالیک/زیرخط/سایز/رنگ را
                        // اعمال می‌کند — مارکرِ "fn:" (خانواده‌ی فونت) را
                        // اصلاً نمی‌فهمد؛ متنِ اصلیِ کتاب این را جداگانه (با
                        // mapFontFamily) اضافه می‌کند، ولی این‌جا قبلاً از
                        // قلم نیفتاده بود. همان الگو را این‌جا هم تکرار
                        // می‌کنیم تا اسکریپتِ صوتی هم فونتِ درست (مثلاً برای
                        // متنِ فارسی/عربی) بگیرد، نه همیشه فونتِ پیش‌فرض.
                        // 🐞 مثلِ fn:، مارکرِ sz: (اندازه‌ی فونت، بر حسبِ
                        // نیم‌پوینتِ Word) هم قبلاً اصلاً اعمال نمی‌شد —
                        // اندازه همیشه همان مقدارِ پیش‌فرضِ ثابت (15) بود،
                        // نه اندازه‌ی واقعیِ سندِ Word. همان تبدیلِ
                        // نیم‌پوینت→پوینت که متنِ اصلیِ کتاب استفاده می‌کند
                        // (تقسیم بر ۲) این‌جا هم تکرار شده.
                        String? fontFamily;
                        double? fontSize;
                        for (final marker in span.markers) {
                          if (marker.startsWith("fn:")) {
                            fontFamily = mapFontFamily(marker.substring(3));
                          } else if (marker.startsWith("sz:")) {
                            final parsed = double.tryParse(marker.substring(3));
                            if (parsed != null) fontSize = parsed / 2;
                          }
                        }
                        final TextStyle styledBase = baseStyle.copyWith(
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                        );

                        final List<InlineSpan> rawSpans =
                            TextRenderEngine.buildInteractiveText(
                              span.content,
                              para.interactives,
                              context,
                              styledBase.copyWith(
                                color: isActiveWord
                                    ? Colors.black
                                    : styledBase.color,
                                backgroundColor: isActiveWord
                                    ? _colors.accent
                                    : null,
                                fontWeight: isActiveWord
                                    ? FontWeight.bold
                                    : styledBase.fontWeight,
                              ),
                              interactiveColor: isActiveWord
                                  ? Colors.black
                                  : _colors.interactive,
                              translationFa: para.translationFa,
                              translationAr: para.translationAr,
                            );

                        // 🐞 لمسِ کلمه → پرشِ پلیر به همان لحظه (span.startMs).
                        // فقط رویِ قسمت‌هایی که recognizer ندارند (یعنی خودِ
                        // کلماتِ دیکشنری نیستند) اضافه می‌شود، تا رفتارِ
                        // «لمس برای دیدنِ معنی» رویِ کلماتِ دیکشنری دست‌نخورده
                        // بماند.
                        final int? seekMs = span.startMs;
                        if (seekMs == null) {
                          richSpans.addAll(rawSpans);
                        } else {
                          richSpans.addAll(
                            rawSpans.map((s) {
                              if (s is TextSpan && s.recognizer == null) {
                                return TextSpan(
                                  text: s.text,
                                  style: s.style,
                                  children: s.children,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      ref
                                          .read(audioPlayerProvider.notifier)
                                          .seek(Duration(milliseconds: seekMs));
                                    },
                                );
                              }
                              return s;
                            }),
                          );
                        }
                      }

                      Widget englishContent = AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: paraIsActive
                              ? _colors.accent.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: paraIsActive
                                ? _colors.accent.withOpacity(0.4)
                                : Colors.transparent,
                            width: 1,
                          ),
                          // 🐞 پولیشِ ظاهری: یک سایه‌ی ملایمِ نارنجی موقعِ
                          // فعال‌بودن، برای جلبِ توجهِ بهتر به پاراگرافِ
                          // در حالِ پخش.
                          boxShadow: paraIsActive
                              ? [
                                  BoxShadow(
                                    color: _colors.accent.withOpacity(0.12),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text.rich(
                          TextSpan(children: richSpans),
                          textAlign: para.direction == "RTL"
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      );

                      return TranslatableContentWrapper(
                        originalContent: englishContent,
                        translationFa: para.translationFa,
                        translationAr: para.translationAr,
                        isDarkMode: true,
                      );
                    },
                  ),
          ),

          // 🐞 بخشِ ادغام‌شده: کنترل‌های کاملِ پخش، دقیقاً همان چیزی که
          // قبلاً فقط در _FullPlayerBottomSheetِ جدا بود — حالا همیشه پایینِ
          // همین شیت ثابت است، حتی وقتی متنِ اسکریپت را می‌خوانید.
          Container(
            decoration: BoxDecoration(
              color: _colors.barBg,
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (audioState.pointA != null && totalMs > 0)
                                Positioned(
                                  left:
                                      (audioState.pointA!.inMilliseconds /
                                              totalMs) *
                                          (constraints.maxWidth - 24) +
                                      12,
                                  top: 10,
                                  bottom: 10,
                                  child: Container(
                                    width: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                              if (audioState.pointB != null && totalMs > 0)
                                Positioned(
                                  left:
                                      (audioState.pointB!.inMilliseconds /
                                              totalMs) *
                                          (constraints.maxWidth - 24) +
                                      12,
                                  top: 10,
                                  bottom: 10,
                                  child: Container(
                                    width: 2,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              Slider(
                                value: audioState.position.inMilliseconds
                                    .toDouble()
                                    .clamp(0, totalMs > 0 ? totalMs : 1.0),
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
                            _formatDuration(audioState.position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                _buildSmallCircleButton(
                                  label: "A",
                                  isActive: audioState.pointA != null,
                                  onTap: () => ref
                                      .read(audioPlayerProvider.notifier)
                                      .setPointA(),
                                ),
                                const SizedBox(width: 12.0),
                                _buildSmallCircleButton(
                                  label: "B",
                                  isActive: audioState.pointB != null,
                                  onTap: () {
                                    if (audioState.pointA != null) {
                                      ref
                                          .read(audioPlayerProvider.notifier)
                                          .setPointB();
                                    }
                                  },
                                ),
                                if (audioState.pointA != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.layers_clear_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: () => ref
                                        .read(audioPlayerProvider.notifier)
                                        .clearAB(),
                                    tooltip: 'پاک کردن',
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<double>(
                            initialValue: audioState.speed,
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
                                "${audioState.speed}x",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            onSelected: (value) => ref
                                .read(audioPlayerProvider.notifier)
                                .setSpeed(value),
                            itemBuilder: (context) => <PopupMenuEntry<double>>[
                              const PopupMenuItem(
                                value: 0.5,
                                child: Text('0.5x'),
                              ),
                              const PopupMenuItem(
                                value: 0.8,
                                child: Text('0.8x'),
                              ),
                              const PopupMenuItem(
                                value: 1.0,
                                child: Text('1.0x'),
                              ),
                              const PopupMenuItem(
                                value: 1.2,
                                child: Text('1.2x'),
                              ),
                              const PopupMenuItem(
                                value: 1.5,
                                child: Text('1.5x'),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(modeIcon, color: modeColor),
                            tooltip: modeTooltip,
                            onPressed: () => ref
                                .read(audioPlayerProvider.notifier)
                                .togglePlaybackMode(),
                          ),
                          Text(
                            _formatDuration(audioState.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          onPressed: () => ref
                              .read(audioPlayerProvider.notifier)
                              .playPrevious(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.replay_10,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => ref
                              .read(audioPlayerProvider.notifier)
                              .skip10Sec(false),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            audioState.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                          ),
                          color: Colors.white,
                          iconSize: 60,
                          onPressed: () => audioState.isPlaying
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
                          onPressed: () => ref
                              .read(audioPlayerProvider.notifier)
                              .skip10Sec(true),
                        ),
                        const SizedBox(width: 8),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
