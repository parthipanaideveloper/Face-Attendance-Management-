import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/admin/admin_dashboard.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'dart:math';

class RegistrationScreen extends StatefulWidget {
  final String? prefilledKey;
  const RegistrationScreen({super.key, this.prefilledKey});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with TickerProviderStateMixin {
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _adminUserController = TextEditingController();
  final _adminPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();

    // Pre-fill the key if passed from activation screen
    if (widget.prefilledKey != null) {
      _keyController.text = widget.prefilledKey!;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _keyController.dispose();
    _nameController.dispose();
    _adminUserController.dispose();
    _adminPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _registerInstitution() async {
    final key = _keyController.text.trim();
    final name = _nameController.text.trim();
    final user = _adminUserController.text.trim();
    final pass = _adminPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (key.isEmpty || name.isEmpty || user.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      _showError('Please fill all fields.');
      return;
    }

    if (pass != confirmPass) {
      _showError('Passwords do not match.');
      return;
    }

    if (pass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final tempKey = prefs.getString('temp_activation_key');

      // Key comparison — strip dashes if user typed formatted key
      final cleanInputKey = key.replaceAll('-', '');
      final cleanTempKey = tempKey?.replaceAll('-', '') ?? '';

      if (tempKey == null || cleanTempKey != cleanInputKey) {
        throw Exception('Invalid Activation Key. Please use the key sent to your admin.');
      }

      // Generate Institution Code
      final random = Random();
      final code = 'DTS-${random.nextInt(900000) + 100000}';

      // Save to Firebase
      await FirebaseFirestore.instance.collection('institutions').doc(code).set({
        'name': name,
        'admin_username': user,
        'admin_password': pass,
        'created_at': FieldValue.serverTimestamp(),
        'subscription_valid_until': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'is_blocked': false,
      });

      // Save locally
      await prefs.setString('institution_code', code);
      await prefs.setString('institution_name', name);
      await prefs.setString('admin_username', user);
      await prefs.setString('admin_password', pass);
      await prefs.setString('role', 'admin');

      // Clear the temp key so it can't be reused
      await prefs.remove('temp_activation_key');

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Registered!', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Institution registered successfully.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentCyan.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge, color: AppTheme.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Institution Code', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            Text(code, style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppTheme.textSecondary, size: 18),
                        onPressed: () {
                          // Copy code to clipboard handled by snackbar
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('⚠️ Save this code — you\'ll need it to login.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AdminDashboard()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
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
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Logo
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentEmerald.withAlpha(80),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/auth_logo.png',
                      height: 100,
                      errorBuilder: (ctx, err, _) => const Icon(Icons.business, size: 100, color: AppTheme.accentEmerald),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Register Your Institution',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the activation key provided by your admin.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Step 1 — Activation Key
                  _sectionLabel('Step 1: Activation Key'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _keyController,
                    label: 'Activation Key (XXXX-XXXX-XXXX-XXXX)',
                    icon: Icons.vpn_key,
                    hint: 'e.g. 1234-5678-9012-3456',
                  ),
                  const SizedBox(height: 24),

                  // Step 2 — Institution Info
                  _sectionLabel('Step 2: Institution Details'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Institution Name',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 24),

                  // Step 3 — Admin Credentials
                  _sectionLabel('Step 3: Admin Credentials'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _adminUserController,
                    label: 'Admin Username',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField(
                    controller: _adminPassController,
                    label: 'Admin Password',
                    obscure: _obscurePass,
                    onToggle: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField(
                    controller: _confirmPassController,
                    label: 'Confirm Password',
                    obscure: _obscureConfirmPass,
                    onToggle: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                  ),
                  const SizedBox(height: 32),

                  // Register Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.accentEmerald))
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _registerInstitution,
                            icon: const Icon(Icons.how_to_reg, size: 20),
                            label: const Text('Register & Go to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.accentCyan.withAlpha(220),
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
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
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          labelStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, color: AppTheme.accentCyan),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
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
        obscureText: obscure,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(Icons.lock, color: AppTheme.accentCyan),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
