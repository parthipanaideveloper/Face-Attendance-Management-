import 'package:flutter/material.dart';
import 'package:student_attendance_app/database/db_helper.dart';
import 'package:student_attendance_app/utils/theme.dart';

class AdminSettingsScreen extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
            leading: const Icon(Icons.history, color: Colors.orangeAccent),
            title: const Text("Clear Attendance History", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Deletes all daily attendance logs", style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onTap: () => _confirmWipe(context, "Clear History", "Are you sure you want to delete all attendance logs? Employee registrations will be kept.", () async {
              final db = await DatabaseHelper().database;
              await db.delete('attendance_logs');
            }),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.people_outline, color: Colors.redAccent),
            title: const Text("Delete All Registered Employees", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            subtitle: const Text("Wipes all FaceID data", style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.warning, color: Colors.redAccent),
            onTap: () => _confirmWipe(context, "Delete All Employees", "WARNING: This will permanently delete all employee FaceID data. You will have to re-register everyone.", () async {
              final db = await DatabaseHelper().database;
              await db.delete('students');
              await db.delete('attendance_logs');
            }),
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
}
