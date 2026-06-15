import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:intl/intl.dart';

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
        syncOfflineData();
      }
    });
    // Also try syncing immediately on startup
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
      final db = dbHelper.db;

      // Ensure the is_synced column exists (in case it wasn't created yet)
      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist, ignore
      }

      // Fetch all unsynced attendance records
      final unsyncedRecords = await db.query('attendance', where: 'is_synced = ? OR is_synced IS NULL', whereArgs: [0]);

      if (unsyncedRecords.isEmpty) {
        debugPrint("[FirebaseSync] No offline data to sync.");
        _isSyncing = false;
        return;
      }

      debugPrint("[FirebaseSync] Found ${unsyncedRecords.length} records to sync.");

      final firestore = FirebaseFirestore.instance;
      
      for (var record in unsyncedRecords) {
        final id = record['id'] as int;
        final registerNo = record['register_no'] as String;
        final date = record['date'] as String;
        
        // Push to Firestore
        await firestore.collection('attendance').doc('\${date}_\${registerNo}').set({
          'register_no': registerNo,
          'date': date,
          'in_time': record['in_time'],
          'out_time': record['out_time'],
          'status': record['status'],
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Mark as synced locally
        await db.update('attendance', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
      }

      debugPrint("[FirebaseSync] Successfully synced offline data.");

    } catch (e) {
      debugPrint("[FirebaseSync] Error syncing data: $e");
    } finally {
      _isSyncing = false;
    }
  }
}
