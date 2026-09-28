import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] for persisting auth tokens across app restarts.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _fcmTokenKey = 'fcm_token';

  /// The phone number the partner just proved they own, kept between
  /// verify-otp and register.
  ///
  /// [AuthNeedsRegistration] carries it in memory, but registration is a long
  /// form with camera round-trips: the process can be killed and rebuilt part
  /// way through, and the in-memory state goes with it. The screen then
  /// submitted an empty `phone` and the backend answered "Phone must be at
  /// least 8 digits", which is unactionable from the partner's side.
  static const _pendingPhoneKey = 'pending_registration_phone';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _fcmTokenKey, value: token);

  Future<String?> getFcmToken() => _storage.read(key: _fcmTokenKey);

  Future<void> savePendingRegistrationPhone(String phone) =>
      _storage.write(key: _pendingPhoneKey, value: phone);

  Future<String?> getPendingRegistrationPhone() =>
      _storage.read(key: _pendingPhoneKey);

  Future<void> clearPendingRegistrationPhone() =>
      _storage.delete(key: _pendingPhoneKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _pendingPhoneKey);
  }

  Future<bool> hasAccessToken() async =>
      (await getAccessToken())?.isNotEmpty ?? false;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
