import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

class LiveMonitoringScreen extends StatelessWidget {
  const LiveMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Live Health & Activity Monitor"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: \${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No activity logs found.", style: TextStyle(color: Colors.white54)));
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;
              final eventType = log['event_type'] ?? 'UNKNOWN';
              final desc = log['description'] ?? '';
              final timeStr = log['local_time'] ?? '';

              IconData icon;
              Color color;

              if (eventType == 'APP_LIFECYCLE') {
                icon = Icons.power_settings_new;
                color = Colors.orangeAccent;
              } else if (eventType == 'DEVICE_ONLINE') {
                icon = Icons.wifi;
                color = Colors.greenAccent;
              } else if (eventType == 'ADMIN_ACTION') {
                icon = Icons.admin_panel_settings;
                color = AppTheme.accentCyan;
              } else {
                icon = Icons.info;
                color = Colors.white54;
              }

              if (desc.contains('DELETED')) {
                color = Colors.redAccent;
              } else if (desc.contains('REGISTERED')) {
                color = AppTheme.accentEmerald;
              }

              return Card(
                color: AppTheme.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(desc, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("\$eventType • \$timeStr", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
