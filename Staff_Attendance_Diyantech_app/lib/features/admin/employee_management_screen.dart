import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/features/admin/admin_auth_screen.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  final String? zoneFilter;
  const EmployeeManagementScreen({super.key, this.zoneFilter});

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
    final employees = await db.getAllStaffs();
    setState(() {
      _employees = employees;
      _isLoading = false;
    });
  }

  void _showFullDetails(Map<String, dynamic> emp) {
    Uint8List? photoBytes;
    if (emp['photos'] != null && emp['photos'].isNotEmpty) {
      try {
        photoBytes = base64Decode(emp['photos'][0]);
      } catch (e) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Employee Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.accentCyan.withOpacity(0.2),
                        backgroundImage: photoBytes != null ? MemoryImage(photoBytes!) : null,
                        child: photoBytes == null ? const Icon(Icons.person, size: 50, color: AppTheme.accentCyan) : null,
                      ),
                      InkWell(
                        onTap: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 500, maxHeight: 500);
                          if (pickedFile != null) {
                            try {
                              final bytes = await File(pickedFile.path).readAsBytes();
                              final base64Image = base64Encode(bytes);
                              final db = ref.read(databaseProvider);
                              final updated = Map<String, dynamic>.from(emp);
                              
                              // If photos is missing or empty, create list
                              List<dynamic> photos = List.from(updated['photos'] ?? []);
                              if (photos.isEmpty) {
                                photos.add(base64Image);
                              } else {
                                photos[0] = base64Image;
                              }
                              updated['photos'] = photos;
                              
                              await db.updateStaff(updated);
                              setStateDialog(() {
                                photoBytes = bytes;
                              });
                              _loadEmployees(); // Refresh list behind dialog
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload image: \${e.toString()}")));
                            }
                          }
                        },
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.accentEmerald,
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _detailRow("Name:", emp['name'] ?? ''),
                _detailRow("ID:", emp['register_no'] ?? ''),
                _detailRow("Dept:", emp['dept'] ?? ''),
                _detailRow("Designation:", emp['designation'] ?? ''),
                _detailRow("Zone:", emp['zone'] ?? ''),
                _detailRow("Gender:", emp['gender'] ?? ''),
                _detailRow("Mobile:", emp['mobile_no'] ?? ''),
                _detailRow("Salary:", "₹${emp['salary'] ?? '0'}"),
                _detailRow("LOP:", "₹${emp['lop_amount'] ?? '0'}"),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }


  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.black12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accentCyan)),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> employee) {
    final TextEditingController regNoCtrl = TextEditingController(text: employee['register_no']);
    final TextEditingController nameCtrl = TextEditingController(text: employee['name']);
    final TextEditingController deptCtrl = TextEditingController(text: employee['dept']);
    final TextEditingController mobileCtrl = TextEditingController(text: employee['mobile_no'] ?? '');
    final TextEditingController salaryCtrl = TextEditingController(text: (employee['salary'] ?? '0').toString());
    final TextEditingController lopCtrl = TextEditingController(text: (employee['lop_amount'] ?? '0').toString());
    final TextEditingController advanceCtrl = TextEditingController(text: (employee['advance_amount'] ?? '0').toString());
    String gender = employee['gender'] ?? 'Male';
    String designation = employee['designation'] ?? 'Teaching Staff';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_document, color: AppTheme.accentCyan),
            const SizedBox(width: 10),
            const Text("Edit Employee", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PERSONAL INFO", style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildTextField(nameCtrl, "Full Name"),
                  _buildTextField(mobileCtrl, "Mobile Number", isNumber: true),
                  DropdownButtonFormField<String>(
                    value: gender,
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: Colors.black12,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accentCyan)),
                    ),
                    items: ['Male', 'Female', 'Others'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) { if (val != null) setStateDialog(() => gender = val); },
                  ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24)),
                  const Text("JOB DETAILS", style: TextStyle(color: AppTheme.accentEmerald, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildTextField(regNoCtrl, "Employee ID"),
                  _buildTextField(deptCtrl, "Department"),
                  DropdownButtonFormField<String>(
                    value: designation,
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Designation",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: Colors.black12,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accentCyan)),
                    ),
                    items: ['Teaching Staff', 'Non-Teaching Staff', 'Admin', 'Bus Driver', 'P.E.T', 'Security Guard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) { if (val != null) setStateDialog(() => designation = val); },
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24)),
                  const Text("FINANCIAL INFO", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildTextField(salaryCtrl, "Monthly Salary (₹)", isNumber: true),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(lopCtrl, "LOP Amount (₹)", isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(advanceCtrl, "Advance (₹)", isNumber: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final updated = Map<String, dynamic>.from(employee);
              String oldRegNo = employee['register_no'];
              String newRegNo = regNoCtrl.text.trim();
              updated['register_no'] = newRegNo;
              updated['name'] = nameCtrl.text;
              updated['dept'] = deptCtrl.text;
              updated['mobile_no'] = mobileCtrl.text;
              updated['gender'] = gender;
              updated['designation'] = designation;
              updated['salary'] = double.tryParse(salaryCtrl.text) ?? 0.0;
              updated['lop_amount'] = double.tryParse(lopCtrl.text) ?? 0.0;
              updated['advance_amount'] = double.tryParse(advanceCtrl.text) ?? 0.0;
              
              if (oldRegNo != newRegNo) {
                 await db.insertStaff(updated);
                 await db.deleteStaff(oldRegNo);
              } else {
                 await db.updateStaff(updated);
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee updated!")));
                _loadEmployees();
              }
            },
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
            onPressed: () {
              Navigator.pop(context); // Close the confirmation dialog
              Navigator.push(context, MaterialPageRoute(builder: (authContext) => AdminAuthScreen(
                onAuthenticated: () async {
                  Navigator.pop(authContext); // Close auth screen correctly
                  final db = ref.read(databaseProvider);
                  await db.deleteStaff(registerNo);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee deleted!")));
                    _loadEmployees();
                  }
                }
              )));
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _employees.where((emp) {
      if (widget.zoneFilter != null && emp['zone'] != widget.zoneFilter) {
         return false;
      }
      final query = _searchQuery.toLowerCase();
      final name = (emp['name'] ?? '').toLowerCase();
      final regNo = (emp['register_no'] ?? '').toLowerCase();
      return name.contains(query) || regNo.contains(query);
    }).toList();
    
    // Sort A-Z by name
    filteredEmployees.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return Scaffold(
      backgroundColor: Colors.grey[50], // White Theme
      appBar: AppBar(
        title: Text(widget.zoneFilter != null ? "${widget.zoneFilter} Staff" : "Employee Directory", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
        : Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search Name or Employee ID...",
                    prefixIcon: const Icon(Icons.search, color: AppTheme.accentCyan),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _employees.isEmpty 
                ? const Center(child: Text("No employees found.", style: TextStyle(color: Colors.black54, fontSize: 18)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.accentCyan.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2), width: 1),
                        ),
                        child: ListTile(
                          onTap: () => _showFullDetails(emp),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentCyan.withOpacity(0.2),
                            backgroundImage: (emp['photos'] != null && emp['photos'].isNotEmpty) 
                                ? MemoryImage(base64Decode(emp['photos'][0])) 
                                : null,
                            child: (emp['photos'] == null || emp['photos'].isEmpty) 
                                ? const Icon(Icons.person, color: AppTheme.accentCyan) 
                                : null,
                          ),
                          title: Text(emp['name'] ?? '', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("ID: ${emp['register_no']} • ${emp['designation'] ?? 'Staff'}", style: const TextStyle(color: Colors.black54)),
                              Text("Dept: ${emp['dept']}", style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
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
              ),
              const AppFooter(isDark: false),
            ],
          ),
    );
  }
}
