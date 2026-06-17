import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:staff_attendance_app/services/email_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DatabaseHelper {


  Future<String> get institutionCode async {
    final prefs = await SharedPreferences.getInstance();
    // Use a legacy code to ensure backwards compatibility for existing single-user data
    return prefs.getString('institution_code') ?? 'LEGACY-000000';
  }

  Future<DocumentReference> get institutionDoc async {
    String code = await institutionCode;
    return (await institutionDoc).collection('institutions').doc(code);
  }

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'attendance_system.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE students ADD COLUMN is_synced INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE schedules ADD COLUMN is_synced INTEGER DEFAULT 0');
          } catch (e) {}
        } else {
          await db.execute('DROP TABLE IF EXISTS students');
          await db.execute('DROP TABLE IF EXISTS attendance');
          await db.execute('DROP TABLE IF EXISTS schedules');
          await _createTables(db);
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE students (
        register_no TEXT PRIMARY KEY,
        data TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        register_no TEXT,
        date TEXT,
        in_time TEXT,
        out_time TEXT,
        status TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE schedules (
        date TEXT PRIMARY KEY,
        type TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> syncFromFirebase() async {
    final db = await database;
    final instDoc = await institutionDoc;

    var batch = db.batch();

    QuerySnapshot studentsSnap = await instDoc.collection('students').get();
    for (var doc in studentsSnap.docs) {
      batch.insert('students', {
        'register_no': doc.id,
        'data': jsonEncode(doc.data())
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    QuerySnapshot attSnap = await instDoc.collection('attendance').get();
    batch.delete('attendance');
    for (var doc in attSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      batch.insert('attendance', {
        'register_no': data['register_no'],
        'date': data['date'],
        'in_time': data['in_time'],
        'out_time': data['out_time'],
        'status': data['status']
      });
    }

    QuerySnapshot schSnap = await instDoc.collection('schedules').get();
    for (var doc in schSnap.docs) {
      var data = doc.data() as Map<String, dynamic>;
      batch.insert('schedules', {
        'date': doc.id,
        'type': data['type']
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<void> insertStaff(Map<String, dynamic> staff) async {
    final db = await database;
    String registerNo = staff['register_no'];
    await db.insert('students', {
      'register_no': registerNo,
      'data': jsonEncode(staff)
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    try {
      await (await institutionDoc).collection('students').doc(registerNo).set(staff, SetOptions(merge: true));
    } catch(e) {}
  }

  Future<List<Map<String, dynamic>>> getAllStaffs() async {
    final db = await database;
    final maps = await db.query('students');
    if (maps.isEmpty) return [];
    
    // Isolate decoding to prevent UI freezing
    return await compute(_decodeStaffsList, maps);
  }

  Future<Map<String, dynamic>?> getStaffByRegisterNo(String registerNo) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students', where: 'register_no = ?', whereArgs: [registerNo]);
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> updateStaff(Map<String, dynamic> staff) async {
    final db = await database;
    String registerNo = staff['register_no'];
    // Merge existing
    var existing = await getStaffByRegisterNo(registerNo);
    if (existing != null) {
      existing.addAll(staff);
      staff = existing;
    }
    await db.update('students', {'data': jsonEncode(staff)}, where: 'register_no = ?', whereArgs: [registerNo]);

    try {
      await (await institutionDoc).collection('students').doc(registerNo).set(staff, SetOptions(merge: true));
    } catch(e) {}
  }

  Future<void> deleteStaff(String registerNo) async {
    final db = await database;
    await db.delete('students', where: 'register_no = ?', whereArgs: [registerNo]);

    try {
      await (await institutionDoc).collection('students').doc(registerNo).delete();
    } catch(e) {}
  }

  Future<void> deleteAllStaffs() async {
    final db = await database;
    await db.delete('students');
  }

  Future<Map<String, dynamic>> logAttendance(String registerNo, String name, String dept) async {
    final db = await database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String nowTime = DateFormat('hh:mm a').format(DateTime.now());

    String designation = 'Teaching Staff';
    var staffData = await getStaffByRegisterNo(registerNo);
    if (staffData != null) {
      designation = staffData['designation'] ?? 'Teaching Staff';
    }

    String status = 'Present';
    DateTime now = DateTime.now();
    int currentMinutes = now.hour * 60 + now.minute;
    
    final prefs = await SharedPreferences.getInstance();
    int teachingInLimit = prefs.getInt('teaching_in_limit') ?? (9 * 60 + 10);
    int nonTeachingInLimit = prefs.getInt('non_teaching_in_limit') ?? (10 * 60);
    
    int limitMinutes = designation == 'Teaching Staff' ? teachingInLimit : nonTeachingInLimit;
    if (currentMinutes > limitMinutes) {
      status = 'Late Entry';
    }

    var existing = await db.query('attendance', where: 'register_no = ? AND date = ?', whereArgs: [registerNo, today], limit: 1);

    if (existing.isEmpty) {
      // Mark IN
      await db.insert('attendance', {
        'register_no': registerNo,
        'date': today,
        'in_time': nowTime,
        'out_time': '',
        'status': status,
        'is_synced': 0
      });

      try {
        (await institutionDoc).collection('attendance').doc('$today-$registerNo').set({
          'register_no': registerNo,
          'date': today,
          'in_time': nowTime,
          'out_time': '',
          'status': status
        }, SetOptions(merge: true));
      } catch(e) {}
      
      if (staffData != null) {
        final phone = staffData['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          // Instant IN SMS disabled to prevent hitting Android limit. 
          // Will be sent via Daily Summary.
        }
      }


      return {
        'name': name,
        'register_no': registerNo,
        'dept': dept,
        'in_time': nowTime,
        'out_time': '',
        'status': status,
        'marked_type': 'IN'
      };
    } else {
      // Mark OUT
      int id = existing.first['id'] as int;
      var record = existing.first;
      
      await db.update('attendance', {'out_time': nowTime, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);

      try {
        (await institutionDoc).collection('attendance').doc('$today-$registerNo').set({
          'out_time': nowTime,
        }, SetOptions(merge: true));
      } catch(e) {}

      if (staffData != null) {
        final phone = staffData['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          String inTime = (record['in_time'] as String?) ?? '';
          String msg = "St.Mary's Matriculation Higher Secondary School Chinna Udayamuthur, Tirupattur\n\nDear $name, your attendance is marked. Morning In Time: $inTime, Out Time: $nowTime";
          SimSmsService.sendSms(phone, msg);
        }
      }


      return {
        'name': name,
        'register_no': registerNo,
        'dept': dept,
        'in_time': record['in_time'] ?? '',
        'out_time': nowTime,
        'status': record['status'] ?? status,
        'marked_type': 'OUT'
      };
    }
  }

  Future<void> logManualAttendance(String registerNo, String date, String status, String inTime, String outTime) async {
    final db = await database;
    var existing = await db.query('attendance', where: 'register_no = ? AND date = ?', whereArgs: [registerNo, date], limit: 1);

    if (existing.isEmpty) {
      await db.insert('attendance', {
        'register_no': registerNo,
        'date': date,
        'in_time': inTime,
        'out_time': outTime,
        'status': status,
        'is_synced': 0
      });
    } else {
      int id = existing.first['id'] as int;
      await db.update('attendance', {
        'in_time': inTime,
        'out_time': outTime,
        'status': status,
        'is_synced': 0
      }, where: 'id = ?', whereArgs: [id]);
    }

  }

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    final db = await database;
    var attendanceSnapshot = await db.query('attendance', where: 'date = ?', whereArgs: [date]);

    List<Map<String, dynamic>> result = [];
    Set<String> processedRegisters = {};

    for (var row in attendanceSnapshot) {
      var attData = Map<String, dynamic>.from(row);
      String regNo = attData['register_no'] as String;
      
      if (processedRegisters.contains(regNo)) continue;
      processedRegisters.add(regNo);

      var staffData = await getStaffByRegisterNo(regNo);
      if (staffData != null) {
        attData['name'] = staffData['name'];
        attData['dept'] = staffData['dept'];
        attData['gender'] = staffData['gender'];
        attData['salary'] = staffData['salary'];
        attData['lop_amount'] = staffData['lop_amount'];
        result.add(attData);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByDateRange(String startDate, String endDate) async {
    final db = await database;
    var attendanceSnapshot = await db.query('attendance', where: 'date >= ? AND date <= ?', whereArgs: [startDate, endDate]);

    List<Map<String, dynamic>> result = [];
    for (var row in attendanceSnapshot) {
      var attData = Map<String, dynamic>.from(row);
      var staffData = await getStaffByRegisterNo(attData['register_no'] as String);
      if (staffData != null) {
        attData['name'] = staffData['name'];
        attData['dept'] = staffData['dept'];
        attData['gender'] = staffData['gender'];
        attData['salary'] = staffData['salary'];
        attData['lop_amount'] = staffData['lop_amount'];
        result.add(attData);
      }
    }
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByMonth(String monthPrefix) async {
    final db = await database;
    var attendanceSnapshot = await db.query('attendance', where: 'date LIKE ?', whereArgs: ['$monthPrefix%']);

    List<Map<String, dynamic>> result = [];
    for (var row in attendanceSnapshot) {
      var attData = Map<String, dynamic>.from(row);
      var staffData = await getStaffByRegisterNo(attData['register_no'] as String);
      if (staffData != null) {
        attData['name'] = staffData['name'];
        attData['dept'] = staffData['dept'];
        attData['gender'] = staffData['gender'];
        attData['salary'] = staffData['salary'];
        attData['lop_amount'] = staffData['lop_amount'];
        result.add(attData);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    final db = await database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    var countResult = await db.rawQuery('SELECT COUNT(*) FROM students');
    int totalStaffs = Sqflite.firstIntValue(countResult) ?? 0;

    var attendanceSnapshot = await db.query('attendance', where: 'date = ?', whereArgs: [today]);
        
    int presentToday = 0;
    int lateToday = 0;
    Map<String, int> presentGender = {'Male': 0, 'Female': 0};
    
    for (var row in attendanceSnapshot) {
      var staff = await getStaffByRegisterNo(row['register_no'] as String);
      if (staff != null) {
        presentToday++;
        if (row['status'] == 'Late Entry') lateToday++;
        String gender = staff['gender'] ?? '';
        if (gender == 'Male') presentGender['Male'] = presentGender['Male']! + 1;
        if (gender == 'Female') presentGender['Female'] = presentGender['Female']! + 1;
      }
    }

    if (presentToday > totalStaffs) presentToday = totalStaffs;
    int absentToday = totalStaffs - presentToday;
    if (absentToday < 0) absentToday = 0;
    double rate = totalStaffs > 0 ? (presentToday / totalStaffs) * 100 : 0.0;

    return {
      'total_staffs': totalStaffs,
      'present_today': presentToday,
      'absent_today': absentToday,
      'late_today': lateToday,
      'today_attendance_rate': rate.toStringAsFixed(1),
      'present_gender': presentGender
    };
  }

  Future<Map<String, dynamic>> getWeeklyAttendanceCounts() async {
    final db = await database;
    List<Map<String, double>> teachingWeekly = List.generate(6, (index) => {'present': 0.0, 'absent': 0.0});
    List<Map<String, double>> nonTeachingWeekly = List.generate(6, (index) => {'present': 0.0, 'absent': 0.0});
    
    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Look back exactly 5 days from today (so we get 6 days total: 5 past days + today)
    DateTime startDay = now.subtract(Duration(days: 5));

    final staffs = await getAllStaffs();
    int totalTeaching = 0;
    int totalNonTeaching = 0;
    
    for (var s in staffs) {
      String regNo = (s['register_no'] ?? '').toUpperCase();
      if (regNo.startsWith('SMSNS')) {
        totalNonTeaching++;
      } else {
        totalTeaching++;
      }
    }

    for (int i = 0; i < 6; i++) {
      DateTime day = startDay.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(day);
      
      var res = await db.rawQuery('SELECT register_no FROM attendance WHERE date = ?', [dateStr]);
      int presentTeaching = 0;
      int presentNonTeaching = 0;
      
      for (var row in res) {
        String regNo = (row['register_no'] as String).toUpperCase();
        if (regNo.startsWith('SMSNS')) {
          presentNonTeaching++;
        } else {
          presentTeaching++;
        }
      }
      
      if (presentTeaching > totalTeaching) presentTeaching = totalTeaching;
      if (presentNonTeaching > totalNonTeaching) presentNonTeaching = totalNonTeaching;
      
      int absentTeaching = totalTeaching - presentTeaching;
      if (absentTeaching < 0) absentTeaching = 0;
      
      int absentNonTeaching = totalNonTeaching - presentNonTeaching;
      if (absentNonTeaching < 0) absentNonTeaching = 0;
      
      if (dateStr.compareTo(todayStr) > 0) {
        absentTeaching = 0;
        absentNonTeaching = 0;
      }
      
      double teachingPresentPct = totalTeaching > 0 ? (presentTeaching / totalTeaching) * 100 : 0.0;
      double teachingAbsentPct = totalTeaching > 0 && dateStr.compareTo(todayStr) <= 0 ? (absentTeaching / totalTeaching) * 100 : 0.0;
      
      double nonTeachingPresentPct = totalNonTeaching > 0 ? (presentNonTeaching / totalNonTeaching) * 100 : 0.0;
      double nonTeachingAbsentPct = totalNonTeaching > 0 && dateStr.compareTo(todayStr) <= 0 ? (absentNonTeaching / totalNonTeaching) * 100 : 0.0;

      teachingWeekly[i] = {'present': teachingPresentPct, 'absent': teachingAbsentPct};
      nonTeachingWeekly[i] = {'present': nonTeachingPresentPct, 'absent': nonTeachingAbsentPct};
    }
    
    return {
      'teaching': teachingWeekly,
      'non_teaching': nonTeachingWeekly,
    };
  }

  Future<void> setSchedule(String date, String type) async {
    final db = await database;
    await db.insert('schedules', {
      'date': date,
      'type': type
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSchedule(String date) async {
    final db = await database;
    var res = await db.query('schedules', where: 'date = ?', whereArgs: [date], limit: 1);
    if (res.isNotEmpty) {
      return res.first['type'] as String?;
    }
    return null;
  }

  Future<Map<String, String>> getAllSchedules() async {
    final db = await database;
    var res = await db.query('schedules');
    Map<String, String> schedules = {};
    for (var row in res) {
      schedules[row['date'] as String] = row['type'] as String;
    }
    return schedules;
  }

  Future<List<Map<String, dynamic>>> getTodayPresentStaffs() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await getAttendanceByDate(today);
  }

  Future<List<Map<String, dynamic>>> getTodayLateStaffs() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await database;
    var attendanceSnapshot = await db.query('attendance', where: 'date = ? AND status = ?', whereArgs: [today, 'Late Entry']);

    List<Map<String, dynamic>> result = [];
    Set<String> processedRegisters = {};
    for (var row in attendanceSnapshot) {
      var attData = Map<String, dynamic>.from(row);
      String regNo = attData['register_no'] as String;

      if (processedRegisters.contains(regNo)) continue;
      processedRegisters.add(regNo);

      var staffData = await getStaffByRegisterNo(regNo);
      if (staffData != null) {
        attData['name'] = staffData['name'];
        attData['dept'] = staffData['dept'];
        result.add(attData);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTodayAbsentStaffs() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await database;
    var attendanceSnapshot = await db.query('attendance', where: 'date = ?', whereArgs: [today]);
    Set<String> presentRegNos = {};
    for (var row in attendanceSnapshot) {
      presentRegNos.add(row['register_no'] as String);
    }
    
    final allStaffs = await getAllStaffs();
    List<Map<String, dynamic>> absentStaffs = [];
    for (var staff in allStaffs) {
      if (!presentRegNos.contains(staff['register_no'])) {
        absentStaffs.add(staff);
      }
    }
    return absentStaffs;
  }
}

// Top-level function for isolate
List<Map<String, dynamic>> _decodeStaffsList(List<Map<String, Object?>> maps) {
  List<Map<String, dynamic>> results = [];
  for (var map in maps) {
    results.add(jsonDecode(map['data'] as String) as Map<String, dynamic>);
  }
  return results;
}
