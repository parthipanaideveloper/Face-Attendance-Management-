import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmsSchedulerService {
  static final SmsSchedulerService _instance = SmsSchedulerService._internal();
  factory SmsSchedulerService() => _instance;
  SmsSchedulerService._internal();

  Timer? _timer;
  bool _isSending = false;

  void startScheduler() {
    // Check every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndSendDailySummary();
    });
  }

  void stopScheduler() {
    _timer?.cancel();
  }

  Future<void> _checkAndSendDailySummary() async {
    if (_isSending) return;

    final now = DateTime.now();
    
    // Check if it's 6:00 PM (18:00)
    if (now.hour == 18 && now.minute == 0) {
      final prefs = await SharedPreferences.getInstance();
      final String todayStr = DateFormat('yyyy-MM-dd').format(now);
      final String lastSentDate = prefs.getString('last_daily_sms_date') ?? '';

      // If we haven't sent it today yet
      if (lastSentDate != todayStr) {
        _isSending = true;
        try {
          await _sendSummaryToAll();
          await prefs.setString('last_daily_sms_date', todayStr);
          debugPrint("[SmsScheduler] Successfully sent 6:00 PM Daily Summary SMS.");
        } catch (e) {
          debugPrint("[SmsScheduler] Error sending daily summary: $e");
        } finally {
          _isSending = false;
        }
      }
    }
  }

  Future<void> _sendSummaryToAll() async {
    final db = DatabaseHelper();
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final allStaff = await db.getAllStaffs();
    final todayAttendance = await db.getAttendanceByDate(today);
    
    Map<String, Map<String, dynamic>> attendanceMap = {};
    for (var a in todayAttendance) {
      attendanceMap[a['register_no'] as String] = a;
    }
    final prefs = await SharedPreferences.getInstance();
    final String instName = prefs.getString('institution_name') ?? 'Your Institution';
    
    for (var staff in allStaff) {
      String phone = staff['mobile_no'] ?? '';
      if (phone.isNotEmpty && phone.length >= 10) {
        String name = staff['name'] ?? 'Employee';
        String regNo = staff['register_no'] ?? '';
        
        String inTime = "Not scanned";
        String outTime = "Not scanned";
        
        if (attendanceMap.containsKey(regNo)) {
           var a = attendanceMap[regNo]!;
           inTime = a['in_time']?.toString() ?? "Not scanned";
           if (inTime.isEmpty) inTime = "Not scanned";
           outTime = a['out_time']?.toString() ?? "Not scanned";
           if (outTime.isEmpty) outTime = "Not scanned";
        }
        
        String message = "$instName\n\nDear $name, Attendance for $today:\nMorning In: $inTime\nEvening Out: $outTime";
        
        await SimSmsService.sendSms(phone, message);
        
        // Delay for 1 minute between each SMS to bypass Android spam limits
        await Future.delayed(const Duration(minutes: 1));
      }
    }
  }
}
