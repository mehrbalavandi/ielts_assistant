package com.example.ielts_assistant

import android.annotation.SuppressLint
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 🌟 DEV-1: شناسه‌ی دستگاه برای محدودیتِ دستگاه.
// ANDROID_ID برای هر (کلیدِ امضای اپ + کاربرِ گوشی + دستگاه) یکتاست و با نصبِ دوباره‌ی اپ
// عوض نمی‌شود (فقط با ریستِ کارخانه). اپ آن را با sha256 به شناسه‌ی دستگاه تبدیل می‌کند و
// خودِ مقدار به سرور فرستاده نمی‌شود (lib/core/device/device_identity.dart).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ielts_assistant/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> result.success(deviceInfo())
                    else -> result.notImplemented()
                }
            }
    }

    @SuppressLint("HardwareIds")
    private fun deviceInfo(): Map<String, Any?> = mapOf(
        "androidId" to Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID),
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "sdk" to Build.VERSION.SDK_INT,
    )
}
