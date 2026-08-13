import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebviewSettingsHelper {
  static Future<InAppWebViewSettings> getDefaultSettings() async {
    final isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    bool useAlgorithmic = false;
    ForceDark useForceDark = ForceDark.AUTO;

    if (Platform.isAndroid && isDarkMode) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        useAlgorithmic = true;
        useForceDark = ForceDark.AUTO;
      } else if (sdkInt >= 29) {
        useAlgorithmic = false;
        useForceDark = ForceDark.ON;
      }
    }

    return InAppWebViewSettings(
      algorithmicDarkeningAllowed: useAlgorithmic,
      forceDark: useForceDark,
      transparentBackground: false,
      preferredContentMode: UserPreferredContentMode.RECOMMENDED,
      javaScriptEnabled: true,
      overScrollMode: OverScrollMode.NEVER,
      useOnDownloadStart: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    );
  }
}