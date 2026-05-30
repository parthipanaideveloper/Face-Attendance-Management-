import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getDashboardAnalytics();
});

final dashboardWeeklyProvider = FutureProvider<List<int>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getWeeklyAttendanceCounts();
});
