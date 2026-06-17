import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:camera/camera.dart';
import 'package:staff_attendance_app/features/admin/admin_dashboard.dart';
import 'package:staff_attendance_app/features/staff/staff_dashboard.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/widgets/app_expired_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/auth/login_screen.dart' as login;

import 'package:staff_attendance_app/services/firebase_sync_service.dart';
import 'package:staff_attendance_app/services/sms_scheduler_service.dart';
import 'package:staff_attendance_app/services/cloud_kiosk_service.dart';
import 'package:staff_attendance_app/services/activity_log_service.dart';
import 'package:staff_attendance_app/services/ml_service.dart';

// Global camera list — used by scanner_screen.dart and register_screen.dart
List<CameraDescription> cameras = [];

// Tracks whether background services have already been started
bool _servicesStarted = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('CameraError: $e');
  }
  await MLService().initialize();
  runApp(const ProviderScope(
    child: MainAppRoot(),
  ));
}

class MainAppRoot extends StatefulWidget {
  const MainAppRoot({super.key});

  @override
  State<MainAppRoot> createState() => _MainAppRootState();
}

class _MainAppRootState extends State<MainAppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    } else if (state == AppLifecycleState.paused) {
      ActivityLogService.logAppLifecycle('paused');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: AppTheme.lightTheme,
      navigatorKey: CloudKioskService().navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    // Extra yield to guarantee paint
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('[Main] Firebase init error: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    final bool isRemotelyLocked = prefs.getBool('is_remotely_locked') ?? false;
    final String remoteLockMessage = prefs.getString('remote_lock_message') ?? '';
    
    bool isExpired = isRemotelyLocked;
    if (!isExpired) {
      final expiryStr = prefs.getString('subscription_expiry_date');
      if (expiryStr != null) {
        try {
          isExpired = DateTime.now().isAfter(DateTime.parse(expiryStr));
        } catch (_) {}
      }
    }

    final bool isActivated = prefs.getString('institution_code') != null;
    final String? role = prefs.getString('role');
    final bool isLoggedIn = role != null;

    Widget nextScreen;
    if (isExpired) {
      nextScreen = AppExpiredScreen(customMessage: isRemotelyLocked ? remoteLockMessage : null);
    } else if (!isActivated || !isLoggedIn) {
      nextScreen = const login.LoginScreen();
    } else {
      if (role == 'admin') {
        nextScreen = const AdminDashboard();
      } else {
        nextScreen = const StaffDashboard();
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    }

    if (isLoggedIn && isActivated && !_servicesStarted) {
      await Future.delayed(const Duration(seconds: 2));
      _startBackgroundServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint, size: 80, color: Color(0xFF06B6D4)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF06B6D4)),
            SizedBox(height: 16),
            Text("Starting System...", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

void _startBackgroundServices() {
  if (_servicesStarted) return;
  _servicesStarted = true;

  Future.microtask(() async {
    await Future.delayed(const Duration(seconds: 0));
    try {
      FirebaseSyncService().startSyncListener();
    } catch (e) {
      debugPrint('FirebaseSyncService error: $e');
    }
  });

  Future.microtask(() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      SmsSchedulerService().startScheduler();
    } catch (e) {
      debugPrint('SmsSchedulerService error: $e');
    }
  });

  Future.microtask(() async {
    await Future.delayed(const Duration(seconds: 4));
    try {
      CloudKioskService().initialize();
    } catch (e) {
      debugPrint('CloudKioskService error: $e');
    }
  });
}

void startServicesAfterLogin() {
  if (_servicesStarted) return;
  Future.delayed(const Duration(seconds: 5), _startBackgroundServices);
}

