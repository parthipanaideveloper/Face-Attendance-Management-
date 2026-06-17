import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/features/auth/login_screen.dart';
// Note: Assuming these feature screens exist or will be migrated. 
// Using placeholders for the actual feature navigations.

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({Key? key}) : super(key: key);

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  List<String> _enabledFeatures = [];
  bool _isLoading = true;

  final Map<String, Map<String, dynamic>> _featureDetails = {
    'take_attendance': {'title': 'Take Attendance', 'icon': Icons.camera_alt, 'color': Colors.blue},
    'register_student': {'title': 'Register Staff', 'icon': Icons.person_add, 'color': Colors.green},
    'view_attendance': {'title': 'View Records', 'icon': Icons.list_alt, 'color': Colors.orange},
    'notify_absentees': {'title': 'Notify Absentees', 'icon': Icons.sms, 'color': Colors.red},
    'send_email_summary': {'title': 'Email Summary', 'icon': Icons.email, 'color': Colors.purple},
    'send_daily_summary': {'title': 'Daily Summary', 'icon': Icons.summarize, 'color': Colors.teal},
  };

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabledFeatures = prefs.getStringList('enabled_features') ?? [];
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('enabled_features');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _navigateToFeature(String featureId) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigating to $featureId')));
    // Placeholder routing logic based on feature ID:
    /*
    switch (featureId) {
      case 'take_attendance': Navigator.push(...); break;
      ...
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _enabledFeatures.isEmpty
          ? const Center(
              child: Text(
                'No features have been assigned to your account.\\nPlease contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _enabledFeatures.length,
              itemBuilder: (context, index) {
                final featureId = _enabledFeatures[index];
                final feature = _featureDetails[featureId];

                if (feature == null) return const SizedBox.shrink();

                return InkWell(
                  onTap: () => _navigateToFeature(featureId),
                  child: Card(
                    elevation: 4,
                    color: feature['color'].withOpacity(0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(feature['icon'], size: 48, color: feature['color']),
                        const SizedBox(height: 16),
                        Text(
                          feature['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: feature['color'],
                          ),
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
