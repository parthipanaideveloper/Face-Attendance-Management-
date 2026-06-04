import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:staff_attendance_app/features/attendance/home_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/widgets/app_expired_screen.dart';
import 'package:staff_attendance_app/services/ml_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Make sure you have run 'flutterfire configure'

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await MLService().initialize();
  } catch (e) {
    print('Error during initialization: $e');
  }
  
  final prefs = await SharedPreferences.getInstance();
  String? installTimeStr = prefs.getString('install_time');
  String? subscriptionExpiryStr = prefs.getString('subscription_expiry_date');
  
  bool isExpired = false;
  
  if (subscriptionExpiryStr != null) {
      // Super Admin explicitly set a subscription expiry date
      DateTime expiryDate = DateTime.parse(subscriptionExpiryStr);
      isExpired = DateTime.now().isAfter(expiryDate);
  } else {
      // Default to 90-days trial logic
      if (installTimeStr == null) {
         installTimeStr = DateTime.now().toIso8601String();
         await prefs.setString('install_time', installTimeStr);
      }
      
      DateTime installTime = DateTime.parse(installTimeStr);
      DateTime expiryTime = installTime.add(const Duration(days: 90));
      isExpired = DateTime.now().isAfter(expiryTime);
  }

  runApp(ProviderScope(child: AttendanceApp(isExpired: isExpired)));
}

class AttendanceApp extends StatelessWidget {
  final bool isExpired;
  const AttendanceApp({super.key, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: AppTheme.darkTheme,
      home: isExpired ? const AppExpiredScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
