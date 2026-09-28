// App Router Configuration
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'route_names.dart';
import '../splash/splash_screen.dart';
import '../auth/screens/login_screen.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../auth/screens/otp_screen.dart';
import '../auth/screens/profile_setup_screen.dart';
import '../main/main_app_shell.dart';
import '../home/home_screen.dart';
import '../cart/cart_screen.dart';
import '../restaurant/screens/store99_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../restaurant/screens/food_detail_loader_screen.dart';
import '../restaurant/screens/food_detail_screen.dart';
import '../restaurant/screens/restaurant_detail_loader_screen.dart';
import '../restaurant/screens/restaurant_screen.dart';
import '../search/screens/search_screen.dart';
import '../address/screens/add_address_screen.dart';
import '../offers/screens/all_offers_screen.dart';
import '../favorites/favorites_screen.dart';
import '../orders/screens/orders_screen.dart';
import '../cms/screens/cms_page_screen.dart';
import '../orders/screens/order_details_screen.dart';
import '../orders/screens/order_tracking_screen.dart';
import '../orders/screens/order_success_screen.dart';
import '../orders/screens/order_delivered_screen.dart';
import '../referral/screens/referral_screen.dart';
import '../referral/screens/referral_ticket_result_screen.dart';
import '../wallet/screens/wallet_screen.dart';
import '../chat/screens/chat_screen.dart';
import '../home/screens/home_filter_screen.dart';
import '../common/webview_screen.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/cart_item_model.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';
import '../checkout/screens/checkout_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKeyHome = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final shellNavigatorKeySearch = GlobalKey<NavigatorState>(
  debugLabel: 'shellSearch',
);
final shellNavigatorKeyOrders = GlobalKey<NavigatorState>(
  debugLabel: 'shellOrders',
);
final shellNavigatorKeyOffers = GlobalKey<NavigatorState>(
  debugLabel: 'shellOffers',
);
final shellNavigatorKeyProfile = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) {
          final fromPath =
              state.uri.queryParameters['from'] ??
              (state.extra is String ? state.extra as String : null);
          return LoginScreen(fromPath: fromPath);
        },
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone =
              extra?['phone']?.toString() ??
              state.uri.queryParameters['phone'] ??
              '';
          final fromPath =
              extra?['from']?.toString() ?? state.uri.queryParameters['from'];
          return OtpScreen(
            phoneNumber: phone,
            devOtp: extra?['devOtp']?.toString(),
            fromPath: fromPath,
          );
        },
      ),
      GoRoute(
        path: RouteNames.profileSetup,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ProfileSetupScreen(
            redirectTo: extra?['from']?.toString() ??
                state.uri.queryParameters['from'] ??
                RouteNames.home,
          );
        },
      ),
      GoRoute(
        path: RouteNames.restaurantDetail,
        builder: (context, state) {
          // `extra` is not guaranteed. A shared link carries only the id, and an
          // unconditional cast threw on arrival; the favourites screen also
          // already pushes '/restaurant-detail/<id>', which never matched this
          // route at all. Both now resolve through the loader.
          final restaurant =
              state.extra is RestaurantModel ? state.extra as RestaurantModel : null;
          if (restaurant != null) {
            return RestaurantScreen(restaurant: restaurant);
          }
          return RestaurantDetailLoaderScreen(
            restaurantId: state.uri.queryParameters['id'] ??
                state.uri.queryParameters['restaurantId'] ??
                '',
          );
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final restaurant = state.extra is RestaurantModel
                  ? state.extra as RestaurantModel
                  : null;
              if (restaurant != null) {
                return RestaurantScreen(restaurant: restaurant);
              }
              return RestaurantDetailLoaderScreen(
                restaurantId: state.pathParameters['id'] ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.foodDetail,
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      GoRoute(
        path: '/food',
        builder: (context, state) {
          final extraFood = state.extra is FoodModel ? state.extra as FoodModel : null;
          final foodId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['productId'] ?? '';
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? state.uri.queryParameters['rId'] ?? '';

          if (extraFood != null) {
            return FoodDetailScreen(food: extraFood);
          }
          return FoodDetailLoaderScreen(
            foodId: foodId,
            restaurantId: restaurantId,
          );
        },
      ),
      // NOTE: /search and /orders are tabs — they are declared once, inside the
      // shell below. Declaring them here as well shadowed the branches, so both
      // tabs opened without the bottom nav and Android back exited the app.
      GoRoute(
        path: RouteNames.checkout,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/orders/details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDetailsScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/track/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderTrackingScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/delivered/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderDeliveredScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.chat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as ChatArgs? ?? const ChatArgs(
            orderId: '',
            peerName: 'Support',
            peerRole: 'ADMIN',
          );
          return ChatScreen(args: args);
        },
      ),
      GoRoute(
        path: RouteNames.homeFilter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            HomeFilterScreen(args: state.extra as HomeFilterArgs),
      ),
      GoRoute(
        path: '/orders/success/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderSuccessScreen(orderId: id);
        },
      ),
      GoRoute(
        path: RouteNames.referral,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: RouteNames.referralTicket,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralTicketResultScreen(),
      ),
      GoRoute(
        path: RouteNames.favorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RouteNames.addAddress,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddAddressScreen(),
      ),
      // Cart and the ₹99 store sit outside the tab shell — they are pushed
      // full-screen from the restaurant, food detail and home surfaces.
      GoRoute(
        path: RouteNames.cart,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: RouteNames.store99,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => Store99Screen(
          maxPrice:
              double.tryParse(state.uri.queryParameters['maxPrice'] ?? ''),
        ),
      ),
      GoRoute(
        path: RouteNames.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: RouteNames.webView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extraMap = state.extra as Map<String, dynamic>?;
          final title =
              extraMap?['title']?.toString() ??
              state.uri.queryParameters['title'] ??
              'Web View';
          final url =
              extraMap?['url']?.toString() ??
              state.uri.queryParameters['url'] ??
              '';
          return WebViewScreen(title: title, url: url);
        },
      ),
      GoRoute(
        path: RouteNames.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CmsPageScreen(
          pageKey: 'about',
          fallbackTitle: 'About Eatinfinity',
        ),
      ),
      GoRoute(
        path: RouteNames.helpSupport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CmsPageScreen(
          pageKey: 'support',
          fallbackTitle: 'Help & Support',
        ),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CmsPageScreen(
          pageKey: 'privacy',
          fallbackTitle: 'Privacy Policy',
        ),
      ),
      GoRoute(
        path: RouteNames.termsConditions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CmsPageScreen(
          pageKey: 'terms',
          fallbackTitle: 'Terms & Conditions',
        ),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.buyAgain,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final items = state.extra as List<CartItemModel>;
          return ProviderScope(
            overrides: [
              cartViewModelProvider.overrideWith(
                () => CartViewModel(initialItems: items, syncEnabled: false),
              ),
              checkoutViewModelProvider.overrideWith(CheckoutViewModel.new),
            ],
            child: const CartScreen(),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyHome,
            routes: [
              GoRoute(
                path: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeySearch,
            routes: [
              GoRoute(
                path: RouteNames.search,
                builder: (context, state) {
                  // Both spellings are in use by callers.
                  final query = state.extra is String
                      ? state.extra as String
                      : state.uri.queryParameters['q'] ??
                          state.uri.queryParameters['query'];
                  return SearchScreen(initialQuery: query);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyOrders,
            routes: [
              GoRoute(
                path: RouteNames.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyOffers,
            routes: [
              GoRoute(
                path: RouteNames.allOffers,
                builder: (context, state) => const AllOffersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellNavigatorKeyProfile,
            routes: [
              GoRoute(
                path: RouteNames.profile,
                // Account is personal by definition, so a signed-out visitor is
                // sent to log in rather than shown an empty "Guest" profile.
                //
                // Guarded on `hasValue` because the provider sits in
                // AsyncLoading while the cold-start session restore runs — a
                // logged-in user opening the app straight onto Account would
                // otherwise be bounced to login before their session resolved.
                //
                // Living on the route rather than in the tab handler means a
                // deep link to /profile is guarded too.
                redirect: (context, state) {
                  final auth = ref.read(authViewModelProvider);
                  if (auth.hasValue && auth.value == null) {
                    return Uri(
                      path: RouteNames.login,
                      queryParameters: {'from': state.matchedLocation},
                    ).toString();
                  }
                  return null;
                },
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
