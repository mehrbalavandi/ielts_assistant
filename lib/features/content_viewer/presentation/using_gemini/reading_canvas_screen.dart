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

  // متغیر وضعیت برای مدیریت هوشمند فیزیک حرکتی
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // اگر زوم بیشتر از حد معمولی شد، وضعیت تغییر می‌کند
    bool zoomed = scale > 1.01;
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        // 🌟 ۱. InteractiveViewer حالا والد اصلی است و کل صفحه را مدیریت می‌کند
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,

          // 🌟 ۲. شاه‌کلید سرعت: جابجایی دو بعدی فقط و فقط زمانی فعال می‌شود که زوم شده باشیم.
          // در حالت عادی (Scale = 1) این ویژگی غیرفعال است تا حرکت انگشت مستقیماً به اسکرولرِ فرزند برسد.
          panEnabled: _isZoomed,
          scaleEnabled: true, // زوم دو انگشتی همیشه بیدار و آماده به کار است

          child: SingleChildScrollView(
            // 🌟 ۳. سوئیچ فیزیک هوشمند:
            // در حالت عادی اسکرول نیتیو و روان فعال است. در حالت زوم، اسکرولر داخلی قفل می‌شود
            // تا با حرکت پانِ InteractiveViewer تداخل پیدا نکند.
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),

            child: Container(
              width:
                  screenWidth, // فیکس کردن عرض کانتینر برای جلوگیری از لقی افقی در حالت عادی
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
                    children: widget.documentParagraphs
                        .map(
                          (para) => _buildParagraph(
                            para,
                            canvasWidth,
                            screenWidth,
                            context,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (بقیه متدهای کمکی شما مثل _buildParagraph و غیره بدون تغییر باقی می‌مانند)

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
  }) {
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return SizedBox(height: isImageCell ? 0 : 8.0);
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
                  : EdgeInsets.symmetric(vertical: isImageCell ? 0.0 : 16.0),
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

    if (hasBgColor || hasBorder) {
      paragraphContent = Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _hexToColor(para.fillColor),
          border: hasBorder
              ? Border.all(
                  color: _hexToColor(para.borderColor) ?? Colors.grey.shade600,
                  width: 1.5,
                )
              : null,
          borderRadius: hasBorder ? BorderRadius.circular(6) : null,
        ),
        padding: const EdgeInsets.all(10.0),
        child: paragraphContent,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: isImageCell ? 0.0 : (isInsideTableCell ? 0.0 : 8.0),
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
                // اطمینان از متوقف شدن صدای قبلی قبل از پخش صدای جدید
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
          padding: EdgeInsets.all(isImageCell ? 0.0 : 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: vAlign,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cell.paragraphs
                .map(
                  (p) => _buildParagraph(
                    p,
                    canvasWidth,
                    screenWidth,
                    context,
                    isImageCell: isImageCell,
                    isInsideTableCell: true,
                  ),
                )
                .toList(),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          border: hasBorders
              ? Border(
                  top: BorderSide(color: Colors.grey.shade400, width: 0.5),
                  left: BorderSide(color: Colors.grey.shade400, width: 0.5),
                )
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
      ),
    );
  }
}
