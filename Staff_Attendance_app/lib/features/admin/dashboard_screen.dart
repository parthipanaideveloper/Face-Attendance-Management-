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
import 'package:staff_attendance_app/features/admin/lop_management_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:staff_attendance_app/core/utils/export_utils.dart';
import 'package:staff_attendance_app/services/sim_sms_service.dart';
import 'package:staff_attendance_app/features/admin/time_settings_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_auth_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openChartScreen(BuildContext context, List<Map<String, int>> weeklyData, Map<String, dynamic> analytics) {
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
                        reservedSize: 40,
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
                      barsSpace: 4, // space between the two rods
                      barRods: [
                        BarChartRodData(
                          toY: (weeklyData[i]['present'] ?? 0).toDouble(),
                          gradient: const LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentEmerald], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          width: 14,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                        BarChartRodData(
                          toY: (weeklyData[i]['absent'] ?? 0).toDouble(),
                          gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          width: 14,
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

  void _showAssignClassDialog(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final staffs = await db.getAllStaffs();

    String _selectedClass = '12-B History';
    String _staffRegNo = '';
    TimeOfDay? _selectedTime;
    
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
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => "${option['name']} (${option['register_no']})",
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return staffs;
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return staffs.where((s) {
                        final name = s['name'].toString().toLowerCase();
                        final regNo = s['register_no'].toString().toLowerCase();
                        return name.contains(query) || regNo.contains(query);
                      });
                    },
                    onSelected: (option) {
                      setState(() => _staffRegNo = option['register_no'] as String);
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: "Search Staff (Name or ID)",
                          prefixIcon: Icon(Icons.badge, color: AppTheme.accentCyan),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.white,
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text("${option['name']} (${option['register_no']})", style: const TextStyle(color: Colors.black87)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
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
                  const SizedBox(height: 20),
                  ListTile(
                    title: Text(_selectedTime == null ? "Select Time" : _selectedTime!.format(context), style: const TextStyle(color: Colors.black87)),
                    trailing: const Icon(Icons.access_time, color: AppTheme.accentCyan),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black26)),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) setState(() => _selectedTime = time);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (_staffRegNo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a Register Number!")));
                      return;
                    }
                    if (_selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Time!")));
                      return;
                    }
                    Navigator.pop(ctx);
                    final db = ref.read(databaseProvider);
                     try {
                      final existing = await db.getStaffByRegisterNo(_staffRegNo);
                      if (existing != null) {
                         String timeStr = _selectedTime!.format(context);
                         await db.updateStaff({
                           'register_no': _staffRegNo, 
                           'assigned_class': _selectedClass,
                           'special_class_time': timeStr,
                         });
                         
                         // Trigger SMS
                         String phone = existing['mobile_no'] ?? '';
                         String name = existing['name'] ?? 'Staff';
                         if (phone.length >= 10) {
                           await SimSmsService.sendSms(phone, "St.Mary's Matriculation Higher Secondary School Chinna Udayamuthur, Tirupattur\n\nDear $name, you have been assigned to Special Class $_selectedClass at $timeStr.");
                         }
                         
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
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard("Present Today", stats['present_today'].toString(), Icons.check_circle, AppTheme.accentEmerald)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard("Absent Today", stats['absent_today'].toString(), Icons.cancel, Colors.redAccent)),
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
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatCard("Present Today", "--", Icons.check_circle, AppTheme.accentEmerald)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatCard("Absent Today", "--", Icons.cancel, Colors.redAccent)),
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
                    _buildMenuCard("Export & Share", Icons.ios_share, AppTheme.accentCyan, () {
                      ExportUtils.showExportDialog(context, 'Monthly', (type, dateStr) async {
                        final db = ref.read(databaseProvider);
                        return type == 'Daily' ? await db.getAttendanceByDate(dateStr) : await db.getAttendanceByMonth(dateStr);
                      });
                    }).animate().fadeIn(delay: 500.ms).scale(),
                    _buildMenuCard("Employee Directory", Icons.badge, Colors.blueAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAuthScreen(
                        onAuthenticated: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()));
                        },
                      )));
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
                    _buildMenuCard("Time Settings", Icons.access_time_filled, Colors.amberAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeSettingsScreen()));
                    }).animate().fadeIn(delay: 660.ms).scale(),
                    _buildMenuCard("Manage Schedule", Icons.calendar_month, Colors.pinkAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScheduleScreen()));
                    }).animate().fadeIn(delay: 675.ms).scale(),
                    _buildMenuCard("Manage LOP & Salary", Icons.currency_rupee, Colors.deepPurpleAccent, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAuthScreen(
                        onAuthenticated: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LopManagementScreen()));
                        },
                      )));
                    }).animate().fadeIn(delay: 700.ms).scale(),
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
          Text(value, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }
}
