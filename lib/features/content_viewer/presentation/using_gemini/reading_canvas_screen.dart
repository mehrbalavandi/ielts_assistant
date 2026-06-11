import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:float_column/float_column.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';
import 'package:just_audio/just_audio.dart';

class ReadingCanvasScreen extends StatefulWidget {
  final List<PageData> documentPages;

  const ReadingCanvasScreen({super.key, required this.documentPages});

  @override
  State<ReadingCanvasScreen> createState() => _ReadingCanvasScreenState();
}

class _ReadingCanvasScreenState extends State<ReadingCanvasScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TransformationController _transformationController =
      TransformationController();

  bool _isZoomed = false;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    bool zoomed = scale > 1.02;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double canvasWidth = screenWidth > 800 ? 760.0 : screenWidth - 32;

    return Scaffold(
      backgroundColor: Colors.grey.shade100, // رنگ پس‌زمینه بیرونی
      body: SafeArea(
        child: Listener(
          onPointerDown: (event) {
            _pointerCount++;
            if (_pointerCount >= 2) {
              setState(() {});
            }
          },
          onPointerUp: (event) {
            _pointerCount =
                Matrix4.identity() == _transformationController.value
                ? 0
                : _pointerCount - 1;
            if (_pointerCount < 0) _pointerCount = 0;
            setState(() {});
          },
          onPointerCancel: (event) {
            _pointerCount = 0;
            setState(() {});
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            scaleEnabled: true,
            panEnabled: _isZoomed || _pointerCount > 1,
            minScale: 1.0,
            maxScale: 3.0,
            child: Center(
              child: SizedBox(
                width: canvasWidth,
                child: ListView.builder(
                  physics: (_pointerCount >= 2 || _isZoomed)
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20.0,
                    horizontal: 8.0,
                  ),
                  itemCount: widget.documentPages.length,
                  itemBuilder: (context, pageIndex) {
                    final page = widget.documentPages[pageIndex];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // هدر تفکیک‌کننده و شماره صفحه
                        _buildPageDivider(page.pageNumber),

                        // بدنه فیزیکی صفحه کاغذ
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(page.paragraphs.length, (
                              pIndex,
                            ) {
                              final p = page.paragraphs[pIndex];
                              final pPrev = pIndex > 0
                                  ? page.paragraphs[pIndex - 1]
                                  : null;
                              final pNext = pIndex < page.paragraphs.length - 1
                                  ? page.paragraphs[pIndex + 1]
                                  : null;

                              return _buildParagraph(
                                p,
                                canvasWidth,
                                screenWidth,
                                context,
                                isInsideTableCell: false,
                                prevPara: pPrev,
                                nextPara: pNext,
                              );
                            }),
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
    );
  }

  Widget _buildPageDivider(int pageNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "PAGE $pageNumber",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1.2)),
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
        blockElements.add(_buildTable(span, canvasWidth, context));
      }
    }

    flushText();

    Widget paragraphContent = Directionality(
      textDirection: para.direction == "RTL"
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: FloatColumn(children: blockElements),
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
    BuildContext context,
  ) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isLargeScreen = screenWidth >= 600;

    // 🌟 اصلاح ۱: شرط ضدگلوله! (حذف تمام فاصله‌ها و تبدیل به حروف کوچک برای شناسایی قطعی)
    String styleId = (tableSpan.tableStyleId ?? tableSpan.tableStyleName ?? "")
        .toLowerCase()
        .replaceAll(" ", "")
        .replaceAll("_", "");

    bool isTableGrid = styleId.contains("tablegrid");

    List<Widget> rowWidgets = [];
    Color? tableBgColor = _hexToColor(tableSpan.fillColor);
    bool hasBorders = tableSpan.hasBorders?.toLowerCase() == "true";

    Color borderColor = Colors.grey.shade400;
    double borderWidth = 0.5;

    // 🌟 اصلاح ۲: اعمال دقیق رنگ‌ها
    if (isTableGrid) {
      // اولویت اول: خواندن رنگی که شما به صورت دستی در ورد تنظیم کردید.
      // اولویت دوم (اگر رنگی ست نشده بود): مشکی استاندارد جدول‌های گرید.
      borderColor = _hexToColor(tableSpan.borderColor) ?? Colors.black87;

      // نکته: چون ضخامت را از JSON نداریم، یک ضخامت استاندارد و توپر برای آن در نظر می‌گیریم.
      borderWidth = 1.2;
    } else {
      borderColor = _hexToColor(tableSpan.borderColor) ?? Colors.grey.shade400;
      borderWidth = 0.5;
    }

    double totalWidthPercent = 1.0;
    if (tableSpan.tableRows.isNotEmpty &&
        tableSpan.tableRows.first.cells.isNotEmpty) {
      double sum = 0.0;
      for (var cell in tableSpan.tableRows.first.cells) {
        sum += cell.widthPercent ?? 0.0;
      }
      if (sum > 0.05 && sum <= 1.0) {
        totalWidthPercent = sum;
      }
    }

    for (var row in tableSpan.tableRows) {
      List<Widget> cellWidgets = [];

      for (var cell in row.cells) {
        if (cell.rowMerge == "continue") continue;

        int flexValue = 1;
        if (cell.widthPercent != null && cell.widthPercent! > 0) {
          flexValue = (cell.widthPercent! * 100).toInt();
        }

        Color? cellBgColor = _hexToColor(cell.fillColor) ?? tableBgColor;
        if (cell.isHeaderCell && cellBgColor == null) {
          cellBgColor = Colors.grey.shade200;
        }

        MainAxisAlignment vAlign = MainAxisAlignment.start;
        if (cell.vAlign == "center") vAlign = MainAxisAlignment.center;
        if (cell.vAlign == "bottom") vAlign = MainAxisAlignment.end;

        bool isImageCell =
            cell.paragraphs.length == 1 &&
            cell.paragraphs.first.spans.any((s) => s.type == "image");

        bool isEmptyCell = cell.paragraphs.every(
          (p) =>
              p.spans.isEmpty ||
              (p.spans.length == 1 &&
                  p.spans.first.type == "text" &&
                  p.spans.first.content.trim().isEmpty),
        );

        Widget cellContent = Container(
          decoration: BoxDecoration(
            color: cellBgColor,
            border: hasBorders
                ? Border(
                    right: BorderSide(color: borderColor, width: borderWidth),
                    bottom: BorderSide(color: borderColor, width: borderWidth),
                  )
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: (isImageCell || isEmptyCell) ? 0.0 : 6.0,
            vertical: (isImageCell || isEmptyCell) ? 0.0 : 6.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: vAlign,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(cell.paragraphs.length, (pIndex) {
              final p = cell.paragraphs[pIndex];
              final pPrev = pIndex > 0 ? cell.paragraphs[pIndex - 1] : null;
              final pNext = pIndex < cell.paragraphs.length - 1
                  ? cell.paragraphs[pIndex + 1]
                  : null;

              return _buildParagraph(
                p,
                canvasWidth,
                screenWidth,
                context,
                isImageCell: isImageCell,
                isInsideTableCell: true,
                prevPara: pPrev,
                nextPara: pNext,
              );
            }),
          ),
        );

        cellWidgets.add(Expanded(flex: flexValue, child: cellContent));
      }

      if (isTableGrid || isLargeScreen) {
        rowWidgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cellWidgets,
          ),
        );
      } else {
        List<Widget> spacedColChildren = [];
        for (int i = 0; i < cellWidgets.length; i++) {
          Widget currentCell = cellWidgets[i];

          if (currentCell is Expanded) {
            currentCell = currentCell.child;
          } else if (currentCell is Flexible) {
            currentCell = currentCell.child;
          }

          spacedColChildren.add(currentCell);
        }

        rowWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spacedColChildren,
          ),
        );
      }
    }

    Widget tableContent = Container(
      decoration: BoxDecoration(
        border: hasBorders
            ? Border(
                top: BorderSide(color: borderColor, width: borderWidth),
                left: BorderSide(color: borderColor, width: borderWidth),
              )
            : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
    );

    if (isTableGrid && isLargeScreen && totalWidthPercent < 0.95) {
      Alignment tableAlignment = Alignment.centerLeft;
      if (tableSpan.tableAlignment?.toLowerCase() == "center") {
        tableAlignment = Alignment.center;
      }
      if (tableSpan.tableAlignment?.toLowerCase() == "right") {
        tableAlignment = Alignment.centerRight;
      }

      return Align(
        alignment: tableAlignment,
        child: FractionallySizedBox(
          widthFactor: totalWidthPercent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: tableContent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: tableContent,
    );
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
      fontStyle: span.markers.contains("i")
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: (span.markers.contains("u") || isAudioLink)
          ? TextDecoration.underline
          : TextDecoration.none,
    );

    List<InlineSpan> interactiveSpans = [];

    if (isAudioLink) {
      interactiveSpans.add(
        TextSpan(
          text: span.content,
          style: baseStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              String fileName = span.url!.replaceFirst("audio:", "");
              try {
                await _audioPlayer.stop();
                await _audioPlayer.setAsset('assets/data/audio/$fileName');
                _audioPlayer.play();
              } catch (e) {
                debugPrint("Error playing audio: $e");
              }
            },
        ),
      );
    } else {
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
}
