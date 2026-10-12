package com.example.ielts_assistant

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 🌟 U-1: نسخه‌ی خودِ اپ برای بررسیِ نسخه‌ی تازه روی سایت.
    // عمداً به‌جای پکیجِ package_info_plus: آن پکیج در build.gradleِ خودش نسخه‌ی
    // دیگری از Android Gradle Plugin را می‌خواهد که باید از dl.google.com دانلود
    // شود و از ایران در دسترس نیست (Build شکست می‌خورد). این چند خط هیچ وابستگیِ
    // تازه‌ای ندارد.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ielts_assistant/app_info")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAppInfo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val info = if (Build.VERSION.SDK_INT >= 33) {
                        packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0)
                    }
                    val buildNumber = if (Build.VERSION.SDK_INT >= 28) {
                        info.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        info.versionCode.toLong()
                    }
                    result.success(
                        mapOf(
                            "version" to (info.versionName ?: ""),
                            "buildNumber" to buildNumber.toString(),
                        )
                    )
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", e.message, null)
                }
            }
    }
}
