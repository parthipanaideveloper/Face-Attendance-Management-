import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/auth/login_screen.dart';
import 'package:staff_attendance_app/features/admin/manage_staff_screen.dart';
import 'package:staff_attendance_app/features/attendance/scanner_screen.dart';
import 'package:staff_attendance_app/features/admin/dashboard_screen.dart' as old_dashboard;
import 'package:staff_attendance_app/features/admin/register_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_settings_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('enabled_features');
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings, size: 40, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back,',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),

              // Action Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildActionCard(
                    context,
                    title: 'Live Scanner',
                    subtitle: 'Face ID & RFID scanner',
                    icon: Icons.camera_alt,
                    color: AppTheme.accentEmerald,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Analytical Reports',
                    subtitle: 'View attendance stats',
                    icon: Icons.bar_chart,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const old_dashboard.DashboardScreen()));
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Register Employee',
                    subtitle: 'Add new face data',
                    icon: Icons.person_add,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Manage Staff',
                    subtitle: 'Add or edit staff features',
                    icon: Icons.people_alt,
                    color: AppTheme.accentCyan,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStaffScreen()));
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Admin Settings',
                    subtitle: 'System configuration',
                    icon: Icons.settings,
                    color: Colors.grey,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsScreen()));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
