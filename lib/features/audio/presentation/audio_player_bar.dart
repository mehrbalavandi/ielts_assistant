import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/audio/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/audio/providers/audio_script_text_scale_provider.dart';
import 'package:ielts_assistant/features/search/data/book_search_engine.dart';
import 'package:ielts_assistant/features/reader/domain/document_models.dart';
import 'package:ielts_assistant/features/reader/data/paged_book_store.dart';
import 'package:ielts_assistant/features/library/providers/books_provider.dart';
import 'package:ielts_assistant/features/reader/presentation/reading_canvas.dart';
import 'package:ielts_assistant/features/reader/presentation/book_outline_navigator.dart';
import 'package:ielts_assistant/features/reader/presentation/rendering/text_render_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:ielts_assistant/core/text/text_direction.dart';

// 🐞 برای دکمه‌ی «برو به متن»: مکانیزمِ موجودِ اسکرول (در
// ReadingCanvas) فقط از رویِ activeSearchProvider/SearchResult کار
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
    // 🐞 S-8: روی خودِ دکمه‌ی همین فایل بنشین، نه بالای پاراگراف/جدول.
    focusAudioLink: playerState.currentPath?.split('/').last,
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
  // 🐞 برای کلمه‌ای که از یک نتیجه‌ی جستجو به آن رسیده‌ایم — عمداً از
  // accent (که برای «الان در حالِ پخش» است) متفاوت است تا با هم قاطی
  // نشوند.
  final Color searchMatch;
  final Color onSearchMatch;
  final Color textPrimary; // قبلاً Colors.white
  final Color textSecondary; // قبلاً Colors.white70
  final Color textMuted; // قبلاً Colors.white54
  final Color borderFaint; // قبلاً Colors.white24
  final Color divider; // قبلاً Colors.white10

  _PlayerColors({
    required this.bgTop,
    required this.bgBottom,
    required this.barBg,
    required this.accent,
    required this.onAccent,
    required this.interactive,
    required this.searchMatch,
    required this.onSearchMatch,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderFaint,
    required this.divider,
  });
}

_PlayerColors _playerColors(BuildContext context) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Theme.of(context).colorScheme.primary,
    brightness: Brightness.dark,
  );
  // 🐞 رفع باگِ «زیرخط رویِ هایلایت دیده نمی‌شود»: scheme.tertiary در یک
  // ColorScheme تیره می‌تواند به‌اندازه‌ی کافی روشن/پررنگ نباشد — وقتی
  // متن/زیرخطِ رویش با رنگِ تیره (برای کنتراست) کشیده می‌شود، این کنتراست
  // از بین می‌رود. برای تضمینِ روشنی/اشباعِ کافی، مستقل از اینکه seedColor
  // چه باشد، با HSL این دو رنگ را به یک بازه‌ی همیشه-خوانا می‌رسانیم.
  Color vivid(Color c, {double lightness = 0.62, double saturation = 0.75}) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  final Color accent = vivid(scheme.tertiary);
  // 🐞 رنگِ جداگانه برای «این نتیجه‌ی جستجو است» — عمداً از رنگِ accent
  // (نارنجیِ «در حالِ پخش») متفاوت است تا با هم قاطی نشوند؛ از رویِ رنگِ
  // اصلیِ برندِ اپ (primary) ساخته می‌شود، نه یک رنگِ کاملاً بی‌ربط.
  final Color searchMatch = vivid(scheme.primary, lightness: 0.68);

  return _PlayerColors(
    bgTop: Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.12)!,
    bgBottom: scheme.surface,
    barBg: scheme.surfaceContainerHighest,
    accent: accent,
    onAccent: Colors.black,
    // 🐞 AS-2: scheme.secondary در تمِ تیره رنگی کم‌اشباع و نزدیک به رنگِ متن است و کلماتِ
    // تعاملی روی پس‌زمینه‌ی تیره دیده نمی‌شدند. حالا مثلِ accent با HSL به روشنی و
    // اشباعِ همیشه-خوانا می‌رسد (همان فامِ secondary، پس با تمِ اپ هماهنگ می‌ماند).
    interactive: vivid(scheme.secondary, lightness: 0.74, saturation: 0.9),
    searchMatch: searchMatch,
    onSearchMatch: Colors.black,
    textPrimary: scheme.onSurface,
    textSecondary: scheme.onSurface.withOpacity(0.7),
    textMuted: scheme.onSurface.withOpacity(0.54),
    borderFaint: scheme.onSurface.withOpacity(0.24),
    divider: scheme.onSurface.withOpacity(0.12),
  );
}

class AudioPlayerBar extends ConsumerWidget {
  // final List<PageData> documentPages;
  final List<AudioScriptTrack> audioScripts; // 🌟 به جای documentPages
  final PagedBookStore pagedBookStore;

