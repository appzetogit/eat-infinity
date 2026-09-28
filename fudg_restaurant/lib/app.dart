import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_theme.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/config/router/app_router.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/services/network_controller.dart';
import 'package:food_user_application/core/widgets/no_network_overlay.dart';

class FoodUserApplication extends ConsumerStatefulWidget {
  const FoodUserApplication({super.key});

  @override
  ConsumerState<FoodUserApplication> createState() =>
      _FoodUserApplicationState();
}

class _FoodUserApplicationState extends ConsumerState<FoodUserApplication>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from background/lock screen is exactly when a push could
    // have been missed (OS throttling, no connectivity, app killed) — refresh
    // straight from the API so no order is ever silently missed.
    if (state == AppLifecycleState.resumed) {
      ref.read(liveOrdersControllerProvider.notifier).refresh();

      // Re-register the push token on every resume.
      //
      // Registration used to happen only at launch and at login, so a token
      // that failed to save — or that FCM rotated while the app was closed —
      // left the restaurant silently unreachable until someone happened to
      // relaunch. That is exactly how five of six restaurants ended up with no
      // token at all while their apps were running fine.
      //
      // The call is cheap, idempotent server-side ($addToSet), and reports its
      // own failures, so running it on every resume costs nothing and closes
      // the window to a single resume.
      unawaited(ref.read(fcmServiceProvider).saveTokenToServer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: currentThemeMode,
      routerConfig: goRouter,
      // The phone's own font-size setting otherwise multiplies every label,
      // pushing text out of its box on devices set to a large system font.
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Stack(
            children: [
              ?child,
              Consumer(
                builder: (context, ref, _) {
                  final isOnline = ref.watch(networkControllerProvider);
                  if (isOnline) return const SizedBox.shrink();
                  return const NoNetworkOverlay();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
