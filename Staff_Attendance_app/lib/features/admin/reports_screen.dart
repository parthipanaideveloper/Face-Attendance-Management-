import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';
import 'package:staff_attendance_app/core/utils/export_utils.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
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
    String startStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    String endStr = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    final records = await db.getAttendanceByDateRange(startStr, endStr);
    setState(() {
      _attendanceRecords = records;
      _isLoading = false;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
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
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _fetchReports();
    }
  }

  void _showManualEntryDialog() async {
    final db = ref.read(databaseProvider);
    final staffs = await db.getAllStaffs();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String? selectedRegNo;
        String status = 'Present';
        TimeOfDay? inTime;
        TimeOfDay? outTime;

        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text("Manual Attendance Entry", style: TextStyle(color: AppTheme.accentCyan)),
            content: SingleChildScrollView(
              child: Column(
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
                      setStateDialog(() => selectedRegNo = option['register_no'] as String);
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Search Employee (Name or ID)",
                          labelStyle: TextStyle(color: Colors.white54),
                          suffixIcon: Icon(Icons.search, color: Colors.white54),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: AppTheme.cardColor,
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text("${option['name']} (${option['register_no']})", style: const TextStyle(color: Colors.white)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(color: Colors.white),
                    items: ['Present', 'Absent', 'Late Entry'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setStateDialog(() => status = val!),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: const Text("IN Time", style: TextStyle(color: Colors.white70)),
                    subtitle: Text(inTime?.format(context) ?? "--:--", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.access_time, color: AppTheme.accentCyan),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t != null) setStateDialog(() => inTime = t);
                    },
                  ),
                  ListTile(
                    title: const Text("OUT Time", style: TextStyle(color: Colors.white70)),
                    subtitle: Text(outTime?.format(context) ?? "--:--", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.access_time, color: AppTheme.accentCyan),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t != null) setStateDialog(() => outTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                onPressed: () async {
                  if (selectedRegNo == null) return;
                  String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Default to today
                  String inStr = inTime != null ? inTime!.format(context) : '';
                  String outStr = outTime != null ? outTime!.format(context) : '';
                  
                  await db.logManualAttendance(selectedRegNo!, dateStr, status, inStr, outStr);
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchReports();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Manual entry saved!")));
                  }
                },
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = _selectedDateRange.start.year == _selectedDateRange.end.year && 
                           _selectedDateRange.start.month == _selectedDateRange.end.month && 
                           _selectedDateRange.start.day == _selectedDateRange.end.day 
                           ? DateFormat('MMMM dd, yyyy').format(_selectedDateRange.start)
                           : "${DateFormat('MMM dd').format(_selectedDateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange.end)}";

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Live View Reports", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppTheme.accentCyan),
            onPressed: () {
              ExportUtils.showExportDialog(context, 'Daily', (type, dateStr) async {
                final db = ref.read(databaseProvider);
                return type == 'Daily' ? await db.getAttendanceByDate(dateStr) : await db.getAttendanceByMonth(dateStr);
              });
            },
          ),
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
                    const Text("Selected Date Range", style: TextStyle(color: Colors.white54, fontSize: 14)),
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
                                  Row(
                                    children: [
                                      Text(r['date'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: r['status'] == 'Present' ? AppTheme.accentEmerald.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(r['status'] ?? '', style: TextStyle(color: r['status'] == 'Present' ? AppTheme.accentEmerald : Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
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
          const AppFooter(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEntryDialog,
        backgroundColor: AppTheme.accentCyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Manual Entry", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
