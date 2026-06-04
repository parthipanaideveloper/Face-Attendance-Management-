import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  final bool isDark;
  
  const AppFooter({super.key, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? Colors.transparent : Colors.transparent,
      child: const Text(
        "Powered By DiaynTech Solutions Pvt Ltd",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
