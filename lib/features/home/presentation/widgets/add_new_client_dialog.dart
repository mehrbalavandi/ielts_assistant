import 'package:flutter/material.dart';
import 'package:ielts_assistant/shared/smart_text_form_field.dart';

class AddOrEditClientDialog extends StatefulWidget {
  final int? clientId;
  final void Function(List<String> data)? onSubmit;

  // final int? initialCityId;
  // final String? initialCityTitle;
  final bool enableCitySearch;

  const AddOrEditClientDialog({
    super.key,
    required this.onSubmit,
    this.enableCitySearch = true,
    this.clientId,
  });

  @override
  State<AddOrEditClientDialog> createState() => _AddOrEditClientDialogState();
}

class _AddOrEditClientDialogState extends State<AddOrEditClientDialog> {
  bool isDoing = false;
  bool isSendingRequest = false;
  //!
  //* انگلیسی
  late TextEditingController txtEnglish;
  late FocusNode nameFocusNode;
  //* فارسی
  late TextEditingController txtPersian;
  late FocusNode persianFocusNode;

  @override
  void initState() {
    super.initState();
    //* انگلیسی
    txtEnglish = TextEditingController();
    nameFocusNode = FocusNode();
    //* فارسی
    txtPersian = TextEditingController();
    persianFocusNode = FocusNode();

    _initLoad();
  }

  @override
  void dispose() {
    //* انگلیسی
    txtEnglish.dispose();
    nameFocusNode.dispose();
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
                      FocusScope.of(context).requestFocus(nameFocusNode);
                      setState(() {
                        isDoing = false;
                      });
                      return;
                    }
                    if (txtPersian.text.trim() == '') {
                      String message = 'متن فارسی نباید خالی باشد';
                      FocusScope.of(context).requestFocus(nameFocusNode);
                      setState(() {
                        isDoing = false;
                      });
                      return;
                    }
                    widget.onSubmit?.call(['formData']);
                    Navigator.pop(context);
                    //
                    setState(() {
                      isDoing = false;
                    });
                  },
                  child: Text(
                    (widget.clientId == null) ? 'افزودن' : 'ذخیره',
                    style: TextStyle(fontFamily: 'YekanBakhBold'),
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
                            style: TextStyle(fontFamily: 'YekanBakhRegular'),
                            keyboardType: TextInputType.phone,
                            textAlign: TextAlign.start,
                            textAlignVertical: TextAlignVertical.center,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              label: Text('فارسی'),
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
                            focusNode: persianFocusNode,
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
                            style: TextStyle(fontFamily: 'YekanBakhRegular'),
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
                            autofocus: true,
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
