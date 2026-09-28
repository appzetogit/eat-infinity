import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';

/// Thin wrapper around the raw `/food/auth/restaurant/*` + `/food/restaurant/current`
/// endpoints. Returns the already-unwrapped `data` payload (see the Dio
/// `onResponse` interceptor) as a `Map<String, dynamic>`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _dio.post(
      '/food/auth/restaurant/request-otp',
      data: {'phone': phone},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
    String platform = 'mobile',
  }) async {
    final response = await _dio.post(
      '/food/auth/restaurant/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        'platform': platform,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getCurrentRestaurant() async {
    final response = await _dio.get('/food/restaurant/current');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout({String? refreshToken, String? fcmToken}) async {
    await _dio.post(
      '/food/auth/logout',
      data: {
        'refreshToken': refreshToken,
        'fcmToken': fcmToken,
        'platform': 'mobile',
      },
    );
  }

  /// Deletes the signed-in restaurant account.
  ///
  /// The backend exposes no self-service deletion route for restaurants — the
  /// API spec lists it as *"none: deletion is deleteCurrentRestaurantAccount,
  /// not routed publicly"*, unlike `DELETE /food/user/profile` for customers
  /// and `DELETE /food/delivery/profile/account` for riders. This used to try
  /// three candidate paths in turn and let the third one's 404 escape as a raw
  /// DioException, which read to the caller as a transient network error rather
  /// than a feature the server does not implement.
  ///
  /// Kept as a real request rather than an outright throw so the app picks the
  /// route up automatically if a deployment adds it; only the all-404 case is
  /// translated into something a human can act on.
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/food/auth/restaurant/account');
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      throw ApiException(
        'Account deletion is not available from the app yet. '
        'Please contact support to close your restaurant account.',
        statusCode: 404,
      );
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
