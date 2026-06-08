import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';

class LopManagementScreen extends ConsumerStatefulWidget {
  const LopManagementScreen({super.key});

  @override
  ConsumerState<LopManagementScreen> createState() => _LopManagementScreenState();
}

class _LopManagementScreenState extends ConsumerState<LopManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseProvider);
    final staff = await db.getAllStaffs();
    if (mounted) {
      setState(() {
        _staffList = staff;
        _isLoading = false;
      });
    }
  }

  void _showUpdateSalaryDialog(Map<String, dynamic> staff) {
    final TextEditingController salaryCtrl = TextEditingController(text: (staff['salary'] ?? '0').toString());
    final TextEditingController lopCtrl = TextEditingController(text: (staff['lop_amount'] ?? '0').toString());
    final TextEditingController advanceCtrl = TextEditingController(text: (staff['advance_amount'] ?? '0').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Update Salary & LOP", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${staff['name']}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            Text("Reg No: ${staff['register_no']}", style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            TextField(
              controller: salaryCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(labelText: "Monthly Salary (₹)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lopCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(labelText: "Manual LOP Deduction (₹)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: advanceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(labelText: "Advance Amount (₹)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
            onPressed: () async {
              double newSalary = double.tryParse(salaryCtrl.text) ?? 0.0;
              double newLop = double.tryParse(lopCtrl.text) ?? 0.0;
              double newAdvance = double.tryParse(advanceCtrl.text) ?? 0.0;

              final db = ref.read(databaseProvider);
              await db.updateStaff({
                'register_no': staff['register_no'],
                'salary': newSalary,
                'lop_amount': newLop,
                'advance_amount': newAdvance,
              });

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salary & LOP Updated!"), backgroundColor: AppTheme.accentEmerald));
                _loadStaff();
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
    final filteredStaff = _staffList.where((s) {
      final text = "${s['name']} ${s['register_no']} ${s['dept']}".toLowerCase();
      return text.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50], // White Theme
      appBar: AppBar(
        title: const Text("Manage LOP & Salary", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Search Employee...",
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(AppTheme.cardColor.withOpacity(0.1)),
                        columns: const [
                          DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Dept", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Zone", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Gender", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Designation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Salary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("LOP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Advance", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Final Pay", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                          DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                        ],
                        rows: filteredStaff.map((staff) {
                          final salaryStr = staff['salary']?.toString() ?? '0';
                          final lopStr = staff['lop_amount']?.toString() ?? '0';
                          final advanceStr = staff['advance_amount']?.toString() ?? '0';

                          final double sal = double.tryParse(salaryStr) ?? 0.0;
                          final double lop = double.tryParse(lopStr) ?? 0.0;
                          final double adv = double.tryParse(advanceStr) ?? 0.0;
                          final double finalPay = sal - lop - adv;
                          
                          String regNo = staff['register_no'] ?? '';
                          String zoneText = staff['zone'] ?? '';
                          if (regNo.startsWith('SMSNS')) {
                            zoneText = '-';
                          }

                          return DataRow(cells: [
                            DataCell(Text(staff['name'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(regNo, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['dept'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['mobile_no'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(zoneText, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['gender'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(staff['designation'] ?? '', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text("₹$sal", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹$lop", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹$adv", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                            DataCell(Text("₹$finalPay", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.accentCyan),
                                tooltip: "Edit",
                                onPressed: () => _showUpdateSalaryDialog(staff),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const AppFooter(isDark: false),
              ],
            ),
    );
  }
}
