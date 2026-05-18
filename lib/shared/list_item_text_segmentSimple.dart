// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_assistant/common/enums.dart';
import 'package:ielts_assistant/shared/models/content_models.dart';

class ManualTemelateData {
  final TextSegmentPersian segment;
  final List<InlineSpan> spansPersian;
  final List<InlineSpan> spansEnglish;
  // final bool hasSearchMatch;
  ManualTemelateData({
    required this.segment,
    required this.spansPersian,
    required this.spansEnglish,
    // required this.hasSearchMatch,
  });
}

class ListItemTextSegmentSimple extends StatelessWidget {
  final WidgetRef ref;
  final int number;
  final ManualTemelateData data;
  final void Function() onTap;
  final void Function() onLongPress;
  // final void Function() onDelete;
  const ListItemTextSegmentSimple({
    super.key,
    required this.ref,
    required this.number,
    required this.data,
    required this.onTap,
    required this.onLongPress,
    // required this.onDelete,
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

          title: Row(
            children: [
              Text(
                number.toString(),
                textAlign: TextAlign.justify,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontFamily: FontFamily.yekanBakhLight.asText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          titleAlignment: ListTileTitleAlignment.top,
          //! سایر موارد
          subtitle: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(children: data.spansPersian),
          ),
        ),
      ),
    );
  }
}
