// 🔊 🎧 ▶ ▶️
import 'package:flutter/material.dart';
import 'package:float_column/float_column.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/book_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/cross_book_search_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/providers/audio_player_provider.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/audio_player/presentation/widgets/telegram_audio_player.dart';
import 'dart:math' as math;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ReadingCanvasScreen extends ConsumerStatefulWidget {
  final List<PageData> documentPages;
  const ReadingCanvasScreen({super.key, required this.documentPages});

  @override
  ConsumerState<ReadingCanvasScreen> createState() =>
      _ReadingCanvasScreenState();
}

class _ReadingCanvasScreenState extends ConsumerState<ReadingCanvasScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final _box = GetStorage();

  // 🌟 جایگزینی ScrollController با موتور قدرتمندتر برای پرش دقیق
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);

    // 🌟 راه‌اندازی شنونده اسکرول برای ذخیره آخرین صفحه (به جای پیکسل)
    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        // صفحه‌ای که در بالای دید کاربر قرار دارد را پیدا می‌کنیم
        int minIndex = positions
            .where((p) => p.itemTrailingEdge > 0)
            .map((p) => p.index)
            .reduce(math.min);

        final currentBook = ref.read(activeBookProvider);
        if (currentBook != null) {
          _box.write('scroll_index_${currentBook.id}', minIndex);
        }
      }
    });
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _isZoomed = scale > 1.05;
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double canvasWidth = screenWidth > 800 ? 760.0 : screenWidth - 24;

    // خواندن آخرین ایندکس برای کتاب جاری در هنگام رندر اولیه
    final currentBook = ref.read(activeBookProvider);
    final int initialIndex =
        _box.read('scroll_index_${currentBook?.id ?? "default"}') ?? 0;

    // 🌟 گوش دادن به بی‌سیم پرشِ جستجو
    ref.listen<SearchResult?>(searchJumpTargetProvider, (previous, next) {
      if (next != null) {
        // پیدا کردن ایندکس صفحه‌ای که پاراگراف در آن است
        int pageIndex = widget.documentPages.indexWhere(
          (p) => p.pageNumber == next.pageNumber,
        );
        if (pageIndex != -1 && _itemScrollController.isAttached) {
          // پرش نرم به صفحه مورد نظر
          _itemScrollController.scrollTo(
            index: pageIndex,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            alignment: 0.1, // کمی پایین‌تر از لبه بالایی قرار می‌گیرد
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            // پلیر صوتی (در صورت نیاز)
            TelegramAudioPlayer(documentPages: widget.documentPages),

            Expanded(
              child: Listener(
                onPointerDown: (event) => setState(() => _pointerCount++),
                onPointerUp: (event) => setState(() => _pointerCount--),
                onPointerCancel: (event) => setState(() => _pointerCount = 0),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  scaleEnabled: true,
                  panEnabled: _isZoomed || _pointerCount > 1,
                  minScale: 1.0,
                  maxScale: 3.5,
                  child: Center(
                    child: SizedBox(
                      width: canvasWidth,
                      // 🌟 جایگزینی ListView با ScrollablePositionedList
                      child: ScrollablePositionedList.builder(
                        itemCount: widget.documentPages.length,
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        initialScrollIndex:
                            initialIndex, // شروع دقیقا از همان صفحه قبلی
                        physics: (_pointerCount >= 2 || _isZoomed)
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 24.0,
                          horizontal: 8.0,
                        ),
                        itemBuilder: (context, pageIndex) {
                          final page = widget.documentPages[pageIndex];
                          List<Widget> paragraphWidgets = [];

                          for (var para in page.paragraphs) {
                            // 🌟 ۱. ساخت ظاهر پاراگراف با استفاده از متدی که از قبل در کلاس دارید
                            // (این متد خودش شامل کدهای FloatColumn و سیستم ترجمه است)
                            Widget paragraphContent = _buildParagraph(
                              para,
                              canvasWidth,
                              screenWidth,
                              context,
                            );

                            // 🌟 ۲. سیستم هوشمند تشخیص و هایلایت پاراگرافِ پیدا شده در جستجو
                            final searchTarget = ref.watch(
                              searchJumpTargetProvider,
                            );
                            if (searchTarget != null &&
                                searchTarget.pageNumber == page.pageNumber) {
                              // مقایسه محتوای پاراگراف جاری با پاراگرافی که در جستجو پیدا شده
                              String currentText = para.spans
                                  .map((e) => e.content ?? '')
                                  .join();
                              String targetText = searchTarget.paragraph.spans
                                  .map((e) => e.content ?? '')
                                  .join();

                              // اگر دقیقاً همان پاراگراف بود، آن را با یک کادر زیبا محاصره کن
                              if (currentText.isNotEmpty &&
                                  currentText == targetText) {
                                paragraphContent = Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.yellow.withOpacity(
                                          0.2,
                                        ), // هایلایت ملایم
                                        border: Border.all(
                                          color: Colors.orangeAccent,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child:
                                          paragraphContent, // پاراگراف اصلی داخل کادر قرار می‌گیرد
                                    ),
                                    // یک برچسب کوچک برای راهنمایی چشم کاربر
                                    Positioned(
                                      top: -12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          "نتیجه جستجو",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }

                            paragraphWidgets.add(paragraphContent);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 24.0),
                            padding: const EdgeInsets.all(32.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: paragraphWidgets,
                            ),
                          );
                        },
                      ),
                    ),
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

Widget _buildPageDivider(int pageNumber) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "PAGE $pageNumber",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.0)),
      ],
    ),
  );
}

String _mapFontFamily(String rawFontName) {
  String normalized = rawFontName
      .toLowerCase()
      .replaceAll("-", "")
      .replaceAll(" ", "");

  if (normalized.contains("sourcesans")) return "Source Sans 3";
  if (normalized.contains("times") || normalized.contains("major"))
    return "Times New Roman";
  if (normalized.contains("arial")) return "Arial";
  if (normalized.contains("tahoma")) return "Tahoma";
  if (normalized.contains("verdana")) return "Verdana";
  if (normalized.contains("gadugi")) return "Gadugi";
  if (normalized.contains("emoji")) return "Segoe UI Emoji";

  if (normalized.contains("zar")) return "Zar";
  if (normalized.contains("titr")) return "Titr";
  if (normalized.contains("yekan")) {
    if (normalized.contains("light")) return "YekanBakhLight";
    if (normalized.contains("extra")) return "YekanBakhExtraBold";
    return "YekanBakhBold";
  }
  return "Source Sans 3";
}

Color? _hexToColor(String? hexString) {
  if (hexString == null ||
      hexString.isEmpty ||
      hexString.toLowerCase() == 'auto')
    return null;
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return null;
  }
}

Widget _buildParagraph(
  ParagraphData para,
  double canvasWidth,
  double screenWidth,
  BuildContext context, {
  bool isImageCell = false,
  bool isInsideTableCell = false,
  ParagraphData? prevPara,
  ParagraphData? nextPara,
}) {
  if (para.spans.isEmpty ||
      (para.spans.length == 1 &&
          para.spans.first.type == "text" &&
          (para.spans.first.content == "\n" ||
              para.spans.first.content.trim().isEmpty))) {
    return const SizedBox.shrink();
  }

  List<Object> blockElements = [];
  List<InlineSpan> currentInlineSpans = [];

  TextAlign textAlign = TextAlign.left;
  if (para.alignment == "C") textAlign = TextAlign.center;
  if (para.alignment == "R") textAlign = TextAlign.right;
  if (para.alignment == "J") textAlign = TextAlign.justify;

  void flushText() {
    if (currentInlineSpans.isNotEmpty) {
      blockElements.add(
        WrappableText(
          text: TextSpan(children: List.from(currentInlineSpans)),
          textAlign: textAlign,
        ),
      );
      currentInlineSpans.clear();
    }
  }

  bool isLargeScreen = screenWidth >= 600;

  for (var span in para.spans) {
    if (span.type == "text") {
      currentInlineSpans.addAll(
        _buildStyledInteractiveText(
          span,
          para.interactives,
          context,
          isInsideTableCell: isInsideTableCell,
          para: para,
        ),
      );
    } else if (span.type == "image") {
      flushText();
      String imagePath = span.url ?? span.content;
      if (imagePath.isNotEmpty) {
        FCFloat floatAlign = FCFloat.none;

        if (isLargeScreen) {
          if (span.floatPosition == 'left') floatAlign = FCFloat.left;
          if (span.floatPosition == 'right') floatAlign = FCFloat.right;
        }

        blockElements.add(
          Floatable(
            float: floatAlign,
            clear: floatAlign == FCFloat.none ? FCClear.both : FCClear.none,
            padding: floatAlign == FCFloat.left
                ? const EdgeInsets.only(right: 16.0, bottom: 8.0, top: 4.0)
                : floatAlign == FCFloat.right
                ? const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 4.0)
                : EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 8.0),
            child: floatAlign == FCFloat.none
                ? Center(
                    child: _buildLocalImage(
                      imagePath,
                      isMobile: !isLargeScreen,
                      screenWidth: screenWidth,
                      isImageCell: isImageCell,
                    ),
                  )
                : _buildLocalImage(
                    imagePath,
                    isMobile: false,
                    screenWidth: screenWidth,
                    isImageCell: isImageCell,
                  ),
          ),
        );
      }
    } else if (span.type == "table") {
      flushText();
      blockElements.add(_buildTable(span, canvasWidth, screenWidth, context));
    }
  }

  flushText();

  // قبل از تغییر:
  // Widget paragraphContent = Directionality(
  //   textDirection: para.direction == "RTL" ? TextDirection.rtl : TextDirection.ltr,
  //   child: FloatColumn(children: blockElements),
  // );

  // 🌟 بعد از تغییر (تزریق سیستم ترجمه):
  Widget paragraphContent = TranslatableContentWrapper(
    translationFa: para.translationFa,
    translationAr: para.translationAr,
    originalContent: Directionality(
      textDirection: para.direction == "RTL"
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: FloatColumn(children: blockElements),
    ),
  );

  bool hasBgColor = para.fillColor != null && para.fillColor!.isNotEmpty;
  bool hasBorder = para.hasBorders == "true";

  double defaultBoxPadding = 6.0;
  double internalTopPadding = 0.0;
  double internalBottomPadding = 0.0;
  double externalTopMargin = 0.0;
  double externalBottomMargin = 0.0;

  bool sameColorBefore =
      prevPara != null && prevPara.fillColor == para.fillColor && hasBgColor;
  bool sameColorAfter =
      nextPara != null && nextPara.fillColor == para.fillColor && hasBgColor;

  double spaceBefore = isImageCell ? 0.0 : para.spaceBefore;
  double spaceAfter = isImageCell ? 0.0 : para.spaceAfter;

  if (hasBgColor) {
    internalTopPadding = sameColorBefore
        ? spaceBefore
        : (defaultBoxPadding + spaceBefore);
    internalBottomPadding = sameColorAfter
        ? spaceAfter
        : (defaultBoxPadding + spaceAfter);
  } else {
    externalTopMargin = spaceBefore;
    externalBottomMargin = spaceAfter;
  }

  if (hasBgColor || hasBorder) {
    Color borderColor = _hexToColor(para.borderColor) ?? Colors.grey.shade600;
    double borderWidth = 1.5;

    paragraphContent = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _hexToColor(para.fillColor),
        border: hasBorder
            ? Border(
                left: BorderSide(color: borderColor, width: borderWidth),
                right: BorderSide(color: borderColor, width: borderWidth),
                top: sameColorBefore
                    ? BorderSide.none
                    : BorderSide(color: borderColor, width: borderWidth),
                bottom: sameColorAfter
                    ? BorderSide.none
                    : BorderSide(color: borderColor, width: borderWidth),
              )
            : null,
        borderRadius: hasBorder
            ? BorderRadius.only(
                topLeft: sameColorBefore
                    ? Radius.zero
                    : const Radius.circular(6),
                topRight: sameColorBefore
                    ? Radius.zero
                    : const Radius.circular(6),
                bottomLeft: sameColorAfter
                    ? Radius.zero
                    : const Radius.circular(6),
                bottomRight: sameColorAfter
                    ? Radius.zero
                    : const Radius.circular(6),
              )
            : null,
      ),
      padding: (isInsideTableCell && hasBorder)
          ? EdgeInsets.zero
          : EdgeInsets.only(
              left: isInsideTableCell ? 2.0 : 10.0,
              right: isInsideTableCell ? 2.0 : 10.0,
              top: internalTopPadding,
              bottom: internalBottomPadding,
            ),
      child: paragraphContent,
    );
  }

  return Padding(
    padding: EdgeInsets.only(
      top: externalTopMargin,
      bottom: externalBottomMargin,
    ),
    child: paragraphContent,
  );
}

