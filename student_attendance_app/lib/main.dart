import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:student_attendance_app/features/attendance/home_screen.dart';
import 'package:student_attendance_app/core/theme/app_theme.dart';
import 'package:student_attendance_app/services/ml_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Make sure you have run 'flutterfire configure'

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  runApp(const ProviderScope(child: AttendanceApp()));
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
