import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  Map<String, String> _schedules = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final schedules = await db.getAllSchedules();
    if (mounted) {
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
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
      setState(() {
        _selectedDate = picked;
      });
      _showScheduleDialog();
    }
  }

  void _showScheduleDialog() {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String currentType = _schedules[dateStr] ?? 'Working Day';
    String selectedType = currentType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text("Set Schedule: $dateStr", style: const TextStyle(color: AppTheme.accentCyan)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => DropdownButtonFormField<String>(
            value: selectedType,
            dropdownColor: AppTheme.cardColor,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Schedule Type",
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
            ),
            items: ['Working Day', 'Non-Working Day', 'Special Day']
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (val) {
              if (val != null) setStateDialog(() => selectedType = val);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.setSchedule(dateStr, selectedType);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule updated!")));
                _loadSchedules();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort schedules by date descending
    var sortedKeys = _schedules.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Admin Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cardColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, color: Colors.black),
                    label: const Text("Pick Date to Set Schedule", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: sortedKeys.isEmpty
                      ? const Center(child: Text("No custom schedules set yet.", style: TextStyle(color: Colors.white54, fontSize: 16)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, index) {
                            String dateStr = sortedKeys[index];
                            String type = _schedules[dateStr]!;
                            
                            Color typeColor = Colors.white;
                            if (type == 'Working Day') typeColor = AppTheme.accentEmerald;
                            if (type == 'Non-Working Day') typeColor = Colors.redAccent;
                            if (type == 'Special Day') typeColor = Colors.orangeAccent;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: typeColor.withOpacity(0.5)),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.event, color: typeColor),
                                title: Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                trailing: Text(type, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
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
