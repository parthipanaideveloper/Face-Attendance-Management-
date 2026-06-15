import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:staff_attendance_app/features/attendance/home_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/widgets/app_expired_screen.dart';
import 'package:staff_attendance_app/services/ml_service.dart';
import 'package:staff_attendance_app/database/db_helper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:staff_attendance_app/firebase_options.dart';
import 'package:staff_attendance_app/services/firebase_sync_service.dart';
import 'package:staff_attendance_app/services/activity_log_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseSyncService().startSyncListener();
    cameras = await availableCameras();
    await DatabaseHelper.initDb();
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

class AttendanceApp extends StatefulWidget {
  final bool isExpired;
  const AttendanceApp({super.key, required this.isExpired});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ActivityLogService.logAppLifecycle('resumed (Opened)');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ActivityLogService.logAppLifecycle('resumed (Opened)');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ActivityLogService.logAppLifecycle(state.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: AppTheme.darkTheme,
      home: widget.isExpired ? const AppExpiredScreen() : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
