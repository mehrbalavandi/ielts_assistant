import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/my_text_form_field.dart';

final isEditModeProvider = StateProvider<bool>((ref) => false);

class ViewTempelate extends ConsumerStatefulWidget {
  TextSegmentPersian? persianTextSegment;
  final void Function(TextSegmentPersian persianTextSegment)? onSubmit;

  ViewTempelate({
    super.key,
    // this.initEnglishText,
    this.persianTextSegment,
    // this.initExplanations,
    required this.onSubmit,
  });

  @override
  ConsumerState<ViewTempelate> createState() => _ViewTempelateState();
}

class _ViewTempelateState extends ConsumerState<ViewTempelate> {
  bool isDoing = false;
  bool isSendingRequest = false;
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
    final isEditMode = ref.watch(isEditModeProvider);
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
                children: [
                  //* فارسی
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: MyTextFormField(
                      onChanged: (value) {},
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: FontFamily.yekanBakhRegular.asText,
                        fontSize: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.fontSize,
                      ),
                      keyboardType: TextInputType.multiline,
                      textAlign: TextAlign.start,
                      textAlignVertical: TextAlignVertical.center,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        label: Text('فارسی'),
                        // floatingLabelBehavior: FloatingLabelBehavior.always,
                        // floatingLabelAlignment: FloatingLabelAlignment.center,
                        labelStyle: TextStyle(fontFamily: 'Zar'),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        // hintText: 'فارسی',
                        hintStyle: TextStyle(
                          fontFamily: 'Zar',
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      controller: txtPersian,
                      autofocus: false,
                      focusNode: persianFocusNode,
                      textInputAction: TextInputAction.newline,
                      onEditingComplete: () {
                        // txtPersian.text = '${txtPersian.text.trim()}\n';
                      },
                    ),
                  ),

                  const SizedBox(height: 16.0),
                  //* انگلیسی
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: MyTextFormField(
                      onChanged: (value) {},
                      // style: TextStyle(fontFamily: 'YekanBakhRegular'),
                      keyboardType: TextInputType.multiline,
                      textAlign: TextAlign.start,
                      textAlignVertical: TextAlignVertical.center,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        label: Text('انگلیسی'),
                        // floatingLabelBehavior: FloatingLabelBehavior.always,
                        // floatingLabelAlignment: FloatingLabelAlignment.center,
                        labelStyle: TextStyle(fontFamily: 'Zar'),
                        alignLabelWithHint: false,
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                        // contentPadding: const EdgeInsets.symmetric(
                        //   horizontal: 8.0,
                        // ),
                        // hintText: 'انگلیسی',
                        hintStyle: TextStyle(
                          fontFamily: 'Zar',
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      controller: txtEnglish,
                      autofocus: false,
                      focusNode: englishFocusNode,
                      textInputAction: TextInputAction.newline,
                      onEditingComplete: () {
                        // txtEnglish.text = '${txtEnglish.text.trim()}\n';
                      },
                    ),
                  ),

                  SizedBox(height: 16.0),
                  //* نکات
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: MyTextFormField(
                      onChanged: (value) {},
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: FontFamily.yekanBakhRegular.asText,
                        fontSize: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.fontSize,
                      ),
                      keyboardType: TextInputType.multiline,
                      textAlign: TextAlign.start,
                      textAlignVertical: TextAlignVertical.center,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        label: Text('نکات'),
                        // floatingLabelBehavior: FloatingLabelBehavior.always,
                        // floatingLabelAlignment: FloatingLabelAlignment.center,
                        labelStyle: TextStyle(fontFamily: 'Zar'),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        // hintText: 'فارسی',
                        hintStyle: TextStyle(
                          fontFamily: 'Zar',
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      controller: txtExplanations,
                      autofocus: false,
                      focusNode: explanationFocusNode,
                      textInputAction: TextInputAction.newline,
                      onEditingComplete: () {
                        // txtPersian.text = '${txtPersian.text.trim()}\n';
                      },
                    ),
                  ),

                  const SizedBox(height: 16.0),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        //* دکمه افزودن
                        TextButton(
                          onPressed: () async {
                            if (isDoing) return;
                            setState(() {
                              isDoing = true;
                            });
                            if (txtPersian.text.trim() == '') {
                              String message = 'متن فارسی نباید خالی باشد';
                              FocusScope.of(
                                context,
                              ).requestFocus(englishFocusNode);
                              setState(() {
                                isDoing = false;
                              });
                              return;
                            }
                            if (txtEnglish.text.trim() == '') {
                              String message = 'متن انگلیسی نباید خالی باشد';
                              FocusScope.of(
                                context,
                              ).requestFocus(englishFocusNode);
                              setState(() {
                                isDoing = false;
                              });
                              return;
                            }
                            TextSegmentPersian textSegmentPersian =
                                TextSegmentPersian(
                                  text: txtPersian.text.trim(),
                                  translation: txtEnglish.text,
                                  explanation: txtExplanations.text,
                                );

                            widget.onSubmit?.call(textSegmentPersian);
                            //
                            setState(() {
                              isDoing = false;
                            });
                          },
                          child: Text(
                            (widget.persianTextSegment == null)
                                ? 'افزودن'
                                : 'ذخیره',
                            style: TextStyle(
                              fontFamily: FontFamily.yekanBakhBold.asText,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (isDoing) return;
                            setState(() {
                              isDoing = true;
                            });
                            Navigator.pop(context, false);
                            if (mounted) {
                              setState(() {
                                isDoing = false;
                              });
                            }
                          },
                          child: Text(
                            'لغو',
                            style: TextStyle(fontFamily: 'YekanBakhBold'),
                          ),
                        ),
                      ],
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
