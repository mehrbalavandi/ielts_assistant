class UtilityPersian {
  // 1: ساخت یک نمونه استاتیک خصوصی از خود کلاس
  static final UtilityPersian _instance = UtilityPersian._internal();

  // 2: کانستراکتور خصوصی (برای جلوگیری از new کردن)
  UtilityPersian._internal();

  // 3: دسترسی عمومی به نمونه Singleton
  factory UtilityPersian() {
    return _instance;
  }

  //[۰۱۲۳۴۵۶۷۸۹][٠١٢٣٤٥٦٧٨٩]
  String repairNumberAndChars(String input) {
    String outPut = input.replaceAll('۰', '0');
    outPut = outPut.replaceAll('٠', '0');

    outPut = outPut.replaceAll('۱', '1');
    outPut = outPut.replaceAll('١', '1');

    outPut = outPut.replaceAll('۲', '2');
    outPut = outPut.replaceAll('٢', '2');

    outPut = outPut.replaceAll('۳', '3');
    outPut = outPut.replaceAll('٣', '3');

    outPut = outPut.replaceAll('۴', '4');
    outPut = outPut.replaceAll('٤', '4');

    outPut = outPut.replaceAll('۵', '5');
    outPut = outPut.replaceAll('٥', '5');

    outPut = outPut.replaceAll('۶', '6');
    outPut = outPut.replaceAll('٦', '6');

    outPut = outPut.replaceAll('۷', '7');
    outPut = outPut.replaceAll('٧', '7');

    outPut = outPut.replaceAll('۸', '8');
    outPut = outPut.replaceAll('٨', '8');

    outPut = outPut.replaceAll('۹', '9');
    outPut = outPut.replaceAll('٩', '9');
    outPut = outPut.replaceAll('ي', 'ی');
    outPut = outPut.replaceAll('ئ', 'ی');
    outPut = outPut.replaceAll('ك', 'ک');
    outPut = outPut.replaceAll('ﮑ', 'ک');
    outPut = outPut.replaceAll('ﮐ', 'ک');
    outPut = outPut.replaceAll('ﮏ', 'ک');
    return outPut;
  }
}
