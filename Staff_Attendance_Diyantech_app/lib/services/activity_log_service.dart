import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ActivityLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logActivity({
    required String eventType,
    required String description,
  }) async {
    try {
      await _firestore.collection('activity_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'event_type': eventType,
        'description': description,
        'local_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });
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
      description: 'Admin \$action: \$details',
    );
  }
}
