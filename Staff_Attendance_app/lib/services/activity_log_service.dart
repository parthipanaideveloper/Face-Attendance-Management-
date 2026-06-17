import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ActivityLogService {
  // Guard: never access Firestore if Firebase isn't initialized
  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  static Future<void> logActivity({
    required String eventType,
    required String description,
  }) async {
    if (!_firebaseReady) return; // silently skip if Firebase not ready
    try {
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'event_type': eventType,
        'description': description,
        'local_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      }).timeout(const Duration(seconds: 5)); // never block more than 5s
      debugPrint("[ActivityLog] Logged: $eventType - $description");
    } catch (e) {
      debugPrint("[ActivityLog] Failed to log: $e");
    }
  }

  static Future<void> logAppLifecycle(String state) async {
    await logActivity(
      eventType: 'APP_LIFECYCLE',
      description: 'App transitioned to $state',
    );
  }

  static Future<void> logDeviceOnline() async {
    await logActivity(
      eventType: 'DEVICE_ONLINE',
      description: 'Tablet reconnected to Network/Wi-Fi',
    );
  }

  static Future<void> logAdminAction(String action, String details) async {
    await logActivity(
      eventType: 'ADMIN_ACTION',
      description: 'Admin $action: $details',
    );
  }
}
