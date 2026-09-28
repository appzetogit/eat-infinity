import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({required this.name, required this.lang, this.flag});
}

/// Central App Constants for the Eatinfinity user application.
class AppConstants {
  const AppConstants._();

  static const String title = 'Eatinfinity';
  static const String appName = 'Eatinfinity';

  /// Merchant name shown on the Razorpay checkout sheet.
  ///
  /// Without this Razorpay falls back to the legal entity registered on the
  /// account ("SWITCHEATS PRIVATE LIMITED"), which is not our consumer brand.
  static const String brandName = 'Eatinfinity';

  /// Public logo URL for the Razorpay sheet. Razorpay fetches this over the
  /// network, so a bundled asset cannot be used — it must be a hosted URL.
  /// Falls back to the backend's configured business logo when set.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');
  static const String appVersion = '1.0.0';

  /// Backend REST API host domain.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://amal.buytogetherindia.com',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$hostUrl/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: hostUrl,
  );

  /// Firebase project configuration for User App (com.minto.user).
  ///
  /// These are only a fallback for when `Firebase.initializeApp()` cannot read
  /// `google-services.json` (see `push_service.dart`). They previously held
  /// credentials for a different project (`flutterfoodapp-e6742`), so on that
  /// fallback path the app registered an FCM token against a project the
  /// backend never sends to — push would go silently missing rather than fail.
  /// Keep these in step with `android/app/google-services.json`.
  static String firebaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyCyKZnq1zsjDI_ALpsyh8QFeX71pESAMO8"
      : "ios firebase api key";

  static String get firbaseApiKey => firebaseApiKey;

  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:464440787714:android:45ea036dddfd77612df81b"
      : "ios firebase app id";

  static String firebaseMessagingSenderId = (kIsWeb || Platform.isAndroid)
      ? "464440787714"
      : "ios firebase sender id";

  static String get firebasemessagingSenderId => firebaseMessagingSenderId;

  static String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "minto-805bd"
      : "ios firebase project id";

  /// Realtime Database URL, used by `OrderRtdbDataSource` for live tracking.
  ///
  /// STALE: this points at `flutterfoodapp-e6742`, a different project. The
  /// app is now on `minto-805bd`, whose google-services.json does carry a
  /// `firebase_url` — but nothing writes order state to that database yet, so
  /// live tracking still runs over Socket.IO. Swap this for
  /// `https://minto-805bd-default-rtdb.firebaseio.com` once the backend
  /// actually publishes there, not before.
  static String firebaseDatabaseUrl =
      "https://flutterfoodapp-e6742-default-rtdb.firebaseio.com";

  /// Google Maps API key (Maps SDK + Geocoding API).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.minto.user';
  static String signKey = '';
}
