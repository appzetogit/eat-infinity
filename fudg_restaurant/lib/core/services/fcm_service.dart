import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';
import 'package:food_user_application/core/services/new_order_overlay_bridge.dart';
import 'package:food_user_application/core/services/order_notification_action_handler.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/views/incoming_order_dialog.dart';

const _kOrderNotificationTypes = {
  'new_order',
  'order_status_update',
  'order_cancelled',
  'cancel_order',
  'order_accepted',
  'order_rejected',
};

String _encodeTapPayload({String? type, String? orderId}) =>
    jsonEncode({'type': type, 'orderId': orderId});

Map<String, dynamic>? _decodeTapPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String? _orderIdFromData(Map<String, dynamic> data) {
  final id = (data['orderMongoId'] ?? data['orderId'])?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Body text for a new-order notification, composed from the data map when the
/// server did not send a ready-made one.
///
/// A data-only push has no `notification` block, so `message.notification` is
/// null and the only text available is whatever sits in `data`. Falling back to
/// an empty string there produced a notification with a title and no content —
/// which reads as a broken push rather than a missing field. The order details
/// are always present in `data`, so build the text from them instead of
/// depending on the server to pre-format it.
String buildOrderNotificationBody(Map<String, dynamic> data) {
  final provided = _nonEmpty(data['body']);
  if (provided != null) return provided;

  final lines = <String>[];
  final items = _nonEmpty(data['itemsList']);
  final total = _nonEmpty(data['total']);
  final customer = _nonEmpty(data['customerName']);
  final address = _nonEmpty(data['address']);
  final payment = _nonEmpty(data['paymentMethod']);

  if (items != null) lines.add(items);
  if (total != null) {
    lines.add(
      payment != null ? 'Total: Rs.$total  ·  $payment' : 'Total: Rs.$total',
    );
  }
  if (customer != null) lines.add(customer);
  if (address != null) lines.add(address);

  // Last resort: an order reference beats a blank notification.
  if (lines.isEmpty) {
    final ref = _nonEmpty(data['orderDisplayId']) ?? _nonEmpty(data['orderId']);
    if (ref != null) lines.add('Order #$ref is waiting for review.');
  }
  return lines.join('\n');
}

/// Must stay top-level (not a class method) — Firebase invokes this in a
/// separate background isolate that has no access to app state, so it needs
/// its own Firebase configuration before touching any Firebase API.
///
/// `new_order` pushes to the restaurant are sent `dataOnly` (no
/// `notification` block) precisely so the OS never auto-displays a plain
/// alert here — that path can't carry the Accept/Reject action buttons. This
/// handler builds that local notification itself instead. Other push types
/// still include a `notification` block and are shown by the OS as before,
/// so nothing else needs to happen here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      // Same reason as main.dart: let the platform config file supply the
      // options. Passing mismatched ones here threw before show() was reached.
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Best-effort — the OS-rendered notification doesn't depend on this.
  }

  if (message.data['type']?.toString() != 'new_order') return;

  if (kDebugMode) {
    debugPrint('[FCM background] new_order push received: ${message.data}');
  }

  try {
    // Fresh isolate — this instance hasn't been initialized yet. The
    // `onResponse` callback given here only fires for the plain-tap case
    // (never for the Accept/Reject actions, which always route through
    // `notificationBackgroundResponseHandler` regardless of app state), and
    // this isolate is torn down right after this function returns, so there
    // is nothing useful to do with a tap here.
    // requestPermission: false — no Activity exists in this isolate, and asking
    // there can throw and abort the whole handler before show() runs.
    await LocalNotificationService.instance.initialize(
      onResponse: (_) {},
      requestPermission: false,
    );
    final orderId = _orderIdFromData(message.data);
    final shown = await LocalNotificationService.instance.show(
      title: _nonEmpty(message.data['title']) ?? 'New order received',
      body: buildOrderNotificationBody(message.data),
      payload: _encodeTapPayload(type: 'new_order', orderId: orderId),
      isNewOrder: true,
      // Lets NewOrderOverlay take this notification down when its card is up.
      orderId: orderId,
    );

    if (kDebugMode) {
      debugPrint('[FCM background] LocalNotificationService.show() returned $shown');
    }

    // Only take down the OS-rendered copy once ours is provably on screen.
    // Ordering alone was not enough: show() used to report success even when it
    // had failed or was never initialized, so this ran anyway and removed the
    // only alert left. The tag is set by the backend and the two must agree.
    if (shown) await cancelFcmTrayCopy(orderId);
  } catch (e) {
    // Deliberately leaves the OS tray copy in place — it is the only thing
    // left telling the restaurant an order arrived.
    if (kDebugMode) {
      debugPrint('[FCM background] new_order handling threw: $e');
    }
  }
}

