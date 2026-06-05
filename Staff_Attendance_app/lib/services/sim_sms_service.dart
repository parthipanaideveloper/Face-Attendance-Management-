import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:permission_handler/permission_handler.dart';

class SimSmsService {
  static const MethodChannel _channel = MethodChannel('com.example.attendance/sms');

  /// Requests the necessary SMS permissions from the user.
  static Future<bool> requestPermissions() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

  /// Sends an SMS via the device's default SIM card using Native Kotlin SmsManager.
  /// [phoneNumber] is the mobile number to send to.
  /// [message] is the text content to send.
  static Future<bool> sendSms(String phoneNumber, String message) async {
    debugPrint("[SimSMS] SMS is temporarily disabled for testing. Would have sent: \$message");
    return true;

    bool hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint("[SimSMS] SMS Permission Denied.");
      return false;
    }

    if (phoneNumber.isEmpty) {
      debugPrint("[SimSMS] No phone number provided.");
      return false;
    }

    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.length == 10 && !cleanNumber.startsWith('+')) {
      cleanNumber = '+91$cleanNumber';
    } else if (cleanNumber.startsWith('0') && cleanNumber.length == 11) {
      cleanNumber = '+91${cleanNumber.substring(1)}';
    }

    try {
      final bool result = await _channel.invokeMethod('sendSms', {
        'phone': cleanNumber,
        'message': message,
      });
      if (result) {
        debugPrint("[SimSMS] Native SMS sent successfully to $phoneNumber");
        return true;
      } else {
        debugPrint("[SimSMS] Native SMS failed, attempting foreground fallback.");
        return await _sendForegroundSms(cleanNumber, message);
      }
    } on PlatformException catch (e) {
      debugPrint("[SimSMS] Native Exception sending SMS: ${e.message}. Attempting foreground fallback.");
      return await _sendForegroundSms(cleanNumber, message);
    } catch (e) {
      debugPrint("[SimSMS] Unknown error: $e. Attempting foreground fallback.");
      return await _sendForegroundSms(cleanNumber, message);
    }
  }

  static Future<bool> _sendForegroundSms(String phone, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': message,
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        debugPrint("[SimSMS] Could not launch SMS app.");
        return false;
      }
    } catch (e) {
      debugPrint("[SimSMS] Error launching SMS app: $e");
      return false;
    }
  }
}
