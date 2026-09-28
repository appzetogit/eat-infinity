import '../constants/app_constants.dart';

/// Central API configuration.
///
/// Base URL is overridable at build time so staging/prod never require a
/// code change:  `flutter run --dart-define=API_BASE_URL=https://…`
class ApiConfig {
  const ApiConfig._();

  static const String host = AppConstants.hostUrl;

  static const String baseUrl = AppConstants.baseUrl;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Resolves a possibly-relative upload path (`/uploads/...`) to an absolute
  /// URL. The API mixes absolute and relative image paths across endpoints.
  static String resolveMedia(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    // Seeded records carry inline `data:image/svg+xml;utf8,...` placeholders.
    // Prefixing those with the host produced
    // `https://api.mintofood.com/data:image/...`, i.e. a guaranteed 404.
    if (path.startsWith('data:')) return path;
    return path.startsWith('/') ? '$host$path' : '$host/$path';
  }
}

/// Endpoint paths, relative to [ApiConfig.baseUrl].
class ApiPaths {
  const ApiPaths._();

  // ---- Auth ----
  static const String requestOtp = '/food/auth/user/request-otp';
  static const String verifyOtp = '/food/auth/user/verify-otp';
  static const String refreshToken = '/food/auth/refresh-token';
  static const String logout = '/food/auth/logout';
  static const String me = '/food/auth/me';

  // ---- User ----
  static const String profile = '/food/user/profile';
  static const String profileImage = '/food/user/profile/profile-image';
  static const String addresses = '/food/user/addresses';
  static const String cart = '/food/user/cart';
  static const String wallet = '/food/user/wallet';
  static const String cashbackHistory = '/food/user/cashback';
  static const String refundHistory = '/food/user/refunds';
  static const String cashbackSettings = '/food/admin/cashback-settings/public';
  static const String referralStats = '/food/user/referrals/stats';
  static const String referralDetails = '/food/user/referrals/details';
  static const String favorites = '/food/user/favorites';
  static const String favoriteRestaurants = '/food/user/favorites/restaurants';
  static const String favoriteFoods = '/food/user/favorites/foods';

  // ---- Chat ----
  static const String chatConversations = '/food/chat/conversations';
  static const String chatMessages = '/food/chat/messages';
  static String chatConversationRead(String conversationId) =>
      '/food/chat/conversations/$conversationId/read';

  // ---- Discovery ----
  static const String restaurants = '/food/restaurant/restaurants';
  static const String publicFoods = '/food/restaurant/public/foods';
  static const String categories = '/food/restaurant/categories/public';
  static const String offers = '/food/restaurant/offers';
  static const String searchUnified = '/food/search/unified';

  static String restaurantById(String id) => '$restaurants/$id';
  static String restaurantMenu(String id) => '$restaurants/$id/menu';
  static String restaurantAddons(String id) => '$restaurants/$id/addons';
  static String restaurantTimings(String id) =>
      '$restaurants/$id/outlet-timings';

  // ---- Home / landing ----
  static const String heroBanners = '/food/hero-banners/public';

  /// Admin-managed promotional banners for the home carousel.
  ///
  /// The backend already filters to active banners inside their start/end
  /// window and sorts by sortOrder, so the app renders whatever it is given in
  /// the order it arrives — scheduling is an admin concern, not a client one.
  static const String promoBanners = '/food/hero-banners/home-promotion/public';

  /// Admin-managed "deal" cards (Items under ₹X etc.) for the home screen's
  /// deals row. Backed by the existing Under-250 banner CMS — no new backend
  /// endpoint needed, the home screen just wasn't wired to it before.
  static const String dealBanners = '/food/hero-banners/under-250/public';

  /// Admin-managed offer banners — a CMS separate from the hero/deal banners
  /// above, where each banner carries its own `ctaLink`.
  ///
  /// NOT DEPLOYED on the current backend (amal.buytogetherindia.com): there is
  /// no offer-banner CMS there and this path answers 404, which
  /// `offerBannersProvider` swallows into an empty list so the home section
  /// hides itself. Kept rather than deleted because the same build targets
  /// deployments that do serve it; the section lights up on its own once the
  /// route exists. Do not "fix" this by repointing it at one of the
  /// hero-banner CMSes — those are different content.
  static const String offerBanners = '/food/offer-banners/public';
  static const String topBanners = '/food/top-banners/public';
  static const String exploreIcons = '/food/explore-icons/public';
  static const String landingSettings = '/food/landing/settings/public';

  // ---- Zones ----
  static const String zoneDetect = '/food/zones/detect';

  // ---- Orders ----
  static const String orders = '/food/orders';
  static const String orderCalculate = '/food/orders/calculate';
  static const String verifyPayment = '/food/orders/verify-payment';
  static String orderById(String id) => '$orders/$id';

  // ---- Tips ----
  // NOT DEPLOYED on the current backend: it exposes no tipping routes at all,
  // so both of these answer 404. `getTipConfig()` catches that and returns a
  // disabled `TipConfig`, which hides the tipping UI entirely — so the feature
  // is dormant rather than broken until the backend ships it.
  static const String tipConfig = '/food/tips/config';
  static String orderTip(String id) => '$orders/$id/tip';

  /// The customer's printable bill for a placed order: self-contained HTML
  /// (inline styles, no network assets). Behind the user token.
  static String orderInvoiceHtml(String id) => '$orders/$id/invoice.html';

  // ---- Notifications / FCM ----
  static const String notificationInbox = '/food/notifications/inbox';
  static const String fcmSaveMobile = '/fcm-tokens/mobile/save';
  static const String fcmRemove = '/fcm-tokens/remove';
  static const String fcmTest = '/fcm-tokens/test';

  // ---- CMS / settings ----
  static const String businessSettings = '/food/admin/business-settings/public';
  static const String featureSettings = '/food/admin/feature-settings/public';
  static const String feeSettings = '/food/admin/fee-settings/public';
  static String cmsPage(String key) => '/food/pages/$key';
}
