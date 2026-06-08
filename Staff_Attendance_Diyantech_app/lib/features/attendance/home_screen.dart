import 'package:flutter/material.dart';
import 'package:staff_attendance_app/features/attendance/scanner_screen.dart';
import 'package:staff_attendance_app/features/admin/dashboard_screen.dart';
import 'package:staff_attendance_app/features/admin/register_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_settings_screen.dart';
import 'package:staff_attendance_app/features/admin/admin_auth_screen.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:staff_attendance_app/core/widgets/footer_widget.dart';
import 'package:staff_attendance_app/services/update_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  final List<Widget> _screens = [
    const ScannerScreen(),
    const DashboardScreen(),
    const RegisterScreen(),
  ];

  bool _isAdminAuthenticated = false;

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    
    if (index == 1 || index == 2) {
      setState(() {
        _isAdminAuthenticated = false; // Always demand auth when switching to these tabs
        _currentIndex = index;
      });
      return;
    }
    setState(() {
      _currentIndex = index;
      _isAdminAuthenticated = false;
    });
  }

  void switchToTab(int index) {
    if (mounted) {
      _onTabTapped(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Scanner', 'Dashboard', 'Register'][_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: (_currentIndex == 1 && _isAdminAuthenticated) ? Drawer(
        backgroundColor: AppTheme.cardColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo removed for Diyantech
                  SizedBox(height: 10),
                  Text("Diyantech Solutions Pvt Ltd", style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Smart Attendance System", style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accentCyan),
              title: const Text('Scanner', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _onTabTapped(0); },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: AppTheme.accentEmerald),
              title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _onTabTapped(1); },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.orangeAccent),
              title: const Text('Register Employee', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _onTabTapped(2); },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Admin Settings', style: TextStyle(color: Colors.white)),
              onTap: () { 
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
              },
            ),
          ],
        ),
      ) : null,
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: (_currentIndex == 1 || _currentIndex == 2) && !_isAdminAuthenticated
                  ? AdminAuthScreen(
                      key: const ValueKey("AuthScreen"),
                      onAuthenticated: () {
                        setState(() {
                          _isAdminAuthenticated = true;
                        });
                      },
                    )
                  : SizedBox(
                      key: ValueKey(_currentIndex),
                      child: _screens[_currentIndex],
                    ),
            ),
          ),
          const AppFooter(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Scanner"),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: "Register"),
        ],
      ),
    );
  }
}
