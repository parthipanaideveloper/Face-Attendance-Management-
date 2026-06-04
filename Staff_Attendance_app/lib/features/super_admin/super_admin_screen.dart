import 'package:flutter/material.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/admin/dashboard_screen.dart';
import 'package:intl/intl.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  DateTime? _selectedExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadExpiryDate();
  }

  Future<void> _loadExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? expiryStr = prefs.getString('subscription_expiry_date');
    if (expiryStr != null) {
      setState(() {
        _selectedExpiryDate = DateTime.parse(expiryStr);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_expiry_date', picked.toIso8601String());
      setState(() {
        _selectedExpiryDate = picked;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expiry Date Updated!"), backgroundColor: AppTheme.accentEmerald));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Super Admin Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 100, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text("Manage Application Subscription", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Card(
                color: AppTheme.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: AppTheme.accentCyan),
                  title: const Text("Current Expiry Date", style: TextStyle(color: Colors.white70)),
                  subtitle: Text(
                    _selectedExpiryDate != null ? DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!) : "Not Set (Using 5-min Trial)",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                    onPressed: () => _selectDate(context),
                    child: const Text("Set Date", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.dashboard, color: Colors.white),
                label: const Text("Access Main Dashboard", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
