import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/features/attendance/home_screen.dart';
import 'dart:math';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _pinController = TextEditingController();
  int _deviceId = 0;
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedId = prefs.getInt('device_id');
    if (savedId == null) {
      // Generate a random 6-digit device ID
      savedId = 100000 + Random().nextInt(900000);
      await prefs.setInt('device_id', savedId);
    }
    setState(() {
      _deviceId = savedId!;
      _isLoading = false;
    });
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) return;
    
    // The secret formula: Device ID * 47
    int expectedPin = _deviceId * 47;
    int? enteredPin = int.tryParse(_pinController.text.trim());

    if (enteredPin == expectedPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_activated', true);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen())
        );
      }
    } else {
      setState(() {
        _errorMsg = "Invalid Activation Key";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: AppTheme.accentCyan),
                  const SizedBox(height: 16),
                  const Text("Device Activation", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("This device is not authorized to run the application. Please enter the activation key to unlock it.", 
                    style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12)
                    ),
                    child: Column(
                      children: [
                        const Text("Your Device ID", style: TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(_deviceId.toString(), style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: "Activation Key",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentCyan)),
                    ),
                  ),
                  
                  if (_errorMsg.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _verifyPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Unlock Application", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
