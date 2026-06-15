package com.example.student_attendance_app

import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.widget.Toast
import android.app.PendingIntent
import android.content.Intent

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.attendance/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")

                if (phone != null && message != null) {
                    try {
                        val smsManager: SmsManager = SmsManager.getDefault()
                        val parts = smsManager.divideMessage(message)
                        if (parts.size > 1) {
                            val sentIntents = java.util.ArrayList<PendingIntent>()
                            for (i in parts.indices) {
                                val intent = Intent("SMS_SENT")
                                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                                sentIntents.add(PendingIntent.getBroadcast(applicationContext, 0, intent, flags))
                            }
                            smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
                        } else {
                            val intent = Intent("SMS_SENT")
                            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                            val sentIntent = PendingIntent.getBroadcast(applicationContext, 0, intent, flags)
                            smsManager.sendTextMessage(phone, null, message, sentIntent, null)
                        }
                        
                        Toast.makeText(applicationContext, "SMS Sent Successfully to \$phone!", Toast.LENGTH_SHORT).show()
                        result.success(true)
                    } catch (e: Exception) {
                        Toast.makeText(applicationContext, "SMS FAILED: \${e.message}", Toast.LENGTH_LONG).show()
                        result.error("SMS_FAILED", "Failed to send SMS: \${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone or message is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
