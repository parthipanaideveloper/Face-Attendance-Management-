import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  static Future<void> initDb() async {
    if (_db != null) return;
    String path = join(await getDatabasesPath(), 'attendance_local.db');
    _db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
           await db.execute('DROP TABLE IF EXISTS students');
           await db.execute('''
             CREATE TABLE students (
               register_no TEXT PRIMARY KEY,
               name TEXT,
               dept TEXT,
               gender TEXT,
               mobile_no TEXT,
               designation TEXT,
               salary REAL,
               lop_amount REAL,
               zone TEXT,
               assigned_class TEXT,
               image_path TEXT,
               embedding TEXT
             )
           ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students (
            register_no TEXT PRIMARY KEY,
            name TEXT,
            dept TEXT,
            gender TEXT,
            mobile_no TEXT,
            designation TEXT,
            salary REAL,
            lop_amount REAL,
            zone TEXT,
            assigned_class TEXT,
            image_path TEXT,
            embedding TEXT
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
            type TEXT
          )
        ''');
      },
    );
  }

  Database get db => _db!;

  Future<void> insertStaff(Map<String, dynamic> staff) async {
    Map<String, dynamic> localStaff = Map.from(staff);
    if (localStaff['embedding'] != null && localStaff['embedding'] is List) {
      localStaff['embedding'] = jsonEncode(localStaff['embedding']);
    }
    await db.insert('students', localStaff, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllStaffs() async {
    List<Map<String, dynamic>> maps = await db.query('students');
    return maps.map((m) {
      var staff = Map<String, dynamic>.from(m);
      if (staff['embedding'] != null && staff['embedding'] is String) {
        // Only decode if we want it as a List, but usually we just return it as string
        // Actually, we'll leave it as a string because scanner_screen expects string 
        // that it decodes itself (or we can just let it be).
      }
      return staff;
    }).toList();
  }

  Future<Map<String, dynamic>?> getStaffByRegisterNo(String registerNo) async {
    List<Map<String, dynamic>> maps = await db.query('students', where: 'register_no = ?', whereArgs: [registerNo]);
    if (maps.isNotEmpty) {
      var staff = Map<String, dynamic>.from(maps.first);
      return staff;
    }
    return null;
  }

  Future<void> updateStaff(Map<String, dynamic> staff) async {
    String registerNo = staff['register_no'];
    Map<String, dynamic> localStaff = Map.from(staff);
    if (localStaff['embedding'] != null && localStaff['embedding'] is List) {
      localStaff['embedding'] = jsonEncode(localStaff['embedding']);
    }
    await db.update('students', localStaff, where: 'register_no = ?', whereArgs: [registerNo]);
  }

  Future<void> deleteStaff(String registerNo) async {
    await db.delete('students', where: 'register_no = ?', whereArgs: [registerNo]);
  }

  Future<void> deleteAllStaffs() async {
    await db.delete('students');
  }

  Future<Map<String, dynamic>> logAttendance(String registerNo, String name, String dept) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String nowTime = DateFormat('hh:mm a').format(DateTime.now());

    String designation = 'Teaching Staff';
    var staffDoc = await getStaffByRegisterNo(registerNo);
    if (staffDoc != null) {
      designation = staffDoc['designation'] ?? 'Teaching Staff';
    }

    String status = 'Present';
    DateTime now = DateTime.now();
    int currentMinutes = now.hour * 60 + now.minute;
    
    final prefs = await SharedPreferences.getInstance();
    int teachingInLimit = prefs.getInt('teaching_in_limit') ?? (9 * 60 + 10);
    int nonTeachingInLimit = prefs.getInt('non_teaching_in_limit') ?? (9 * 60 + 40);
    
    int limitMinutes = designation == 'Teaching Staff' ? teachingInLimit : nonTeachingInLimit;
    
    if (currentMinutes > limitMinutes) {
      status = 'Late Entry';
    }

    List<Map<String, dynamic>> existing = await db.query('attendance',
        where: 'register_no = ? AND date = ?',
        whereArgs: [registerNo, today],
        limit: 1);

    if (existing.isEmpty) {
      await db.insert('attendance', {
        'register_no': registerNo,
        'date': today,
        'in_time': nowTime,
        'out_time': '',
        'status': status,
        'is_synced': 0
      });
      
      if (staffDoc != null) {
        final phone = staffDoc['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          SimSmsService.sendSms(phone, "Diyantech Solutions Pvt Ltd\\n\\nDear $name, your attendance is marked as $status (IN) at $nowTime.");
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
      int id = existing.first['id'] as int;
      var record = existing.first;
      await db.update('attendance', {'out_time': nowTime, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);

      if (staffDoc != null) {
        final phone = staffDoc['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          SimSmsService.sendSms(phone, "Diyantech Solutions Pvt Ltd\\n\\nDear $name, your attendance is marked OUT at $nowTime.");
        }
      }

      return {
        'name': name,
        'register_no': registerNo,
        'dept': dept,
        'in_time': record['in_time'],
        'out_time': nowTime,
        'status': record['status'] ?? status,
        'marked_type': 'OUT'
      };
    }
  }

  Future<void> logManualAttendance(String registerNo, String date, String status, String inTime, String outTime) async {
    List<Map<String, dynamic>> existing = await db.query('attendance',
        where: 'register_no = ? AND date = ?',
        whereArgs: [registerNo, date],
        limit: 1);

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
    List<Map<String, dynamic>> attendanceSnapshot = await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    List<Map<String, dynamic>> result = [];
    for (var attData in attendanceSnapshot) {
      var mutData = Map<String, dynamic>.from(attData);
      var staffData = await getStaffByRegisterNo(mutData['register_no']);
      if (staffData != null) {
        mutData['name'] = staffData['name'];
        mutData['dept'] = staffData['dept'];
        mutData['gender'] = staffData['gender'];
        mutData['salary'] = staffData['salary'];
        mutData['lop_amount'] = staffData['lop_amount'];
        result.add(mutData);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByDateRange(String startDate, String endDate) async {
    List<Map<String, dynamic>> attendanceSnapshot = await db.query('attendance',
        where: 'date >= ? AND date <= ?', whereArgs: [startDate, endDate]);
    List<Map<String, dynamic>> result = [];
    for (var attData in attendanceSnapshot) {
      var mutData = Map<String, dynamic>.from(attData);
      var staffData = await getStaffByRegisterNo(mutData['register_no']);
      if (staffData != null) {
        mutData['name'] = staffData['name'];
        mutData['dept'] = staffData['dept'];
        mutData['gender'] = staffData['gender'];
        mutData['salary'] = staffData['salary'];
        mutData['lop_amount'] = staffData['lop_amount'];
        result.add(mutData);
      }
    }
    result.sort((a, b) => b['date'].compareTo(a['date']));
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByMonth(String monthPrefix) async {
    List<Map<String, dynamic>> attendanceSnapshot = await db.query('attendance',
        where: 'date LIKE ?', whereArgs: ['$monthPrefix%']);
    List<Map<String, dynamic>> result = [];
    for (var attData in attendanceSnapshot) {
      var mutData = Map<String, dynamic>.from(attData);
      var staffData = await getStaffByRegisterNo(mutData['register_no']);
      if (staffData != null) {
        mutData['name'] = staffData['name'];
        mutData['dept'] = staffData['dept'];
        mutData['gender'] = staffData['gender'];
        mutData['salary'] = staffData['salary'];
        mutData['lop_amount'] = staffData['lop_amount'];
        result.add(mutData);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    int totalStaffs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students')) ?? 0;

    List<Map<String, dynamic>> attendanceSnapshot = await db.query('attendance', where: 'date = ?', whereArgs: [today]);
        
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
    List<Map<String, double>> teachingWeekly = List.generate(6, (index) => {'present': 0.0, 'absent': 0.0});
    List<Map<String, double>> nonTeachingWeekly = List.generate(6, (index) => {'present': 0.0, 'absent': 0.0});
    
    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    int daysToSubtract = now.weekday - DateTime.monday;
    if (daysToSubtract < 0) daysToSubtract += 7;
    DateTime monday = now.subtract(Duration(days: daysToSubtract));

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
      DateTime day = monday.add(Duration(days: i));
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
    await db.insert('schedules', {'date': date, 'type': type}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSchedule(String date) async {
    List<Map<String, dynamic>> docs = await db.query('schedules', where: 'date = ?', whereArgs: [date]);
    if (docs.isNotEmpty) {
      return docs.first['type'] as String?;
    }
    return null;
  }

  Future<Map<String, String>> getAllSchedules() async {
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
    var attendanceSnapshot = await db.query('attendance', where: 'date = ? AND status = ?', whereArgs: [today, 'Late Entry']);

    List<Map<String, dynamic>> result = [];
    for (var row in attendanceSnapshot) {
      var attData = Map<String, dynamic>.from(row);
      var staffData = await getStaffByRegisterNo(attData['register_no'] as String);
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
