import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_overlay_bridge.dart';
import 'package:food_user_application/core/services/referral_tracking_service.dart';
import 'package:food_user_application/core/theme/app_theme.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/active_trip_screen.dart';
import 'package:food_user_application/features/orders/presentation/widgets/minimized_trip_bar.dart';
import 'package:food_user_application/features/orders/presentation/screens/incoming_order_screen.dart';
import 'package:food_user_application/core/presentation/widgets/no_network_overlay.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/features/orders/presentation/screens/rate_customer_screen.dart';
import 'package:food_user_application/core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: QuickCommerceDeliveryApp()));
}

class QuickCommerceDeliveryApp extends ConsumerStatefulWidget {
  const QuickCommerceDeliveryApp({super.key});

  @override
  ConsumerState<QuickCommerceDeliveryApp> createState() =>
      _QuickCommerceDeliveryAppState();
}

class _QuickCommerceDeliveryAppState
    extends ConsumerState<QuickCommerceDeliveryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(fcmServiceProvider).initialize();
      ReferralTrackingService.initialize();
      _consumeOverlayHandoff();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Tapping the overlay resumes an already-running app rather than starting
      // it, so the handoff has to be picked up here as well as at launch.
      _consumeOverlayHandoff();
      // Re-checks the full-screen-intent permission on every resume,
      // not just cold start — catches a rider who dismissed the Settings
      // prompt the first time or toggled it manually while the app was
      // backgrounded (see FcmService.ensureAndroidAlertPermissions).
      ref.read(fcmServiceProvider).ensureAndroidAlertPermissions();

      // Re-register the push token on every resume, for the same reason.
      //
      // Registration only happened at launch and login, so a save that failed
      // — or a token FCM rotated while the app was closed — left the rider
      // silently unreachable until the next relaunch. Five of six online riders
      // were in exactly that state: apps running, GPS fresh, no token on the
      // server, and no order offers reaching them.
      //
      // Idempotent server-side ($addToSet), so repeating it is free.
      unawaited(ref.read(fcmServiceProvider).registerToken());
    }
  }

  /// Picks up whatever the native overlay left for us: the order the partner
  /// tapped, and any they rejected while the app was not running.
  Future<void> _consumeOverlayHandoff() async {
    final controller = ref.read(incomingOrderControllerProvider.notifier);
    unawaited(controller.flushOverlayRejections());

    final handoff = await NewOrderOverlayBridge.consumeLaunchOrder();
    if (handoff == null || !mounted) return;
    await controller.showById(handoff.orderId, autoAccept: handoff.autoAccept);
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConstants.title,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: goRouter,
          builder: (context, routedChild) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            // The phone's own font-size setting otherwise multiplies every
            // label on top of ScreenUtil's scaling, pushing text out of its
            // box on devices set to a large system font.
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: isDarkMode
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: Stack(
                  children: [
                    ?routedChild,
                    Consumer(
                      builder: (context, ref, _) {
                        final ordersState = ref.watch(ordersControllerProvider);
                        final hasActiveOrder =
                            ordersState is OrdersLoaded &&
                            ordersState.currentOrder != null;
                        final showTrip = ref.watch(
                          activeTripVisibilityControllerProvider,
                        );
                        if (!hasActiveOrder) return const SizedBox.shrink();
                        if (!showTrip) {
                          return MinimizedTripBar(
                            order: ordersState.currentOrder!,
                          );
                        }
                        return const ActiveTripScreen();
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final incomingOrder = ref.watch(
                          incomingOrderControllerProvider,
                        );
                        if (incomingOrder == null) {
                          return const SizedBox.shrink();
                        }
                        return IncomingOrderScreen(
                          key: ValueKey(incomingOrder.id),
                          order: incomingOrder,
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final pendingRating = ref.watch(
                          pendingCustomerRatingControllerProvider,
                        );
                        if (pendingRating == null) {
                          return const SizedBox.shrink();
                        }
                        return RateCustomerScreen(
                          key: ValueKey(pendingRating.id),
                          order: pendingRating,
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final isOnline = ref.watch(networkControllerProvider);
                        if (isOnline) return const SizedBox.shrink();
                        return const NoNetworkOverlay();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
