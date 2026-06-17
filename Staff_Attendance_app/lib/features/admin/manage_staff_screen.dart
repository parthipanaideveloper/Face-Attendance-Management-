import 'package:flutter/material.dart';
import 'package:staff_attendance_app/database/db_helper.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'dart:math';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({Key? key}) : super(key: key);

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _staffs = [];
  bool _isLoading = true;

  final List<Map<String, String>> _availableFeatures = [
    {'id': 'take_attendance', 'label': 'Take Live Attendance'},
    {'id': 'register_student', 'label': 'Register New Student'},
    {'id': 'view_attendance', 'label': 'View Attendance Records'},
    {'id': 'notify_absentees', 'label': 'Notify Absentees (SMS)'},
    {'id': 'send_email_summary', 'label': 'Send Email Summaries'},
    {'id': 'send_daily_summary', 'label': 'Send Daily Summaries'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffs();
  }

  Future<void> _loadStaffs() async {
    setState(() => _isLoading = true);
    try {
      final staffs = await _dbHelper.getAllStaffs();
      // Filter out only those who actually have a username (meaning they are staff users, not just raw registered faces)
      _staffs = staffs.where((s) => s.containsKey('username')).toList();
    } catch (e) {
      debugPrint("Error loading staffs: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditStaffDialog({Map<String, dynamic>? existingStaff}) {
    final nameController = TextEditingController(text: existingStaff?['name'] ?? '');
    final phoneController = TextEditingController(text: existingStaff?['mobile_no'] ?? '');
    final regNoController = TextEditingController(text: existingStaff?['register_no'] ?? '');
    
    // Auto generate credentials if new
    final random = Random();
    final String initialUsername = existingStaff?['username'] ?? 'staff\${random.nextInt(9000) + 1000}';
    final String initialPassword = existingStaff?['password'] ?? 'pass\${random.nextInt(9000) + 1000}';
    
    final userController = TextEditingController(text: initialUsername);
    final passController = TextEditingController(text: initialPassword);

    List<String> enabledFeatures = [];
    if (existingStaff != null && existingStaff['features'] != null) {
      enabledFeatures = List<String>.from(existingStaff['features']);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                existingStaff == null ? 'Add New Staff' : 'Edit Staff',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: regNoController, decoration: const InputDecoration(labelText: 'Register/ID No', border: OutlineInputBorder()), enabled: existingStaff == null),
                    const SizedBox(height: 10),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder())),
                    const Divider(height: 30),
                    TextField(controller: userController, decoration: const InputDecoration(labelText: 'Login Username', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: passController, decoration: const InputDecoration(labelText: 'Login Password', border: OutlineInputBorder())),
                    const Divider(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Feature Access:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ),
                    const SizedBox(height: 10),
                    ..._availableFeatures.map((feature) {
                      return CheckboxListTile(
                        title: Text(feature['label']!, style: const TextStyle(fontSize: 14)),
                        value: enabledFeatures.contains(feature['id']),
                        activeColor: AppTheme.accentCyan,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              enabledFeatures.add(feature['id']!);
                            } else {
                              enabledFeatures.remove(feature['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || regNoController.text.isEmpty) return;

                    final staffData = {
                      'name': nameController.text,
                      'register_no': regNoController.text,
                      'mobile_no': phoneController.text,
                      'username': userController.text,
                      'password': passController.text,
                      'features': enabledFeatures,
                      'designation': 'Teaching Staff', // Default or add field
                    };

                    if (existingStaff == null) {
                      await _dbHelper.insertStaff(staffData);
                    } else {
                      await _dbHelper.updateStaff(staffData);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadStaffs();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteStaff(String regNo) async {
    await _dbHelper.deleteStaff(regNo);
    _loadStaffs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text('Manage Staff', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _staffs.length,
            itemBuilder: (context, index) {
              final staff = _staffs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentCyan.withAlpha(30),
                    child: Icon(Icons.person, color: AppTheme.accentCyan),
                  ),
                  title: Text(staff['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  subtitle: Text("User: \${staff['username']}\nFeatures: \${(staff['features'] as List?)?.length ?? 0}", style: TextStyle(color: AppTheme.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: AppTheme.accentCyan),
                        onPressed: () => _showAddEditStaffDialog(existingStaff: staff),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteStaff(staff['register_no']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentCyan,
        onPressed: () => _showAddEditStaffDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
