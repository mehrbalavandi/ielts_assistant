import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/text_render_engine.dart';
import 'package:ielts_assistant/shared/models/models.dart';

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
  int _pointerCount = 0; // شمارنده انگشت‌های روی صفحه

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChanged);
  }

  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // اگر کاربر کاملاً از زوم خارج شد و هیچ انگشتی هم روی صفحه نیست، اسکرول عادی را برگردان
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double canvasWidth = screenWidth > 650 ? 650 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        // استفاده از Listener برای شکار لمس‌ها قبل از رسیدن به اسکرول‌ویو
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            _pointerCount++;
            // به محض گذاشتن انگشت دوم، اسکرول را قفل و زوم را آماده کن
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
              // اگر انگشت‌ها برداشته شد و زوم نبودیم، وضعیت را ریست کن
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
            panEnabled: _isZoomed, // در حالت زوم اجازه حرکت ۴ جهته می‌دهد
            scaleEnabled: true,
            constrained: true,
            child: SingleChildScrollView(
              // مدیریت هوشمند و آنی فیزیک اسکرول
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(), // اسکرول بسیار روان و نیتیو
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
    // مدیریت پاراگراف‌های خالی (Enterها)
    if (para.spans.length == 1 && para.spans.first.content == "\n") {
      return const SizedBox(height: 16);
    }

    List<Widget> blockElements = [];
    List<InlineSpan> inlineSpans = [];

    // تعیین تراز متن بر اساس خروجی پارسر C#
    TextAlign textAlign = TextAlign.left;
    if (para.alignment == "C") textAlign = TextAlign.center;
    if (para.alignment == "R") textAlign = TextAlign.right;
    if (para.alignment == "J") textAlign = TextAlign.justify;

    for (var span in para.spans) {
      if (span.type == "text") {
        // اعمال استایل‌ها و لغات تعاملی
        inlineSpans.addAll(
          _buildStyledInteractiveText(
            span.content,
            span.markers,
            para.interactives,
            context,
          ),
        );
      } else if (span.type == "image") {
        // ابتدا متن‌های قبل از عکس را رندر کن
        if (inlineSpans.isNotEmpty) {
          blockElements.add(
            _buildRichText(inlineSpans, para.direction, textAlign),
          );
          inlineSpans = [];
        }
        // رندر کردن عکس از آدرس متغیر شما
        // استفاده از span.url به عنوان نام عکس. اگر null بود برای اطمینان span.content را می‌خوانیم
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
        // پاس دادن عرض دینامیک به جدول
        blockElements.add(_buildTable(span, canvasWidth, context));
      }
    }

    if (inlineSpans.isNotEmpty) {
      blockElements.add(_buildRichText(inlineSpans, para.direction, textAlign));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: para.direction == "RTL"
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: blockElements,
      ),
    );
  }

  // متد جدید: ترکیب استایل‌های لایه Word (Bold/Italic) با کلمات تعاملی AI
  List<InlineSpan> _buildStyledInteractiveText0(
    String content,
    List<String> markers,
    List<InteractiveWord> interactives,
    BuildContext context,
  ) {
    // تعیین استایل پایه این اسپن بر اساس مارکرهای استخراج شده از ورد
    TextStyle baseStyle = TextStyle(
      fontSize: 12,
      color: Colors.black87,
      height: 1.5,
      fontWeight: markers.contains("b") ? FontWeight.bold : FontWeight.normal,
      fontStyle: markers.contains("i") ? FontStyle.italic : FontStyle.normal,
      decoration: markers.contains("u")
          ? TextDecoration.underline
          : TextDecoration.none,
    );

    // حالا کلمات تعاملی را در این اسپن با حفظ استایل پایه پیدا می‌کنیم
    // (می‌توانید متد TextRenderEngine را به‌روز کنید تا TextStyle پایه را هم ورودی بگیرد)
    return TextRenderEngine.buildInteractiveText(
      content,
      interactives,
      context,
      baseStyle,
    );
  }

  // متد آپدیت‌شده: پشتیبانی از سایز و نام فونت استخراج شده از Word
  List<InlineSpan> _buildStyledInteractiveText(
    String content,
    List<String> markers,
    List<InteractiveWord> interactives,
    BuildContext context,
  ) {
    // مقادیر پیش‌فرض برای زمانی که ورد فونت یا سایزی مشخص نکرده است
    double fontSize = 17.0;
    String? fontFamily;

    // پیمایش مارکرها برای پیدا کردن سایز (sz) و فونت (fn)
    for (var marker in markers) {
      if (marker.startsWith("sz:")) {
        // استخراج عدد سایز (مثلاً از sz:36 عدد 36 را می‌گیریم)
        String sizeStr = marker.substring(3);
        double? parsedSize = double.tryParse(sizeStr);
        if (parsedSize != null) {
          // چون اعداد ورد نیم‌پوینت هستند، تقسیم بر ۲ می‌کنیم
          // ضمناً می‌توانید یک ضریب (Scale Factor) هم اضافه کنید
          // مثلاً اگر در موبایل فونت‌ها خیلی ریز شدند، آن را کمی بزرگتر کنید
          fontSize = parsedSize / 2;
        }
      } else if (marker.startsWith("fn:")) {
        // استخراج نام فونت (مثلاً از fn:Verdana رشته Verdana را می‌گیریم)
        fontFamily = marker.substring(3);

        // نکته: گاهی اوقات ورد نام فونت‌های تم را با ستاره یا پسوند می‌آورد
        // (مثل *Times New Roman-Bold-7729-Iden). این خط آن را تمیز می‌کند:
        if (fontFamily.contains("*") || fontFamily.contains("-")) {
          fontFamily = fontFamily.replaceAll("*", "").split("-").first;
        }
      }
    }

    // ساخت استایل پایه با فونت و سایزِ دینامیک
    TextStyle baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      color: Colors.black87,
      height: 1.5,
      fontWeight: markers.contains("b") ? FontWeight.bold : FontWeight.normal,
      fontStyle: markers.contains("i") ? FontStyle.italic : FontStyle.normal,
      decoration: markers.contains("u")
          ? TextDecoration.underline
          : TextDecoration.none,
    );

    // ارسال استایل آماده شده به موتور رندر متن‌های تعاملی
    return TextRenderEngine.buildInteractiveText(
      content,
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
    // تغییر ۳: استفاده از Text.rich به جای RichText
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: direction == "RTL" ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  // ویجت نمایش عکس‌های محلی از آدرسی که گفتید
  Widget _buildLocalImage(String imageName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/data/images/$imageName',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // در صورتی که عکس پیدا نشد، یک آیکون خطا نشان بده تا برنامه کرش نکند
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

  Widget _buildTable(
    SpanData tableSpan,
    double canvasWidth,
    BuildContext context,
  ) {
    List<Widget> rowWidgets = [];

    for (var row in tableSpan.tableRows) {
      List<Widget> cellWidgets = [];

      for (var cell in row.cells) {
        // تبدیل درصد به یک عدد صحیح برای استفاده در flex
        // مثلاً 39.09 درصد تبدیل می‌شود به 3909
        int flexValue = 1; // مقدار پیش‌فرض برای جلوگیری از خطا
        if (cell.widthPercent != null && cell.widthPercent! > 0) {
          flexValue = (cell.widthPercent! * 100).toInt();
        }

        cellWidgets.add(
          Expanded(
            flex: flexValue,
            child: Padding(
              // اضافه کردن پدینگ افقی برای جلوگیری از چسبیدن متن‌ها به هم یا به عکس
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // جلوگیری از اشغال فضای عمودی نامحدود
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
          // هم‌تراز کردن ارتفاع تمام سلول‌های این سطر
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start, // چیدمان از بالای سلول
            children: cellWidgets,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
    );
  }
}
