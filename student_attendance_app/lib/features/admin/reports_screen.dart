import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final records = await db.getAttendanceByDate(dateStr);
    setState(() {
      _attendanceRecords = records;
      _isLoading = false;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentCyan,
              onPrimary: Colors.black,
              surface: AppTheme.cardColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('MMMM dd, yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Live View Reports", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppTheme.accentCyan),
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selected Date", style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan.withOpacity(0.2), elevation: 0),
                  icon: const Icon(Icons.calendar_today, color: AppTheme.accentCyan, size: 18),
                  label: const Text("Change", style: TextStyle(color: AppTheme.accentCyan)),
                  onPressed: () => _pickDate(context),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
              : _attendanceRecords.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text("No attendance records for this date.", style: TextStyle(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attendanceRecords.length,
                    itemBuilder: (context, index) {
                      final r = _attendanceRecords[index];
                      return Card(
                        color: AppTheme.cardColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: r['status'] == 'Present' ? AppTheme.accentEmerald.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(r['status'] ?? '', style: TextStyle(color: r['status'] == 'Present' ? AppTheme.accentEmerald : Colors.redAccent, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text("${r['register_no']} • ${r['dept']}", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                              const Divider(color: Colors.white10, height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.login, color: AppTheme.accentCyan, size: 16),
                                      const SizedBox(width: 6),
                                      Text("IN: ${r['in_time']}", style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.logout, color: Colors.orangeAccent, size: 16),
                                      const SizedBox(width: 6),
                                      Text("OUT: ${(r['out_time'] != null && r['out_time'].toString().isNotEmpty) ? r['out_time'] : '--:--'}", style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
