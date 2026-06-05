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
import 'package:staff_attendance_app/features/admin/dashboard_staff_list_screen.dart';
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

  void _openChartScreen(BuildContext context, Map<String, dynamic> weeklyData, Map<String, dynamic> analytics) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      List<Map<String, double>> teachingData = (weeklyData['teaching'] as List).cast<Map<String, double>>();
      List<Map<String, double>> nonTeachingData = (weeklyData['non_teaching'] as List).cast<Map<String, double>>();
      
      Map<String, dynamic> presentGender = analytics['present_gender'] ?? {'Male': 0, 'Female': 0};
      int maleCount = presentGender['Male'] ?? 0;
      int femaleCount = presentGender['Female'] ?? 0;
      int totalGender = maleCount + femaleCount;
      double malePct = totalGender > 0 ? (maleCount / totalGender) * 100 : 0.0;
      double femalePct = totalGender > 0 ? (femaleCount / totalGender) * 100 : 0.0;

      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        appBar: AppBar(
          title: const Text("Analytical Reports", style: TextStyle(color: Colors.white)), 
          backgroundColor: AppTheme.cardColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("Teaching Staff Attendance (%)", Icons.school, AppTheme.accentCyan),
              const SizedBox(height: 16),
              _buildWeeklyChart(teachingData),
              const SizedBox(height: 40),
              _buildSectionTitle("Non-Teaching Staff Attendance (%)", Icons.group_work, Colors.orangeAccent),
              const SizedBox(height: 16),
              _buildWeeklyChart(nonTeachingData),
              const SizedBox(height: 40),
              _buildSectionTitle("Today's Gender Distribution (%)", Icons.pie_chart, Colors.purpleAccent),
              const SizedBox(height: 16),
              _buildGenderChart(malePct, femalePct),
            ],
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
        ),
      );
    }));
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWeeklyChart(List<Map<String, double>> data) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem('${rod.toY.toStringAsFixed(1)}%', const TextStyle(color: Colors.white));
              }
            )
          ),
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
                interval: 20,
                getTitlesWidget: (double value, TitleMeta meta) {
                   return Text('${value.toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 12));
                }
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false, 
            horizontalInterval: 20,
            getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1)
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(6, (i) {
            return BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: data[i]['present'] ?? 0.0,
                  gradient: const LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentEmerald], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 14,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                ),
                BarChartRodData(
                  toY: data[i]['absent'] ?? 0.0,
                  gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 14,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGenderChart(double malePct, double femalePct) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.blueAccent,
                    value: malePct,
                    title: '${malePct.toStringAsFixed(1)}%',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.pinkAccent,
                    value: femalePct,
                    title: '${femalePct.toStringAsFixed(1)}%',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegend("Male", Colors.blueAccent),
                const SizedBox(height: 16),
                _buildLegend("Female", Colors.pinkAccent),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
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
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Total Staff", stats['total_staffs'].toString(), Icons.people, AppTheme.accentCyan, () {
                        final db = ref.read(databaseProvider);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardStaffListScreen(title: "Total Staffs", staffsFuture: db.getAllStaffs())));
                      })),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard("Late Entries", (stats['late_today'] ?? 0).toString(), Icons.access_time_filled, Colors.orangeAccent, () {
                        final db = ref.read(databaseProvider);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardStaffListScreen(title: "Late Entries Today", staffsFuture: db.getTodayLateStaffs())));
                      })),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Present Today", stats['present_today'].toString(), Icons.check_circle, AppTheme.accentEmerald, () {
                        final db = ref.read(databaseProvider);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardStaffListScreen(title: "Present Today", staffsFuture: db.getTodayPresentStaffs())));
                      })),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatCard("Absent Today", stats['absent_today'].toString(), Icons.cancel, Colors.redAccent, () {
                        final db = ref.read(databaseProvider);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardStaffListScreen(title: "Absent Today", staffsFuture: db.getTodayAbsentStaffs())));
                      })),
                    ],
                  ),
                ]
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
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildStatCard("Total Staff", "--", Icons.people, AppTheme.accentCyan, null)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard("Late Entries", "--", Icons.access_time_filled, Colors.orangeAccent, null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard("Present Today", "--", Icons.check_circle, AppTheme.accentEmerald, null)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard("Absent Today", "--", Icons.cancel, Colors.redAccent, null)),
                      ],
                    ),
                  ]
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