  const AudioPlayerBar({
    super.key,
    required this.audioScripts,
    required this.pagedBookStore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider);

    // 🐞 مشکلِ گزارش‌شده: با دکمه‌ی back این نوار بسته می‌شد ولی کاربر متوجه
    // نمی‌شد و فکر می‌کرد back کار نکرده. سه چیز با هم عوض شد:
    // (۱) ناپدیدشدن حالا انیمیشن دارد — قبلاً یک return ناگهانیِ
    //     SizedBox.shrink بود که در یک فریم محو می‌شد و چشم نمی‌گرفتش.
    //     AnimatedSwitcher + SizeTransition نوار را به‌سمتِ بالا جمع می‌کند،
    //     یعنی حرکتی که حتی در دیدِ محیطی هم دیده می‌شود.
    // (۲) رنگِ پس‌زمینه از سفیدِ خالص (دقیقاً همرنگِ صفحه‌ی کتاب) به یک
    //     تهْ‌رنگِ نیلی + یک خطِ ضخیمِ نیلی در لبه‌ی پایین تغییر کرد، تا تا
    //     وقتی باز است هم به‌وضوح «یک لایه‌ی جدا» دیده شود.
    // (۳) پیامِ صریح موقعِ بسته‌شدن — در reader_screen.dart.
    // نکته: AnimatedSwitcher عمداً بیرونِ شرط است تا هنگامِ بسته‌شدن، ویجتِ
    // قدیمی تا پایانِ انیمیشن زنده بماند؛ اگر مثلِ قبل زودتر return می‌کردیم
    // چیزی برای انیمیشن‌دادن باقی نمی‌ماند.
    // 🌟 خروجِ کندتر و محسوس‌تر از ورود (۴۲۰ در برابر ۲۲۰ میلی‌ثانیه): نوار
    // هم‌زمان جمع می‌شود، محو می‌شود، و به‌سمتِ بالا از صفحه بیرون می‌رود.
    // جهتِ Offset منفی است چون این نوار overlayِ بالای صفحه است.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.6),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
      ),
      child: audioState.currentPath == null
          ? const SizedBox.shrink(key: ValueKey('audioBarHidden'))
          : _buildBar(context, ref, audioState),
    );
  }

  Widget _buildBar(
    BuildContext context,
    WidgetRef ref,
    AudioPlayerState audioState,
  ) {
    return GestureDetector(
      key: const ValueKey('audioBarVisible'),
      onTap: () => _showFullPlayerModal(context, ref),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          border: const Border(
            bottom: BorderSide(color: Colors.indigo, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
            // IconButton(
            //   icon: const Icon(Icons.description_rounded),
            //   tooltip: "مشاهده متن صوتی + کنترل‌های پخش",
            //   onPressed: () =>
            //       showCombinedPlayerModal(context, ref, audioScripts),
            // ),
            // IconButton(
            //   icon: const Icon(Icons.queue_music_rounded),
            //   tooltip: "پلی‌لیستِ کتاب",
            //   onPressed: () => showBookAudioPlaylist(context, pagedBookStore),
            // ),
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
            // 🌟 S-11: همان نمایشگرِ صوتیِ متحرکِ پلی‌لیست، وقتی واقعاً پخش می‌شود.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: audioState.isPlaying
                  ? const Padding(
                      key: ValueKey('barMeter'),
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: _AudioMeter(color: Colors.indigo),
                    )
                  : const SizedBox(key: ValueKey('barNoMeter'), width: 32),
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
    showCombinedPlayerModal(
      context,
      ref,
      audioScripts,
      pagedBookStore: pagedBookStore,
    );
  }
}

// 🐞 محاسبه‌ی مستقیمِ اولین وقوعِ یک فایلِ صوتی در متنِ کتاب — از رویِ
// pagedBookStore.audioLinksIndex (منبعِ اصلیِ داده)، نه از رویِ
// state.firstOccurrence که ممکن است در برخی توالی‌ها (مثلاً پخشِ یک فایل،
// بستنِ مودال، بعد بازکردنش از رویِ جستجو) به‌موقع/درست پر نشده باشد.
// این تابع، مستقل از تاریخچه‌ی پلیر، همیشه یک جواب قابلِ‌اتکا می‌دهد.
AudioLocation? firstOccurrenceForTrack(
  PagedBookStore pagedBookStore,
  String audioTrackName,
) {
  for (final entry in pagedBookStore.audioLinksIndex) {
    if (entry.fileName == audioTrackName) {
      return AudioLocation(
        pageNumber: entry.pageNumber,
        paraIndex: entry.paraIndex,
      );
    }
  }
  return null;
}

// 🐞 پلی‌لیستِ کتاب: قبلاً فقط از داخلِ نوارِ کوچکِ پلیر (که تا وقتی هیچ
// فایلی پخش نشده اصلاً نمایش داده نمی‌شد) در دسترس بود — یعنی برای دیدنِ
// پلی‌لیست، اول باید یک فایل را پخش می‌کردید. حالا این یک تابعِ سطحِ‌بالا
// و عمومی است تا از هرجایی (مثلاً یک آیکونِ همیشه‌دیده در AppBar) بشود
// صدایش زد، مستقل از این‌که چیزی در حالِ پخش هست یا نه.
void showBookAudioPlaylist(
  BuildContext context,
  PagedBookStore pagedBookStore,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AudioPlaylistSheet(pagedBookStore: pagedBookStore),
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
  List<AudioScriptTrack> audioScripts, {
  // 🐞 وقتی از یک نتیجه‌ی جستجو باز می‌شود، این‌جا StartMsِ *همه‌ی*
  // کلماتِ یافت‌شده‌ی همین تراک می‌آید (نه فقط همانی که رویش تپ/پرش
  // کرده‌ایم) — تا اگر کلمه‌ی جستجوشده چندبار در همین تراک آمده باشد،
  // همه‌شان با هم هایلایت شوند؛ به‌جای هایلایتِ نارنجیِ «در حالِ پخش»
  // (که ممکن است با آن قاطی شود)، یک هایلایتِ کاملاً متفاوت (نشانه‌ی
  // «نتیجه‌ی جستجو») می‌گیرند.
  Set<int>? searchMatchTimestamps,
  // 🌟 AS-1: برای کلمات تعاملیِ سطحِ کتاب داخلِ متنِ اسکریپت.
  PagedBookStore? pagedBookStore,
  // 🌟 S-16: فایلی که searchMatchTimestamps مالِ آن است (نوارِ جستجوی داخلِ برگه).
  String? searchTrackName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CombinedAudioSheet(
      audioScripts: audioScripts,
      searchMatchTimestamps: searchMatchTimestamps,
      searchTrackName: searchTrackName,
      pagedBookStore: pagedBookStore,
    ),
  );
}

// 🐞 هم از لیستِ نتایجِ جستجو (تپ مستقیم) هم از دکمه‌های بعدی/قبلیِ
// جستجو (که currentIndex را عوض می‌کنند) باید بشود به یک نتیجه‌ی صوتی
// رفت — قبلاً فقط مسیرِ لیست این را مدیریت می‌کرد، پس دکمه‌های بعدی/قبلی
// وقتی currentIndex به یک نتیجه‌ی صوتی می‌رسید هیچ اتفاقی نمی‌افتاد. این
// تابعِ مشترک، هر دو مسیر را از همین یک‌جا پوشش می‌دهد.
Future<void> openAudioSearchResult({
  required BuildContext context,
  required WidgetRef ref,
  required SearchSession session,
  required SearchResult target,
  required PagedBookStore pagedBookStore,
  required BookModel activeBook,
}) async {
  final resolvedPath = InlineAudioLink.resolveAudioPath(
    target.audioTrackName!,
    activeBook,
  );
  // 🐞 قبلاً explicitLocation پاس داده نمی‌شد — یعنی targetLocation فقط
  // اگر state.firstOccurrence[resolvedPath] از قبل درست پر شده بود کار
  // می‌کرد؛ در توالیِ «پخشِ یک فایل بدونِ جستجو → بستنِ مودال → بازکردن
  // از رویِ جستجو»، این نبود و دکمه‌ی «برو به متن» ناپدید می‌شد. حالا
  // مستقیم از رویِ pagedBookStore.audioLinksIndex محاسبه می‌شود.
  final location = firstOccurrenceForTrack(
    pagedBookStore,
    target.audioTrackName!,
  );
  await ref
      .read(audioPlayerProvider.notifier)
      .playFile(
        resolvedPath,
        autoPlay: false,
        seekToMs: target.matchedStartMs,
        explicitLocation: location,
      );

  // 🐞 رفعِ باگِ «برگشتن به نتیجه‌ی جستجوی قبلی»: قبلاً برایِ نتایجِ صوتی،
  // activeSearchProvider هیچ‌وقت آپدیت نمی‌شد (فقط نتایجِ متنی این کار را
  // می‌کردند) — یعنی اگر یک جستجویِ قدیمی‌تر از قبل در این پرووایدر بود،
  // همان‌جا می‌ماند و با بستنِ مودال، همان جستجویِ قدیمی دوباره نمایان
  // می‌شد. حالا همین‌جا هم آپدیت می‌شود، مستقل از این‌که خودِ اسکرول به
  // صفحه معنایی دارد یا نه.
  ref.read(activeSearchProvider.notifier).state = session;

  if (context.mounted) {
    // 🐞 حالا که خودِ موتورِ جستجو نتایجِ یک تراک را گروه‌بندی می‌کند،
    // target.audioMatchTimestamps معمولاً همه‌ی لحظات را از قبل دارد —
    // نیازی به گشتنِ کلِ session.results نیست. برای اطمینان (مثلاً اگر
    // یک نتیجه‌ی قدیمیِ گروه‌بندی‌نشده جایی باقی مانده باشد)،
    // matchedStartMsForTrack همچنان به‌عنوانِ فال‌بک نگه داشته شده.
    final Set<int> timestamps =
        target.audioMatchTimestamps?.toSet() ??
        matchedStartMsForTrack(session.results, target.audioTrackName!);
    showCombinedPlayerModal(
      context,
      ref,
      pagedBookStore.audioScripts,
      searchMatchTimestamps: timestamps,
      searchTrackName: target.audioTrackName,
      pagedBookStore: pagedBookStore,
    );
  }
}

/// 🌟 S-11: نمایشگرِ صوتیِ متحرک (چهار میله که بالا و پایین می‌روند) برای فایلِ
/// در حالِ پخش در پلی‌لیست. فقط یک AnimationController و یک CustomPaint — پس با
/// هر فریم فقط همین چند پیکسل دوباره کشیده می‌شوند، نه کلِ ردیف. اگر کاربر در
/// تنظیماتِ دستگاه انیمیشن‌ها را خاموش کرده باشد، میله‌ها ثابت می‌مانند.
class _AudioMeter extends StatefulWidget {
  final Color color;
  const _AudioMeter({super.key, required this.color});

  @override
  State<_AudioMeter> createState() => _AudioMeterState();
}

class _AudioMeterState extends State<_AudioMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.3;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'در حالِ پخش',
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(20, 18),
          painter: _AudioMeterPainter(_controller, widget.color),
        ),
      ),
    );
  }
}

