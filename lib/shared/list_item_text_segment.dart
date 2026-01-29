import 'package:flutter/material.dart';
import 'package:ielts_assistant/common/enums.dart';

class ListItemTextSegment extends StatelessWidget {
  final bool isPersianTextSegment;
  final int number;
  final String segmentText;
  final void Function() onTap;
  const ListItemTextSegment({
    super.key,
    required this.isPersianTextSegment,
    required this.number,
    required this.segmentText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
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
          title: Text(
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
          titleAlignment: ListTileTitleAlignment.top,
          //! سایر موارد
          subtitle: Text(
            segmentText,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: isPersianTextSegment
                  ? FontFamily.yekanBakhLight.asText
                  : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
