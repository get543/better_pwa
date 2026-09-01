import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:better_pwa/constants/app_constants.dart';

class AppUpdater {
  /// Checks if a new version is available on GitHub and prompts the user
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      // 2. Fetch latest release from GitHub API
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagVersion = data['tag_name'].toString().replaceAll('v', ''); // Removes 'v' from 'v1.0.0'

        // 3. Compare versions (Simple string comparison works for standard semantic versioning)
        if (_isNewerVersion(currentVersion, tagVersion)) {
          // Find the APK download URL from the release assets
          final assets = data['assets'] as List<dynamic>;
          final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null && context.mounted) {
            _showUpdateDialog(context, tagVersion, apkAsset['browser_download_url'].toString());
          }
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  /// Displays the update prompt
  static void _showUpdateDialog(BuildContext context, String newVersion, String downloadUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Force the user to choose
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('Version $newVersion is available. Would you like to update now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadAndInstall(context, downloadUrl, newVersion);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  /// Downloads the APK and triggers the Android Installer
  static Future<void> _downloadAndInstall(BuildContext context, String url, String version) async {
    // Show a loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Downloading update..."),
          ],
        ),
      ),
    );

    try {
      // Create a temporary file path
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/app-update-$version.apk';

      // Download the file
      final response = await http.get(Uri.parse(url));
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      // Close the loading dialog
      if (context.mounted) Navigator.pop(context);

      // Open the APK to trigger the Android installer
      final result = await OpenFilex.open(savePath);

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open installer: ${result.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Please check your connection.')),
        );
      }
    }
  }

  /// Helper to check if GitHub version is greater than current version
  static bool _isNewerVersion(String current, String github) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> githubParts = github.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (i >= githubParts.length) return false;
      if (githubParts[i] > currentParts[i]) return true;
      if (githubParts[i] < currentParts[i]) return false;
    }
    return githubParts.length > currentParts.length;
  }
}
