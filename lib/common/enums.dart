enum FontFamily {
  zar,
  titr,
  yekanBakhBold,
  yekanBakhExtraBold,
  yekanBakhLight,
  yekanBakhRegular,
}

extension FontFamilyX on FontFamily {
  String get asText => switch (this) {
    FontFamily.zar => 'Zar',
    FontFamily.titr => 'Titr',
    FontFamily.yekanBakhBold => 'YekanBakhBold',
    FontFamily.yekanBakhExtraBold => 'YekanBakhExtraBold',
    FontFamily.yekanBakhLight => 'YekanBakhLight',
    FontFamily.yekanBakhRegular => 'YekanBakhRegular',
  };
  static FontFamily parse(String s) => FontFamily.values.firstWhere(
    (e) => e.asText.toLowerCase() == s.toLowerCase(),
    orElse: () => FontFamily.zar,
  );
}
