import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_attendance_app/features/admin/providers/dashboard_provider.dart';
import 'package:student_attendance_app/features/admin/admin_settings_screen.dart';
import 'package:student_attendance_app/features/admin/reports_screen.dart';
import 'package:student_attendance_app/core/theme/app_theme.dart';
import 'package:student_attendance_app/core/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _exportAndShareCSV(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    try {
      final db = ref.read(databaseProvider);
      final records = await db.getAttendanceByMonth(monthStr);
      String csv = "Date,Name,RegNo,Dept,InTime,OutTime,Status,Hours,Salary\n";
      for (var r in records) {
        double hours = 0;
        if (r['in_time'] != null && r['out_time'] != null) {
          try {
             final inFormat = DateFormat("hh:mm a").parse(r['in_time']);
             final outFormat = DateFormat("hh:mm a").parse(r['out_time']);
             hours = outFormat.difference(inFormat).inMinutes / 60.0;
             if (hours < 0) hours += 24;
          } catch(e) {}
        }
        final salary = hours * 12.0; // Hourly wage
        csv += "${r['date']},${r['name']},${r['register_no']},${r['dept']},${r['in_time']},${r['out_time'] ?? '--:--:--'},${r['status']},${hours.toStringAsFixed(2)},\$${salary.toStringAsFixed(2)}\n";
      }
      
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/report_$monthStr.csv";
      final file = File(path);
      await file.writeAsString(csv);
      Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Attendance Report for $monthStr');
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e")));
    }
  }

  void _openChartScreen(BuildContext context, List<int> weeklyData, Map<String, dynamic> analytics) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      int total = analytics['total_students'] ?? 0;
      double maxY = total.toDouble();
      if (maxY < 6) maxY = 6.0;

      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        appBar: AppBar(
          title: const Text("Weekly Attendance", style: TextStyle(color: Colors.white)), 
          backgroundColor: AppTheme.cardColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14);
                          String text;
                          switch (value.toInt()) {
                            case 0: text = 'Mon'; break;
                            case 1: text = 'Tue'; break;
                            case 2: text = 'Wed'; break;
                            case 3: text = 'Thu'; break;
                            case 4: text = 'Fri'; break;
                            case 5: text = 'Sat'; break;
                            default: text = ''; break;
                          }
                          return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, 
                        reservedSize: 40, // Increased for tablets to prevent overlap
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                           return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 12));
                        }
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(6, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weeklyData[i].toDouble(),
                          gradient: const LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentEmerald], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          width: 26, // Slightly wider for better visibility on tablets
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        )
                      ],
                    );
                  }),
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ),
      );
    }));
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final weeklyAsync = ref.watch(dashboardWeeklyProvider);

    return Container(
      color: AppTheme.bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Admin Dashboard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  SizedBox(height: 4),
                  Text("Welcome back, Super Admin", style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
              Container(
                height: 50, width: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardColor,
                  border: Border.all(color: AppTheme.accentCyan, width: 2),
                ),
                child: const Icon(Icons.shield, color: AppTheme.accentCyan),
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
          
          const SizedBox(height: 30),
          
          // Stats row
          statsAsync.when(
            data: (stats) {
              return Row(
                children: [
                  Expanded(child: _buildStatCard("Total Staff", stats['total_students'].toString(), Icons.people, AppTheme.accentCyan)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard("Present Today", stats['present_today'].toString(), Icons.check_circle, AppTheme.accentEmerald)),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
            error: (err, stack) => Text("Error loading stats: $err", style: const TextStyle(color: Colors.redAccent)),
          ),
          
          const SizedBox(height: 30),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _buildMenuCard("Analytical Chart", Icons.bar_chart, AppTheme.accentEmerald, () {
                  weeklyAsync.whenData((weekly) {
                     statsAsync.whenData((stats) {
                         _openChartScreen(context, weekly, stats);
                     });
                  });
                }).animate().fadeIn(delay: 300.ms).scale(),
                _buildMenuCard("Live View Reports", Icons.receipt_long, Colors.orangeAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
                }).animate().fadeIn(delay: 400.ms).scale(),
                _buildMenuCard("Export & Share", Icons.ios_share, AppTheme.accentCyan, () => _exportAndShareCSV(context, ref)).animate().fadeIn(delay: 500.ms).scale(),
                _buildMenuCard("Admin Settings", Icons.admin_panel_settings, Colors.purpleAccent, () async {
                  final LocalAuthentication auth = LocalAuthentication();
                  bool authenticated = false;
                  try {
                    authenticated = await auth.authenticate(
                      localizedReason: 'Authenticate to access Admin Settings',
                      options: const AuthenticationOptions(stickyAuth: true),
                    );
                  } catch (e) { print(e); }
                  if (authenticated && context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
                  }
                }).animate().fadeIn(delay: 600.ms).scale(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }
}
