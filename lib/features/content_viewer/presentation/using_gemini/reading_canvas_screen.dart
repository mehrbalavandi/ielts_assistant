import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/text_render_engine.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/models.dart';

class ReadingCanvasScreen extends StatefulWidget {
  final List<ParagraphData> documentParagraphs;

  const ReadingCanvasScreen({super.key, required this.documentParagraphs});

  @override
  State<ReadingCanvasScreen> createState() => _ReadingCanvasScreenState();
}

class _ReadingCanvasScreenState extends State<ReadingCanvasScreen> {
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
    if (scale <= 1.01 && _isZoomed && _pointerCount == 0) {
      setState(() {
        _isZoomed = false;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  // متد کمکی: تبدیل کدهای Hex ورد به Color فلاتر
  Color? _hexToColor(String? hexString) {
    if (hexString == null ||
        hexString.isEmpty ||
        hexString.toLowerCase() == 'auto') {
      return null;
    }
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double canvasWidth = screenWidth > 650 ? 650 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            _pointerCount++;
            if (_pointerCount >= 2 && !_isZoomed) {
              setState(() {
                _isZoomed = true;
              });
            }
          },
          onPointerUp: (PointerUpEvent event) {
            _pointerCount = (_pointerCount - 1).clamp(0, 10);
            if (_pointerCount == 0) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              if (scale <= 1.01 && _isZoomed) {
                setState(() {
                  _isZoomed = false;
                });
              }
            }
          },
          onPointerCancel: (PointerCancelEvent event) {
            _pointerCount = (_pointerCount - 1).clamp(0, 10);
            if (_pointerCount == 0) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              if (scale <= 1.01 && _isZoomed) {
                setState(() {
                  _isZoomed = false;
                });
              }
            }
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            panEnabled: _isZoomed,
            scaleEnabled: true,
            constrained: true,
            child: SingleChildScrollView(
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
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
                          (para) => _buildParagraph(para, canvasWidth, context),
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

  Widget _buildParagraph(
    ParagraphData para,
    double canvasWidth,
    BuildContext context,
  ) {
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return const SizedBox(height: 16);
    }

    List<Widget> blockElements = [];
    List<InlineSpan> inlineSpans = [];

    TextAlign textAlign = TextAlign.left;
    if (para.alignment == "C") textAlign = TextAlign.center;
    if (para.alignment == "R") textAlign = TextAlign.right;
    if (para.alignment == "J") textAlign = TextAlign.justify;

    for (var span in para.spans) {
      if (span.type == "text") {
        inlineSpans.addAll(
          _buildStyledInteractiveText(span, para.interactives, context),
        );
      } else if (span.type == "image") {
        if (inlineSpans.isNotEmpty) {
          blockElements.add(
            _buildRichText(inlineSpans, para.direction, textAlign),
          );
          inlineSpans = [];
        }
        String imagePath = span.url ?? span.content;
        if (imagePath.isNotEmpty) {
          blockElements.add(_buildLocalImage(imagePath));
        }
      } else if (span.type == "table") {
        if (inlineSpans.isNotEmpty) {
          blockElements.add(
            _buildRichText(inlineSpans, para.direction, textAlign),
          );
          inlineSpans = [];
        }
        blockElements.add(_buildTable(span, canvasWidth, context));
      }
    }

    if (inlineSpans.isNotEmpty) {
      blockElements.add(_buildRichText(inlineSpans, para.direction, textAlign));
    }

    Widget paragraphContent = Column(
      crossAxisAlignment: para.direction == "RTL"
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: blockElements,
    );

    // اعمال رنگ پس‌زمینه (Shading) برای کل پاراگراف
    if (para.fillColor != null && para.fillColor!.isNotEmpty) {
      paragraphContent = Container(
        width: double.infinity,
        color: _hexToColor(para.fillColor),
        padding: const EdgeInsets.all(6.0),
        child: paragraphContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: paragraphContent,
    );
  }

  // متد آپدیت‌شده: دریافت مستقیم شیء SpanData برای پشتیبانی از FillColor کلمات
  List<InlineSpan> _buildStyledInteractiveText(
    SpanData span,
    List<InteractiveWord> interactives,
    BuildContext context,
  ) {
    double fontSize = 13.0;
    String? fontFamily;

    for (var marker in span.markers) {
      if (marker.startsWith("sz:")) {
        String sizeStr = marker.substring(3);
        double? parsedSize = double.tryParse(sizeStr);
        if (parsedSize != null) fontSize = parsedSize / 2;
      } else if (marker.startsWith("fn:")) {
        fontFamily = marker.substring(3);
        if (fontFamily.contains("*") || fontFamily.contains("-")) {
          fontFamily = fontFamily.replaceAll("*", "").split("-").first;
        }
        if (fontFamily.toLowerCase().contains("major")) {
          fontFamily = "Times New Roman";
        } else if (fontFamily.toLowerCase().contains("minor")) {
          fontFamily = "Roboto";
        }
      }
    }

    // تبدیل رنگ متن استخراج شده از ورد به رنگ فلاتر
    Color? customTextColor = _hexToColor(span.textColor);

    // استایل پایه با پشتیبانی از رنگ متن و پس‌زمینه اختصاصی
    TextStyle baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      color:
          customTextColor ??
          Colors.black87, // <--- اعمال رنگ متن اختصاصی در صورت وجود
      height: 1.5,
      backgroundColor: _hexToColor(span.fillColor),
      fontWeight: span.markers.contains("b")
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: span.markers.contains("i")
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: span.markers.contains("u")
          ? TextDecoration.underline
          : TextDecoration.none,
    );

    return TextRenderEngine.buildInteractiveText(
      span.content,
      interactives,
      context,
      baseStyle,
    );
  }

  Widget _buildRichText(
    List<InlineSpan> spans,
    String direction,
    TextAlign textAlign,
  ) {
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: direction == "RTL" ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  Widget _buildLocalImage(String imageName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/data/images/$imageName',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Row(
                children: [
                  const Icon(Icons.broken_image, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    "Image not found: $imageName",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // متد جدول: بازنویسی شده با پشتیبانی کامل از حاشیه‌ها، سلول‌های ادغام شده، هدر و Shading
  Widget _buildTable(
    SpanData tableSpan,
    double canvasWidth,
    BuildContext context,
  ) {
    List<Widget> rowWidgets = [];

    Color? tableBgColor = _hexToColor(tableSpan.fillColor);
    bool hasBorders = tableSpan.hasBorders?.toLowerCase() == "true";

    for (var row in tableSpan.tableRows) {
      List<Widget> cellWidgets = [];

      for (var cell in row.cells) {
        // سلول‌هایی که بخشی از ادغام عمودی (rowMerge) هستند و در زیر قرار دارند پنهان می‌شوند
        if (cell.rowMerge == "continue") {
          continue;
        }

        int flexValue = 1;
        if (cell.widthPercent != null && cell.widthPercent! > 0) {
          flexValue = (cell.widthPercent! * 100).toInt();
        }

        // اگر سلول ادغام ستونی (colSpan) دارد، پارسر C# عرض آن را متناسب محاسبه کرده،
        // اما اگر لازم بود می‌توان flex را بر اساس colSpan هم ضریب داد.

        // تعیین رنگ نهایی سلول: اولویت با رنگ سلول، بعد رنگ هدر، بعد رنگ جدول
        Color? cellBgColor = _hexToColor(cell.fillColor) ?? tableBgColor;
        if (cell.isHeaderCell && cellBgColor == null) {
          cellBgColor =
              Colors.grey.shade200; // رنگ استاندارد هدرها در صورت نبود رنگ دستی
        }

        // تعیین تراز عمودی متن در سلول
        MainAxisAlignment vAlign = MainAxisAlignment.start;
        if (cell.vAlign == "center") vAlign = MainAxisAlignment.center;
        if (cell.vAlign == "bottom") vAlign = MainAxisAlignment.end;

        cellWidgets.add(
          Expanded(
            flex: flexValue,
            child: Container(
              decoration: BoxDecoration(
                color: cellBgColor,
                // ترفند رندر دقیق حاشیه: ترسیم خط راست و پایین برای هر سلول
                border: hasBorders
                    ? Border(
                        right: BorderSide(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                        bottom: BorderSide(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: vAlign,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cell.paragraphs
                    .map((p) => _buildParagraph(p, canvasWidth, context))
                    .toList(),
              ),
            ),
          ),
        );
      }

      rowWidgets.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cellWidgets,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          // تکمیل حاشیه کل جدول: ترسیم خط بالا و چپ در لایه بیرونی
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
