import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_attendance_app/core/theme/app_theme.dart';
import 'package:student_attendance_app/core/providers/db_provider.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends ConsumerState<EmployeeManagementScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final employees = await db.getAllStudents();
    setState(() {
      _employees = employees;
      _isLoading = false;
    });
  }

  void _showEditDialog(Map<String, dynamic> employee) {
    final TextEditingController nameCtrl = TextEditingController(text: employee['name']);
    final TextEditingController deptCtrl = TextEditingController(text: employee['dept']);
    String gender = employee['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text("Edit Employee", style: const TextStyle(color: AppTheme.accentCyan)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Name",
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.accentCyan)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Department",
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.accentCyan)),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: gender,
                dropdownColor: AppTheme.cardColor,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Gender",
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppTheme.accentCyan)),
                ),
                items: ['Male', 'Female', 'Others'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => gender = val);
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
              final db = ref.read(databaseProvider);
              final updated = Map<String, dynamic>.from(employee);
              updated['name'] = nameCtrl.text;
              updated['dept'] = deptCtrl.text;
              updated['gender'] = gender;
              await db.updateStudent(updated);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee updated!")));
                _loadEmployees();
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String registerNo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Delete Employee", style: TextStyle(color: Colors.redAccent)),
        content: const Text("Are you sure you want to delete this employee? Face data will be wiped.", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.deleteStudent(registerNo);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee deleted!")));
                _loadEmployees();
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Manage Employees", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
        : _employees.isEmpty 
          ? const Center(child: Text("No employees found.", style: TextStyle(color: Colors.white54, fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return Card(
                  color: AppTheme.cardColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(emp['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${emp['register_no']} • ${emp['dept']}", style: const TextStyle(color: Colors.white70)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.accentCyan),
                          onPressed: () => _showEditDialog(emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(emp['register_no']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
