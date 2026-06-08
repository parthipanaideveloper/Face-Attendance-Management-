import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/database/db_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});
