import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:staff_attendance_app/features/auth/activation_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_dashboard.dart';
import 'package:staff_attendance_app/features/staff/staff_dashboard.dart';
import 'package:staff_attendance_app/features/super_admin/master_admin_dashboard.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/main.dart' show startServicesAfterLogin;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _institutionCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Master Admin Secret Trigger
  int _tapCount = 0;
  Timer? _tapTimer;
  final int _requiredTaps = 24;
  final Duration _timeLimit = const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadSavedInstitutionCode();
  }

  @override
  void dispose() {
    _institutionCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedInstitutionCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('institution_code');
    if (savedCode != null && mounted) {
      _institutionCodeController.text = savedCode;
    }
  }

  void _handleLogoTap() {
    _tapCount++;
    if (_tapCount == 1) {
      _tapTimer = Timer(_timeLimit, () {
        _tapCount = 0;
      });
    }
    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _tapTimer?.cancel();
      _showMasterAdminPrompt();
    }
  }

  void _showMasterAdminPrompt() {
    final masterPassController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Master Admin Access', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: masterPassController,
          obscureText: true,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter Master Password',
            hintStyle: TextStyle(color: Colors.black54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withAlpha(60)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF06B6D4)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            onPressed: () {
              if (masterPassController.text == 'Master@123') {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MasterAdminDashboard()),
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Master Password')),
                );
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final code = _institutionCodeController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (code.isEmpty || username.isEmpty || password.isEmpty) {
      _showError('Please fill all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('institutions')
          .doc(code)
          .get();

      if (!docSnapshot.exists) throw Exception('Invalid Institution Code.');

      final data = docSnapshot.data() as Map<String, dynamic>;

      if (data['is_blocked'] == true) {
        throw Exception('This institution has been blocked by the admin.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('institution_code', code);
      if (data.containsKey('name')) {
        await prefs.setString('institution_name', data['name']);
      }

      // Check if Admin
      if (data['admin_username'] == username && data['admin_password'] == password) {
        await prefs.setString('role', 'admin');
        startServicesAfterLogin(); // start background services now that user is logged in
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        }
        return;
      }

      // Check if Staff
      final staffQuery = await FirebaseFirestore.instance
          .collection('institutions')
          .doc(code)
          .collection('students')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (staffQuery.docs.isNotEmpty) {
        final staffData = staffQuery.docs.first.data();
        await prefs.setString('role', 'staff');
        await prefs.setString('staff_register_no', staffQuery.docs.first.id);
        List<dynamic> features = staffData['features'] ?? [];
        await prefs.setStringList(
          'enabled_features',
          features.map((e) => e.toString()).toList(),
        );
        startServicesAfterLogin(); // start background services now that user is logged in
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StaffDashboard()),
          );
        }
        return;
      }

      throw Exception('Invalid Username or Password.');
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow
                GestureDetector(
                  onTap: _handleLogoTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withAlpha(80),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/auth_logo.png',
                      height: 120,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.security, size: 120, color: Color(0xFF06B6D4)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to continue',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 36),

                // Institution Code
                _styledField(
                  controller: _institutionCodeController,
                  label: 'Institution Code (e.g. DTS-123456)',
                  icon: Icons.business,
                ),
                const SizedBox(height: 14),

                // Username
                _styledField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.person,
                ),
                const SizedBox(height: 14),

                // Password
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: Icon(Icons.lock, color: AppTheme.accentCyan),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Login Button
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF06B6D4))
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _login,
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                const SizedBox(height: 16),

                // New Institution Link
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivationScreen()),
                    );
                  },
                  child: const Text(
                    'New Institution? Activate →',
                    style: TextStyle(color: Color(0xFF06B6D4), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, color: AppTheme.accentCyan),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
