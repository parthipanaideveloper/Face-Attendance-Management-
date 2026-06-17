import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailService {
  // Sender credentials for activation & notification emails
  static const String defaultSenderEmail = 'parthipan25m@gmail.com';
  static const String defaultAppPassword = 'lrimzrtmqlragqmp';
  static const List<String> defaultReceiverEmails = [
    'parthipan25m@gmail.com',
  ];
  static Future<void> sendCustomEmail(String to, String subject, String body) async {
    try {
      final smtpServer = gmail(defaultSenderEmail, defaultAppPassword);
      final message = Message()
        ..from = const Address(defaultSenderEmail, 'Attendance System')
        ..recipients.add(to)
        ..subject = subject
        ..text = body;

      final sendReport = await send(message, smtpServer);
      debugPrint('[EmailService] Custom email sent: $sendReport');
    } catch (e) {
      debugPrint('[EmailService] Error sending custom email: $e');
    }
  }

  static Future<void> sendAttendanceSummaryEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final senderEmail = prefs.getString('email_sender')?.trim() ?? defaultSenderEmail;
      final appPassword = prefs.getString('email_password')?.trim() ?? defaultAppPassword;
      final receiversStr = prefs.getString('email_receivers')?.trim() ?? '';
      final bccStr = prefs.getString('email_bcc')?.trim() ?? '';

      List<String> receiverEmails = receiversStr.isNotEmpty 
          ? receiversStr.split(',').map((e) => e.trim()).toList() 
          : defaultReceiverEmails;
          
      List<String> bccEmails = bccStr.isNotEmpty
          ? bccStr.split(',').map((e) => e.trim()).toList()
          : [];

      final dbHelper = DatabaseHelper();
      final staffs = await dbHelper.getAllStaffs();
      
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendanceList = await dbHelper.getAttendanceByDate(today);

      Map<String, Map<String, List<String>>> summary = {
        'Teaching Staff': {'Present': [], 'Absent': [], 'Late Entry': []},
        'Non-Teaching Staff': {'Present': [], 'Absent': [], 'Late Entry': []}
      };

      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var att in attendanceList) {
        attendanceMap[att['register_no']] = att;
      }

      for (var staff in staffs) {
        String regNo = (staff['register_no'] ?? '').toUpperCase();
        String name = staff['name'] ?? 'Unknown';
        // Categorize based on existing logic or register_no prefix
        String designation = staff['designation'] ?? 'Teaching Staff';
        
        String staffType = 'Teaching Staff';
        if (regNo.startsWith('SMSNS') || designation.contains('Non-Teaching')) {
          staffType = 'Non-Teaching Staff';
        } else if (designation.contains('Teaching')) {
          staffType = 'Teaching Staff';
        } else {
          // fallback
          if (regNo.startsWith('SMSNS')) {
            staffType = 'Non-Teaching Staff';
          }
        }

        var record = attendanceMap[regNo];
        if (record != null) {
          String status = record['status'] ?? 'Present';
          String inTime = record['in_time'] ?? '';
          String outTime = record['out_time'] ?? '';
          
          String entry = '$name (In: $inTime, Out: ${outTime.isEmpty ? 'N/A' : outTime})';
          
          if (status == 'Present') {
            summary[staffType]!['Present']!.add(entry);
          } else if (status == 'Late Entry') {
            summary[staffType]!['Late Entry']!.add(entry);
          } else {
            summary[staffType]!['Present']!.add(entry);
          }
        } else {
          summary[staffType]!['Absent']!.add(name);
        }
      }

      // Check if we should send the automated email (Morning @ 10:30, Evening @ 19:00)
      String lastMorningSentDate = prefs.getString('last_morning_email_date') ?? '';
      String lastEveningSentDate = prefs.getString('last_evening_email_date') ?? '';

      DateTime now = DateTime.now();
      // Morning window: 10:30 AM to 11:30 AM
      bool isMorningTime = (now.hour == 10 && now.minute >= 30) || (now.hour == 11 && now.minute <= 30);
      // Evening window: 7:00 PM to 8:00 PM
      bool isEveningTime = (now.hour == 19);

      bool shouldSendMorning = isMorningTime && lastMorningSentDate != today;
      bool shouldSendEvening = isEveningTime && lastEveningSentDate != today;

      if (!shouldSendMorning && !shouldSendEvening) {
        debugPrint('[EmailService] Automated email blocked. Time: ${now.hour}:${now.minute}, MorningSent: $lastMorningSentDate, EveningSent: $lastEveningSentDate');
        return;
      }

      int totalStaffsCount = staffs.length;
      int totalPresentCount = 0;
      int totalAbsentCount = 0;
      int totalLateCount = 0;

      String htmlBody = '''
      <h2>📅 Daily Staff Attendance Report - $today</h2>
      <hr>
      ''';

      for (var staffType in ['Teaching Staff', 'Non-Teaching Staff']) {
        var presentList = summary[staffType]!['Present']!;
        var lateList = summary[staffType]!['Late Entry']!;
        var absentList = summary[staffType]!['Absent']!;
        
        int totalCategoryStaff = presentList.length + lateList.length + absentList.length;
        if (totalCategoryStaff == 0) continue;

        totalPresentCount += presentList.length;
        totalAbsentCount += absentList.length;
        totalLateCount += lateList.length;

        double presentPct = (presentList.length / totalCategoryStaff) * 100;
        double latePct = (lateList.length / totalCategoryStaff) * 100;
        double absentPct = (absentList.length / totalCategoryStaff) * 100;

        htmlBody += '''
        <h3>🧑‍🏫 $staffType (Total: $totalCategoryStaff)</h3>
        <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 100%; text-align: left; font-family: Arial, sans-serif;">
          <tr style="background-color: #f2f2f2;">
            <th style="width: 20%;">Status</th>
            <th style="width: 10%;">Count</th>
            <th style="width: 15%;">Percentage</th>
            <th style="width: 55%;">Names</th>
          </tr>
          <tr>
            <td>✅ Present</td>
            <td><b>${presentList.length}</b></td>
            <td>${presentPct.toStringAsFixed(1)}%</td>
            <td>${presentList.isEmpty ? '-' : presentList.join(", ")}</td>
          </tr>
          <tr>
            <td>⏰ Late Entry</td>
            <td><b>${lateList.length}</b></td>
            <td>${latePct.toStringAsFixed(1)}%</td>
            <td>${lateList.isEmpty ? '-' : lateList.join(", ")}</td>
          </tr>
          <tr>
            <td>❌ Absent</td>
            <td><b>${absentList.length}</b></td>
            <td>${absentPct.toStringAsFixed(1)}%</td>
            <td>${absentList.isEmpty ? '-' : absentList.join(", ")}</td>
          </tr>
        </table>
        <br>
        ''';
      }

      htmlBody += '''
      <h3>📊 Overall Summary</h3>
      <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 50%; text-align: left; font-family: Arial, sans-serif;">
        <tr><td style="background-color: #f2f2f2;"><b>Total Staffs</b></td><td>$totalStaffsCount</td></tr>
        <tr><td style="background-color: #f2f2f2;"><b>Total Present</b></td><td>$totalPresentCount</td></tr>
        <tr><td style="background-color: #f2f2f2;"><b>Total Late Entry</b></td><td>$totalLateCount</td></tr>
        <tr><td style="background-color: #f2f2f2;"><b>Total Absent</b></td><td>$totalAbsentCount</td></tr>
      </table>
      ''';

      if (senderEmail.isEmpty || appPassword == 'your_app_password') {
        debugPrint('[EmailService] SENDER_EMAIL or app password is not configured.');
        return;
      }

      String subjectText = shouldSendEvening ? 'Daily Staff Attendance Summary (Evening) - $today' : 'Daily Staff Attendance Summary (Morning) - $today';

      final smtpServer = gmail(senderEmail, appPassword);
      final message = Message()
        ..from = Address(senderEmail, 'Attendance System')
        ..recipients.addAll(receiverEmails)
        ..bccRecipients.addAll(bccEmails)
        ..subject = subjectText
        ..html = htmlBody;

      debugPrint('[EmailService] Sending email to $receiverEmails');
      final sendReport = await send(message, smtpServer);
      debugPrint('[EmailService] Message sent: $sendReport');
      
      // Save the date so it doesn't send again today for this particular slot
      if (shouldSendMorning) {
        await prefs.setString('last_morning_email_date', today);
      } else if (shouldSendEvening) {
        await prefs.setString('last_evening_email_date', today);
      }

    } catch (e) {
      debugPrint('[EmailService] Error sending email: $e');
    }
  }
}
