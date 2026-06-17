import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:staff_attendance_app/services/email_service.dart';
import 'package:staff_attendance_app/services/activity_log_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  Timer? _emailTimer;
  bool _isSyncing = false;
  bool _isStarted = false;

  // Guard: never call Firestore if Firebase isn't ready
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  void startSyncListener() async {
    if (_isStarted) return; // prevent double-start
    _isStarted = true;

    if (!_firebaseReady) {
      debugPrint('[FirebaseSync] Firebase not ready — skipping sync listener.');
      return;
    }

    // ── Connectivity listener: sync when device comes online ────────────────
    // This is lightweight — just listens for network changes, no data loaded
    try {
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        if (results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi)) {
          debugPrint('[FirebaseSync] Online — scheduling sync in 5s.');
          ActivityLogService.logDeviceOnline();
          // Delay sync by 5s after network comes up to let the connection stabilise
          Future.delayed(const Duration(seconds: 5), syncOfflineData);
        }
      });
    } catch (e) {
      debugPrint('[FirebaseSync] Connectivity listener error: $e');
    }

    // ── Periodic sync every 30 minutes ──────────────────────────────────────
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      debugPrint('[FirebaseSync] 30-min auto sync.');
      syncOfflineData();
    });

    // ── Email timer every 1 minute ───────────────────────────────────────────
    _emailTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      EmailService.sendAttendanceSummaryEmail();
    });

    // ── REMOVED: Real-time Firestore snapshot listeners ─────────────────────
    // These were downloading ALL attendance + ALL students on startup,
    // causing the "UI not responding" ANR crash.
    // Data is now pulled on-demand via syncOfflineData() which is
    // triggered when online or every 30 minutes — safe and efficient.

    // Do an initial sync 10 seconds after start (let the app fully settle first)
    Future.delayed(const Duration(seconds: 10), syncOfflineData);
  }

  void stopSyncListener() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _emailTimer?.cancel();
    _isStarted = false;
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    if (!_firebaseReady) return;

    _isSyncing = true;
    debugPrint('[FirebaseSync] Starting sync...');

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Ensure column exists (safe no-op if already there)
      try {
        await db.execute(
            'ALTER TABLE attendance ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (_) {}

      // ── Push unsynced attendance records to Firebase ─────────────────────
      final unsyncedAttendance = await db.query('attendance',
          where: 'is_synced = ? OR is_synced IS NULL', whereArgs: [0]);

      if (unsyncedAttendance.isNotEmpty) {
        final instDoc = await dbHelper.institutionDoc;
        for (var record in unsyncedAttendance) {
          try {
            final id = record['id'] as int;
            final registerNo = record['register_no'] as String;
            final date = record['date'] as String;

            await instDoc
                .collection('attendance')
                .doc('$date-$registerNo')
                .set({
              'register_no': registerNo,
              'date': date,
              'in_time': record['in_time'],
              'out_time': record['out_time'],
              'status': record['status'],
              'synced_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            await db.update('attendance', {'is_synced': 1},
                where: 'id = ?', whereArgs: [id]);
          } catch (e) {
            debugPrint('[FirebaseSync] Failed to push record: $e');
          }
        }
        debugPrint(
            '[FirebaseSync] Pushed ${unsyncedAttendance.length} attendance records.');
      }

      // ── Push unsynced staff records to Firebase ──────────────────────────
      final unsyncedStaff = await db.query('students',
          where: 'is_synced = ? OR is_synced IS NULL', whereArgs: [0]);

      for (var staffRow in unsyncedStaff) {
        try {
          final regNo = staffRow['register_no'] as String;
          final dataStr = staffRow['data'] as String;
          final staffData = jsonDecode(dataStr);
          await (await dbHelper.institutionDoc)
              .collection('students')
              .doc(regNo)
              .set(staffData, SetOptions(merge: true));
          await db.update('students', {'is_synced': 1},
              where: 'register_no = ?', whereArgs: [regNo]);
        } catch (e) {
          debugPrint('[FirebaseSync] Failed to push staff: $e');
        }
      }

      // ── Pull latest data from Firebase ───────────────────────────────────
      debugPrint('[FirebaseSync] Pulling latest from Firebase...');
      await dbHelper.syncFromFirebase();
      debugPrint('[FirebaseSync] Sync complete.');
    } catch (e) {
      debugPrint('[FirebaseSync] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