Widget _buildTable(
  SpanData tableSpan,
  double canvasWidth,
  double screenWidth,
  BuildContext context,
) {
  final bool isLargeScreen = screenWidth > 600;

  final String rawStyle =
      (tableSpan.tableStyleId ?? tableSpan.tableStyleName ?? "")
          .toLowerCase()
          .replaceAll(" ", "")
          .replaceAll("_", "");

  final bool isDottedTable = rawStyle.contains("dottedtable");
  final bool isTableGrid = rawStyle.contains("tablegrid");
  final bool isBorderedTable = rawStyle.contains("borderedtable");

  final bool hideBorders = isDottedTable || isTableGrid;

  double borderWidth = tableSpan.borderWidth ?? (isBorderedTable ? 1.0 : 0.5);
  Color borderColor =
      _hexToColor(tableSpan.borderColor) ??
      (isBorderedTable ? Colors.black : Colors.grey.shade400);

  BoxBorder? cellBorder;
  BoxBorder? tableBorder;

  if (!hideBorders && (isBorderedTable || tableSpan.hasBorders == "true")) {
    cellBorder = Border(
      right: BorderSide(color: borderColor, width: borderWidth),
      bottom: BorderSide(color: borderColor, width: borderWidth),
    );
    tableBorder = Border(
      top: BorderSide(color: borderColor, width: borderWidth),
      left: BorderSide(color: borderColor, width: borderWidth),
    );
  }

  List<Widget> rowWidgets = [];

  for (var row in tableSpan.tableRows) {
    List<Widget> cellWidgets = [];

    // 🌟 سیستم تشخیص هوشمند ردیف‌های کاملاً تصویری
    bool hasAnyImage = false;
    bool hasAnyText = false;

    for (var cell in row.cells) {
      bool isImg =
          cell.paragraphs.length == 1 &&
          cell.paragraphs.first.spans.any((s) => s.type == "image");
      bool isEmpty = cell.paragraphs.every(
        (p) =>
            p.spans.isEmpty ||
            (p.spans.length == 1 &&
                p.spans.first.type == "text" &&
                p.spans.first.content.trim().isEmpty),
      );

      if (isImg) {
        hasAnyImage = true;
      } else if (!isEmpty) {
        hasAnyText = true;
      }
    }

    // 🌟 اگر ردیف فقط شامل عکس (و سلول‌های خالی) باشد، آن را افقی نگه می‌داریم
    bool isImageRow = hasAnyImage && !hasAnyText;

    for (var cell in row.cells) {
      List<Widget> cellParagraphs = [];

      bool isImageCell =
          cell.paragraphs.length == 1 &&
          cell.paragraphs.first.spans.any((s) => s.type == "image");

      for (int pIndex = 0; pIndex < cell.paragraphs.length; pIndex++) {
        final p = cell.paragraphs[pIndex];
        final pPrev = pIndex > 0 ? cell.paragraphs[pIndex - 1] : null;
        final pNext = pIndex < cell.paragraphs.length - 1
            ? cell.paragraphs[pIndex + 1]
            : null;

        cellParagraphs.add(
          _buildParagraph(
            p,
            canvasWidth,
            screenWidth,
            context,
            isImageCell: isImageCell,
            isInsideTableCell: true,
            prevPara: pPrev,
            nextPara: pNext,
          ),
        );
      }

      double? currentCellWidth = cell.widthPercent;

      Widget cellContent = Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: _hexToColor(cell.fillColor),
          border: cellBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: cellParagraphs,
        ),
      );

      // 🌟 اعمال رفتار یکپارچه برای صفحه‌های بزرگ، جداول اصلی و ردیف‌های تصویری
      if (isLargeScreen || isBorderedTable || isImageRow) {
        if (currentCellWidth != null && currentCellWidth > 0) {
          cellWidgets.add(
            Expanded(
              flex: (currentCellWidth * 100).toInt(),
              child: cellContent,
            ),
          );
        } else {
          cellWidgets.add(Expanded(child: cellContent));
        }
      } else {
        cellWidgets.add(cellContent);
      }
    }

    // 🌟 چیدمان افقی تضمینی برای ردیف‌های تصویری حتی در موبایل
    if (isLargeScreen || isBorderedTable || isImageRow) {
      rowWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cellWidgets,
        ),
      );
    } else {
      rowWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cellWidgets,
        ),
      );
    }
  }

  Widget tableContainer = Container(
    margin: const EdgeInsets.symmetric(vertical: 12.0),
    decoration: BoxDecoration(
      color: _hexToColor(tableSpan.fillColor),
      border: tableBorder,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    ),
  );

  if (isBorderedTable && tableSpan.tableWidthPercent != null) {
    double docPct = tableSpan.tableWidthPercent!;

    if (isLargeScreen) {
      Alignment tableAlign = Alignment.centerLeft;
      if (tableSpan.tableAlignment == "center") tableAlign = Alignment.center;
      if (tableSpan.tableAlignment == "right")
        tableAlign = Alignment.centerRight;

      return Align(
        alignment: tableAlign,
        child: SizedBox(
          width: canvasWidth * (docPct / 100),
          child: tableContainer,
        ),
      );
    } else {
      if (docPct < 40) {
        return Align(
          alignment: Alignment.center,
          child: SizedBox(width: canvasWidth * 0.6, child: tableContainer),
        );
      }
      return tableContainer;
    }
  }

  return tableContainer;
}

