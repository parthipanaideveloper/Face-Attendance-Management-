import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/admin/admin_dashboard.dart'; // Placeholder
import 'package:staff_attendance_app/features/auth/login_screen.dart';
import 'package:intl/intl.dart';

class MasterAdminDashboard extends StatefulWidget {
  const MasterAdminDashboard({Key? key}) : super(key: key);

  @override
  State<MasterAdminDashboard> createState() => _MasterAdminDashboardState();
}

class _MasterAdminDashboardState extends State<MasterAdminDashboard> {
  Future<void> _logout() async {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Future<void> _toggleBlockStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('institutions').doc(docId).update({
      'is_blocked': !currentStatus,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Institution \${!currentStatus ? 'blocked' : 'unblocked'} successfully.")),
    );
  }

  Future<void> _extendValidity(String docId, String currentValidUntilStr) async {
    DateTime currentValidUntil;
    try {
      currentValidUntil = DateTime.parse(currentValidUntilStr);
    } catch (e) {
      currentValidUntil = DateTime.now();
    }
    
    // Extend by 1 year from the current expiry date or now, whichever is later
    DateTime newDate = currentValidUntil.isAfter(DateTime.now()) 
        ? currentValidUntil.add(const Duration(days: 365)) 
        : DateTime.now().add(const Duration(days: 365));

    await FirebaseFirestore.instance.collection('institutions').doc(docId).update({
      'subscription_valid_until': newDate.toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription extended by 1 year.')),
    );
  }

  Future<void> _deleteInstitution(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Institution'),
        content: const Text('Are you sure you want to completely delete this institution? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('institutions').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Institution deleted.')),
      );
    }
  }

  Future<void> _impersonateAdmin(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('institution_code', docId);
    await prefs.setString('role', 'admin');
    
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Admin Console'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('institutions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No institutions registered yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String name = data['name'] ?? 'Unknown';
              final String code = doc.id;
              final bool isBlocked = data['is_blocked'] ?? false;
              final String validUntilStr = data['subscription_valid_until'] ?? DateTime.now().toIso8601String();
              
              DateTime validUntil;
              try {
                validUntil = DateTime.parse(validUntilStr);
              } catch(e) {
                validUntil = DateTime.now();
              }
              
              bool isExpired = validUntil.isBefore(DateTime.now());
              String formattedDate = DateFormat('MMM dd, yyyy').format(validUntil);

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isBlocked)
                            const Chip(label: Text('BLOCKED', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.red)
                          else if (isExpired)
                            const Chip(label: Text('EXPIRED', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.orange)
                          else
                            const Chip(label: Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Code: $code', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text('Subscription Valid Until: $formattedDate', style: TextStyle(color: isExpired ? Colors.red : Colors.black87)),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                            color: isBlocked ? Colors.green : Colors.orange,
                            tooltip: isBlocked ? 'Unblock' : 'Block',
                            onPressed: () => _toggleBlockStatus(code, isBlocked),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_business),
                            color: Colors.blue,
                            tooltip: 'Extend Validity (1 Year)',
                            onPressed: () => _extendValidity(code, validUntilStr),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            tooltip: 'Delete Institution',
                            onPressed: () => _deleteInstitution(code),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Impersonate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _impersonateAdmin(code),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
