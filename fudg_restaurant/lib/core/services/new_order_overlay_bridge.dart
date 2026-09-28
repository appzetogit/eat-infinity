import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's side of the native incoming-order overlay.
///
/// The overlay itself is Kotlin: it is drawn straight from the FCM
/// `RemoteMessage`, with no Flutter engine involved. It exists because
/// `fullScreenIntent` — what the app used before — is only honoured by Android
/// while the screen is off or locked. With the phone unlocked and in the
/// restaurant's hand the OS downgrades it to a heads-up banner by design, which
/// is why the alert made a sound and never took over the screen.
///
/// This class only carries the small amount of state that has to come back the
/// other way: which order the restaurant tapped, and whether they hit Accept.
class NewOrderOverlayBridge {
  NewOrderOverlayBridge._();

  static const _channel = MethodChannel('app.mintorestaurant/new_order_overlay');

  static Future<T?> _call<T>(String method) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      // The channel lives on MainActivity, so it does not exist in the FCM
      // background isolate. Calling from there is a no-op, not a crash.
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[overlay] bridge $method failed: $e');
      return null;
    }
  }

  /// The order the restaurant tapped on the overlay, or null.
  ///
  /// Cleared natively on read, so a resume or a rotation cannot re-raise an
  /// order that has already been answered. `autoAccept` is true when they hit
  /// ACCEPT rather than tapping the card body.
  static Future<({String orderId, bool autoAccept})?> consumeLaunchOrder() async {
    final result = await _call<Map<Object?, Object?>>('consumeLaunchOrder');
    final orderId = result?['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return null;
    return (orderId: orderId, autoAccept: result?['autoAccept'] == true);
  }

  static Future<bool> hasPermission() async =>
      await _call<bool>('hasOverlayPermission') ?? false;

  /// Opens the system "Display over other apps" screen. There is no way to
  /// grant this without the user, so this is as far as the app can take it.
  static Future<void> requestPermission() => _call<bool>('requestOverlayPermission');

  /// Takes the floating card down — used when the in-app dialog takes over, so
  /// the restaurant is never looking at two copies of the same order.
  static Future<void> dismiss() => _call<bool>('dismissOverlay');
}
