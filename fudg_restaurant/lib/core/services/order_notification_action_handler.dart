import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_user_application/config/constants/app_constants.dart';

const orderAcceptActionId = 'accept_order';
const orderRejectActionId = 'reject_order';

Map<String, dynamic>? _decodePayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Handles taps on the Accept/Reject buttons of the new-order notification.
///
/// Accept is declared `showsUserInterface: true`, so Android routes it through
/// MainActivity and it also reaches the app's normal main-isolate handler.
/// Reject is `showsUserInterface: false` on purpose — declining should not drag
/// the restaurant out of whatever they were doing — so the OS dispatches it to
/// this callback in a fresh background isolate instead. That requires
/// ActionBroadcastReceiver to be declared in AndroidManifest.xml; without it the
/// press is swallowed and the order is never rejected.
///
/// Being a fresh isolate, there is no Riverpod container or cached Dio client
/// here: the access token is read straight from secure storage (the same key
/// `TokenStorage` uses) and the request goes out on a bare, one-off Dio.
@pragma('vm:entry-point')
Future<void> notificationBackgroundResponseHandler(
  NotificationResponse response,
) async {
  final actionId = response.actionId;
  if (actionId != orderAcceptActionId && actionId != orderRejectActionId) {
    return;
  }

  final orderId = _decodePayload(response.payload)?['orderId'] as String?;
  if (orderId == null || orderId.isEmpty) return;

  // A background isolate starts with no plugins registered. Without this,
  // FlutterSecureStorage below throws MissingPluginException — and that read is
  // the first plugin call in the function, so the whole handler dies before it
  // ever reaches the try/catch and the rejection is lost silently.
  //
  // Harmless and idempotent when the isolate already has them (the foreground
  // delegation path in FcmService calls this same function).
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {
    // Already initialized, or a platform where it does not apply.
  }

  final orderStatus = actionId == orderAcceptActionId
      ? 'confirmed'
      : 'cancelled_by_restaurant';

  try {
    const storage = FlutterSecureStorage();
    var token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) return;

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    try {
      await dio.patch(
        '/food/restaurant/orders/$orderId/status',
        data: {'orderStatus': orderStatus},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      // The access token is short-lived and this isolate has no interceptor
      // to refresh it (unlike the main app's dioProvider) — a token that
      // expired between the push arriving and the button being tapped made
      // this request 401 and silently drop the accept, leaving the order
      // stuck on 'created' so it demanded Accept again once the app opened.
      if (e.response?.statusCode != 401) rethrow;
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) return;
      final refreshResponse = await dio.post(
        '/food/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final body = refreshResponse.data;
      final payload = (body is Map && body['data'] != null) ? body['data'] : body;
      token = payload?['accessToken'] as String?;
      final newRefreshToken = payload?['refreshToken'] as String?;
      if (token == null || token.isEmpty) return;
      await storage.write(key: 'access_token', value: token);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await storage.write(key: 'refresh_token', value: newRefreshToken);
      }
      await dio.patch(
        '/food/restaurant/orders/$orderId/status',
        data: {'orderStatus': orderStatus},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }
  } catch (_) {
    // Best-effort — there is no UI running in this isolate to surface a retry.
    // The token read is inside the try now: it is a plugin call and can throw,
    // and an uncaught throw here takes the isolate down mid-action.
  }
}
