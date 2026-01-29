import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextDirection? textDirection;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final int? maxLines;
  final TextStyle? style;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final TapRegionCallback? onTapOutside;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final bool obscureText;
  final String obscuringCharacter;
  final bool selectAllOnFocus;
  final List<TextInputFormatter>? inputFormatters;

  const MyTextFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.textDirection,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.textAlign = TextAlign.start,
    this.textAlignVertical = TextAlignVertical.center,
    this.maxLines,
    this.style,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.onTapOutside,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.selectAllOnFocus = true,
    this.inputFormatters,
  });

  @override
  State<MyTextFormField> createState() => _MyTextFormFieldState();
}

class _MyTextFormFieldState extends State<MyTextFormField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _focusNode = widget.focusNode ?? FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.selectAllOnFocus) {
        // انتخاب کل متن هنگام فوکوس فقط اگر فعال باشد
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );

        // پاکسازی composing range برای رفع مشکل backspace
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final value = widget.controller.value;
          if (!value.composing.isCollapsed) {
            widget.controller.value = value.copyWith(
              composing: TextRange.empty,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  //'!obscureText || maxLines == 1': Obscured fields cannot be multiline.)
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      inputFormatters: widget.inputFormatters,
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      textDirection: widget.textDirection,
      style: widget.style,
      decoration: widget.decoration ?? const InputDecoration(),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onEditingComplete: widget.onEditingComplete,
      onTapOutside: widget.onTapOutside,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
    );
  }
}
