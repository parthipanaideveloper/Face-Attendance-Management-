import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_attendance_app/database/db_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});
