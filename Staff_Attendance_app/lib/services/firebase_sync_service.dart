import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:staff_attendance_app/services/email_service.dart';
import 'package:staff_attendance_app/services/activity_log_service.dart'; // NEW
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  void startSyncListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        debugPrint("[FirebaseSync] Device is online. Attempting to sync...");
        ActivityLogService.logDeviceOnline(); // NEW
        syncOfflineData();
      }
    });

    // Auto-sync every 30 minutes in the background so the user never has to click the button manually
    Timer.periodic(const Duration(minutes: 30), (timer) {
      debugPrint("[FirebaseSync] Running automatic 30-minute background sync...");
      syncOfflineData();
    });

    // 1-Minute Timer to check if it's time to send the Automated Email (10:30 AM or 7:00 PM)
    Timer.periodic(const Duration(minutes: 1), (timer) {
      EmailService.sendAttendanceSummaryEmail();
    });

    // Real-time listener: Instantly updates this device when ANY other device pushes an attendance scan to Firebase
    FirebaseFirestore.instance.collection('attendance').snapshots().listen((snapshot) async {
      try {
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
            var data = doc.doc.data();
            if (data != null && data.containsKey('register_no') && data.containsKey('date')) {
              var registerNo = data['register_no'];
              var date = data['date'];
              var inTime = data['in_time'] ?? '';
              var outTime = data['out_time'] ?? '';
              var status = data['status'] ?? '';
              
              var existing = await db.query('attendance', where: 'register_no = ? AND date = ?', whereArgs: [registerNo, date], limit: 1);
              if (existing.isEmpty) {
                await db.insert('attendance', {
                  'register_no': registerNo,
                  'date': date,
                  'in_time': inTime,
                  'out_time': outTime,
                  'status': status,
                  'is_synced': 1
                });
              } else {
                // If local is_synced=0, it means we have local offline data that hasn't been pushed yet. 
                // We shouldn't overwrite it until it's pushed. But if is_synced=1, we can overwrite safely.
                if (existing.first['is_synced'] == 1 || existing.first['is_synced'] == null) {
                  await db.update('attendance', {
                    'in_time': inTime,
                    'out_time': outTime,
                    'status': status,
                    'is_synced': 1
                  }, where: 'id = ?', whereArgs: [existing.first['id']]);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error in realtime sync: $e");
      }
    });

    // Real-time listener: Instantly updates this device when ANY other device registers or edits a staff member
    FirebaseFirestore.instance.collection('students').snapshots().listen((snapshot) async {
      try {
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
            await db.insert('students', {
              'register_no': doc.doc.id,
              'data': jsonEncode(doc.doc.data())
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } catch (e) {
        debugPrint("Error syncing students realtime: $e");
      }
    });

    // Try on start
    syncOfflineData();
  }

  void stopSyncListener() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore if exists
      }

      final unsyncedRecords = await db.query('attendance', where: 'is_synced = ? OR is_synced IS NULL', whereArgs: [0]);

      if (unsyncedRecords.isNotEmpty) {
        final firestore = FirebaseFirestore.instance;
        for (var record in unsyncedRecords) {
          final id = record['id'] as int;
          final registerNo = record['register_no'] as String;
          final date = record['date'] as String;
          
          await firestore.collection('attendance').doc('\${date}-\${registerNo}').set({
            'register_no': registerNo,
            'date': date,
            'in_time': record['in_time'],
            'out_time': record['out_time'],
            'status': record['status'],
            'synced_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await db.update('attendance', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
        }
        debugPrint("[FirebaseSync] Successfully pushed offline data up.");
      }

      // Also ensure all local staffs are pushed to Firebase to prevent lost registrations
      final allLocalStaffs = await db.query('students');
      for (var staffRow in allLocalStaffs) {
        final regNo = staffRow['register_no'] as String;
        final dataStr = staffRow['data'] as String;
        try {
          final staffData = jsonDecode(dataStr);
          await FirebaseFirestore.instance.collection('students').doc(regNo).set(staffData, SetOptions(merge: true));
        } catch(e) {}
      }

      // Automatically pull down the latest data from Firebase (so Admin doesn't have to manually click Sync)
      debugPrint("[FirebaseSync] Pulling latest data down from Firebase...");
      await dbHelper.syncFromFirebase();
      debugPrint("[FirebaseSync] Successfully pulled latest data.");

    } catch (e) {
      debugPrint("[FirebaseSync] Error syncing data: $e");
    } finally {
      _isSyncing = false;
    }
  }
}
