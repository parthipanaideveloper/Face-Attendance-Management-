import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_attendance_app/database/db_helper.dart';
import 'package:student_attendance_app/screens/admin_settings_screen.dart';
import 'package:student_attendance_app/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _analytics = {'total_students': 0, 'present_today': 0, 'late_today': 0, 'absent_today': 0};
  List<Map<String, dynamic>> _todayRecords = [];
  bool _loading = true;
  final double hourlyWage = 12.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    _todayRecords = await DatabaseHelper().getAttendanceByDate(dateStr);
    _analytics = await DatabaseHelper().getDashboardAnalytics();
    setState(() => _loading = false);
  }

  Future<void> _exportAndShareCSV() async {
    final now = DateTime.now();
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    try {
      final records = await DatabaseHelper().getAttendanceByMonth(monthStr);
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
        final salary = hours * hourlyWage;
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

  void _openChartScreen() async {
    setState(() => _loading = true);
    List<int> weeklyData = await DatabaseHelper().getWeeklyAttendanceCounts();
    setState(() => _loading = false);
    if (!mounted) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) {
      int total = _analytics['total_students'] ?? 0;
      double maxY = total.toDouble();
      if (maxY < 6) maxY = 6.0;

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Weekly Attendance", style: TextStyle(color: Colors.black87)), 
          backgroundColor: Colors.grey[100],
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      const style = TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14);
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
                    reservedSize: 28, 
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                       return Text(value.toInt().toString(), style: const TextStyle(color: Colors.black54, fontSize: 12));
                    }
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey[300], strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(6, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: weeklyData[i].toDouble(),
                      color: AppTheme.accentEmerald,
                      width: 22,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                    )
                  ],
                );
              }),
            ),
          ),
        ),
      );
    }));
  }

  void _openReportsScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Live View Reports", style: TextStyle(color: Colors.black87)), 
          backgroundColor: Colors.grey[100],
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _todayRecords.length,
          itemBuilder: (ctx, i) {
            final r = _todayRecords[i];
            String salaryTxt = "";
            if (r['in_time'] != null && r['out_time'] != null) {
              try {
                final inF = DateFormat("hh:mm a").parse(r['in_time']);
                final outF = DateFormat("hh:mm a").parse(r['out_time']);
                double hrs = outF.difference(inF).inMinutes / 60.0;
                if(hrs < 0) hrs += 24;
                salaryTxt = " | \$${(hrs * hourlyWage).toStringAsFixed(2)}";
              } catch(e) {}
            }
            return Card(
              color: Colors.grey[50], margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(backgroundColor: r['status'] == 'Late' ? Colors.orange : AppTheme.accentEmerald, child: const Icon(Icons.person, color: Colors.white)),
                title: Text(r['name'], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: Text("In: ${r['in_time']} - Out: ${r['out_time'] ?? '--:--'}\n${r['status']}$salaryTxt", style: const TextStyle(color: Colors.black54)),
              ),
            );
          },
        ),
      );
    }));
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 15),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
    
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              height: 100, width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.accentCyan.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.5), width: 2),
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Image.asset('assets/tech_logo.png', fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.business, color: AppTheme.accentCyan, size: 60)),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Admin Dashboard", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 40),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _buildMenuCard("Analytical Chart", Icons.pie_chart, AppTheme.accentEmerald, _openChartScreen),
                _buildMenuCard("Live View Reports", Icons.list_alt, Colors.orange, _openReportsScreen),
                _buildMenuCard("Export & Share", Icons.share, AppTheme.accentCyan, _exportAndShareCSV),
                _buildMenuCard("Admin Settings", Icons.settings, Colors.purpleAccent, () async {
                  final LocalAuthentication auth = LocalAuthentication();
                  bool authenticated = false;
                  try {
                    authenticated = await auth.authenticate(
                      localizedReason: 'Please authenticate to access Admin Settings',
                      options: const AuthenticationOptions(stickyAuth: true),
                    );
                  } catch (e) {
                    print(e);
                  }
                  if (authenticated && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication Failed"), backgroundColor: Colors.redAccent));
                  }
                }),
              ],
            ),
          )
        ],
      ),
    );
  }
}
