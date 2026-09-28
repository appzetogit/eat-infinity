import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/auth_verify_result.dart';
import 'models/delivery_partner.dart';

class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<Result<String, AppError>> requestOtp(String phone) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.requestOtp,
        data: {'phone': phone},
      );
      final message = res.data is Map<String, dynamic>
          ? (res.data['message'] as String? ??
                res.data['data']?['message'] as String? ??
                'OTP sent successfully')
          : 'OTP sent successfully';
      return Result.success(message);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    } catch (e) {
      return Result.failure(
        NetworkError('Failed to request OTP: ${e.toString()}'),
      );
    }
  }

  Future<Result<AuthVerifyResult, AppError>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.verifyOtp,
        data: {
          'phone': phone,
          'otp': otp,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
          'platform': 'mobile',
        },
      );
      final rawData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final data = (rawData['data'] is Map<String, dynamic>)
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      final result = AuthVerifyResult.fromJson(data);
      if (result.isLoggedIn) {
        await _tokenStorage.saveTokens(
          accessToken: result.accessToken!,
          refreshToken: result.refreshToken ?? '',
        );
      }
      return Result.success(result);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    } catch (e) {
      return Result.failure(
        NetworkError('Verification error: ${e.toString()}'),
      );
    }
  }

  Future<Result<DeliveryPartner, AppError>> getMe() async {
    try {
      final res = await _dio.get(ApiEndpoints.me);
      final rawData = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final data = (rawData['data'] is Map<String, dynamic>)
          ? rawData['data'] as Map<String, dynamic>
          : rawData;
      final userJson = ((data['user'] as Map<String, dynamic>?) ?? data);
      return Result.success(DeliveryPartner.fromJson(userJson));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    } catch (e) {
      return Result.failure(
        NetworkError('Failed to get profile: ${e.toString()}'),
      );
    }
  }

  Future<Result<DeliveryPartner, AppError>> register(
    FormData formData,
  ) async {
    try {
      final res = await _dio.post(ApiEndpoints.register, data: formData);
      final data = (res.data['data'] as Map<String, dynamic>?) ??
          (res.data as Map<String, dynamic>? ?? const {});

      final accessToken = data['accessToken'] as String? ??
          res.data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String? ??
          res.data['refreshToken'] as String?;

      if (accessToken != null && accessToken.isNotEmpty) {
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken ?? '',
        );
      }

      final userJson = ((data['user'] as Map<String, dynamic>?) ?? data);
      return Result.success(DeliveryPartner.fromJson(userJson));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    } catch (e) {
      return Result.failure(
        NetworkError('Registration error: ${e.toString()}'),
      );
    }
  }

  Future<Result<bool, AppError>> checkVehicleAvailable(String number) async {
    try {
      final res = await _dio.get(ApiEndpoints.checkVehicle(number));
      return Result.success(res.data['isAvailable'] as bool? ?? true);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      await _dio.post(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Ignore network errors on logout — tokens are cleared locally regardless.
    }
    await _tokenStorage.clear();
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    final message = responseData is Map<String, dynamic>
        ? (responseData['message'] as String? ??
              responseData['error'] as String? ??
              e.message ??
              'Something went wrong')
        : (e.message ?? 'Something went wrong');
    return NetworkError(message);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider), ref.read(tokenStorageProvider));
});
