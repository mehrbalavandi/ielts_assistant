//! تحریم شکن
/*
185.51.200.2 or 185.51.200.1
178.22.122.102

Using Flutter in China
https://docs.flutter.dev/community/china#configuring-flutter-to-use-a-mirror-site

$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get

پیش‌فرض مقادیر فوق
$env:PUB_HOSTED_URL="https://pub.dev"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com"
flutter pub get

یا
Remove-Item Env:PUB_HOSTED_URL
Remove-Item Env:FLUTTER_STORAGE_BASE_URL

اگر خواستی برای همیشه پاک بشن:
باید از طریق مسیر زیر در ویندوز حذفشون کنی:

وارد تنظیمات ویندوز شو.

بخش System > About > Advanced system settings

روی دکمه Environment Variables کلیک کن.

متغیرهای PUB_HOSTED_URL و FLUTTER_STORAGE_BASE_URL رو حذف کن.
*/

//! json_serializable
/*
dart run build_runner build
*/

//! realm
/*
dart run realm generate
جهت نصب:
dart run realm install
*/
//! خروجی گرفتن از برنامه
/*
flutter build apk --release

🧱این دستور فقط آیکون‌های استفاده‌شده را نگه می‌دارد --tree-shake-icons
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --tree-shake-icons

01- visitory(1.0.29), v8a
02- visitory(1.0.29), v7a
flutter build apk --release --tree-shake-icons

🧪 استفاده از App Bundle (.aab) برای انتشار در Play Store
  flutter build appbundle
  📦 مزیت:
    گوگل Play فقط ABI مورد نیاز کاربر را تحویل می‌دهد.
    خروجی .aab سبک‌تر از .apk است.


🔧 یا فقط از ndk.abiFilters استفاده کن
اگر فقط می‌خوای خروجی واحد داشته باشی:
defaultConfig {
    ...
    ndk {
        abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
    }
}
و حذف کن:
splits {
    abi {
        isEnable = true
        ...
    }
}
🔧 یا فقط از splits.abi.include استفاده کن
اگر می‌خوای apk جدا برای هر ABI داشته باشی:
splits {
    abi {
        isEnable = true
        reset()
        include("armeabi-v7a", "arm64-v8a", "x86_64")
        isUniversalApk = false
    }
}
و حذف کن:
ndk {
    abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
}    
*/

//! برخی دستورات دیگر
/*
flutter clean
flutter pub get
flutter pub upgrade
flutter pub run realm generate
flutter build apk
flutter upgrade --force
flutter analyze --suggestions
flutter --version
flutter update-packages --force-upgrade
//! جهت بررسی حجم فایل apk fvhd lulhvd arm64
flutter build apk --target-platform android-arm64 --analyze-size
*/
/*
//! وصل شدن به گوشی از طریق وایفای
ابتدا مسیر platform-tools رو به PATH اضافه کن
C:\Users\<YourUsername>\AppData\Local\Android\Sdk\platform-tools
adb connect 192.168.8.4:38821
//! در system variables ذخیره گردد
JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot"
//! راه‌اندازی آفلاین Gradle برای Flutter:
C:\Users\نام_کاربر\.gradle\wrapper\dists\
*/

/*
مسیر ذخیره فایل debug.keystore در ویندوز
C:\Users\Yasaman\.android\debug.keystore
*/

/*
جهت آیکون برنامه:
dart run flutter_launcher_icons:generate
*/

/*
//! پاک کردن Gradle
cd android
.\gradlew clean
cd ..
*/
