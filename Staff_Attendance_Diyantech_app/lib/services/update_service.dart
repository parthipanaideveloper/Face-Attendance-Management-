import 'package:flutter/material.dart';
// Removed firestore
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    // Offline Demo version: Auto-update is disabled because there is no cloud database
    return;
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
