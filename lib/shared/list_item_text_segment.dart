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
      child: ListTile(
        isThreeLine: true,
        horizontalTitleGap: 4.0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        onTap: () {
          onTap();
        },
        //! عنوان کتاب
        title: Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 5.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text: number.toString(),
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              fontFamily: isPersianTextSegment
                                  ? FontFamily.yekanBakhRegular.asText
                                  : null,
                              fontWeight: FontWeight.bold,
                              fontSize: isPersianTextSegment ? 12.0 : 16.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        titleAlignment: ListTileTitleAlignment.top,
        //! سایر موارد
        subtitle: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            segmentText,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: isPersianTextSegment
                  ? FontFamily.yekanBakhRegular.asText
                  : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
