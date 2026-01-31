import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';

class ListItemTextSegment extends StatelessWidget {
  final WidgetRef ref;
  final bool isPersianTextSegment;
  final int number;
  // final String segmentText;
  final List<TextSpan> spans;
  final void Function() onTap;
  final void Function() onEdit;
  final void Function() onDelete;
  const ListItemTextSegment({
    super.key,
    required this.ref,
    required this.isPersianTextSegment,
    required this.number,
    required this.spans,
    // required this.segmentText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    // List<List<InlineSpan>>

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 1.0,
        child: ListTile(
          isThreeLine: false,
          horizontalTitleGap: 4.0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          onTap: () {
            onTap();
          },

          //! عنوان کتاب
          title: Row(
            children: [
              Text(
                number.toString(),
                textAlign: TextAlign.justify,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontFamily: isPersianTextSegment
                      ? FontFamily.yekanBakhLight.asText
                      : null,
                  fontWeight: FontWeight.bold,
                  fontSize: isPersianTextSegment ? 12.0 : null,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        onEdit();
                      },
                      icon: Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      iconSize: 20.0,
                      onPressed: () {
                        onDelete();
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          titleAlignment: ListTileTitleAlignment.top,
          //! سایر موارد
          subtitle:
              //  Text(
              //   segmentText,
              //   style: Theme.of(context).textTheme.bodySmall!.copyWith(
              //     fontFamily: isPersianTextSegment
              //         ? FontFamily.yekanBakhLight.asText
              //         : null,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),
              RichText(
                textAlign: isPersianTextSegment
                    ? TextAlign.right
                    : TextAlign.left,
                text: TextSpan(children: spans),
              ),
        ),
      ),
    );
  }
}
