import 'package:flutter/material.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminAuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AdminAuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  String _pin = '';
  final String _correctPin = '1234'; // Default Admin PIN
  bool _hasError = false;

  void _onKeyPress(String key) {
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _hasError = false;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  void _verifyPin() {
    if (_pin == _correctPin) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: AppTheme.accentCyan)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(delay: 200.ms),
              const SizedBox(height: 20),
              const Text(
                "Admin Authentication",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 10),
              Text(
                _hasError ? "Incorrect PIN, try again" : "Enter Admin PIN to access dashboard",
                style: TextStyle(color: _hasError ? Colors.redAccent : Colors.white54, fontSize: 16),
              ).animate(target: _hasError ? 1 : 0).shake(),
              const SizedBox(height: 40),
              
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  bool isFilled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppTheme.accentCyan : Colors.transparent,
                      border: Border.all(color: AppTheme.accentCyan, width: 2),
                    ),
                  ).animate(target: isFilled ? 1 : 0).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)).then().scale(begin: const Offset(1.2, 1.2), end: const Offset(1.0, 1.0));
                }),
              ),
              
              const SizedBox(height: 50),
              
              // Keypad
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox.shrink(); // Empty space
                    if (index == 11) {
                      return _buildKeypadButton(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                      );
                    }
                    int number = index == 10 ? 0 : index + 1;
                    return _buildKeypadButton(
                      text: number.toString(),
                      onTap: () => _onKeyPress(number.toString()),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton({String? text, IconData? icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        splashColor: AppTheme.accentCyan.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cardColor,
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: text != null
                ? Text(text, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600))
                : Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
