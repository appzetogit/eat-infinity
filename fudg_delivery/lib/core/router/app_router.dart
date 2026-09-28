import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/features/splash/presentation/screens/splash_screen.dart';
import 'package:food_user_application/features/main/presentation/screens/main_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/driver_details_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/driver_id_card_screen.dart';
import 'package:food_user_application/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:food_user_application/features/refer_earn/presentation/screens/refer_earn_screen.dart';
import 'package:food_user_application/features/refer_earn/presentation/screens/referral_ticket_result_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/registration_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/account_status_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/order_delivered_screen.dart';
import 'package:food_user_application/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:food_user_application/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/history/presentation/screens/trip_detail_screen.dart';
import 'package:food_user_application/features/history/presentation/screens/history_screen.dart';
import 'package:food_user_application/features/support/presentation/screens/help_screen.dart';
import 'package:food_user_application/features/support/presentation/screens/support_ticket_screen.dart';
import 'package:food_user_application/features/onboarding/presentation/screens/app_permissions_screen.dart';
import 'router_notifier.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/app-permissions',
        builder: (context, state) => const AppPermissionsScreen(),
      ),
      GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/driver-details',
        builder: (context, state) =>
            DriverDetailsScreen(section: state.extra as String?),
      ),
      GoRoute(
        path: '/driver-id-card',
        builder: (context, state) => const DriverIdCardScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/refer-earn',
        builder: (context, state) => const ReferEarnScreen(),
        routes: [
          GoRoute(
            path: 'ticket',
            builder: (context, state) => const ReferralTicketResultScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/phone-login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) =>
            OtpVerifyScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegistrationScreen(phone: state.extra as String? ?? ''),
      ),
      // Where a partner lands the moment registration succeeds: the backend
      // creates them with status 'pending', so `_applyPartnerStatus` emits
      // AuthPendingApproval and RouterNotifier redirects here.
      //
      // The screen existed and RouterNotifier had always redirected to it, but
      // the route itself was never registered — so submitting KYC dropped
      // every new partner onto "no routes for location: /account-status".
      GoRoute(
        path: '/account-status',
        builder: (context, state) => const AccountStatusScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      // Profile is tab 3 of MainScreen, but the bottom bars on the wallet and
      // history screens navigate to it by path. Registering it standalone —
      // as /earnings and /wallet already are — is what those call sites
      // expect; without it, tapping Profile from either threw the same
      // "no routes for location" GoException.
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/order-details',
        builder: (context, state) => const OrderDetailScreen(),
      ),
      GoRoute(
        path: '/order-delivered',
        builder: (context, state) => OrderDeliveredScreen(
          order: state.extra as DeliveryOrder?,
        ),
      ),
      GoRoute(
        path: '/trip-details',
        builder: (context, state) => TripDetailScreen(
          trip: state.extra as Map<String, dynamic>? ?? const {},
        ),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpScreen(),
        routes: [
          GoRoute(
            path: 'ticket',
            builder: (context, state) => const SupportTicketScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.error}'))),
  );
});
