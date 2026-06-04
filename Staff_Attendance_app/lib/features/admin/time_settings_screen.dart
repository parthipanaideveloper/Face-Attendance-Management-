import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_attendance_app/core/theme/app_theme.dart';

class TimeSettingsScreen extends StatefulWidget {
  const TimeSettingsScreen({super.key});

  @override
  State<TimeSettingsScreen> createState() => _TimeSettingsScreenState();
}

class _TimeSettingsScreenState extends State<TimeSettingsScreen> {
  TimeOfDay _teachingIn = const TimeOfDay(hour: 9, minute: 10);
  TimeOfDay _teachingOut = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _nonTeachingIn = const TimeOfDay(hour: 9, minute: 40);
  TimeOfDay _nonTeachingOut = const TimeOfDay(hour: 16, minute: 30);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _teachingIn = _timeFromMinutes(prefs.getInt('teaching_in_limit') ?? (9 * 60 + 10));
      _teachingOut = _timeFromMinutes(prefs.getInt('teaching_out_limit') ?? (16 * 60 + 0));
      _nonTeachingIn = _timeFromMinutes(prefs.getInt('non_teaching_in_limit') ?? (9 * 60 + 40));
      _nonTeachingOut = _timeFromMinutes(prefs.getInt('non_teaching_out_limit') ?? (16 * 60 + 30));
      _isLoading = false;
    });
  }

  TimeOfDay _timeFromMinutes(int mins) {
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('teaching_in_limit', _teachingIn.hour * 60 + _teachingIn.minute);
    await prefs.setInt('teaching_out_limit', _teachingOut.hour * 60 + _teachingOut.minute);
    await prefs.setInt('non_teaching_in_limit', _nonTeachingIn.hour * 60 + _nonTeachingIn.minute);
    await prefs.setInt('non_teaching_out_limit', _nonTeachingOut.hour * 60 + _nonTeachingOut.minute);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Time Settings Saved Successfully!"), backgroundColor: AppTheme.accentEmerald),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _pickTime(BuildContext context, TimeOfDay initial, Function(TimeOfDay) onPicked) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Widget _buildTimeSelector(String title, TimeOfDay time, Function(TimeOfDay) onPicked) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(time.format(context), style: const TextStyle(color: AppTheme.accentCyan, fontSize: 16)),
      trailing: const Icon(Icons.access_time, color: Colors.orangeAccent),
      onTap: () => _pickTime(context, time, (picked) => setState(() => onPicked(picked))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppTheme.bgColor, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("Attendance Time Settings"),
        backgroundColor: AppTheme.cardColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Teaching Staff", style: TextStyle(color: AppTheme.accentCyan, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildTimeSelector("Morning In-Time (Cutoff)", _teachingIn, (t) => _teachingIn = t),
                const Divider(color: Colors.white24),
                _buildTimeSelector("Evening Out-Time", _teachingOut, (t) => _teachingOut = t),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          const Text("Non-Teaching Staff", style: TextStyle(color: AppTheme.accentCyan, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildTimeSelector("Morning In-Time (Cutoff)", _nonTeachingIn, (t) => _nonTeachingIn = t),
                const Divider(color: Colors.white24),
                _buildTimeSelector("Evening Out-Time", _nonTeachingOut, (t) => _nonTeachingOut = t),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Save Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
