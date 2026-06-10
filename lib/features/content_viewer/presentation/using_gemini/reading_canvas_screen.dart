import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:float_column/float_column.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';
import 'package:just_audio/just_audio.dart';

class ReadingCanvasScreen extends StatefulWidget {
  final List<ParagraphData> documentParagraphs;

  const ReadingCanvasScreen({super.key, required this.documentParagraphs});

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
    double canvasWidth = screenWidth > 650 ? 650 : screenWidth;

    return Listener(
      onPointerDown: (event) {
        _pointerCount++;
        if (_pointerCount >= 2) {
          setState(() {});
        }
      },
      onPointerUp: (event) {
        _pointerCount = Matrix4.identity() == _transformationController.value
            ? 0
            : _pointerCount - 1;
        if (_pointerCount < 0) _pointerCount = 0;
        setState(() {});
      },
      onPointerCancel: (event) {
        _pointerCount = 0;
        setState(() {});
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            panEnabled: _isZoomed,
            scaleEnabled: true,
            clipBehavior: Clip.none,
            child: SingleChildScrollView(
              physics: (_pointerCount >= 2 || _isZoomed)
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: Container(
                width: screenWidth,
                color: Colors.grey[100],
                child: Center(
                  child: Container(
                    width: canvasWidth,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // 🌟 اصلاح اول: ارسال پاراگراف‌های همسایه (قبل و بعد) برای مدیریت هوشمند Shading متوالی
                      children: List.generate(
                        widget.documentParagraphs.length,
                        (index) {
                          final para = widget.documentParagraphs[index];
                          final prevPara = index > 0
                              ? widget.documentParagraphs[index - 1]
                              : null;
                          final nextPara =
                              index < widget.documentParagraphs.length - 1
                              ? widget.documentParagraphs[index + 1]
                              : null;

                          return _buildParagraph(
                            para,
                            canvasWidth,
                            screenWidth,
                            context,
                            prevPara: prevPara,
                            nextPara: nextPara,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
    ParagraphData? prevPara, // 🌟 اضافه شدن همسایه قبلی
    ParagraphData? nextPara, // 🌟 اضافه شدن همسایه بعدی
  }) {
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return const SizedBox(height: 0.0);
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
          _buildStyledInteractiveText(span, para.interactives, context),
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

    // 🌟 منطق هوشمند ادغام پدینگ‌ها و فواصل متوالی برای Shading یکپارچه
    double internalTopPadding = 10.0;
    double internalBottomPadding = 10.0;
    double externalTopMargin = 0.0;
    double externalBottomMargin = 0.0;

    bool sameColorBefore =
        prevPara != null && prevPara.fillColor == para.fillColor && hasBgColor;
    bool sameColorAfter =
        nextPara != null && nextPara.fillColor == para.fillColor && hasBgColor;

    if (hasBgColor) {
      // اگر بک‌گراند داریم، فواصل را می‌آوریم داخل باکس تا فضا رنگی بماند
      internalTopPadding += isImageCell ? 0.0 : para.spaceBefore;
      internalBottomPadding += isImageCell ? 0.0 : para.spaceAfter;
    } else {
      // اگر بک‌گراند نداریم، فواصل خارج از باکس به عنوان مارجین اعمال می‌شوند
      externalTopMargin = isImageCell ? 0.0 : para.spaceBefore;
      externalBottomMargin = isImageCell ? 0.0 : para.spaceAfter;
    }

    if (hasBgColor || hasBorder) {
      Color borderColor = _hexToColor(para.borderColor) ?? Colors.grey.shade600;
      double borderWidth = 1.5;

      paragraphContent = Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _hexToColor(para.fillColor),
          // ادغام هوشمند بوردرها در صورت یکسان بودن shading همسایه‌ها
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
          // ادغام هوشمند انحنای گوشه‌ها (فقط بالا و پایین کل بلاک یکپارچه منحنی شود)
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
        padding: EdgeInsets.only(
          left: 10.0,
          right: 10.0,
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

  List<InlineSpan> _buildStyledInteractiveText(
    SpanData span,
    List<InteractiveWord> interactives,
    BuildContext context,
  ) {
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

    Color? customTextColor = _hexToColor(span.textColor);
    bool isAudioLink = span.url != null && span.url!.startsWith("audio:");

    if (isAudioLink) {
      customTextColor = Colors.blue;
    }
    bool isInlineBorder = span.hasBorders == "true";

    TextStyle baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      color: customTextColor ?? Colors.black87,
      height: 1.5,
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
      );
    }

    if (isInlineBorder) {
      return [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
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
    bool isMobile = false,
    required double screenWidth,
    bool isImageCell = false,
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

  Widget _buildTable(
    SpanData tableSpan,
    double canvasWidth,
    BuildContext context,
  ) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isLargeScreen = screenWidth >= 600;

    List<Widget> rowWidgets = [];
    Color? tableBgColor = _hexToColor(tableSpan.fillColor);
    bool hasBorders = tableSpan.hasBorders?.toLowerCase() == "true";

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

        Widget cellContent = Container(
          decoration: BoxDecoration(
            color: cellBgColor,
            border: hasBorders
                ? Border(
                    right: BorderSide(color: Colors.grey.shade400, width: 0.5),
                    bottom: BorderSide(color: Colors.grey.shade400, width: 0.5),
                  )
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isImageCell ? 0.0 : 12.0,
            vertical: isImageCell ? 0.0 : 4.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: vAlign,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // 🌟 اصلاح دوم: پیاده‌سازی منطق همسایگی در پاراگراف‌های متوالی داخل سلول‌های جدول
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

        cellWidgets.add(
          isLargeScreen
              ? Expanded(flex: flexValue, child: cellContent)
              : SizedBox(width: double.infinity, child: cellContent),
        );
      }

      if (isLargeScreen) {
        List<Widget> spacedRowChildren = [];
        for (int i = 0; i < cellWidgets.length; i++) {
          spacedRowChildren.add(cellWidgets[i]);
          if (i != cellWidgets.length - 1) {
            spacedRowChildren.add(const SizedBox(width: 24.0));
          }
        }

        rowWidgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: spacedRowChildren,
          ),
        );
      } else {
        List<Widget> spacedColChildren = [];
        for (int i = 0; i < cellWidgets.length; i++) {
          spacedColChildren.add(cellWidgets[i]);
          if (i != cellWidgets.length - 1) {
            spacedColChildren.add(const SizedBox(height: 0.0));
          }
        }

        rowWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: spacedColChildren,
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: hasBorders
            ? Border(
                top: BorderSide(color: Colors.grey.shade400, width: 0.5),
                left: BorderSide(color: Colors.grey.shade400, width: 0.5),
              )
            : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
    );
  }
}
