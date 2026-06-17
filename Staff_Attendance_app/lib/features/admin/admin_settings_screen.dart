import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/features/admin/employee_management_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_auth_screen.dart';
import 'package:staff_attendance_app/features/admin/super_admin_auth_screen.dart';
import 'package:staff_attendance_app/features/admin/email_config_screen.dart';
import 'package:staff_attendance_app/features/admin/change_super_admin_pin_screen.dart';
import 'package:staff_attendance_app/features/admin/live_monitoring_screen.dart'; // NEW
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/features/admin/mismatch_images_screen.dart' as staff_attendance_app_mismatch;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  void _confirmWipe(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(content, style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title Completed!"), backgroundColor: AppTheme.accentEmerald));
            },
            child: const Text("Confirm Delete", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyAbsentees(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String instName = prefs.getString('institution_name') ?? 'Your Institution';
      
      final allStaff = await db.getAllStaffs();
      final todayAttendance = await db.getAttendanceByDate(today);
      
      Set<String> attendedIds = todayAttendance.map((a) => a['register_no'] as String).toSet();
      
      int sentCount = 0;
      for (var staff in allStaff) {
        String regNo = staff['register_no'] ?? '';
        if (regNo.isNotEmpty && !attendedIds.contains(regNo)) {
          String phone = staff['mobile_no'] ?? '';
          if (phone.isNotEmpty) {
            String name = staff['name'] ?? 'Employee';
            String message = "$instName\n\nDear $name, you have been marked ABSENT for today ($today).";
            await SimSmsService.sendSms(phone, message);
            sentCount++;
          }
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Absent notifications sent to $sentCount employees."),
          backgroundColor: AppTheme.accentEmerald,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error sending notifications: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final String instName = prefs.getString('institution_name') ?? 'Your Institution';
      
      final db = ref.read(databaseProvider);
      final staffs = await db.getAllStaffs();
      final String jsonStr = jsonEncode({'staff_backup': staffs, 'timestamp': DateTime.now().toIso8601String()});
      final directory = await getApplicationDocumentsDirectory();
      final instCode = prefs.getString('institution_code') ?? 'backup';
      final file = File('${directory.path}/${instCode}_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);
      
      if (context.mounted) {
        Navigator.pop(context); // close loading
        await Share.shareXFiles([XFile(file.path)], text: 'Database Backup');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exporting data: $e")));
      }
    }
  }

  Future<void> _sendDailySummarySms(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Sending Daily Summary", style: TextStyle(color: Colors.orangeAccent)),
        content: const Text("Sending SMS slowly (1 per minute) to avoid Android security blocks.\n\nPlease DO NOT close this app or lock your screen until it finishes.", style: TextStyle(color: AppTheme.textPrimary)),
        contentPadding: const EdgeInsets.all(20),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String instName = prefs.getString('institution_name') ?? 'Your Institution';
      
      final allStaff = await db.getAllStaffs();
      final todayAttendance = await db.getAttendanceByDate(today);
      
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var a in todayAttendance) {
        attendanceMap[a['register_no'] as String] = a;
      }
      
      int sentCount = 0;
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
          sentCount++;
          
          // Delay for 1 minute to bypass Android limit
          await Future.delayed(const Duration(minutes: 1));
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Daily Summary successfully sent to $sentCount employees."),
          backgroundColor: AppTheme.accentEmerald,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error sending daily summary: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _sendPrincipalEmailReport(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String instName = prefs.getString('institution_name') ?? 'Your Institution';

      final allStaff = await db.getAllStaffs();
      final todayAttendance = await db.getAttendanceByDate(today);

      int totalTeaching = 0;
      int totalNonTeaching = 0;

      for (var staff in allStaff) {
        String regNo = staff['register_no'] ?? '';
        if (regNo.toUpperCase().startsWith('SMSNS')) {
          totalNonTeaching++;
        } else {
          totalTeaching++;
        }
      }

      int presentTeaching = 0;
      int lateTeaching = 0;
      int presentNonTeaching = 0;
      int lateNonTeaching = 0;

      for (var att in todayAttendance) {
        String regNo = att['register_no'] ?? '';
        String status = att['status'] ?? 'Present';
        
        if (regNo.toUpperCase().startsWith('SMSNS')) {
          presentNonTeaching++;
          if (status == 'Late Entry') lateNonTeaching++;
        } else {
          presentTeaching++;
          if (status == 'Late Entry') lateTeaching++;
        }
      }

      int absentTeaching = totalTeaching - presentTeaching;
      if (absentTeaching < 0) absentTeaching = 0;

      int absentNonTeaching = totalNonTeaching - presentNonTeaching;
      if (absentNonTeaching < 0) absentNonTeaching = 0;

      if (context.mounted) Navigator.pop(context); // hide loading

      String subject = "Daily Staff Attendance Report - $today";
      String body = '''Respected Principal,

Please find the staff attendance summary for today ($today) below:

--- TEACHING STAFF ---
Total: $totalTeaching
Present: $presentTeaching
Absent: $absentTeaching
Late Entry: $lateTeaching

--- NON-TEACHING STAFF ---
Total: $totalNonTeaching
Present: $presentNonTeaching
Absent: $absentNonTeaching
Late Entry: $lateNonTeaching

Regards,
Attendance System
$instName
''';

      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: '',
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open email app. Please ensure an email app is installed."), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating report: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _broadcastSms(BuildContext context, WidgetRef ref) {
    final TextEditingController msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Broadcast SMS", style: TextStyle(color: Colors.orangeAccent)),
        content: TextField(
          controller: msgCtrl,
          style: TextStyle(color: AppTheme.textPrimary),
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Enter message to send to ALL staff...", hintStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String msg = msgCtrl.text.trim();
              if (msg.isEmpty) return;
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              int sentCount = 0;
              try {
                final db = ref.read(databaseProvider);
                final allStaff = await db.getAllStaffs();
                for (var staff in allStaff) {
                  String phone = staff['mobile_no'] ?? '';
                  if (phone.length >= 10) {
                    await SimSmsService.sendSms(phone, msg);
                    sentCount++;
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SMS sent to $sentCount employees."), backgroundColor: AppTheme.accentEmerald));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text("Send to All"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Admin Settings"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
        children: [
          const Text("Database Management", style: TextStyle(color: AppTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.cloud_download, color: Colors.blueAccent),
            title: const Text("Sync Data from Firebase", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("One-time sync to download all staff to local DB", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.sync, color: Colors.blueAccent),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              try {
                final db = ref.read(databaseProvider);
                await db.syncFromFirebase();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Complete! All data is now locally stored."), backgroundColor: AppTheme.accentEmerald));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Failed: ${e.toString()}"), backgroundColor: Colors.redAccent));
                }
              }
            },
          ),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.download, color: AppTheme.accentCyan),
            title: const Text("Export Database Backup", style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
               _exportDatabase(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.history, color: Colors.orangeAccent),
            title: const Text("Clear Attendance History", style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text("Deletes all daily attendance logs", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onTap: () => _confirmWipe(context, "Clear History", "Are you sure you want to delete all attendance logs? Employee registrations will be kept.", () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cloud Wipes are disabled for safety. Contact SuperAdmin.")));
            }),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.people, color: AppTheme.accentEmerald),
            title: const Text("Manage Employees", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Edit or delete individual employee data", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.accentEmerald, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeManagementScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.sms_failed, color: Colors.orangeAccent),
            title: const Text("Notify Absentees (SMS)", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Send 'Absent' SMS to all employees not scanned today", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.send, color: Colors.orangeAccent, size: 16),
            onTap: () {
               _notifyAbsentees(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.podcasts, color: Colors.orangeAccent),
            title: const Text("Broadcast / Schedule SMS", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Send a custom SMS to all registered employees", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.send, color: Colors.orangeAccent, size: 16),
            onTap: () {
               _broadcastSms(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.email, color: AppTheme.accentCyan),
            title: const Text("Email Configuration", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Set sender, receivers, and BCC emails", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.accentCyan, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EmailConfigScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.security, color: Colors.orangeAccent),
            title: const Text("Change SuperAdmin PIN", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Set a new password for SuperAdmin features", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orangeAccent, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangeSuperAdminPinScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.monitor_heart, color: Colors.pinkAccent),
            title: const Text("Live Health & Monitoring Hub", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Track tablet health and all admin activity logs in real-time", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.pinkAccent, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LiveMonitoringScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.schedule_send, color: AppTheme.accentEmerald),
            title: const Text("Send Daily Summary SMS", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Send consolidated IN/OUT times (1 message per minute)", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.send, color: AppTheme.accentEmerald, size: 16),
            onTap: () {
               _sendDailySummarySms(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.email, color: Colors.blueAccent),
            title: const Text("Send Principal Email Report", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Generate and email the daily attendance status report", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent, size: 16),
            onTap: () {
               _sendPrincipalEmailReport(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.people_outline, color: Colors.redAccent),
            title: const Text("Delete All Registered Employees", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            subtitle: const Text("Wipes all FaceID data", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.warning, color: Colors.redAccent),
            onTap: () => _confirmWipe(context, "Delete All Employees", "WARNING: This will permanently delete all employee FaceID data.", () async {
              final db = ref.read(databaseProvider);
              await db.deleteAllStaffs();
            }),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.image, color: Colors.blueAccent),
            title: const Text("View Mismatch Images", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("View, share, or delete captured mismatch photos", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const staff_attendance_app_mismatch.MismatchImagesScreen()));
            },
          ),
          const SizedBox(height: 30),
          const Text("Security Settings", style: TextStyle(color: AppTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.password, color: AppTheme.accentCyan),
            title: const Text("Change Admin PIN", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text("Update the 4-digit PIN for admin access", style: TextStyle(color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.accentCyan, size: 16),
            onTap: () {
              _showChangePinDialog(context);
            },
          ),
          const SizedBox(height: 30),
          const Text("AI Recognition Distance", style: TextStyle(color: AppTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "For best results, employees should stand exactly 0.5 to 1.0 meters (1.5 to 3 feet) from the camera. If the system is struggling to recognize someone, ask them to step slightly closer so the AI can capture more facial details. Ensure there is good lighting on the face.",
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          ),
        ],
            ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final TextEditingController pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Change Admin PIN", style: TextStyle(color: AppTheme.accentCyan)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, letterSpacing: 8),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: "Enter 4-digit PIN",
            hintStyle: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 1),
            counterText: "",
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              if (pinCtrl.text.length == 4) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('admin_pin', pinCtrl.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin PIN Updated Successfully!", style: TextStyle(color: AppTheme.textPrimary)), backgroundColor: AppTheme.accentEmerald));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN must be exactly 4 digits", style: TextStyle(color: AppTheme.textPrimary)), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Save PIN", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
