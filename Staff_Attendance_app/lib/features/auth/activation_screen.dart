import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staff_attendance_app/features/auth/registration_screen.dart';
import 'package:staff_attendance_app/services/email_service.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> with TickerProviderStateMixin {
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  bool _keySent = false;
  String _generatedKey = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<String> _getDeviceId() async {
    try {
      // Use shared preferences to store/retrieve a unique device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_unique_id');
      if (deviceId == null) {
        final random = Random();
        deviceId = 'DVC-${random.nextInt(900000) + 100000}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        await prefs.setString('device_unique_id', deviceId);
      }
      return deviceId;
    } catch (e) {
      return 'UNKNOWN-DEVICE';
    }
  }

  Future<void> _generateAndSendKey() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate a 16-digit activation key in groups of 4
      final random = Random.secure();
      String rawKey = '';
      for (int i = 0; i < 16; i++) {
        rawKey += random.nextInt(10).toString();
      }
      // Format as XXXX-XXXX-XXXX-XXXX
      _generatedKey = '${rawKey.substring(0, 4)}-${rawKey.substring(4, 8)}-${rawKey.substring(8, 12)}-${rawKey.substring(12, 16)}';

      // Get device ID
      final deviceId = await _getDeviceId();

      // Save temporarily for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_activation_key', rawKey); // store without dashes for comparison

      // Send email in background — don't await on UI thread to avoid ANR
      _sendActivationEmail(mobile, _generatedKey, deviceId);

      setState(() {
        _keySent = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Activation request sent! Check your email for the key.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Fire-and-forget email — runs async without blocking UI
  Future<void> _sendActivationEmail(String mobile, String key, String deviceId) async {
    try {
      final subject = '🔑 New Institution Activation Request';
      final body = '''
New Institution Activation Request
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 Mobile Number : $mobile
🔑 Activation Key: $key
📟 Device ID     : $deviceId
📅 Requested At  : ${DateTime.now().toString()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Please provide this Activation Key to the institution owner to complete registration.

Staff Auth App — Activation System
''';
      await EmailService.sendCustomEmail('parthipan25m@gmail.com', subject, body);
    } catch (e) {
      // Silently handle email errors — don't crash the app
      debugPrint('[ActivationScreen] Email send error: $e');
    }
  }

  void _proceedToRegistration() {
    // Navigate and pass the generated key for pre-fill
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrationScreen(),
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
                          color: AppTheme.accentCyan.withAlpha(80),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/auth_logo.png',
                      height: 110,
                      errorBuilder: (ctx, err, _) => const Icon(Icons.security, size: 110, color: AppTheme.accentCyan),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Activate Your Product',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your mobile number to request an activation key.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Mobile number field
                  _buildTextField(
                    controller: _mobileController,
                    label: 'Mobile Number',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    enabled: !_keySent,
                  ),
                  const SizedBox(height: 20),

                  // Generate Key Button
                  if (!_keySent)
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
                        : _buildButton(
                            label: 'Generate Activation Key',
                            icon: Icons.vpn_key,
                            onPressed: _generateAndSendKey,
                            color: AppTheme.accentCyan,
                          ),

                  // After key is sent — show success state
                  if (_keySent) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withAlpha(80)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.mark_email_read, color: Colors.green, size: 36),
                          const SizedBox(height: 10),
                          const Text(
                            'Activation key sent to admin!',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your activation request has been sent.\nContact admin to receive your key.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildButton(
                      label: 'Proceed to Register',
                      icon: Icons.arrow_forward,
                      onPressed: _proceedToRegistration,
                      color: AppTheme.accentEmerald,
                    ),
                  ],

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()));
                    },
                    child: Text(
                      'Already have a key? Register →',
                      style: TextStyle(color: AppTheme.accentCyan.withAlpha(220), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
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
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: enabled,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
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

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
      ),
    );
  }
}