class _AudioMeterPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  _AudioMeterPainter(this.t, this.color) : super(repaint: t);

  // هر میله با سرعت و فازِ خودش؛ جمعِ دو سینوس تا حرکت تکراری و مکانیکی دیده نشود.
  static const List<double> _speeds = [1.0, 2.0, 1.0, 3.0];
  static const List<double> _phases = [0.0, 1.7, 3.3, 0.9];

  @override
  void paint(Canvas canvas, Size size) {
    const int bars = 4;
    final double gap = size.width * 0.12;
    final double barW = (size.width - gap * (bars - 1)) / bars;
    final paint = Paint()..color = color;
    final double a = t.value * 2 * math.pi;
    for (int i = 0; i < bars; i++) {
      final double wave =
          0.5 +
          0.30 * math.sin(a * _speeds[i] + _phases[i]) +
          0.20 * math.sin(a * (_speeds[i] + 1) + _phases[i] * 1.6);
      final double h = size.height * (0.18 + 0.82 * wave.clamp(0.0, 1.0));
      final double x = i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioMeterPainter old) => old.color != color;
}

class _AudioPlaylistSheet extends ConsumerStatefulWidget {
  final PagedBookStore pagedBookStore;
  const _AudioPlaylistSheet({required this.pagedBookStore});

  @override
  ConsumerState<_AudioPlaylistSheet> createState() =>
      _AudioPlaylistSheetState();
}

class _AudioPlaylistSheetState extends ConsumerState<_AudioPlaylistSheet> {
  // 🌟 S-10: ارتفاعِ ثابتِ هر ردیف (ListTileِ یک‌خطی) تا جای هر آیتم دقیقاً
  // معلوم باشد و بشود بدونِ ساختنِ همه‌ی ردیف‌ها مستقیم به آن پرید.
  // 🌟 AU-7: دوخطی (نامِ فایل + درس و مهارت) ← ارتفاعِ ListTileِ دوخطی.
  static const double _rowExtent = 72.0;

