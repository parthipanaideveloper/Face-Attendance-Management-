import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:staff_attendance_app/core/utils/export_utils.dart';

class DashboardStaffListScreen extends StatelessWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> staffsFuture;

  const DashboardStaffListScreen({super.key, required this.title, required this.staffsFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final staffs = await staffsFuture;
              if (staffs.isEmpty) return;
              
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text("Export $title", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  content: const Text("Select format to export this list:", style: TextStyle(color: Colors.black87)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ExportUtils.exportCSV(context, title, staffs, 'Daily', includeSalary: false);
                      },
                      child: const Text("CSV"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ExportUtils.exportExcel(context, title, staffs, 'Daily', includeSalary: false);
                      },
                      child: const Text("Excel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ExportUtils.exportPDF(context, title, staffs, 'Daily', includeSalary: false);
                      },
                      child: const Text("PDF"),
                    ),
                  ]
                )
              );
            },
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: staffsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text("No staffs found.", style: TextStyle(color: Colors.white54, fontSize: 18)),
                ],
              ),
            );
          }

          final staffs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staffs.length,
            itemBuilder: (context, index) {
              final staff = staffs[index];
              return Card(
                color: AppTheme.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentCyan.withOpacity(0.2),
                    child: const Icon(Icons.person, color: AppTheme.accentCyan),
                  ),
                  title: Text(staff['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${staff['register_no'] ?? ''} • ${staff['dept'] ?? ''}", style: const TextStyle(color: Colors.white70)),
                  trailing: staff['status'] != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(staff['status']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(staff['status'], style: TextStyle(color: _getStatusColor(staff['status']), fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      : null,
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == 'Present') return AppTheme.accentEmerald;
    if (status == 'Late Entry') return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
