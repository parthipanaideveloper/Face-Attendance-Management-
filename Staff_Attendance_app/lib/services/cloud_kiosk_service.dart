import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/core/widgets/app_expired_screen.dart';
import 'package:staff_attendance_app/database/db_helper.dart';

class CloudKioskService {
  static final CloudKioskService _instance = CloudKioskService._internal();
  factory CloudKioskService() => _instance;
  CloudKioskService._internal();

  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot>? _configSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void initialize() {
    _startHeartbeat();
    _listenToSuperAdminConfig();
  }

  void _startHeartbeat() {
    // Send a heartbeat every 10 minutes
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi);
        
        if (isOnline) {
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          await FirebaseFirestore.instance.collection('device_health').doc('kiosk_tablet').set({
            'last_heartbeat': FieldValue.serverTimestamp(),
            'app_version': packageInfo.version,
            'is_online': true,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint("Heartbeat error: $e");
      }
    });
  }

  void _listenToSuperAdminConfig() {
    _configSubscription = FirebaseFirestore.instance.collection('super_admin_config').doc('status').snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data();
        if (data != null) {
          String status = data['subscription_status'] ?? 'active';
          String message = data['lock_message'] ?? 'Subscription Expired. Please contact Diyantech.';
          bool requestWipe = data['request_wipe'] ?? false;
          String announcement = data['announcement'] ?? '';

          final prefs = await SharedPreferences.getInstance();

          // 1. Remote App Lock (Kill Switch)
          if (status == 'unpaid' || status == 'locked') {
             await prefs.setBool('is_remotely_locked', true);
             await prefs.setString('remote_lock_message', message);
             
             // Navigate to AppExpiredScreen instantly
             if (navigatorKey.currentState != null) {
               navigatorKey.currentState!.pushAndRemoveUntil(
                 MaterialPageRoute(builder: (_) => AppExpiredScreen(customMessage: message)),
                 (Route<dynamic> route) => false,
               );
             }
          } else {
             bool wasLocked = prefs.getBool('is_remotely_locked') ?? false;
             if (wasLocked) {
               await prefs.setBool('is_remotely_locked', false);
               // App must be restarted to restore state cleanly if it was unlocked.
             }
          }

          // 2. Remote Data Wipe
          if (requestWipe) {
             debugPrint("REMOTE WIPE TRIGGERED");
             final db = DatabaseHelper();
             await db.deleteAllStaffs(); // Deletes all Face Embeddings and Employee Data locally
             
             // Acknowledge wipe complete so it doesn't loop
             await FirebaseFirestore.instance.collection('super_admin_config').doc('status').update({
               'request_wipe': false,
               'last_wiped': FieldValue.serverTimestamp()
             });
          }

          // 3. Global Announcements
          if (announcement.isNotEmpty) {
             String lastAnnouncement = prefs.getString('last_announcement') ?? '';
             if (lastAnnouncement != announcement) {
               await prefs.setString('last_announcement', announcement);
               if (navigatorKey.currentState != null) {
                 showDialog(
                   context: navigatorKey.currentState!.overlay!.context,
                   builder: (context) => AlertDialog(
                     title: const Text("Announcement"),
                     content: Text(announcement),
                     actions: [
                       TextButton(onPressed: () => Navigator.pop(context), child: const Text("Dismiss"))
                     ],
                   ),
                 );
               }
             }
          }
        }
      }
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _configSubscription?.cancel();
  }
}
