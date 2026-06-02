import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/features/admin/employee_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:intl/intl.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  void _confirmWipe(BuildContext context, String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(content, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title Completed!"), backgroundColor: AppTheme.accentEmerald));
            },
            child: const Text("Confirm Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      final allStaff = await db.getAllStaffs();
      final todayAttendance = await db.getAttendanceByDate(today);
      
      Set<String> attendedIds = todayAttendance.map((a) => a['register_no'] as String).toSet();
      
      int sentCount = 0;
      for (var staff in allStaff) {
        String regNo = staff['register_no'] ?? '';
        if (regNo.isNotEmpty && !attendedIds.contains(regNo)) {
          String phone = staff['phone_number'] ?? '';
          if (phone.isNotEmpty) {
            String name = staff['name'] ?? 'Employee';
            await SimSmsService.sendSms(phone, "Dear $name, you have been marked ABSENT for today ($today).");
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Admin Settings"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Database Management", style: TextStyle(color: AppTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.download, color: AppTheme.accentCyan),
            title: const Text("Export Database Backup", style: TextStyle(color: Colors.white)),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data is synced automatically with Firebase Cloud.")));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.history, color: Colors.orangeAccent),
            title: const Text("Clear Attendance History", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Deletes all daily attendance logs", style: TextStyle(color: Colors.white54)),
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
            title: const Text("Manage Employees", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("Edit or delete individual employee data", style: TextStyle(color: Colors.white54)),
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
            title: const Text("Notify Absentees (SMS)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("Send 'Absent' SMS to all employees not scanned today", style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.send, color: Colors.orangeAccent, size: 16),
            onTap: () {
               _notifyAbsentees(context, ref);
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.people_outline, color: Colors.redAccent),
            title: const Text("Delete All Registered Employees", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            subtitle: const Text("Wipes all FaceID data", style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.warning, color: Colors.redAccent),
            onTap: () => _confirmWipe(context, "Delete All Employees", "WARNING: This will permanently delete all employee FaceID data.", () async {
              final db = ref.read(databaseProvider);
              await db.deleteAllStaffs();
            }),
          ),
          const SizedBox(height: 30),
          const Text("Security Settings", style: TextStyle(color: AppTheme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.password, color: AppTheme.accentCyan),
            title: const Text("Change Admin PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text("Update the 4-digit PIN for admin access", style: TextStyle(color: Colors.white54)),
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
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
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
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              if (pinCtrl.text.length == 4) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('admin_pin', pinCtrl.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin PIN Updated Successfully!", style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.accentEmerald));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN must be exactly 4 digits", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Save PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
