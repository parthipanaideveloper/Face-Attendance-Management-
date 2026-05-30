class AttendanceLog {
  final String? id;
  final String registerNo;
  final String date;
  final String inTime;
  final String outTime;
  final String status;
  final String? name; // Joined from Staff
  final String? dept; // Joined from Staff

  AttendanceLog({
    this.id,
    required this.registerNo,
    required this.date,
    required this.inTime,
    required this.outTime,
    required this.status,
    this.name,
    this.dept,
  });

  factory AttendanceLog.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AttendanceLog(
      id: docId,
      registerNo: map['register_no'] ?? '',
      date: map['date'] ?? '',
      inTime: map['in_time'] ?? '',
      outTime: map['out_time'] ?? '',
      status: map['status'] ?? 'Absent',
      name: map['name'],
      dept: map['dept'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'register_no': registerNo,
      'date': date,
      'in_time': inTime,
      'out_time': outTime,
      'status': status,
    };
  }
}
