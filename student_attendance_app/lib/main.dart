import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:student_attendance_app/screens/home_screen.dart';
import 'package:student_attendance_app/utils/theme.dart';
import 'package:student_attendance_app/services/ml_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
    await MLService().initialize();
  } catch (e) {
    print('Error during initialization: $e');
  }
  runApp(const AttendanceApp());
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
