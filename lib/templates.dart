/*             
Widget richText = RichText(
  textAlign: TextAlign.justify,
  text: TextSpan(
    // text: 'data',
    style: TextStyle(
      fontFamily: 'YekanBakhRegular',
      color: Get.theme.colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    ),
    children: <InlineSpan>[
      TextSpan(
        text:
            'احراز هویت با موفقیت انجام شد. اینترنت را متصل نگهدارید و پس از مشاهده ناتیفیکیشن در بالای صفحه، اقدام به ',
        style: TextStyle(
          fontFamily: 'YekanBakhLight',
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () async {},
          child: Text(
            'دانلود داده‌ها ',
            style: TextStyle(color: Get.theme.primaryColor),
          ),
        ),
      ),
      TextSpan(
        text: 'نمائید..',
        style: TextStyle(
          fontFamily: 'YekanBakhLight',
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  ),
);
*/
/*
Future.microtask(() {
  _tabController.animateTo(0);
}); 

WidgetsBinding.instance.addPostFrameCallback((_) {
  _tabController.animateTo(0);
});

Container(
  width: double.infinity,
  decoration: BoxDecoration(
    color: CfPublic().getTabBackgroundColor(isSelected),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(8.0),
      topRight: Radius.circular(8.0),
    ),
  ),
  child: ..
);
 */

/* //! برای toast
| هدف                 | رنگ مناسب از `colorScheme`                                         |
| ------------------- | ------------------------------------------------------------------ |
| پیام موفقیت‌آمیز    | `colorScheme.secondaryContainer` یا `tertiaryContainer`            |
| پیام خطا            | `colorScheme.errorContainer`                                       |
| پیام هشدار یا اطلاع | `colorScheme.primaryContainer`                                     |
| متن                 | `colorScheme.on...` مربوط به رنگ بالا (مثلاً `onErrorContainer`)   |
| پس‌زمینه عمومی      | `colorScheme.surfaceVariant` یا `surfaceContainer` (در Material 3) |
*/

/*
چک لیست dispose
☐ ScrollController?
☐ TextEditingController?
☐ AnimationController?
☐ Timer?
☐ Stream / Subscription?
☐ Listeners؟ (addListener/removeListener)
☐ FocusNode?
☐ ChangeNotifier (دستی ساخته شده)؟
☐ Custom Resources?
*/

/*
    // جایگزینی حروف عربی به فارسی
    _arabicToPersianMap.forEach((arabicChar, persianChar) {
      text = text.replaceAll(arabicChar, persianChar);
    });

    // حذف حرکات (اعراب) در صورت نیاز
    if (removeTashkeel) {
      text = text.replaceAll(_tashkeelRegex, '');
    }
*/
