import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'attendance_system.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        register_no TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        dept TEXT NOT NULL,
        gender TEXT NOT NULL,
        image_path TEXT NOT NULL,
        embedding TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        register_no TEXT NOT NULL,
        date TEXT NOT NULL,
        in_time TEXT,
        out_time TEXT,
        status TEXT,
        FOREIGN KEY(register_no) REFERENCES students(register_no)
      )
    ''');
  }

  Future<int> insertStudent(Map<String, dynamic> student) async {
    Database db = await database;
    return await db.insert('students', student, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    Database db = await database;
    return await db.query('students');
  }

  Future<Map<String, dynamic>?> getStudentByRegisterNo(String registerNo) async {
    Database db = await database;
    List<Map<String, dynamic>> res = await db.query('students', where: 'register_no = ?', whereArgs: [registerNo]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<Map<String, dynamic>> logAttendance(String registerNo, String name, String dept) async {
    Database db = await database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String nowTime = DateFormat('hh:mm a').format(DateTime.now());

    List<Map<String, dynamic>> existing = await db.query(
      'attendance',
      where: 'register_no = ? AND date = ?',
      whereArgs: [registerNo, today],
    );

    if (existing.isEmpty) {
      await db.insert('attendance', {
        'register_no': registerNo,
        'date': today,
        'in_time': nowTime,
        'out_time': nowTime,
        'status': 'Present'
      });
      return {
        'name': name,
        'register_no': registerNo,
        'dept': dept,
        'in_time': nowTime,
        'out_time': nowTime,
        'status': 'Present'
      };
    } else {
      await db.update(
        'attendance',
        {'out_time': nowTime},
        where: 'register_no = ? AND date = ?',
        whereArgs: [registerNo, today],
      );
      var record = existing.first;
      return {
        'name': name,
        'register_no': registerNo,
        'dept': dept,
        'in_time': record['in_time'],
        'out_time': nowTime,
        'status': 'Present'
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT a.*, s.name, s.dept, s.gender 
      FROM attendance a 
      JOIN students s ON a.register_no = s.register_no 
      WHERE a.date = ?
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getAttendanceByMonth(String monthPrefix) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT a.*, s.name, s.dept, s.gender 
      FROM attendance a 
      JOIN students s ON a.register_no = s.register_no 
      WHERE a.date LIKE ?
    ''', ['$monthPrefix%']);
  }

  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    Database db = await database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    var totalRes = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    int totalStudents = Sqflite.firstIntValue(totalRes) ?? 0;

    var presentRes = await db.rawQuery('SELECT COUNT(*) as count FROM attendance WHERE date = ?', [today]);
    int presentToday = Sqflite.firstIntValue(presentRes) ?? 0;

    int absentToday = totalStudents - presentToday;
    double rate = totalStudents > 0 ? (presentToday / totalStudents) * 100 : 0.0;

    var genderRes = await db.rawQuery('''
      SELECT s.gender, COUNT(a.id) as count 
      FROM attendance a 
      JOIN students s ON a.register_no = s.register_no 
      WHERE a.date = ? 
      GROUP BY s.gender
    ''', [today]);

    Map<String, int> presentGender = {'Male': 0, 'Female': 0};
    for (var row in genderRes) {
      if (row['gender'] == 'Male') presentGender['Male'] = row['count'] as int;
      if (row['gender'] == 'Female') presentGender['Female'] = row['count'] as int;
    }

    return {
      'total_students': totalStudents,
      'present_today': presentToday,
      'absent_today': absentToday,
      'today_attendance_rate': rate.toStringAsFixed(1),
      'present_gender': presentGender
    };
  }

  Future<List<int>> getWeeklyAttendanceCounts() async {
    Database db = await database;
    List<int> weeklyCounts = List.filled(6, 0); // Mon to Sat
    DateTime now = DateTime.now();
    // Find most recent Monday
    int daysToSubtract = now.weekday - DateTime.monday;
    if (daysToSubtract < 0) daysToSubtract += 7;
    DateTime monday = now.subtract(Duration(days: daysToSubtract));

    for (int i = 0; i < 6; i++) {
      DateTime day = monday.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(day);
      var res = await db.rawQuery('SELECT COUNT(*) as count FROM attendance WHERE date = ?', [dateStr]);
      weeklyCounts[i] = Sqflite.firstIntValue(res) ?? 0;
    }
    return weeklyCounts;
  }
}