List<InlineSpan> _buildStyledInteractiveText(
  SpanData span,
  List<InteractiveWord> interactives,
  BuildContext context, {
  bool isInsideTableCell = false,
  required ParagraphData para,
}) {
  double fontSize = 14.0;
  String? fontFamily;

  for (var marker in span.markers) {
    if (marker.startsWith("sz:")) {
      String sizeStr = marker.substring(3);
      double? parsedSize = double.tryParse(sizeStr);
      if (parsedSize != null) fontSize = parsedSize / 2;
    } else if (marker.startsWith("fn:")) {
      fontFamily = _mapFontFamily(marker.substring(3));
    }
  }

  Color? effectiveBgColor =
      _hexToColor(span.fillColor) ?? _hexToColor(para.fillColor);

  Color interactiveColor = Colors.blue;
  if (effectiveBgColor != null) {
    if (effectiveBgColor.computeLuminance() < 0.4) {
      interactiveColor = Colors.lightBlueAccent;
    } else {
      interactiveColor = Colors.blue.shade900;
    }
  }

  Color? customTextColor = _hexToColor(span.textColor);
  bool isAudioLink = span.url != null && span.url!.startsWith("audio:");

  if (isAudioLink) {
    customTextColor = interactiveColor;
  }

  bool isInlineBorder = span.hasBorders == "true";

  TextStyle baseStyle = TextStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    color: customTextColor ?? Colors.black87,
    height: 1.3,
    backgroundColor: !isInlineBorder ? _hexToColor(span.fillColor) : null,
    fontWeight: span.markers.contains("b")
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: span.markers.contains("i") ? FontStyle.italic : FontStyle.normal,
    decoration:
        (span.markers.contains("u")) // || isAudioLink)
        ? TextDecoration.underline
        : TextDecoration.none,
  );

  List<InlineSpan> interactiveSpans = [];

  if (isAudioLink) {
    String fileName = span.url!.replaceFirst("audio:", "");

    interactiveSpans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineAudioLink(
          fileName: fileName,
          text: span.content,
          baseColor:
              interactiveColor, // رنگی که هوشمندانه بر اساس بک‌گراند تعیین کرده بودید
        ),
      ),
    );
  } else {
    // ... ادامه کدهای قبلی برای کلمات تعاملی (InteractiveText) ... else {
    interactiveSpans = TextRenderEngine.buildInteractiveText(
      span.content,
      interactives,
      context,
      baseStyle,
      interactiveColor: interactiveColor,
    );
  }

  if (isInlineBorder) {
    return [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: isInsideTableCell
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          margin: isInsideTableCell
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: _hexToColor(span.fillColor),
            border: Border.all(
              color: _hexToColor(span.borderColor) ?? Colors.grey.shade600,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text.rich(TextSpan(children: interactiveSpans)),
        ),
      ),
    ];
  }

  return interactiveSpans;
}

