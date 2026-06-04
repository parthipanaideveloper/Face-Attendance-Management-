import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. Fetch latest version info from Firestore
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('versioning')
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data() as Map<String, dynamic>;
        
        // Example: "1.0.1"
        String latestVersion = data['latest_version'] ?? currentVersion;
        // Example: 2
        int latestBuildNumber = data['latest_build_number'] ?? currentBuildNumber;
        // URL to your APK (e.g. Firebase Storage link or Google Drive direct link)
        String updateUrl = data['update_url'] ?? '';

        // 3. Compare build numbers (more reliable than version strings)
        if (latestBuildNumber > currentBuildNumber && updateUrl.isNotEmpty) {
           _showUpdateDialog(context, latestVersion, updateUrl);
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String latestVersion, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Set to true if you want users to be able to skip
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available!'),
          content: Text('A new version of the app ($latestVersion) is available with new features and fixes. Please update now.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Update Now'),
              onPressed: () async {
                final Uri url = Uri.parse(updateUrl);
                if (await canLaunchUrl(url)) {
                  // Launch in external browser so Android handles the APK download properly
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('Could not launch $updateUrl');
                }
              },
            ),
          ],
        );
      },
    );
  }
}
