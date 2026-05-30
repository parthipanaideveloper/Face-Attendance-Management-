import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/features/admin/providers/dashboard_provider.dart';
import 'package:staff_attendance_app/features/admin/admin_settings_screen.dart';
import 'package:staff_attendance_app/features/admin/reports_screen.dart';
import 'package:staff_attendance_app/features/admin/employee_management_screen.dart';
import 'package:staff_attendance_app/features/admin/zone_dashboard_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_schedule_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _exportCSV(BuildContext context, WidgetRef ref, String monthStr, List<Map<String, dynamic>> records) async {
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
        final salary = hours * 12.0;
        csv += "${r['date']},${r['name']},${r['register_no']},${r['dept']},${r['in_time']},${r['out_time'] ?? '--:--:--'},${r['status']},${hours.toStringAsFixed(2)},\$${salary.toStringAsFixed(2)}\n";
      }
      final directory = await getTemporaryDirectory();
      final file = File("${directory.path}/report_$monthStr.csv");
      await file.writeAsString(csv);
      Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Attendance Report CSV');
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref, String monthStr, List<Map<String, dynamic>> records) async {
      var excel = xl.Excel.createExcel();
      xl.Sheet sheetObject = excel['Attendance Report'];
      excel.setDefaultSheet('Attendance Report');
      
      sheetObject.appendRow([
        xl.TextCellValue('Date'), xl.TextCellValue('Name'), xl.TextCellValue('RegNo'), 
        xl.TextCellValue('Dept'), xl.TextCellValue('InTime'), xl.TextCellValue('OutTime'), 
        xl.TextCellValue('Status'), xl.TextCellValue('Hours'), xl.TextCellValue('Salary')
      ]);

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
        final salary = hours * 12.0;
        sheetObject.appendRow([
          xl.TextCellValue(r['date'].toString()), xl.TextCellValue(r['name'].toString()), 
          xl.TextCellValue(r['register_no'].toString()), xl.TextCellValue(r['dept'].toString()), 
          xl.TextCellValue(r['in_time'].toString()), xl.TextCellValue((r['out_time'] ?? '--:--:--').toString()), 
          xl.TextCellValue(r['status'].toString()), xl.TextCellValue(hours.toStringAsFixed(2)), 
          xl.TextCellValue('\$${salary.toStringAsFixed(2)}')
        ]);
      }
      
      final directory = await getTemporaryDirectory();
      final file = File("${directory.path}/report_$monthStr.xlsx");
      await file.writeAsBytes(excel.encode()!);
      Share.shareXFiles([XFile(file.path)], text: 'Attendance Report Excel');
  }

  Future<void> _exportPDF(BuildContext context, WidgetRef ref, String monthStr, List<Map<String, dynamic>> records) async {
      final pdf = pw.Document();
      
      final ByteData logoBytes = await rootBundle.load('assets/St-Marys-school-logo.webp');
      final Uint8List logoData = logoBytes.buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, width: 50, height: 50),
                  pw.SizedBox(width: 15),
                  pw.Text("St. Marrys School Attendance - $monthStr", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Date', 'Name', 'RegNo', 'In', 'Out', 'Hrs', 'Salary'],
                data: records.map((r) {
                  double hours = 0;
                  if (r['in_time'] != null && r['out_time'] != null) {
                    try {
                      final inFormat = DateFormat("hh:mm a").parse(r['in_time']);
                      final outFormat = DateFormat("hh:mm a").parse(r['out_time']);
                      hours = outFormat.difference(inFormat).inMinutes / 60.0;
                      if (hours < 0) hours += 24;
                    } catch(e) {}
                  }
                  final salary = hours * 12.0;
                  return [r['date'], r['name'], r['register_no'], r['in_time'], r['out_time'] ?? '--:--:--', hours.toStringAsFixed(1), '\$${salary.toStringAsFixed(2)}'];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File("${directory.path}/report_$monthStr.pdf");
      await file.writeAsBytes(await pdf.save());
      Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: 'Attendance Report PDF');
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Export & Share", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: const Text("Choose the format for the attendance report:", style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              final records = await db.getAttendanceByMonth(monthStr);
              _exportCSV(context, ref, monthStr, records);
            },
            child: const Text("CSV"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              final records = await db.getAttendanceByMonth(monthStr);
              _exportExcel(context, ref, monthStr, records);
            },
            child: const Text("Excel (XLSX)"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              final records = await db.getAttendanceByMonth(monthStr);
              _exportPDF(context, ref, monthStr, records);
            },
            child: const Text("PDF Document"),
          ),
        ],
      ),
    );
  }

  void _openChartScreen(BuildContext context, List<int> weeklyData, Map<String, dynamic> analytics) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      int total = analytics['total_staffs'] ?? 0;
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
                        interval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                           return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 12));
                        }
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false, 
                    horizontalInterval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
                    getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1)
                  ),
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

  void _showAssignClassDialog(BuildContext context, WidgetRef ref) {
    String _selectedClass = '12-B History';
    String _staffRegNo = '';
    
    final classesList = [
      '12-B History', '12-A Maths', '11 Physics', '10-B Chemistry', '10-A Tamil', '9 - English',
      '8-A Zoology', '8-B Botany', '7-A Social', '7-b Tamil', '6-A Tamil', '6-B Science',
      '5-A English', '5-B Tamil', '4-A Maths', '4-B English', '4-C Maths', '3 - A Tamil',
      '3-b English', '3-C English', '3-D Maths', '2-A', '2-B', '2-C', '2-D', '1-A', '1-B', '1-C', '1-D',
      'UKG-A', 'UKG-B', 'UKG-C', 'UKG-D', 'UKG-E', 'LKG -B', 'LKG - C', 'LKG - D', 'LKG - E',
      'Coding', 'STEM', 'Hindi', 'Commerce / Accountancy', 'Computer Science', 'Economics'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text("Assign Special Class", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (val) => _staffRegNo = val,
                    style: const TextStyle(color: Colors.black87),
                    decoration: const InputDecoration(
                      labelText: "Staff Register Number",
                      prefixIcon: Icon(Icons.badge, color: AppTheme.accentCyan),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Select Class",
                      prefixIcon: Icon(Icons.class_, color: AppTheme.accentCyan),
                    ),
                    items: classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedClass = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (_staffRegNo.isEmpty) return;
                    Navigator.pop(ctx);
                    final db = ref.read(databaseProvider);
                    try {
                      final existing = await db.getStaffByRegisterNo(_staffRegNo);
                      if (existing != null) {
                         await db.updateStaff({'register_no': _staffRegNo, 'assigned_class': _selectedClass});
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class assigned successfully!"), backgroundColor: AppTheme.accentEmerald));
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff not found!"), backgroundColor: Colors.red));
                      }
                    } catch(e) {
                      print(e);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                  child: const Text("Assign", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
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
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
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
      color: Colors.grey[50], // White Theme Background
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
                  Text("Admin Dashboard", style: TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  SizedBox(height: 4),
                  Text("Welcome back, Super Admin", style: TextStyle(color: Colors.black54, fontSize: 14)),
                ],
              ),
              Container(
                height: 60, width: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppTheme.accentCyan, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/St-Marys-school-logo.webp'),
                    fit: BoxFit.contain,
                  ),
                ),
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            ],
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
          
          const SizedBox(height: 30),
          
          // Stats row
          statsAsync.when(
            data: (stats) {
              return Row(
                children: [
                  Expanded(child: _buildStatCard("Total Staff", stats['total_staffs'].toString(), Icons.people, AppTheme.accentCyan)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard("Present Today", stats['present_today'].toString(), Icons.check_circle, AppTheme.accentEmerald)),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
            error: (err, stack) => Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Network Error: Unable to fetch live stats. Showing offline data.", 
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatCard("Total Staff", "--", Icons.people, AppTheme.accentCyan)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard("Present Today", "--", Icons.check_circle, AppTheme.accentEmerald)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 3 : 2);
                double childAspectRatio = constraints.maxWidth > 800 ? 1.5 : (constraints.maxWidth > 500 ? 1.2 : 1.0);
                
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
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
                    _buildMenuCard("Export & Share", Icons.ios_share, AppTheme.accentCyan, () => _showExportDialog(context, ref)).animate().fadeIn(delay: 500.ms).scale(),
                    _buildMenuCard("Employee Directory", Icons.badge, Colors.blueAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()));
                    }).animate().fadeIn(delay: 550.ms).scale(),
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
                    _buildMenuCard("Zone Categories", Icons.map, Colors.indigoAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ZoneDashboardScreen()));
                    }).animate().fadeIn(delay: 625.ms).scale(),
                    _buildMenuCard("Assign Class", Icons.assignment_ind, AppTheme.accentEmerald, () {
                      _showAssignClassDialog(context, ref);
                    }).animate().fadeIn(delay: 650.ms).scale(),
                    _buildMenuCard("Manage Schedule", Icons.calendar_month, Colors.pinkAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScheduleScreen()));
                    }).animate().fadeIn(delay: 675.ms).scale(),
              ],
            );
          }),
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
