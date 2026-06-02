import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SimSmsService {
  static const MethodChannel _channel = MethodChannel('com.example.attendance/sms');

  /// Requests the necessary SMS permissions from the user.
  /// (Handled by the Android OS manually via Settings for restricted apps)
  static Future<bool> requestPermissions() async {
    return true; // We rely on the manual permission grant for this restricted app
  }

  /// Sends an SMS via the device's default SIM card using Native Kotlin SmsManager.
  /// [phoneNumber] is the mobile number to send to.
  /// [message] is the text content to send.
  static Future<bool> sendSms(String phoneNumber, String message) async {
    if (phoneNumber.isEmpty) {
      debugPrint("[SimSMS] No phone number provided.");
      return false;
    }

    try {
      final bool result = await _channel.invokeMethod('sendSms', {
        'phone': phoneNumber,
        'message': message,
      });
      debugPrint("[SimSMS] Native SMS sent successfully to $phoneNumber");
      return result;
    } on PlatformException catch (e) {
      debugPrint("[SimSMS] Native Exception sending SMS: ${e.message}");
      return false;
    }
  }
}
