import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/my_text_form_field.dart';

class ViewTempelateWidget extends ConsumerStatefulWidget {
  TextSegmentPersian? persianTextSegment;

  ViewTempelateWidget({super.key, this.persianTextSegment});

  @override
  ConsumerState<ViewTempelateWidget> createState() => _ViewTempelateState();
}

class _ViewTempelateState extends ConsumerState<ViewTempelateWidget> {
  bool isDoing = false;
  //!
  //* انگلیسی
  late TextEditingController txtEnglish;
  late FocusNode englishFocusNode;
  //* فارسی
  late TextEditingController txtPersian;
  late FocusNode persianFocusNode;
  //* نکات
  late TextEditingController txtExplanations;
  late FocusNode explanationFocusNode;

  @override
  void initState() {
    super.initState();
    //* انگلیسی
    txtEnglish = TextEditingController(
      text: widget.persianTextSegment?.translation,
    );
    englishFocusNode = FocusNode();
    //* فارسی
    txtPersian = TextEditingController(text: widget.persianTextSegment?.text);
    persianFocusNode = FocusNode();
    //* نکات
    txtExplanations = TextEditingController(
      text: widget.persianTextSegment?.explanation,
    );
    explanationFocusNode = FocusNode();
  }

  @override
  void dispose() {
    //* انگلیسی
    txtEnglish.dispose();
    englishFocusNode.dispose();
    //* فارسی
    txtPersian.dispose();
    persianFocusNode.dispose();
    //* نکات
    txtExplanations.dispose();
    explanationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: Theme.of(context).platform == TargetPlatform.iOS
          ? '.AppleSystemUIFont'
          : 'sans-serif',
      fontFamilyFallback: [FontFamily.zar.asText],
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      color: Theme.of(context).textTheme.bodySmall!.color,
      // fontSize: Theme.of(context).textTheme.bodySmall!.fontSize,
      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //* فارسی
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Align(
                      alignment: AlignmentGeometry.centerRight,
                      child: Text(
                        widget.persianTextSegment?.text ?? '',
                        style: textStyle,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16.0),
                  //* انگلیسی
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      widget.persianTextSegment?.translation ?? '',
                      style: textStyle.copyWith(
                        fontSize: Theme.of(
                          context,
                        ).textTheme.bodyLarge!.fontSize,
                      ),
                    ),
                  ),

                  if (widget.persianTextSegment?.explanation != null &&
                      (widget.persianTextSegment?.explanation ?? '').isNotEmpty)
                    SizedBox(height: 8.0),
                  //* نکات
                  if (widget.persianTextSegment?.explanation != null &&
                      (widget.persianTextSegment?.explanation ?? '').isNotEmpty)
                    Align(
                      alignment: AlignmentGeometry.centerRight,
                      child: Text(
                        'نکات:',
                        style: textStyle.copyWith(
                          fontFamily: FontFamily.yekanBakhBold.asText,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  if (widget.persianTextSegment?.explanation != null &&
                      (widget.persianTextSegment?.explanation ?? '').isNotEmpty)
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Align(
                        alignment: AlignmentGeometry.centerRight,
                        child: Text(
                          widget.persianTextSegment?.explanation ?? '',
                          style: textStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
