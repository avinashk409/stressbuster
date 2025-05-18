import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class ProdConfig {
  static Future<void> initialize() async {
    // Enable Crashlytics in production
    if (!kDebugMode) {
      // Initialize App Check with production providers
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
    }
  }
} 