import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:staff_attendance_app/core/providers/db_provider.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

import 'package:staff_attendance_app/features/admin/employee_management_screen.dart';

class ZoneDashboardScreen extends ConsumerStatefulWidget {
  const ZoneDashboardScreen({super.key});

  @override
  ConsumerState<ZoneDashboardScreen> createState() => _ZoneDashboardScreenState();
}

class _ZoneDashboardScreenState extends ConsumerState<ZoneDashboardScreen> {
  bool _isLoading = true;
  Map<String, int> _zoneCounts = {
    'LKG': 0,
    'Pre KG': 0,
    'Secondary': 0,
    'Primary': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchZoneData();
  }

  Future<void> _fetchZoneData() async {
    final db = ref.read(databaseProvider);
    try {
      final allStaff = await db.getAllStaffs();
      for (var staff in allStaff) {
        String zone = staff['zone'] ?? '';
        if (_zoneCounts.containsKey(zone)) {
          _zoneCounts[zone] = _zoneCounts[zone]! + 1;
        }
      }
    } catch (e) {
      print(e);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Zone Categories"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double ratio = constraints.maxWidth > 600 ? 1.5 : 1.1;
                  return GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: ratio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildZoneCard('LKG', _zoneCounts['LKG'] ?? 0, Colors.orange),
                      _buildZoneCard('Pre KG', _zoneCounts['Pre KG'] ?? 0, Colors.pink),
                      _buildZoneCard('Primary', _zoneCounts['Primary'] ?? 0, Colors.blue),
                      _buildZoneCard('Secondary', _zoneCounts['Secondary'] ?? 0, Colors.purple),
                    ],
                  );
                }
              ),
            ),
    );
  }

  Widget _buildZoneCard(String title, int count, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeManagementScreen(zoneFilter: title)));
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 40, color: color),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("$count Staff Members", style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
