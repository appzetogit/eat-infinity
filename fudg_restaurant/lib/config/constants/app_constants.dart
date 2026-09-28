class AppConstants {
  static const String title = 'Eatinfinity Restaurant Partner';

  /// Backend origin.
  ///
  /// Overridable at build time so a staging build never needs a code edit:
  ///   flutter build apk --dart-define=API_HOST=https://api.example.com
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://amal.buytogetherindia.com',
  );

  /// Backend REST API base URL (all endpoints are mounted under `/api/v1`).
  static const String baseUrl = '$apiHost/api/v1';

  /// Socket.IO server base (same host, root path — see `Backend/socket-server.js`).
  static const String socketUrl = apiHost;

  /// Turns a backend-relative upload path (`/uploads/...`) into a full URL,
  /// leaving absolute and data URLs untouched.
  ///
  /// The API returns relative paths (`UPLOAD_BASE_URL=/uploads` in production),
  /// so every image URL off the wire must go through this or it renders broken.
  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  // Firebase options are NOT declared here. They live in
  // android/app/google-services.json and ios/Runner/GoogleService-Info.plist,
  // which both platforms read automatically. A second copy in Dart only gave
  // the two a chance to disagree — and they did, which silently broke push.

  /// Google Maps API key (Maps SDK for Android/iOS + Geocoding API enabled).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  static const String stripPublishKey = '';

  static String packageName = 'com.fooddelivery.app';
  static String signKey = '';
}