Widget _buildLocalImage(
  String imageName, {
  required bool isMobile,
  required double screenWidth,
  required bool isImageCell,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 4.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(isImageCell ? 0 : 6),
      child: Image.asset(
        'assets/data/images/$imageName',
        fit: BoxFit.contain,
        // عکس‌های خارج از جدول در موبایل ۸۵٪ پهنا می‌گیرند، اما عکس‌های درون جدول اندازه خودشان را حفظ می‌کنند
        width: (isMobile && !isImageCell) ? screenWidth * 0.85 : null,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.red),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Image not found: $imageName",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// 🌟 ویجت هوشمند برای لینک‌های صوتی با قابلیت نمایش پیشرفت
class InlineAudioLink extends ConsumerWidget {
  final String fileName;
  final String text;
  final Color baseColor;

  const InlineAudioLink({
    super.key,
    required this.fileName,
    required this.text,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // گوش دادن به استیت پلیر ریورپاد
    final audioState = ref.watch(audioPlayerProvider);
    final fullPath = 'assets/data/audio/$fileName';

    // خواندن داده‌های آفلاین از حافظه (بدون نیاز به ایمپورت اضافه، GetStorage به صورت سینگلتون کار میکند)
    // نکته: اگر در این فایل GetStorage ایمپورت نشده، پکیج آن را در بالای صفحه اضافه کنید:
    // import 'package:get_storage/get_storage.dart';
    final box = GetStorage();

    // بررسی وضعیت
    bool isCurrent = audioState.currentPath == fullPath;
    bool isPlaying = isCurrent && audioState.isPlaying;

    // استخراج میلی‌ثانیه‌ها (یا از پلیر زنده یا از حافظه)
    int currentPosMs = isCurrent
        ? audioState.position.inMilliseconds
        : (box.read('pos_$fullPath') ?? 0);
    int currentDurMs = isCurrent && audioState.duration.inMilliseconds > 0
        ? audioState.duration.inMilliseconds
        : (box.read('dur_$fullPath') ?? 0);

    // محاسبه درصد پیشرفت (عددی بین 0.0 تا 1.0)
    double progress = currentDurMs > 0
        ? (currentPosMs / currentDurMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (isPlaying) {
          ref.read(audioPlayerProvider.notifier).pause();
        } else {
          ref.read(audioPlayerProvider.notifier).playFile(fullPath);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: baseColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress, // اگر 0 باشد، دایره خالی می‌ماند
                    strokeWidth: 2.5,
                    backgroundColor: baseColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                  ),
                  Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : (progress > 0 && progress < 1
                              ? Icons.play_arrow_rounded
                              : Icons.play_arrow_rounded),
                    size: 16,
                    color: baseColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: baseColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🌟 ویجت هوشمند و نامرئی برای مدیریت ترجمه با لمس طولانی (Long Press)
class TranslatableContentWrapper extends StatefulWidget {
  final Widget originalContent;
  final String? translationFa;
  final String? translationAr;
  final bool isDarkMode; // 🌟 برای تنظیم تضاد رنگی در مودال‌های تاریک

  const TranslatableContentWrapper({
    super.key,
    required this.originalContent,
    this.translationFa,
    this.translationAr,
    this.isDarkMode = false, // پیش‌فرض برای صفحات اصلی کتاب (روشن)
  });

  @override
  State<TranslatableContentWrapper> createState() =>
      _TranslatableContentWrapperState();
}

class _TranslatableContentWrapperState
    extends State<TranslatableContentWrapper> {
  bool _showTranslation = false;

  @override
  Widget build(BuildContext context) {
    bool hasTranslation =
        (widget.translationFa != null && widget.translationFa!.isNotEmpty) ||
        (widget.translationAr != null && widget.translationAr!.isNotEmpty);

    if (!hasTranslation) return widget.originalContent;

    String finalTranslation = (widget.translationFa?.isNotEmpty ?? false)
        ? widget.translationFa!
        : widget.translationAr!;

    // 🌟 تنظیم هوشمندِ تضاد رنگ‌ها بر اساس محیط (تاریک/روشن)
    Color bgColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.08)
        : Colors.blue.withOpacity(0.05);
    Color borderColor = widget.isDarkMode
        ? Colors.orangeAccent
        : Colors.blueAccent;
    Color textColor = widget.isDarkMode
        ? Colors.white.withOpacity(0.9)
        : Colors.black87;

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque, // تا فضای خالی پاراگراف هم قابل لمس باشد
      // 🌟 اجرای انیمیشن با لمس طولانی
      onLongPress: () {
        setState(() {
          _showTranslation = !_showTranslation;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.originalContent,

          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              margin: const EdgeInsets.only(top: 6, bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(right: BorderSide(color: borderColor, width: 3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                finalTranslation,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'YekanBakh', // فونت فارسی پروژه
                  fontSize: 14,
                  height: 1.6,
                  color: textColor,
                ),
              ),
            ),
            crossFadeState: _showTranslation
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }
}
