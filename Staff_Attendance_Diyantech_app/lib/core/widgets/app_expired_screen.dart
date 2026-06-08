import 'package:flutter/material.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:staff_attendance_app/features/attendance/home_screen.dart';

import 'package:staff_attendance_app/features/super_admin/super_admin_screen.dart';

class AppExpiredScreen extends StatefulWidget {
  const AppExpiredScreen({super.key});

  @override
  State<AppExpiredScreen> createState() => _AppExpiredScreenState();
}

class _AppExpiredScreenState extends State<AppExpiredScreen> {
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    
    // Force migration if the old ID does not start with DTS- or has the literal bug
    if (id == null || !id.startsWith('DTS-') || id.contains('\${')) {
      String generateBlock() {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
      }
      id = "DTS-${generateBlock()}-${generateBlock()}";
      await prefs.setString('device_id', id);
    }
    setState(() {
      _deviceId = id!;
    });
  }

  void _showSuperAdminLogin() {
    final TextEditingController passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Super Admin Login", style: TextStyle(color: Colors.redAccent)),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Master Password",
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (passCtrl.text == "superadmin123") {
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Password"), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _contactDeveloper() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'developer@example.com',
      query: 'subject=Subscription Renewal Request&body=My Device ID is: $_deviceId',
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch email app')));
      }
    }
  }

  void _showEnterKeyDialog() {
    final TextEditingController keyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Enter License Key", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: keyCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Activation Code",
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              // Expected Key: Replace DTS with SMS, and reverse the remaining string.
              // Example: DTS-A1B2-C3D4 -> SMS-4D3C-2B1A
              String expectedPrefix = "SMS-";
              String partsToReverse = _deviceId.substring(4); // gets A1B2-C3D4
              String reversedParts = partsToReverse.split('').reversed.join('');
              String expectedKey = expectedPrefix + reversedParts;

              if (keyCtrl.text.trim().toUpperCase() == expectedKey) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('install_time', DateTime.now().toIso8601String());
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subscription Renewed Successfully!"), backgroundColor: AppTheme.accentEmerald));
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                }
              } else {
                if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Secure License Key"), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text("Activate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium, size: 100, color: Colors.amberAccent),
              const SizedBox(height: 24),
              const Text(
                "Subscription Expired",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Your trial period for the Smart Attendance App has successfully concluded. To continue using the software and accessing advanced features, an active developer subscription is required.",
                style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text("Device ID: $_deviceId", style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.email, color: Colors.white),
                label: const Text("Email Developer Code", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _contactDeveloper,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.vpn_key, color: Colors.white70),
                label: const Text("Enter License Key", style: TextStyle(color: Colors.white70, fontSize: 16)),
                onPressed: _showEnterKeyDialog,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onLongPress: _showSuperAdminLogin,
                child: const Text("Super Admin Access", style: TextStyle(color: Colors.white24, fontSize: 12)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
