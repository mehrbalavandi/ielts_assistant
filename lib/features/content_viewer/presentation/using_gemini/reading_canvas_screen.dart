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

// کلاس کمکی برای هماهنگ نگه داشتن نقشه متن‌های جداول
class MapOffset {
  int value = 0;
}

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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final GlobalKey _targetParaKey = GlobalKey();

  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);

    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        int minIndex = positions
            .where((p) => p.itemTrailingEdge > 0)
            .map((p) => p.index)
            .reduce(math.min);
        final currentBook = ref.read(activeBookProvider);
        if (currentBook != null)
          _box.write('scroll_page_${currentBook.id}', minIndex);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTargetVisible());
  }

  void _handleTransformationChanged() {
    setState(
      () => _isZoomed =
          _transformationController.value.getMaxScaleOnAxis() > 1.05,
    );
  }

  void _ensureTargetVisible() {
    if (_targetParaKey.currentContext != null) {
      Scrollable.ensureVisible(
        _targetParaKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double canvasWidth = MediaQuery.of(context).size.width > 800
        ? 760.0
        : MediaQuery.of(context).size.width - 24;
    final currentBook = ref.read(activeBookProvider);
    final searchSession = ref.watch(activeSearchProvider);

    int initialIndex =
        _box.read('scroll_page_${currentBook?.id ?? "default"}') ?? 0;
    final activeTarget =
        (searchSession != null && searchSession.results.isNotEmpty)
        ? searchSession.results[searchSession.currentIndex] as SearchResult
        : null;

    if (activeTarget != null) {
      int pIndex = widget.documentPages.indexWhere(
        (p) => p.pageNumber == activeTarget.pageNumber,
      );
      if (pIndex != -1) initialIndex = pIndex;
    }

    // 🌟 رفع مشکل پرش‌های سرگیجه‌آور اسکرول با بررسی دیده شدن صفحه
    ref.listen<SearchSession?>(activeSearchProvider, (previous, next) async {
      if (next != null && next.results.isNotEmpty) {
        if (previous?.query != next.query ||
            previous?.currentIndex != next.currentIndex) {
          final target = next.results[next.currentIndex] as SearchResult;
          int pageIndex = widget.documentPages.indexWhere(
            (p) => p.pageNumber == target.pageNumber,
          );

          if (pageIndex != -1 && _itemScrollController.isAttached) {
            final visiblePositions = _itemPositionsListener.itemPositions.value;
            bool isPageVisible = visiblePositions.any(
              (pos) => pos.index == pageIndex,
            );

            if (!isPageVisible) {
              _itemScrollController.jumpTo(index: pageIndex, alignment: 0.0);
              await Future.delayed(
                const Duration(milliseconds: 100),
              ); // فرصت برای رندر فلاتر
            } else {
              await Future.delayed(const Duration(milliseconds: 50));
            }
            _ensureTargetVisible();
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
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
                      child: ScrollablePositionedList.builder(
                        itemCount: widget.documentPages.length,
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        initialScrollIndex:
                            initialIndex < widget.documentPages.length
                            ? initialIndex
                            : 0,
                        physics: (_pointerCount >= 2 || _isZoomed)
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        itemBuilder: (context, pageIndex) {
                          final page = widget.documentPages[pageIndex];
                          List<Widget> paragraphWidgets = [];

                          for (
                            int pIndex = 0;
                            pIndex < page.paragraphs.length;
                            pIndex++
                          ) {
                            var para = page.paragraphs[pIndex];
                            bool isTargetParagraph =
                                activeTarget != null &&
                                activeTarget.pageNumber == page.pageNumber &&
                                activeTarget.paraIndex == pIndex;

                            // ایجاد نقشه یکپارچه برای کل پاراگراف و جدول‌های درون آن
                            List<int>? rootHighlightMap;
                            if (searchSession?.query != null &&
                                searchSession!.query.isNotEmpty) {
                              String fullText = _extractFullText(para);
                              rootHighlightMap = _buildOccurrenceMap(
                                fullText,
                                searchSession!.query,
                              );
                            }
                            MapOffset offset = MapOffset();

                            Widget paragraphContent = _buildParagraph(
                              para,
                              canvasWidth,
                              MediaQuery.of(context).size.width,
                              context,
                              rootHighlightMap: rootHighlightMap,
                              mapOffset: offset,
                              activeOccurrence: isTargetParagraph
                                  ? activeTarget.occurrenceIndex
                                  : null,
                            );

                            if (isTargetParagraph)
                              paragraphContent = Container(
                                key: _targetParaKey,
                                child: paragraphContent,
                              );
                            paragraphWidgets.add(paragraphContent);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPageDivider(page.pageNumber),
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: 24.0,
                                  left: 8.0,
                                  right: 8.0,
                                ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: paragraphWidgets,
                                ),
                              ),
                            ],
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

// 🌟 نقشه‌ساز کلمات جستجوشده در پاراگراف
String _normalizeText(String text) {
  return text
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ة', 'ه')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('\u200c', ' ');
}

String _extractFullText(ParagraphData para) {
  StringBuffer sb = StringBuffer();
  for (var span in para.spans) {
    if (span.type == "text" && span.content != null)
      sb.write(span.content);
    else if (span.type == "table" && span.tableRows != null) {
      for (var row in span.tableRows!) {
        for (var cell in row.cells) {
          for (var cellPara in cell.paragraphs)
            sb.write(_extractFullText(cellPara));
        }
      }
    }
  }
  return sb.toString();
}

List<int> _buildOccurrenceMap(String fullText, String query) {
  String nText = _normalizeText(fullText);
  String nQuery = _normalizeText(query);
  List<int> map = List.filled(fullText.length, -1);
  if (nQuery.isEmpty) return map;

  int matchIndex = nText.indexOf(nQuery);
  int occ = 0;
  while (matchIndex != -1) {
    for (int i = 0; i < nQuery.length; i++) {
      if (matchIndex + i < map.length) map[matchIndex + i] = occ;
    }
    occ++;
    matchIndex = nText.indexOf(nQuery, matchIndex + nQuery.length);
  }
  return map;
}

Widget _buildPageDivider(int pageNumber) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0, left: 8.0, right: 8.0),
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
  List<int>? rootHighlightMap,
  MapOffset? mapOffset,
  int? activeOccurrence, // 🌟 نقشه‌های لیزری متن
}) {
  if (para.spans.isEmpty ||
      (para.spans.length == 1 &&
          para.spans.first.type == "text" &&
          (para.spans.first.content == "\n" ||
              para.spans.first.content.trim().isEmpty)))
    return const SizedBox.shrink();

  if (mapOffset == null) mapOffset = MapOffset(); // پشتیبان ایمنی

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
      String content = span.content ?? '';
      List<int>? localMap;
      if (rootHighlightMap != null &&
          content.isNotEmpty &&
          mapOffset.value + content.length <= rootHighlightMap.length) {
        localMap = rootHighlightMap.sublist(
          mapOffset.value,
          mapOffset.value + content.length,
        );
      }
      currentInlineSpans.addAll(
        _buildStyledInteractiveText(
          span,
          para.interactives,
          context,
          isInsideTableCell: isInsideTableCell,
          para: para,
          localMap: localMap,
          activeOccurrence: activeOccurrence,
        ),
      );
      mapOffset.value += content.length;
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
      blockElements.add(
        _buildTable(
          span,
          canvasWidth,
          screenWidth,
          context,
          rootHighlightMap,
          mapOffset,
          activeOccurrence,
        ),
      );
    }
  }

  flushText();

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
  double defaultBoxPadding = 6.0,
      internalTopPadding = 0.0,
      internalBottomPadding = 0.0,
      externalTopMargin = 0.0,
      externalBottomMargin = 0.0;
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
  List<int>? rootMap,
  MapOffset? mapOffset,
  int? activeOcc,
) {
  final bool isLargeScreen = screenWidth > 600;
  final String rawStyle =
      (tableSpan.tableStyleId ?? tableSpan.tableStyleName ?? "")
          .toLowerCase()
          .replaceAll(" ", "")
          .replaceAll("_", "");
  final bool isBorderedTable = rawStyle.contains("borderedtable");
  final bool hideBorders =
      rawStyle.contains("dottedtable") || rawStyle.contains("tablegrid");
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
    bool hasAnyImage = false, hasAnyText = false;
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
      if (isImg)
        hasAnyImage = true;
      else if (!isEmpty)
        hasAnyText = true;
    }
    bool isImageRow = hasAnyImage && !hasAnyText;

    for (var cell in row.cells) {
      List<Widget> cellParagraphs = [];
      bool isImageCell =
          cell.paragraphs.length == 1 &&
          cell.paragraphs.first.spans.any((s) => s.type == "image");
      for (int pIndex = 0; pIndex < cell.paragraphs.length; pIndex++) {
        cellParagraphs.add(
          _buildParagraph(
            cell.paragraphs[pIndex],
            canvasWidth,
            screenWidth,
            context,
            isImageCell: isImageCell,
            isInsideTableCell: true,
            prevPara: pIndex > 0 ? cell.paragraphs[pIndex - 1] : null,
            nextPara: pIndex < cell.paragraphs.length - 1
                ? cell.paragraphs[pIndex + 1]
                : null,
            rootHighlightMap: rootMap,
            mapOffset: mapOffset,
            activeOccurrence: activeOcc,
          ),
        );
      }
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
      if (isLargeScreen || isBorderedTable || isImageRow) {
        if (cell.widthPercent != null && cell.widthPercent! > 0)
          cellWidgets.add(
            Expanded(
              flex: (cell.widthPercent! * 100).toInt(),
              child: cellContent,
            ),
          );
        else
          cellWidgets.add(Expanded(child: cellContent));
      } else {
        cellWidgets.add(cellContent);
      }
    }
    if (isLargeScreen || isBorderedTable || isImageRow)
      rowWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cellWidgets,
        ),
      );
    else
      rowWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cellWidgets,
        ),
      );
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
    if (isLargeScreen) {
      Alignment tableAlign = Alignment.centerLeft;
      if (tableSpan.tableAlignment == "center") tableAlign = Alignment.center;
      if (tableSpan.tableAlignment == "right")
        tableAlign = Alignment.centerRight;
      return Align(
        alignment: tableAlign,
        child: SizedBox(
          width: canvasWidth * (tableSpan.tableWidthPercent! / 100),
          child: tableContainer,
        ),
      );
    } else {
      if (tableSpan.tableWidthPercent! < 40)
        return Align(
          alignment: Alignment.center,
          child: SizedBox(width: canvasWidth * 0.6, child: tableContainer),
        );
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
  List<int>? localMap,
  int? activeOccurrence,
}) {
  double fontSize = 14.0;
  String? fontFamily;
  for (var marker in span.markers) {
    if (marker.startsWith("sz:")) {
      double? parsedSize = double.tryParse(marker.substring(3));
      if (parsedSize != null) fontSize = parsedSize / 2;
    } else if (marker.startsWith("fn:"))
      fontFamily = _mapFontFamily(marker.substring(3));
  }

  Color? effectiveBgColor =
      _hexToColor(span.fillColor) ?? _hexToColor(para.fillColor);
  Color interactiveColor = Colors.blue;
  if (effectiveBgColor != null) {
    interactiveColor = effectiveBgColor.computeLuminance() < 0.4
        ? Colors.lightBlueAccent
        : Colors.blue.shade900;
  }
  Color? customTextColor = _hexToColor(span.textColor);
  bool isAudioLink = span.url != null && span.url!.startsWith("audio:");
  if (isAudioLink) customTextColor = interactiveColor;
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
    decoration: (span.markers.contains("u"))
        ? TextDecoration.underline
        : TextDecoration.none,
  );

  List<InlineSpan> interactiveSpans = [];
  if (isAudioLink) {
    interactiveSpans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineAudioLink(
          fileName: span.url!.replaceFirst("audio:", ""),
          text: span.content ?? '',
          baseColor: interactiveColor,
        ),
      ),
    );
  } else {
    interactiveSpans = TextRenderEngine.buildInteractiveText(
      span.content ?? '',
      interactives,
      context,
      baseStyle,
      interactiveColor: interactiveColor,
      localHighlightMap: localMap,
      activeOccurrence: activeOccurrence,
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
        width: (isMobile && !isImageCell) ? screenWidth * 0.85 : null,
        errorBuilder: (context, error, stackTrace) => Container(
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
        ),
      ),
    ),
  );
}

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
    final audioState = ref.watch(audioPlayerProvider);
    final fullPath = 'assets/data/audio/$fileName';
    final box = GetStorage();
    bool isCurrent = audioState.currentPath == fullPath;
    bool isPlaying = isCurrent && audioState.isPlaying;
    int currentPosMs = isCurrent
        ? audioState.position.inMilliseconds
        : (box.read('pos_$fullPath') ?? 0);
    int currentDurMs = isCurrent && audioState.duration.inMilliseconds > 0
        ? audioState.duration.inMilliseconds
        : (box.read('dur_$fullPath') ?? 0);
    double progress = currentDurMs > 0
        ? (currentPosMs / currentDurMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (isPlaying)
          ref.read(audioPlayerProvider.notifier).pause();
        else
          ref.read(audioPlayerProvider.notifier).playFile(fullPath);
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
                    value: progress,
                    strokeWidth: 2.5,
                    backgroundColor: baseColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                  ),
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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

class TranslatableContentWrapper extends StatefulWidget {
  final Widget originalContent;
  final String? translationFa;
  final String? translationAr;
  final bool isDarkMode;
  const TranslatableContentWrapper({
    super.key,
    required this.originalContent,
    this.translationFa,
    this.translationAr,
    this.isDarkMode = false,
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
      behavior: HitTestBehavior.opaque,
      onLongPress: () => setState(
        () => _showTranslation = !_showTranslation,
      ), // 🌟 بازگشت قطعی به لمس طولانی
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
                  fontFamily: 'YekanBakh',
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
