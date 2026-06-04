import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'SourceSans3';

  /// -----------------------------------------------------------
  /// 1. Caption / Footnote
  /// توضیح تصاویر، پاورقی، منابع
  /// SourceSans3 Light (w300)
  /// -----------------------------------------------------------
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w300,
    fontSize: 9,
    height: 1.2,
  );

  /// -----------------------------------------------------------
  /// 2. Main Body
  /// متن اصلی Reading, Listening, Writing
  /// SourceSans3 Regular (w400)
  /// -----------------------------------------------------------
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 10.5,
    height: 1.3,
  );

  /// -----------------------------------------------------------
  /// 3. Example / Note
  /// مثال‌ها، نکات آموزشی
  /// SourceSans3 Italic
  /// -----------------------------------------------------------
  static const TextStyle note = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    fontSize: 10.5,
    height: 1.3,
  );

  /// -----------------------------------------------------------
  /// 4. Instruction Text
  /// دستور تمرین‌ها و توضیحات آموزشی
  /// SourceSans3 Medium (w500)
  /// -----------------------------------------------------------
  static const TextStyle instruction = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 10.5,
    height: 1.3,
  );

  /// -----------------------------------------------------------
  /// 5. Keyword / Highlight
  /// کلمات کلیدی و Header جدول
  /// SourceSans3 SemiBold (w600)
  /// -----------------------------------------------------------
  static const TextStyle keyword = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 10.5,
    height: 1.3,
  );

  /// -----------------------------------------------------------
  /// 6. Exercise Number
  /// 01 , 02 , 03 ...
  /// SourceSans3 Bold (w700)
  /// -----------------------------------------------------------
  static const TextStyle exerciseNumber = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 12,
  );

  /// -----------------------------------------------------------
  /// 7. Section Title
  /// READING
  /// WRITING
  /// VOCABULARY
  /// LISTENING
  /// SourceSans3 Bold (w700)
  /// -----------------------------------------------------------
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    letterSpacing: .5,
  );

  /// -----------------------------------------------------------
  /// 8. Unit Title
  /// UNIT / 01
  /// SourceSans3 ExtraBold (w800)
  /// -----------------------------------------------------------
  static const TextStyle unitTitle = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    letterSpacing: .5,
  );

  /// -----------------------------------------------------------
  /// 9. Page Banner Title
  /// WRITING
  /// READING
  /// LISTENING
  /// ابتدای هر یونیت
  /// SourceSans3 Black (w900)
  /// -----------------------------------------------------------
  static const TextStyle pageTitle = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w900,
    fontSize: 44,
    height: 1,
  );
}
/*
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      'UNIT / 01',
      style: AppTextStyles.unitTitle,
    ),

    Text(
      'WRITING',
      style: AppTextStyles.pageTitle,
    ),

    Text(
      'READING',
      style: AppTextStyles.sectionTitle,
    ),

    Text(
      '01',
      style: AppTextStyles.exerciseNumber,
    ),

    Text(
      'Complete the sentences using the correct verb tense.',
      style: AppTextStyles.instruction,
    ),

    Text(
      'Urbanisation',
      style: AppTextStyles.keyword,
    ),

    Text(
      'Many people move to cities every year.',
      style: AppTextStyles.body,
    ),

    Text(
      'Note: Remember to use the correct tense.',
      style: AppTextStyles.note,
    ),

    Text(
      'Photo: Rural life in northern England',
      style: AppTextStyles.caption,
    ),
  ],
);
 */