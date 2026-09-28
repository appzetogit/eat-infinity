import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() => message;
}

/// dio_client's interceptor always throws a [DioException] with the real
/// [ApiException] nested in `.error` — `e is ApiException` on the caught
/// exception is never true, which is why so many catch blocks were showing
/// their generic fallback instead of the backend's actual message.
extension ApiErrorMessage on Object {
  String apiMessage(String fallback) {
    final err = this;
    if (err is ApiException) return err.message;
    if (err is DioException && err.error is ApiException) {
      return (err.error as ApiException).message;
    }
    return fallback;
  }
}
