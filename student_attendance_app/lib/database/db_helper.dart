import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> insertStudent(Map<String, dynamic> student) async {
    String registerNo = student['register_no'];
    await _firestore.collection('students').doc(registerNo).set(student, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    QuerySnapshot snapshot = await _firestore.collection('students').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getStudentByRegisterNo(String registerNo) async {
    DocumentSnapshot doc = await _firestore.collection('students').doc(registerNo).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> logAttendance(String registerNo, String name, String dept) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String nowTime = DateFormat('hh:mm a').format(DateTime.now());

    QuerySnapshot existing = await _firestore
        .collection('attendance')
        .where('register_no', isEqualTo: registerNo)
        .where('date', isEqualTo: today)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _firestore.collection('attendance').add({
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
      String docId = existing.docs.first.id;
      var record = existing.docs.first.data() as Map<String, dynamic>;
      
      await _firestore.collection('attendance').doc(docId).update({
        'out_time': nowTime,
      });

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
    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .get();

    List<Map<String, dynamic>> result = [];
    for (var doc in attendanceSnapshot.docs) {
      var attData = doc.data() as Map<String, dynamic>;
      var studentData = await getStudentByRegisterNo(attData['register_no']);
      if (studentData != null) {
        attData['name'] = studentData['name'];
        attData['dept'] = studentData['dept'];
        attData['gender'] = studentData['gender'];
        result.add(attData);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendanceByMonth(String monthPrefix) async {
    // For Firestore, a simple prefix search requires startAt and endAt or just fetching and filtering
    // Fetching all for the month
    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: monthPrefix)
        .where('date', isLessThan: monthPrefix + 'z')
        .get();

    List<Map<String, dynamic>> result = [];
    for (var doc in attendanceSnapshot.docs) {
      var attData = doc.data() as Map<String, dynamic>;
      var studentData = await getStudentByRegisterNo(attData['register_no']);
      if (studentData != null) {
        attData['name'] = studentData['name'];
        attData['dept'] = studentData['dept'];
        attData['gender'] = studentData['gender'];
        result.add(attData);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    AggregateQuerySnapshot studentsQuery = await _firestore.collection('students').count().get();
    int totalStudents = studentsQuery.count ?? 0;

    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: today)
        .get();
        
    int presentToday = attendanceSnapshot.docs.length;
    int absentToday = totalStudents - presentToday;
    double rate = totalStudents > 0 ? (presentToday / totalStudents) * 100 : 0.0;

    Map<String, int> presentGender = {'Male': 0, 'Female': 0};
    
    for (var doc in attendanceSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      var student = await getStudentByRegisterNo(data['register_no']);
      if (student != null) {
        String gender = student['gender'] ?? '';
        if (gender == 'Male') presentGender['Male'] = presentGender['Male']! + 1;
        if (gender == 'Female') presentGender['Female'] = presentGender['Female']! + 1;
      }
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
    List<int> weeklyCounts = List.filled(6, 0); // Mon to Sat
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday - DateTime.monday;
    if (daysToSubtract < 0) daysToSubtract += 7;
    DateTime monday = now.subtract(Duration(days: daysToSubtract));

    for (int i = 0; i < 6; i++) {
      DateTime day = monday.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(day);
      
      AggregateQuerySnapshot countSnapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .count()
          .get();
          
      weeklyCounts[i] = countSnapshot.count ?? 0;
    }
    return weeklyCounts;
  }
}
