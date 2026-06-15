import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

class ChangeSuperAdminPinScreen extends StatefulWidget {
  const ChangeSuperAdminPinScreen({super.key});

  @override
  State<ChangeSuperAdminPinScreen> createState() => _ChangeSuperAdminPinScreenState();
}

class _ChangeSuperAdminPinScreenState extends State<ChangeSuperAdminPinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  String _actualCurrentPin = '0000';

  @override
  void initState() {
    super.initState();
    _loadCurrentPin();
  }

  Future<void> _loadCurrentPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _actualCurrentPin = prefs.getString('super_admin_pin') ?? '0000';
    });
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin != _actualCurrentPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect Current PIN!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (newPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PIN must be exactly 4 digits!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PIN and Confirm PIN do not match!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('super_admin_pin', newPin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SuperAdmin PIN Changed Successfully!'), backgroundColor: AppTheme.accentEmerald),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('Change SuperAdmin PIN', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current SuperAdmin PIN', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text('New SuperAdmin PIN (4 Digits)', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Confirm New SuperAdmin PIN', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _changePin,
                child: const Text('Change PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
