import 'package:flutter/material.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class ListItemSearch extends StatelessWidget {
  final OriginalContent originalContent;
  final void Function() onTap;
  const ListItemSearch({
    super.key,
    required this.originalContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 1.0,
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
                          text: originalContent.book.name,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontFamily:
                                    (originalContent.book.name.contains(
                                      'قالبهای موقعیتی',
                                    ))
                                    ? FontFamily.yekanBakhRegular.asText
                                    : null,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    (originalContent.book.name.contains(
                                      'قالبهای موقعیتی',
                                    ))
                                    ? 12
                                    : 16,
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
              originalContent.root,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                // fontFamily: FontFamily.yekanBakhRegular.asText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
