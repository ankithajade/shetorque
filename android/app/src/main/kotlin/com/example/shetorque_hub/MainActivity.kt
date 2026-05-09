package com.example.shetorque_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SmsManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shetorque.hub/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendSms") {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")

                    if (phone != null && message != null) {
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                            // Split long messages and send as multipart
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)

                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone and message are required", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
