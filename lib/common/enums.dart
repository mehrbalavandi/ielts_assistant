enum FontFamily {
  zar,
  titr,
  yekanBakhBold,
  yekanBakhExtraBold,
  yekanBakhLight,
  yekanBakhRegular,
  arial,
  calibri,
  gadugi,
  segoe,
  tahoma,
  timesNewRoman,
  verdana,
}

extension FontFamilyX on FontFamily {
  String get asText => switch (this) {
    FontFamily.zar => 'Zar',
    FontFamily.titr => 'Titr',
    FontFamily.yekanBakhBold => 'YekanBakhBold',
    FontFamily.yekanBakhExtraBold => 'YekanBakhExtraBold',
    FontFamily.yekanBakhLight => 'YekanBakhLight',
    FontFamily.yekanBakhRegular => 'YekanBakhRegular',
    FontFamily.arial => 'Arial',
    FontFamily.calibri => 'Calibri',
    FontFamily.gadugi => 'Gadugi',
    FontFamily.segoe => 'Segoe',
    FontFamily.tahoma => 'Tahoma',
    FontFamily.timesNewRoman => 'Times New Roman',
    FontFamily.verdana => 'Verdana',
  };
  static FontFamily parse(String s) => FontFamily.values.firstWhere(
    (e) => e.asText.toLowerCase() == s.toLowerCase(),
    orElse: () => FontFamily.zar,
  );
}
