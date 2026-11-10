import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum FirebaseSetupStatus { ready, notConfigured, unavailable }

/// SDK initialization is local configuration, not authentication or a successful
/// connection to Firestore. It never grants a pricing session or writes data.
class FirebaseBootstrap {
  static const projectId = 'hyner-541ad';
  static const androidAppId = '1:746350362575:android:5927a4265e5de1b7419cba';

  /// Android uses the resources generated from google-services.json. No web app
  /// is registered for this project yet; Android options must not be reused on
  /// web. The app can render and calculate locally while this future is pending.
  static Future<FirebaseSetupStatus> initialize({
    TargetPlatform? platform,
    bool? isWeb,
    Future<FirebaseOptions> Function()? initializeSdk,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if ((isWeb ?? kIsWeb) ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.android) {
      return FirebaseSetupStatus.notConfigured;
    }

    try {
      final options = await (initializeSdk ?? _initializeAndroid)().timeout(
        timeout,
      );
      if (options.projectId != projectId || options.appId != androidAppId) {
        return FirebaseSetupStatus.unavailable;
      }
      return FirebaseSetupStatus.ready;
    } catch (_) {
      // Do not substitute an identity, business scope, or permission on failure.
      // A timed-out platform call can finish later; it still cannot start sync.
      return FirebaseSetupStatus.unavailable;
    }
  }

  static Future<FirebaseOptions> _initializeAndroid() async =>
      (await Firebase.initializeApp()).options;
}
