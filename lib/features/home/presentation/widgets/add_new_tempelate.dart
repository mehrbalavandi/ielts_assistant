import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';
import 'package:ielts_assistant/shared/smart_text_form_field.dart';

class AddNewTempelate extends StatefulWidget {
  final void Function(
    String allText,
    MainTextSegment mainTextSegment,
    PersianTextSegment persianTextSegment,
  )?
  onSubmit;

  const AddNewTempelate({super.key, required this.onSubmit});

  @override
  State<AddNewTempelate> createState() => _AddNewTempelateState();
}

class _AddNewTempelateState extends State<AddNewTempelate> {
  bool isDoing = false;
  bool isSendingRequest = false;
  //!
  //* انگلیسی
  late TextEditingController txtEnglish;
  late FocusNode englishFocusNode;
  //* فارسی
  late TextEditingController txtPersian;
  late FocusNode persianFocusNode;

  @override
  void initState() {
    super.initState();
    //* انگلیسی
    txtEnglish = TextEditingController();
    englishFocusNode = FocusNode();
    //* فارسی
    txtPersian = TextEditingController();
    persianFocusNode = FocusNode();

    _initLoad();
  }

  @override
  void dispose() {
    //* انگلیسی
    txtEnglish.dispose();
    englishFocusNode.dispose();
    //* فارسی
    txtPersian.dispose();
    persianFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {}

  InputDecoration _decor(String label) {
    return InputDecoration(
      floatingLabelAlignment: FloatingLabelAlignment.center,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
      label: Text(label),
      labelStyle: TextStyle(fontFamily: 'Zar'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: Scaffold(
        //! دکمه‌های افزودن و لغو
        persistentFooterButtons: [
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
                    if (txtEnglish.text.trim() == '') {
                      String message = 'متن انگلیسی نباید خالی باشد';
                      FocusScope.of(context).requestFocus(englishFocusNode);
                      setState(() {
                        isDoing = false;
                      });
                      return;
                    }
                    if (txtPersian.text.trim() == '') {
                      String message = 'متن فارسی نباید خالی باشد';
                      FocusScope.of(context).requestFocus(englishFocusNode);
                      setState(() {
                        isDoing = false;
                      });
                      return;
                    }
                    String allText = '${txtEnglish.text}\n\n${txtPersian.text}';
                    MainTextSegment mainTextSegment = MainTextSegment(
                      text: txtEnglish.text,
                      isInteractive: false,
                    );

                    PersianTextSegment persianTextSegment = PersianTextSegment(
                      text: txtPersian.text,
                    );

                    widget.onSubmit?.call(
                      allText,
                      mainTextSegment,
                      persianTextSegment,
                    );
                    Navigator.pop(context);
                    //
                    setState(() {
                      isDoing = false;
                    });
                  },
                  child: Text(
                    'افزودن',
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
                    Navigator.pop(context);
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
        resizeToAvoidBottomInset: true,
        extendBody: false,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          title: Text(
            'افزودن قالب جدید',
            style: TextStyle(
              fontFamily: 'YekanBakhBold',
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    child: Column(
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextFormField(
                            onChanged: (value) {},
                            // style: TextStyle(fontFamily: 'YekanBakhRegular'),
                            textAlign: TextAlign.start,
                            textAlignVertical: TextAlignVertical.center,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              label: Text('انگلیسی'),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              floatingLabelAlignment:
                                  FloatingLabelAlignment.center,
                              labelStyle: TextStyle(fontFamily: 'Zar'),
                              alignLabelWithHint: false,
                              border: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(10.0),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              // hintText: 'فارسی',
                              hintStyle: TextStyle(
                                fontFamily: 'Zar',
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            controller: txtEnglish,
                            autofocus: true,
                            focusNode: englishFocusNode,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () {
                              // تکمیل شود
                            },
                          ),
                        ),

                        //* فارسی
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: SmartTextFormField(
                            onChanged: (value) {},
                            maxLines: null,
                            style: TextStyle(
                              fontFamily: FontFamily.yekanBakhRegular.asText,
                            ),
                            // keyboardType: TextInputType.number,
                            textAlign: TextAlign.start,
                            textAlignVertical: TextAlignVertical.center,
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              label: Text('فارسی'),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              floatingLabelAlignment:
                                  FloatingLabelAlignment.center,
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
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () {
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        SizedBox(height: 12.0),
                      ],
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
}
