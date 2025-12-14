import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String value;
  final List<String> items;
  final Function(String?) onChanged;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  CustomDropdownState createState() => CustomDropdownState();
}

class CustomDropdownState extends State<CustomDropdown> {
  final GlobalKey _dropdownButtonKey = GlobalKey();

  /// این متد باعث می‌شه Dropdown باز بشه
  void showButtonMenu() {
    final dropdownContext = _dropdownButtonKey.currentContext;
    if (dropdownContext != null) {
      GestureDetector? detector;

      void search(Element element) {
        if (element.widget is GestureDetector) {
          detector = element.widget as GestureDetector;
        } else {
          element.visitChildElements(search);
        }
      }

      dropdownContext.visitChildElements(search);

      if (detector?.onTap != null) {
        detector!.onTap!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      key: _dropdownButtonKey,
      value: widget.value,
      underline: const SizedBox(),
      items: widget.items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: widget.onChanged,
    );
  }
}
