import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_user_application/app.dart';
import 'package:food_user_application/core/services/fcm_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Surface framework-caught errors (widget build/layout/paint) instead of
    // letting them silently die, without taking the app down.
    FlutterError.onError = FlutterError.presentError;
    // Catches everything else (async errors outside a caught Future) so a
    // stray exception can't reach the platform embedder as a fatal crash.
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
      return true;
    };

    try {
      // No `options:` — both platforms already auto-initialize the default app
      // from their config file (android/app/google-services.json,
      // ios/Runner/GoogleService-Info.plist), and firebase_core throws
      // `duplicate-app` when Dart then hands it options whose apiKey differs
      // from that app's. The hardcoded AppConstants values named a different
      // Firebase project entirely, so this call threw on every single launch —
      // and took the line below down with it, leaving the background handler
      // unregistered. That is why a new order raised nothing whenever the app
      // was backgrounded or killed: no handler, no local notification.
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e, s) {
      // On devices with missing/outdated Google Play Services (common on
      // budget phones) this used to throw here, before runApp — killing the
      // app on launch with no UI shown at all. Push notifications simply
      // won't work if this fails; that beats a crash on every open.
      if (kDebugMode) debugPrint('Firebase init failed: $e\n$s');
    }

    runApp(const ProviderScope(child: FoodUserApplication()));
  }, (error, stack) {
    if (kDebugMode) debugPrint('Uncaught zone error: $error\n$stack');
  });
}
