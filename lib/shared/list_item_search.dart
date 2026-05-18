import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/features/content_viewer/providers/content_provider.dart';
import 'package:ielts_assistant/shared/cf_public.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class ListItemSearch extends StatelessWidget {
  final WidgetRef ref;
  final OriginalContent originalContent;
  final void Function() onTap;
  const ListItemSearch({
    super.key,
    required this.ref,
    required this.originalContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: Theme.of(context).platform == TargetPlatform.iOS
          ? '.AppleSystemUIFont'
          : 'sans-serif',
      fontFamilyFallback: [FontFamily.yekanBakhRegular.asText],
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.alphabetic,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      // color: Theme.of(context).textTheme.bodySmall!.color,
      fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
    );

    final List<String> labels = [];
    labels.add(originalContent.book.name.replaceAll('قالبهای AI', 'قالبها'));
    var book = ref
        .read(allContentProvider)
        .value!
        .where((x) => x.name == originalContent.book.name)
        .first;
    if (book.units.length == 1 && book.units.first.topics.length == 1) {
    } else {
      labels.add(originalContent.unit.name.replaceAll('Unit ', 'U '));
      labels.add(originalContent.page.name.replaceAll('Page ', 'P '));
    }
    labels.add(
      originalContent.finalTopic.name.substring(
        originalContent.finalTopic.name.indexOf(' ') + 1,
      ),
    );

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
            padding: const EdgeInsets.only(left: 8.0, bottom: 5.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                originalContent.book.name,
                style: textStyle.copyWith(
                  fontSize: Theme.of(context).textTheme.titleSmall!.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          titleAlignment: ListTileTitleAlignment.top,
          //! سایر موارد
          subtitle: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CfPublic().buildTitle(
              labels,
              textStyle.copyWith(
                fontSize: Theme.of(context).textTheme.bodySmall!.fontSize,
              ),
            ),
            // Text(
            //   originalContent.root,
            //   style: textStyle.copyWith(fontWeight: FontWeight.bold),
            // ),
          ),
        ),
      ),
    );
  }
}
