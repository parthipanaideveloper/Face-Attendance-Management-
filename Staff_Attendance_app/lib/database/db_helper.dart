import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> insertStaff(Map<String, dynamic> staff) async {
    String registerNo = staff['register_no'];
    await _firestore.collection('students').doc(registerNo).set(staff, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getAllStaffs() async {
    QuerySnapshot snapshot = await _firestore.collection('students').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getStaffByRegisterNo(String registerNo) async {
    DocumentSnapshot doc = await _firestore.collection('students').doc(registerNo).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> updateStaff(Map<String, dynamic> staff) async {
    String registerNo = staff['register_no'];
    await _firestore.collection('students').doc(registerNo).update(staff);
  }

  Future<void> deleteStaff(String registerNo) async {
    await _firestore.collection('students').doc(registerNo).delete();
  }

  Future<void> deleteAllStaffs() async {
    QuerySnapshot snapshot = await _firestore.collection('students').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<Map<String, dynamic>> logAttendance(String registerNo, String name, String dept) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String nowTime = DateFormat('hh:mm a').format(DateTime.now());

    // Check designation to determine Late Entry
    String designation = 'Teaching Staff';
    DocumentSnapshot staffDoc = await _firestore.collection('students').doc(registerNo).get();
    if (staffDoc.exists) {
      final data = staffDoc.data() as Map<String, dynamic>;
      designation = data['designation'] ?? 'Teaching Staff';
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

    QuerySnapshot existing = await _firestore
        .collection('attendance')
        .where('register_no', isEqualTo: registerNo)
        .where('date', isEqualTo: today)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      // First scan of the day -> Mark IN
      await _firestore.collection('attendance').add({
        'register_no': registerNo,
        'date': today,
        'in_time': nowTime,
        'out_time': '', // Empty on first scan
        'status': status
      });
      
      if (staffDoc.exists) {
        final data = staffDoc.data() as Map<String, dynamic>;
        final phone = data['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          SimSmsService.sendSms(phone, "St.Mary's Matriculation Higher Secondary School Chinna Udayamuthur, Tirupattur\n\nDear $name, your attendance is marked as $status (IN) at $nowTime.");
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
      // Second scan of the day -> Mark OUT
      String docId = existing.docs.first.id;
      var record = existing.docs.first.data() as Map<String, dynamic>;
      
      await _firestore.collection('attendance').doc(docId).update({
        'out_time': nowTime,
      });

      if (staffDoc.exists) {
        final data = staffDoc.data() as Map<String, dynamic>;
        final phone = data['mobile_no'] ?? '';
        if (phone.isNotEmpty && name.isNotEmpty) {
          SimSmsService.sendSms(phone, "St.Mary's Matriculation Higher Secondary School Chinna Udayamuthur, Tirupattur\n\nDear $name, your attendance is marked OUT at $nowTime.");
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
    QuerySnapshot existing = await _firestore
        .collection('attendance')
        .where('register_no', isEqualTo: registerNo)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _firestore.collection('attendance').add({
        'register_no': registerNo,
        'date': date,
        'in_time': inTime,
        'out_time': outTime,
        'status': status
      });
    } else {
      String docId = existing.docs.first.id;
      await _firestore.collection('attendance').doc(docId).update({
        'in_time': inTime,
        'out_time': outTime,
        'status': status
      });
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
      var staffData = await getStaffByRegisterNo(attData['register_no']);
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
    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();

    List<Map<String, dynamic>> result = [];
    for (var doc in attendanceSnapshot.docs) {
      var attData = doc.data() as Map<String, dynamic>;
      var staffData = await getStaffByRegisterNo(attData['register_no']);
      if (staffData != null) {
        attData['name'] = staffData['name'];
        attData['dept'] = staffData['dept'];
        attData['gender'] = staffData['gender'];
        attData['salary'] = staffData['salary'];
        attData['lop_amount'] = staffData['lop_amount'];
        result.add(attData);
      }
    }
    // Sort by date descending
    result.sort((a, b) => b['date'].compareTo(a['date']));
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
      var staffData = await getStaffByRegisterNo(attData['register_no']);
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
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    AggregateQuerySnapshot staffsQuery = await _firestore.collection('students').count().get();
    int totalStaffs = staffsQuery.count ?? 0;

    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: today)
        .get();
        
    int presentToday = 0;
    Map<String, int> presentGender = {'Male': 0, 'Female': 0};
    
    for (var doc in attendanceSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      var staff = await getStaffByRegisterNo(data['register_no']);
      if (staff != null) {
        presentToday++;
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
      'today_attendance_rate': rate.toStringAsFixed(1),
      'present_gender': presentGender
    };
  }

  Future<List<Map<String, int>>> getWeeklyAttendanceCounts() async {
    List<Map<String, int>> weeklyData = List.generate(6, (index) => {'present': 0, 'absent': 0});
    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    int daysToSubtract = now.weekday - DateTime.monday;
    if (daysToSubtract < 0) daysToSubtract += 7;
    DateTime monday = now.subtract(Duration(days: daysToSubtract));

    AggregateQuerySnapshot staffsQuery = await _firestore.collection('students').count().get();
    int totalStaffs = staffsQuery.count ?? 0;

    for (int i = 0; i < 6; i++) {
      DateTime day = monday.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(day);
      
      AggregateQuerySnapshot countSnapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .count()
          .get();
          
      int present = countSnapshot.count ?? 0;
      if (present > totalStaffs) present = totalStaffs;
      int absent = totalStaffs - present;
      if (absent < 0) absent = 0;
      
      // Do not show absentees for future dates
      if (dateStr.compareTo(todayStr) > 0) {
        absent = 0;
      }
      
      weeklyData[i] = {'present': present, 'absent': absent};
    }
    return weeklyData;
  }

  // SCHEDULE MANAGEMENT
  Future<void> setSchedule(String date, String type) async {
    await _firestore.collection('schedules').doc(date).set({
      'date': date,
      'type': type, // e.g., 'Working Day', 'Non-Working Day', 'Special Day'
    }, SetOptions(merge: true));
  }

  Future<String?> getSchedule(String date) async {
    DocumentSnapshot doc = await _firestore.collection('schedules').doc(date).get();
    if (doc.exists) {
      return (doc.data() as Map<String, dynamic>)['type'] as String?;
    }
    return null;
  }

  Future<Map<String, String>> getAllSchedules() async {
    QuerySnapshot snapshot = await _firestore.collection('schedules').get();
    Map<String, String> schedules = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      schedules[doc.id] = data['type'] as String;
    }
    return schedules;
  }
}
