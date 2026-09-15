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
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // 2. Fetch latest release from GitHub API
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagVersion = _normalizeVersion(data['tag_name'].toString());

        // 3. Compare the major, minor, and patch components numerically.
        if (_isNewerVersion(currentVersion, tagVersion)) {
          // Find the APK download URL from the release assets
          final assets = (data['assets'] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
          final apkAssets = assets.where((asset) {
            final name = asset['name'];
            return name is String && name.endsWith('.apk');
          });
          final apkAsset = apkAssets.isEmpty ? null : apkAssets.first;

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
    final downloadProgress = ValueNotifier<double?>(0);

    // Show a loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<double?>(
        valueListenable: downloadProgress,
        builder: (context, progress, child) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                progress == null
                    ? 'Downloading update...'
                    : 'Downloading update... ${(progress * 100).toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      ),
    );

    try {
      // Create a temporary file path
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/app-update-$version.apk';

      final file = File(savePath);
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw HttpException('Update download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final output = file.openWrite();

      await response.stream.forEach((chunk) {
        output.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes != null && totalBytes > 0) {
          downloadProgress.value = receivedBytes / totalBytes;
        }
      });
      await output.close();
      downloadProgress.value = 1;

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
    } finally {
      downloadProgress.dispose();
    }
  }

  /// Helper to check if GitHub version is greater than current version
  static bool _isNewerVersion(String current, String github) {
    final currentParts = _parseVersion(current);
    final githubParts = _parseVersion(github);

    if (currentParts == null || githubParts == null) {
      debugPrint('Unable to compare app versions: "$current" and "$github"');
      return false;
    }

    for (var i = 0; i < currentParts.length; i++) {
      if (githubParts[i] > currentParts[i]) return true;
      if (githubParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static String _normalizeVersion(String version) {
    return version.replaceFirst(RegExp(r'^v'), '');
  }

  static List<int>? _parseVersion(String version) {
    final normalized = _normalizeVersion(version);
    final versionParts = normalized.split('+');
    final parts = versionParts.first.split('.');

    if (parts.length != 3 || parts.any((part) => int.tryParse(part) == null)) {
      return null;
    }

    final parsed = parts.map(int.parse).toList();
    if (versionParts.length > 1) {
      final buildNumber = int.tryParse(versionParts[1]);
      if (buildNumber == null) return null;
      parsed.add(buildNumber);
    } else {
      parsed.add(0);
    }
    return parsed;
  }
}
