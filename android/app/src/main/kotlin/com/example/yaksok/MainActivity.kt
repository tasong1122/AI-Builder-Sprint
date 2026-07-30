package com.example.yaksok

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val reminderSmsChannel = "yaksok/reminder_sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            reminderSmsChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "openSmsComposer") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val body = call.argument<String>("body").orEmpty()
            val phoneNumber = call.argument<String>("phoneNumber").orEmpty()
            val uri = if (phoneNumber.isBlank()) {
                Uri.parse("smsto:")
            } else {
                Uri.parse("smsto:${Uri.encode(phoneNumber)}")
            }
            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                putExtra("sms_body", body)
            }

            if (intent.resolveActivity(packageManager) == null) {
                result.error("NO_SMS_APP", "No SMS app is available.", null)
                return@setMethodCallHandler
            }

            startActivity(intent)
            result.success(null)
        }
    }
}
