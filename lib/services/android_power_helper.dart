import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';

class AndroidPowerHelper {
  AndroidPowerHelper._();

  static bool get isSupported => Platform.isAndroid;

  static Future<void> openIgnoreBatteryOptimizationSettings() async {
    if (!isSupported) {
      return;
    }
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  static Future<void> requestIgnoreBatteryOptimizations(String packageName) async {
    if (!isSupported) {
      return;
    }
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:$packageName',
    );
    await intent.launch();
  }
}