/// Removes the OS-rendered copy of the new-order push.
///
/// The push is hybrid: FCM posts a tray notification itself, tagged
/// `order_<id>` by the backend, so ROMs that refuse to start the app in the
/// background still alert the restaurant. Wherever the app's own alert does
/// show, this takes the tray copy down so only one is visible. FCM posts
/// tagged notifications under id 0.
Future<void> cancelFcmTrayCopy(String? orderId) async {
  if (orderId == null || orderId.isEmpty) return;
  try {
    await FlutterLocalNotificationsPlugin().cancel(0, tag: 'order_$orderId');
  } catch (_) {
    // Worst case the tray copy stays — a duplicate, not a missed order.
  }
}

/// Wraps device push-token registration against the two endpoints the
/// backend exposes for restaurant partners: `/fcm-tokens/mobile/save` and
/// `/fcm-tokens/remove`. Token saves are best-effort — a failure here should
/// never block login or app startup.
class FcmService {
  FcmService(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _foregroundHandlingWired = false;

  Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Permission prompt failing (e.g. unsupported platform) shouldn't crash startup.
    }
  }

  /// Why the last registration attempt failed, for the diagnostics screen.
  ///
  /// Every step here used to swallow its error, so a restaurant with no push
  /// notifications produced no evidence anywhere — on the device or the server.
  /// Suvio had logged in twelve times with zero tokens saved and nothing said
  /// why. Keeping the reason costs nothing and turns "notifications don't work"
  /// into an answerable question.
  static String? lastRegistrationError;

  Future<String?> currentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        lastRegistrationError = 'FCM returned no token for this device';
      }
      return token;
    } catch (e) {
      lastRegistrationError = 'FCM getToken failed: $e';
      if (kDebugMode) debugPrint('[FCM] getToken failed: $e');
      return null;
    }
  }

  /// Registers this device against the logged-in restaurant.
  ///
  /// Retried, because the common failure is a race rather than a permanent
  /// fault: this runs immediately after login, and a token save that lands
  /// before the access token is readable comes back 401 and was then simply
  /// dropped — leaving the restaurant permanently unreachable until the next
  /// login happened to win the race. Push is how a restaurant learns it has an
  /// order, so one silent miss is worth three cheap retries.
  Future<bool> saveTokenToServer() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      final token = await currentToken();
      if (token == null || token.isEmpty) continue;

      try {
        await _dio.post('/fcm-tokens/mobile/save', data: {'token': token});
        lastRegistrationError = null;
        if (kDebugMode) debugPrint('[FCM] token registered');
        return true;
      } catch (e) {
        lastRegistrationError = 'Token save failed: $e';
        if (kDebugMode)
          debugPrint('[FCM] save attempt ${attempt + 1} failed: $e');
      }
    }
    return false;
  }

  Future<void> removeTokenFromServer() async {
    final token = await currentToken();
    if (token == null || token.isEmpty) return;
    try {
      await _dio.delete('/fcm-tokens/remove', data: {'token': token});
    } catch (_) {
      // Best-effort — logging out should proceed regardless.
    }
  }

  void listenForTokenRefresh(void Function() onRefresh) {
    _messaging.onTokenRefresh.listen((_) => onRefresh());
  }

  /// Sets up everything needed for a push to actually be *visible*:
  /// - foreground messages (never auto-displayed by the OS) get shown via
  ///   [LocalNotificationService], and a `new_order` also pops an immediate
  ///   in-app accept/reject dialog so the restaurant doesn't have to notice
  ///   and tap a system notification while the app is already open.
  /// - taps on a background/terminated notification, and taps on the local
  ///   one we show ourselves, both route through [_navigateForType] straight
  ///   to the Order Details screen.
  ///
  /// Safe to call multiple times — wiring only happens once.
  Future<void> initForegroundHandling() async {
    if (_foregroundHandlingWired) return;
    _foregroundHandlingWired = true;

    await LocalNotificationService.instance.initialize(
      onResponse: _handleNotificationResponse,
    );

    unawaited(_askForOverlayPermissionOnce());

    // The OS can rotate the FCM token at any time (rare, but it happens) —
    // keep the backend's copy in sync or pushes silently stop working.
    listenForTokenRefresh(saveTokenToServer);

    // Explicitly save the token on initialization in case it wasn't saved yet
    await saveTokenToServer();

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final type = message.data['type']?.toString();
      final orderId = _orderIdFromData(message.data);
      final isNewOrder = type == 'new_order';

      final title =
          _nonEmpty(notification?.title) ??
          _nonEmpty(message.data['title']) ??
          (isNewOrder ? 'New order received' : 'Eatinfinity Restaurant Partner');
      final body = isNewOrder
          ? buildOrderNotificationBody(message.data)
          : (_nonEmpty(notification?.body) ??
                _nonEmpty(message.data['body']) ??
                '');

      LocalNotificationService.instance
          .show(
            title: title,
            body: body,
            payload: _encodeTapPayload(type: type, orderId: orderId),
            isNewOrder: isNewOrder,
            orderId: orderId,
            // The app is already in the foreground here, about to show its own
            // full-screen "new order" dialog below — a full-screen-intent
            // notification on top of that races the OS's screen takeover against
            // Flutter's, which is what was hanging the app/phone on order receipt.
            fullScreenIntent: false,
            // The dialog below rings on a loop until it is answered. Letting
            // the channel chime as well just plays the same file twice.
            silent: isNewOrder,
          )
          .then((shown) {
            if (kDebugMode && isNewOrder) {
              debugPrint('[FCM foreground] LocalNotificationService.show() returned $shown');
            }
            // Cancelled only once ours is provably on screen — same reason as the
            // background handler: assuming success turns any failure to show into
            // no notification at all.
            if (isNewOrder && shown) cancelFcmTrayCopy(orderId);
          });

      if (_kOrderNotificationTypes.contains(type)) {
        _ref.read(liveOrdersControllerProvider.notifier).refresh();
      } else {
        _ref.read(notificationsControllerProvider.notifier).refresh();
      }

      // App is already open — surface the order immediately instead of
      // making the restaurant dig it out of the notification tray.
      if (isNewOrder && orderId != null) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          showIncomingOrderDialog(context, orderId: orderId);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateForType(
        message.data['type']?.toString(),
        _orderIdFromData(message.data),
      );
    });

    // Accept launches the app, so when it was TERMINATED the button press arrives
    // here rather than at onResponse — flutter_local_notifications delivers the
    // launching interaction through getNotificationAppLaunchDetails, not the live
    // callback. Without this the app simply opened and the order was never
    // accepted.
    final launchDetails = await LocalNotificationService.instance
        .launchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }

    // The overlay hands its order over through the launch Intent, which Flutter
    // only sees when the activity is (re)created or re-delivered. Checked on
    // cold start and again on every resume, because tapping the card while the
    // app is merely backgrounded produces the second case, not the first.
    await _consumeOverlayLaunch();
    _overlayLifecycle ??= AppLifecycleListener(
      onResume: () => unawaited(_consumeOverlayLaunch()),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final type = initialMessage.data['type']?.toString();
      final orderId = _orderIdFromData(initialMessage.data);
      // This runs inside the same login/session-restore chain that the
      // splash screen awaits before doing its own default `go('/orders')` —
      // deferring a beat lets our deep link win that race instead of being
      // immediately overwritten.
      Future.delayed(const Duration(milliseconds: 400), () {
        _navigateForType(type, orderId);
      });
    }
  }

  /// Sends the restaurant to "Display over other apps" the first time only.
  ///
  /// Without this grant a new order arriving while the phone is unlocked can
  /// only be a heads-up banner — Android refuses to let a full-screen intent
  /// take over a device someone is using, so the overlay is the only thing that
  /// can show the order over whatever they are doing.
  ///
  /// Asked once and never again: there is no API to grant it from here, so a
  /// restaurant who declines would otherwise be thrown into Settings on every
  /// single launch. They can still turn it on from the app's own settings.
  Future<void> _askForOverlayPermissionOnce() async {
    if (await NewOrderOverlayBridge.hasPermission()) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_overlayPromptShownKey) ?? false) return;
    await prefs.setBool(_overlayPromptShownKey, true);
    await NewOrderOverlayBridge.requestPermission();
  }

  static const _overlayPromptShownKey = 'overlay_permission_prompt_shown';

  AppLifecycleListener? _overlayLifecycle;

  /// Picks up an order the restaurant answered on the native overlay.
  ///
  /// ACCEPT is routed through the same [_handleNotificationResponse] the
  /// notification's Accept button uses, so there is still exactly one
  /// implementation of accepting an order. A tap on the card body means "show me
  /// this" rather than "take it", so it opens the usual dialog to decide in.
  Future<void> _consumeOverlayLaunch() async {
    final launch = await NewOrderOverlayBridge.consumeLaunchOrder();
    if (launch == null) return;

    if (launch.autoAccept) {
      _handleNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: orderAcceptActionId,
          payload: _encodeTapPayload(type: 'new_order', orderId: launch.orderId),
        ),
      );
      return;
    }

    _ref.read(liveOrdersControllerProvider.notifier).refresh();
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      showIncomingOrderDialog(context, orderId: launch.orderId);
    } else {
      _navigateForType('new_order', launch.orderId);
    }
  }

  /// Routes an Accept/Reject action button or a plain notification tap.
  ///
  /// Shared by the live-tap callback and the cold-start path, because which of the
  /// two fires depends only on whether the app happened to be running — and both
  /// have to perform the action, not merely open the order.
  ///
  /// The action is delegated to [notificationBackgroundResponseHandler] so there is
  /// exactly one implementation: it is self-contained (reads the token from secure
  /// storage, uses its own Dio) and behaves identically in either isolate.
  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final isAccept = actionId == orderAcceptActionId;
    final isReject = actionId == orderRejectActionId;

    if (isAccept || isReject) {
      unawaited(
        notificationBackgroundResponseHandler(response).then((_) async {
          // The order list is stale the moment the status changes. Awaited
          // now: OrderDetailsScreen's initState takes a fast path straight
          // off this cache, so navigating before it lands re-shows the order
          // with its pre-accept status — and the Accept button with it.
          await _ref.read(liveOrdersControllerProvider.notifier).refresh();

          // Accept opens the app, so land on the order just taken on. Reject
          // stays put — there is nothing left to look at.
          if (isAccept) {
            final decoded = _decodeTapPayload(response.payload);
            _navigateForType('new_order', decoded?['orderId'] as String?);
          }
        }),
      );
      return;
    }

    final decoded = _decodeTapPayload(response.payload);
    _navigateForType(
      decoded?['type'] as String?,
      decoded?['orderId'] as String?,
    );
  }

  void _navigateForType(String? type, String? orderId) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    if (_kOrderNotificationTypes.contains(type)) {
      if (orderId != null && orderId.isNotEmpty) {
        GoRouter.of(context).push('/order-details/$orderId');
      } else {
        GoRouter.of(context).go('/orders');
      }
    } else {
      GoRouter.of(context).go('/notifications');
    }
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.watch(dioProvider), ref);
});