  /// AU-7: برچسبِ درس و مهارتِ هر فایل (یک‌بار حساب می‌شود).
  final Map<String, String?> _locationLabels = {};

  String? _locationOf(String fileName) => _locationLabels.putIfAbsent(fileName, () {
    final AudioLocation? loc = firstOccurrenceForTrack(pagedBookStore, fileName);
    if (loc == null || pagedBookStore.outline.isEmpty) return null;
    return outlineLocationLabel(
      pagedBookStore.outline,
      loc.pageNumber,
      loc.paraIndex,
    );
  });
  final ScrollController _scrollController = ScrollController();
  bool _didInitialScroll = false;

  PagedBookStore get pagedBookStore => widget.pagedBookStore;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 🌟 S-10: با بازشدنِ پلی‌لیست، فایلِ در حالِ پخش — یا اگر چیزی پخش نمی‌شود،
  /// آخرین فایلی که پخش شده — وسطِ فهرست دیده شود. فقط یک‌بار، تا اسکرولِ خودِ
  /// کاربر را به هم نزند.
  void _scrollToCurrentOnce(List<String> playlist, String? target) {
    if (_didInitialScroll || playlist.isEmpty) return;
    _didInitialScroll = true;
    final int index = target == null ? -1 : playlist.indexOf(target);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final double offset =
          index * _rowExtent - (position.viewportDimension - _rowExtent) / 2;
      _scrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final colors = _playerColors(context);
    // فایلی که باید نشان داده شود: در حالِ پخش، وگرنه آخرین پخش‌شده.
    final String? markedPath =
        state.currentPath ??
        ref.read(audioPlayerProvider.notifier).lastPlayedPath;
    _scrollToCurrentOnce(state.playlist, markedPath);

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
                color: colors.borderFaint,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "پلی‌لیستِ کتاب",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: colors.divider, height: 20),
            Expanded(
              child: state.playlist.isEmpty
                  ? Center(
                      child: Text(
                        "فایلِ صوتی‌ای در این کتاب یافت نشد.",
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )
                  // 🌟 UI-2: سرعنوانِ فارسیِ برگه راست‌به‌چپ است (جهتِ اپ)، ولی فهرستِ نامِ
                  // فایل‌ها انگلیسی است و چپ‌به‌راست می‌ماند.
                  : Directionality(
                      textDirection: TextDirection.ltr,
                      child: ListView.builder(
                      controller: _scrollController,
                      itemExtent: _rowExtent,
                      itemCount: state.playlist.length,
                      itemBuilder: (context, index) {
                        final path = state.playlist[index];
                        // 🌟 S-10: بعد از اجرای دوباره‌ی برنامه (چیزی در حالِ پخش
                        // نیست) آخرین فایلِ پخش‌شده هم مثلِ فایلِ جاری علامت دارد.
                        final bool isCurrent = markedPath == path;
                        final bool isPlayingRow = isCurrent && state.isPlaying;
                        return ListTile(
                          // 🌟 S-11: فایلِ در حالِ پخش زمینه‌ی ملایمِ رنگِ تأکید
                          // و به‌جای آیکون، نمایشگرِ صوتیِ متحرک دارد.
                          tileColor: isPlayingRow
                              ? colors.accent.withOpacity(0.10)
                              : null,
                          leading: SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isPlayingRow
                                    ? _AudioMeter(
                                        key: const ValueKey('meter'),
                                        color: colors.accent,
                                      )
                                    : Icon(
                                        Icons.play_circle_fill_rounded,
                                        key: const ValueKey('icon'),
                                        color: isCurrent
                                            ? colors.accent
                                            : colors.textMuted,
                                      ),
                              ),
                            ),
                          ),
                          // 🌟 AU-7: درس و مهارتِ هر فایل زیرِ نامش.
                          subtitle: _locationOf(path.split('/').last) == null
                              ? null
                              : Text(
                                  _locationOf(path.split('/').last)!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                          title: Text(
                            path.split('/').last,
                            style: TextStyle(
                              color: isCurrent
                                  ? colors.accent
                                  : colors.textSecondary,
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
                            // 🐞 قبلاً newFirstOccurrence: state.firstOccurrence
                            // پاس داده می‌شد — که در برخی توالی‌ها (پخشِ یک
                            // فایل، بستنِ مودال، بازکردنش از رویِ جستجو) درست
                            // پر نبود و «برو به متن» را خراب می‌کرد. حالا
                            // مستقیم از رویِ pagedBookStore.audioLinksIndex
                            // (منبعِ اصلی) محاسبه می‌شود — همیشه قابلِ‌اتکا.
                            final fileName = path.split('/').last;
                            await ref
                                .read(audioPlayerProvider.notifier)
                                .playFile(
                                  path,
                                  newPlaylist: state.playlist,
                                  newFirstOccurrence: state.firstOccurrence,
                                  explicitLocation: firstOccurrenceForTrack(
                                    pagedBookStore,
                                    fileName,
                                  ),
                                );
                            if (!context.mounted) return;
                            _jumpToAudioLocation(ref, context);
                          },
                        );
                      },
                    ),
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
  final Set<int>? searchMatchTimestamps;
  // 🌟 AS-1: منبعِ کلمات تعاملیِ سطحِ کتاب (index.json). پاراگراف‌های اسکریپت
  // فهرستِ Interactivesِ خودشان را ندارند؛ بدونِ این، هیچ کلمه‌ای در اسکریپت
  // تعاملی نمی‌شد.
  final PagedBookStore? pagedBookStore;

  /// 🌟 S-16: فایلِ صوتی‌ای که [searchMatchTimestamps] مالِ آن است.
  final String? searchTrackName;

  const CombinedAudioSheet({
    super.key,
    required this.audioScripts,
    this.searchMatchTimestamps,
    this.pagedBookStore,
    this.searchTrackName,
  });

  @override
  ConsumerState<CombinedAudioSheet> createState() => _CombinedAudioSheetState();
}

class _CombinedAudioSheetState extends ConsumerState<CombinedAudioSheet> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _lastActiveIndex = -1;

  // 🌟 S-16: پیمایشِ جستجو داخلِ برگه. _matches = لحظه‌های یافته‌شده در فایلِ _searchTrack
  // (مرتب)، _matchIndex = همانی که الان رویش هستیم.
  List<int> _matches = const [];
  String? _searchTrack;
  int _matchIndex = 0;

  @override
  void initState() {
    super.initState();
    _matches = (widget.searchMatchTimestamps?.toList() ?? <int>[])..sort();
    _searchTrack = widget.searchTrackName ??
        ref.read(audioPlayerProvider).currentPath?.split('/').last;
  }

  /// S-16: یافته‌ی بعدی/قبلی: اول داخلِ همین فایل؛ بعد از آخری، نتیجه‌ی بعدیِ جستجو — اگر
  /// فایلِ صوتیِ دیگری است همین‌جا به آن می‌رود، اگر متنِ کتاب است برگه بسته و صفحه به آن
  /// اسکرول می‌شود (مثلِ نوارِ جستجوی پایینِ صفحه، چرخشی).
  Future<void> _stepSearch(int dir) async {
    if (_matches.isEmpty) return;
    final AudioPlayerNotifier player = ref.read(audioPlayerProvider.notifier);
    final int next = _matchIndex + dir;
    if (next >= 0 && next < _matches.length) {
      setState(() => _matchIndex = next);
      player.seek(Duration(milliseconds: _matches[next]));
      return;
    }
    final searchCtl = ref.read(activeSearchProvider.notifier);
    final SearchSession? session = searchCtl.state;
    if (session == null || session.results.length <= 1) {
      final int wrap = dir > 0 ? 0 : _matches.length - 1;
      setState(() => _matchIndex = wrap);
      player.seek(Duration(milliseconds: _matches[wrap]));
      return;
    }
    final int n = session.results.length;
    final int ni = (session.currentIndex + dir + n) % n;
    final SearchResult target = session.results[ni] as SearchResult;
    if (target.audioTrackName == null) {
      // متنِ کتاب: برگه بسته می‌شود و صفحه‌ی مطالعه به نتیجه می‌رود.
      Navigator.of(context).pop();
      searchCtl.state = session.copyWith(
        currentIndex: ni,
        jumpTrigger: session.jumpTrigger + 1,
      );
      return;
    }
    final List<int> ts = [
      ...(target.audioMatchTimestamps ??
          [if (target.matchedStartMs != null) target.matchedStartMs!]),
    ]..sort();
    if (ts.isEmpty) return;
    final int idx = dir > 0 ? 0 : ts.length - 1;
    searchCtl.state = session.copyWith(currentIndex: ni, handledInPlayer: true);
    if (target.audioTrackName != _searchTrack) {
      final PagedBookStore? store = widget.pagedBookStore;
      final BookModel? book = ref.read(activeBookProvider);
      if (store == null || book == null) return;
      await player.playFile(
        InlineAudioLink.resolveAudioPath(target.audioTrackName!, book),
        autoPlay: false,
        seekToMs: ts[idx],
        explicitLocation: firstOccurrenceForTrack(store, target.audioTrackName!),
      );
    } else {
      player.seek(Duration(milliseconds: ts[idx]));
    }
    if (!mounted) return;
    setState(() {
      _searchTrack = target.audioTrackName;
      _matches = ts;
      _matchIndex = idx;
      _lastActiveIndex = -1;
    });
  }

  /// S-16: پایانِ جستجو (× در نوارِ جستجوی برگه): هایلایت‌ها و نوارِ پایینِ صفحه هم می‌روند.
  void _clearSearch() {
    ref.read(activeSearchProvider.notifier).state = null;
    setState(() {
      _matches = const [];
      _searchTrack = null;
    });
  }

  /// 🌟 AU-5: منوی «پایانِ فایل»: توقف، تکرارِ همین فایل، پخشِ پیوسته تا آخرِ کتاب، تکرارِ مهارتِ
  /// فعلیِ درسِ فعلی، تکرارِ کلِ درسِ فعلی، تکرارِ کلِ کتاب. زیرِ دو حالتِ دامنه‌دار نامِ درس/مهارتِ
  /// فایلِ فعلی می‌آید تا معلوم باشد چه چیزی تکرار می‌شود.
  Widget _buildPlaybackModeMenu(
    AudioPlayerState audioState,
    IconData icon,
    Color color,
    String tooltip,
  ) {
    final AudioPlayerNotifier notifier = ref.read(audioPlayerProvider.notifier);
    final String? path = audioState.currentPath;
    final String? where = path == null ? null : notifier.trackLocationLabel(path);
    final String? unitOnly = where?.split(' · ').first;
    PopupMenuItem<PlaybackMode> item(
      PlaybackMode mode,
      IconData i,
      String title, [
      String? subtitle,
    ]) {
      final bool selected = audioState.playbackMode == mode;
      return PopupMenuItem<PlaybackMode>(
        value: mode,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(i, size: 20, color: selected ? _colors.accent : null),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 18, color: _colors.accent),
            ],
          ),
        ),
      );
    }

    return PopupMenuButton<PlaybackMode>(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      initialValue: audioState.playbackMode,
      onSelected: notifier.setPlaybackMode,
      itemBuilder: (_) => [
        item(PlaybackMode.stop, Icons.stop_circle_outlined, 'توقف پس از پایانِ فایل'),
        item(PlaybackMode.repeatOne, Icons.repeat_one_rounded, 'تکرارِ همین فایل'),
        item(
          PlaybackMode.autoAdvance,
          Icons.playlist_play_rounded,
          'پخشِ پیوسته تا آخرِ کتاب',
        ),
        item(
          PlaybackMode.repeatSection,
          Icons.repeat_rounded,
          'تکرارِ فایل‌های همین مهارت',
          where,
        ),
        item(
          PlaybackMode.repeatUnit,
          Icons.repeat_on_rounded,
          'تکرارِ فایل‌های همین درس',
          unitOnly,
        ),
        item(PlaybackMode.repeatBook, Icons.all_inclusive_rounded, 'تکرارِ کلِ کتاب'),
      ],
    );
  }

  /// S-16: فاصله‌ی نوارِ جستجو از پایینِ ناحیه‌ی متن (کاربر با کشیدن عوضش می‌کند؛ تا بسته شدنِ
  /// برنامه یادش می‌ماند).
  static double _stripBottom = 8;

  /// S-16: نوارِ جستجوی شناور روی متن — پیش‌فرض پایین (همان‌جای نوارِ جستجوی صفحه‌ی مطالعه)،
  /// با کشیدنِ عمودی جابه‌جا می‌شود: «نتیجه‌ی ۲۸ از ۳۱ · «true»»؛ اگر فایل بیش از یک یافته دارد،
  /// «یافته‌ی ۲ از ۴ در این فایل» هم.
  Widget _buildFloatingSearchStrip(double areaHeight) {
    const double stripHeight = 52;
    final double maxBottom = (areaHeight - stripHeight - 4).clamp(0.0, double.infinity);
    final double bottom = _stripBottom.clamp(0.0, maxBottom);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) => setState(() {
          _stripBottom = (bottom - d.delta.dy).clamp(0.0, maxBottom);
        }),
        child: _buildSearchStrip(),
      ),
    );
  }

  Widget _buildSearchStrip() {
    final SearchSession? session = ref.watch(activeSearchProvider);
    final String query = session?.query ?? '';
    final Color fg = _colors.textSecondary;
    final bool many = session != null && session.results.length > 1;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _colors.searchMatch.withOpacity(0.22),
            _colors.bgBottom,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _colors.searchMatch.withOpacity(0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: fg),
              tooltip: 'یافته‌ی بعدی',
              visualDensity: VisualDensity.compact,
              onPressed: () => _stepSearch(1),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_up, color: fg),
              tooltip: 'یافته‌ی قبلی',
              visualDensity: VisualDensity.compact,
              onPressed: () => _stepSearch(-1),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (many)
                        'نتیجه‌ی ${session!.currentIndex + 1} از ${session!.results.length}',
                      if (query.isNotEmpty) '«${bidiIsolate(query)}»',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_matches.length > 1)
                    Text(
                      'یافته‌ی ${_matchIndex + 1} از ${_matches.length} در این فایل',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _colors.textMuted, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            Icon(Icons.drag_indicator_rounded, color: _colors.textMuted, size: 18),
            IconButton(
              icon: Icon(Icons.close, color: _colors.textMuted, size: 20),
              tooltip: 'پایانِ جستجو',
              visualDensity: VisualDensity.compact,
              onPressed: _clearSearch,
            ),
          ],
        ),
      ),
    );
  }

  // 🐞 در build() مقداردهی می‌شود؛ چون _buildSmallCircleButton هم به آن
  // نیاز دارد (و context ندارد)، به‌عنوانِ فیلدِ کلاس نگه داشته می‌شود.
  late _PlayerColors _colors;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// 🌟 AS-3: اندازه‌ی Word (pt) ← px در صفحه‌ی اسکریپت. متنِ عادیِ کتاب (۱۱٫۵pt) همان
  /// [base] می‌شود؛ تیترها نسبتشان را با توانِ ۰٫۷۵ نگه می‌دارند (مثلِ حالتِ «خوانا»).
  /// قبلاً pt مستقیم px گرفته می‌شد و متنِ ۱۱٫۵pt روی گوشی ریز بود.
  static double _scriptFontSize(double pt, double base) {
    final double v = base * math.pow(pt / 11.5, 0.75).toDouble();
    return v.clamp(base * 0.85, base * 1.9).toDouble();
  }

  /// 🌟 AS-4: شماره/بولتِ خودکارِ Word (ListMarker) با تورفتگیِ آویزان: شماره در ستونِ
  /// خودش و متن کنارش، تا سطرهای بعدی زیرِ متن بیایند نه زیرِ شماره. پاراگرافِ بی‌شماره‌ای
  /// که در Word تورفتگی دارد (ادامه‌ی همان بند، مثلِ «Candidate 1: …» زیرِ «1 Examiner: …»)
  /// به اندازه‌ی همین ستون جلو می‌رود تا با متنِ بند هم‌تراز باشد.
  Widget _withListLayout(
    ParagraphData para,
    Widget text,
    double fontSize, {
    required bool trackHasList,
  }) {
    final double column = fontSize * 1.7;
    final String? marker = para.listMarker?.trim();
    final bool rtl = para.direction == "RTL";
    if (marker != null && marker.isNotEmpty) {
      return Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: column),
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: fontSize * 0.35),
                child: Text(
                  marker,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: fontSize,
                    height: 1.5,
                    fontWeight: para.listMarkerBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            Expanded(child: text),
          ],
        ),
      );
    }
    if (trackHasList && (para.indentLeft ?? 0) >= 18) {
      return Padding(
        padding: rtl
            ? EdgeInsets.only(right: column)
            : EdgeInsets.only(left: column),
        child: text,
      );
    }
    return text;
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
            color: isActive ? _colors.accent : _colors.textMuted,
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
    // 🌟 S-16: جستجو فقط برای همان فایلی که یافته‌ها مالِ آن است (با «قبلی/بعدی»ِ پلیر به
    // فایلِ دیگری رفتیم ← نوار و هایلایت‌ها نمی‌آیند).
    final bool searchOn =
        _matches.isNotEmpty && _searchTrack != null && _searchTrack == currentFileName;
    final int? currentMatchMs = searchOn
        ? _matches[_matchIndex.clamp(0, _matches.length - 1)]
        : null;

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
    // 🌟 AS-3/AS-4
    final double textScale = ref.watch(audioScriptTextScaleProvider);
    final AudioScriptTextScaleNotifier scaleNotifier = ref.read(
      audioScriptTextScaleProvider.notifier,
    );
    final double baseFontSize = kAudioScriptBodyPx * textScale;
    final bool trackHasList = paragraphs.any(
      (p) => p.listMarker != null && p.listMarker!.trim().isNotEmpty,
    );

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
        modeColor = _colors.textMuted;
        modeTooltip = "توقف پس از پایان";
        break;
      // 🌟 AU-5
      case PlaybackMode.repeatSection:
        modeIcon = Icons.repeat_rounded;
        modeColor = _colors.accent;
        modeTooltip = "تکرارِ فایل‌های همین مهارت";
        break;
      case PlaybackMode.repeatUnit:
        modeIcon = Icons.repeat_on_rounded;
        modeColor = _colors.accent;
        modeTooltip = "تکرارِ فایل‌های همین درس";
        break;
      case PlaybackMode.repeatBook:
        modeIcon = Icons.all_inclusive_rounded;
        modeColor = _colors.accent;
        modeTooltip = "تکرارِ کلِ کتاب";
        break;
    }

    // 🌟 UI-2: اسکریپت و کنترل‌های پخش انگلیسی/جهت‌دارند (نوارِ پیشرفت از چپ پر می‌شود)،
    // پس کلِ برگه چپ‌به‌راست است؛ متن‌های فارسیِ آن خودشان راست‌به‌چپ اعلام می‌شوند.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
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
              color: _colors.borderFaint,
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
                    textDirection: audioState.currentPath == null
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 🌟 AS-3: کوچک/بزرگ‌کردنِ متنِ اسکریپت
                IconButton(
                  icon: Icon(
                    Icons.text_decrease_rounded,
                    color: scaleNotifier.canDecrease
                        ? _colors.textSecondary
                        : _colors.textMuted.withOpacity(0.4),
                    size: 20,
                  ),
                  tooltip: 'متنِ کوچک‌تر',
                  visualDensity: VisualDensity.compact,
                  onPressed: scaleNotifier.canDecrease
                      ? scaleNotifier.decrease
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.text_increase_rounded,
                    color: scaleNotifier.canIncrease
                        ? _colors.textSecondary
                        : _colors.textMuted.withOpacity(0.4),
                    size: 20,
                  ),
                  tooltip: 'متنِ بزرگ‌تر',
                  visualDensity: VisualDensity.compact,
                  onPressed: scaleNotifier.canIncrease
                      ? scaleNotifier.increase
                      : null,
                ),
                if (audioState.targetLocation != null)
                  // 🐞 «برو به متن»: کاربر را به دقیقاً همان صفحه/پاراگرافی
                  // می‌برد که یا اولین وقوعِ این فایل در کتاب است (اگر با
                  // قبلی/بعدی یا لیستِ پخش به این فایل رسیده‌ایم)، یا همان
                  // نقطه‌ی دقیقی که رویِ دکمه‌ی صوتیِ داخلِ متن تپ شده.
                  IconButton(
                    icon: Icon(
                      Icons.subject_rounded,
                      color: _colors.accent,
                      size: 20,
                    ),
                    tooltip: 'برو به متن',
                    onPressed: () => _jumpToAudioLocation(ref, context),
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: _colors.divider, height: 20),

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
          //         style: TextStyle(color: _colors.textMuted, fontSize: 11),
          //       ),
          //     ],
          //   ),
          // ),
          Expanded(
            // 🌟 S-16: نوارِ جستجو روی متن، پایینِ آن (هم‌جای نوارِ جستجوی صفحه)؛ با کشیدن جابه‌جا
            // می‌شود.
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned.fill(
                    child: paragraphs.isEmpty
                ? Center(
                    child: Text(
                      "هیچ متن صوتی همگام‌سازی شده‌ای برای این بخش یافت نشد.",
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _colors.textMuted),
                    ),
                  )
                : ScrollablePositionedList.builder(
                    itemCount: paragraphs.length,
                    itemScrollController: _itemScrollController,
                    // S-16: جا برای نوارِ جستجوی شناورِ پایین، تا آخرین سطرها زیرش نمانند.
                    padding: EdgeInsets.fromLTRB(14, 4, 14, searchOn ? 72 : 4),
                    itemBuilder: (context, index) {
                      final para = paragraphs[index];
                      final bool paraIsActive = index == activeIndex;

                      final List<InlineSpan> richSpans = [];
                      for (final span in para.spans) {
                        // 🐞 هایلایتِ موقعیتِ فعلی: حالا مستقل از isPlaying
                        // همیشه نشان داده می‌شود — کاربر باید هر لحظه (چه
                        // در حالِ پخش چه مکث‌کرده) بداند دقیقاً رویِ کدام
                        // کلمه است.
                        // 🌟 AS-5: متنِ گفته‌نشده (برچسبِ گوینده، NotSpoken) هیچ‌وقت
                        // هایلایت نمی‌شود؛ بازه‌اش (سکوت یا صدای بی‌متن) بی‌هایلایت
                        // می‌گذرد. خودِ پاراگراف در این بازه فعال می‌ماند تا کادر
                        // زودتر رویِ سطرِ بعد بنشیند.
                        final bool isActiveWord =
                            paraIsActive &&
                            !span.unspoken &&
                            span.startMs != null &&
                            span.endMs != null &&
                            currentPosMs >= span.startMs! &&
                            currentPosMs < span.endMs!;

                        // 🐞 کلمه‌ای که از رویِ یک نتیجه‌ی جستجو به آن
                        // رسیده‌ایم — هایلایتِ کاملاً متفاوتی می‌گیرد
                        // (searchMatch، نه accent) تا با هایلایتِ موقعیتِ
                        // فعلی قاطی نشود. اگر همان کلمه‌ی جستجوشده چندبار در
                        // همین تراک آمده باشد، همه‌شان (نه فقط همانی که
                        // رویش پرش کرده‌ایم) هایلایت می‌شوند. وقتی موقعیتِ
                        // فعلی دقیقاً رویِ یک نتیجه‌ی جستجو باشد، هایلایتِ
                        // موقعیت اولویت دارد (پاسخِ «الان کجام؟» مهم‌تر است).
                        final bool isSearchMatch =
                            !isActiveWord &&
                            searchOn &&
                            span.startMs != null &&
                            span.endMs != null &&
                            _matches.any(
                              (ms) => ms >= span.startMs! && ms < span.endMs!,
                            );
                        // S-16: یافته‌ای که الان رویش هستیم پررنگ، بقیه کم‌رنگ‌تر.
                        final bool isCurrentMatch =
                            isSearchMatch &&
                            currentMatchMs != null &&
                            currentMatchMs >= span.startMs! &&
                            currentMatchMs < span.endMs!;

                        final TextStyle baseStyle =
                            TextRenderEngine.applySpanStyle(
                              TextStyle(
                                color: _colors.textSecondary,
                                fontSize: baseFontSize,
                                height: 1.5,
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
                            // 🌟 AS-3: نیم‌پوینتِ Word ← pt ← px نسبت به متنِ عادی
                            if (parsed != null) {
                              fontSize = _scriptFontSize(
                                parsed / 2,
                                baseFontSize,
                              );
                            }
                          }
                        }
                        final TextStyle styledBase = baseStyle.copyWith(
                          fontFamily: fontFamily,
                          fontSize: fontSize,
                        );

                        final Color? highlightBg = isActiveWord
                            ? _colors.accent
                            : (isSearchMatch
                                  ? (isCurrentMatch
                                        ? _colors.searchMatch
                                        : _colors.searchMatch.withOpacity(0.45))
                                  : null);
                        final Color? onHighlight = isActiveWord
                            ? _colors.onAccent
                            : (isCurrentMatch ? _colors.onSearchMatch : null);

                        // 🌟 AS-1: فهرستِ خودِ پاراگراف (قالبِ قدیم) اگر هست، وگرنه
                        // کلمات تعاملیِ کلِ کتاب با همان الگوی آماده‌ی صفحه‌ها.
                        final PagedBookStore? store = widget.pagedBookStore;
                        final List<InteractiveWord>? bookWords =
                            (para.interactives.isEmpty &&
                                store != null &&
                                store.interactives.isNotEmpty)
                            ? store.interactives
                            : null;
                        final List<InlineSpan>
                        rawSpans = TextRenderEngine.buildInteractiveText(
                          span.content,
                          bookWords ?? para.interactives,
                          context,
                          interactivesPattern: bookWords != null
                              ? store?.interactivesPattern
                              : null,
                          interactivesByText: bookWords != null
                              ? store?.interactivesByText
                              : null,
                          styledBase.copyWith(
                            color: onHighlight ?? styledBase.color,
                            backgroundColor: highlightBg,
                            // 🐞 قبلاً هایلایت‌شدن باعثِ bold هم می‌شد —
                            // چون حروفِ بولد پهن‌ترند، با حرکتِ هایلایت از
                            // کلمه‌ای به کلمه‌ی بعدی، طولِ خطوط پیوسته کم و
                            // زیاد می‌شد (آزاردهنده). حالا وزنِ فونت همیشه
                            // همان مقدارِ اصلیِ کلمه می‌ماند؛ فقط رنگِ
                            // پس‌زمینه هایلایت را نشان می‌دهد، بدونِ تأثیر
                            // روی چیدمانِ متن.
                            fontWeight: styledBase.fontWeight,
                            decoration: styledBase.decoration,
                            decorationColor: onHighlight ?? styledBase.color,
                          ),
                          interactiveColor: onHighlight ?? _colors.interactive,
                          translationFa: para.translationFa,
                          translationAr: para.translationAr,
                        );

                        // 🐞 لمسِ کلمه → پرشِ پلیر به همان لحظه (span.startMs).
                        // فقط رویِ قسمت‌هایی که recognizer ندارند (یعنی خودِ
                        // کلماتِ دیکشنری نیستند) اضافه می‌شود، تا رفتارِ
                        // «لمس برای دیدنِ معنی» رویِ کلماتِ دیکشنری دست‌نخورده
                        // بماند.
                        // 🌟 AS-5: لمسِ برچسبِ گفته‌نشده → شروعِ همان سطر (پایانِ برچسب)
                        final int? seekMs = span.unspoken
                            ? (span.endMs ?? span.startMs)
                            : span.startMs;
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
                        // 🌟 AS-3: فاصله‌ی پاراگراف‌ها کم شد (قبلاً ۴+۱۲ از هر طرف ≈ ۳۲px
                        // بینِ دو پاراگراف)؛ حالا ≈ ۱۴px، و کادرِ پاراگرافِ فعال هنوز
                        // دورِ متن جا دارد.
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                        child: _withListLayout(
                          para,
                          Text.rich(
                            TextSpan(children: richSpans),
                            textAlign: para.direction == "RTL"
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                          baseFontSize,
                          trackHasList: trackHasList,
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
                  if (searchOn) _buildFloatingSearchStrip(box.maxHeight),
                ],
              ),
            ),
          ),

          // 🐞 بخشِ ادغام‌شده: کنترل‌های کاملِ پخش، دقیقاً همان چیزی که
          // قبلاً فقط در _FullPlayerBottomSheetِ جدا بود — حالا همیشه پایینِ
          // همین شیت ثابت است، حتی وقتی متنِ اسکریپت را می‌خوانید.
          Container(
            decoration: BoxDecoration(
              color: _colors.barBg,
              border: Border(top: BorderSide(color: _colors.divider)),
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
                            style: TextStyle(
                              color: _colors.textSecondary,
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
                                    icon: Icon(
                                      Icons.layers_clear_outlined,
                                      color: _colors.textMuted,
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
                          // 🌟 AU-5: منوی رفتارِ پایانِ فایل (به جای چرخیدن با هر لمس).
                          _buildPlaybackModeMenu(
                            audioState,
                            modeIcon,
                            modeColor,
                            modeTooltip,
                          ),
                          Text(
                            _formatDuration(audioState.duration),
                            style: TextStyle(
                              color: _colors.textSecondary,
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
    ),
    );
  }
}
