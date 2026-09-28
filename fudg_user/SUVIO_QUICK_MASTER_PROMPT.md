# MASTER PROMPT — "Suvio Quick" Full-Stack Application (Flutter + Backend, Production Architecture)

You are an expert Senior Flutter Architect, Backend Engineer, and UI/UX Engineer. Your task is to generate a complete, production-quality, **full-stack** application named **"Suvio Quick"** — a premium Quick Commerce (instant grocery/essentials delivery) application inspired by the category defined by apps like Blinkit, Zepto, Instamart, and BigBasket Now. Build two things together, in the same effort, as one deliverable: a Flutter mobile frontend and a real, working backend API server that the frontend talks to over HTTP from the very first screen that needs data.

You must **NOT copy any existing app's UI, layout, iconography, or visual identity**. You must design a **unique, premium, modern, beautiful, production-grade visual language** that feels more polished, more considered, and more delightful than existing quick-commerce apps, while remaining fast, dense, and functional (quick-commerce UIs must never sacrifice speed and scannability for decoration).

Read this entire prompt before writing a single file. Build methodically, layer by layer, screen by screen. Do not skip requirements. Do not simplify silently — if a requirement is ambiguous, make the most production-sensible decision and stay consistent with it everywhere.

---

## 0. Scope Contract

- **The backend already exists. Do NOT create, replace, rewrite, or scaffold a new backend.** A complete, working Node.js/Express/MongoDB backend ships inside the `backend/` folder of this project. Your job is to **build only the Flutter frontend**, and integrate it against that existing backend exactly as it is.
- **Before writing a single Flutter file, thoroughly read the existing backend source**: `backend/food-backend/Backend/src/` — its route files (`routes/`, `core/*/*.routes.js`, `modules/food/*/routes/*.routes.js`), controllers, Mongoose models, validators, and DTOs. §1.1 below is a confirmed map of what exists as of this writing to get you started — treat it as a starting point, not a substitute for reading the actual source. **Never invent an endpoint, field name, or response shape.** If something this prompt describes (e.g. a generic "Product"/"Category"/"Brand" catalog) has no direct backend equivalent, map it onto the closest real resource the backend actually exposes (see §1.1) rather than fabricating a new one.
- **The backend is the single source of truth for all data**: restaurants, food items/menus, categories, banners, cart, orders, addresses, wallet, favorites, notifications, chat, reviews. The Flutter app never invents or hardcodes catalog/business data — it fetches everything from the existing REST API.
- **Strict layering still applies on the Flutter side**: UI and Domain must never know transport details. Data-layer repository implementations (`ApiProductRepository`, `ApiCartRepository`, etc.) call the backend through a single `ApiClient`/`DioApiClient` — see §2.3 for how the base URL is configured per environment.
- **Authentication is real, against the existing backend**: phone + OTP flow calling the backend's actual OTP request/verify endpoints and storing the JWT it returns (see §1.1), not a hardcoded client-side code.
- **Payment gateway and maps SDKs remain simulated** on the Flutter side (no Razorpay SDK / Google Maps SDK integration required) — the existing backend already exposes real payment endpoints (`core/payments`); call them for order creation/verification, but stub the actual gateway checkout UI with a short "processing" animation rather than embedding a payment SDK.
- Do not stub out screens with "TODO" or "Coming soon" placeholders. Every screen in the required list must be fully designed and fully functional against the real, existing backend, and every request it makes must match a real endpoint.
- Keep frontend and backend fully synchronized: if a screen needs data the existing backend genuinely does not expose anywhere, do not silently mock it — flag the gap explicitly in your output (e.g. a short "Backend Gaps" note) rather than inventing a fake endpoint that will fail at runtime.

---

## 1. Tech Stack & Foundational Decisions

- **Framework:** Flutter (latest stable), null-safe, Dart 3.x syntax (records, patterns, sealed classes where they clarify code).
- **State Management:** **Riverpod** (`flutter_riverpod` + code-generation via `riverpod_generator` if you choose to use annotations — otherwise hand-written `NotifierProvider`/`AsyncNotifierProvider`). Riverpod is the single state management solution for the entire app. Do not mix in Provider, GetX, Bloc, or setState-driven business state.
- **Routing:** `go_router`. Centralized, declarative, typed routes. Support deep linking structure even though there is no backend (e.g. `/product/:id`, `/category/:id`).
- **Networking layer:** Build an abstract `ApiClient` interface and a `DioApiClient` implementation using `dio`, and **actually use it** — every `Api*Repository` in `data/repository_impl/` calls the real backend (§1.1) through this client, with interceptors for auth-token attachment, error mapping, and logging.
- **Image loading/caching:** `cached_network_image` for product/category/banner image URLs returned by the backend (seed data should reference a stable placeholder image service, e.g. picsum/unsplash source URLs, since no image-upload pipeline is required), with shimmer placeholders and graceful fallback icons on failure.
- **Shimmer:** `shimmer` package or a hand-rolled shimmer widget — pick one and use it consistently everywhere loading state is shown.
- **Local persistence:** wrap `shared_preferences` behind a `LocalStorage` interface in `core/` for things like theme preference, recently viewed products, cached cart, and the JWT auth token.
- **Fonts:** Use `google_fonts` with a single premium sans-serif type family (e.g. a geometric/humanist sans such as "Inter", "Manrope", or "Sora" — pick one and apply it globally via `ThemeData.textTheme`).
- **Icons:** Use a single consistent icon set (`Icons` / Material Symbols, or `phosphor_flutter` / `lucide_icons` — pick one, do not mix icon families).
- **Animations:** `flutter_animate` (or hand-rolled `AnimationController`/`Hero`/`AnimatedSwitcher` — your call) used consistently for micro-interactions, page transitions, and list entrance animations.
- **Linting:** `flutter_lints` (or `very_good_analysis`) enabled with zero analyzer warnings in the final output.

### 1.1 Existing Backend — Integration Reference (read the source before relying on this)

The backend is already fully built: Node.js/Express + MongoDB/Mongoose, at `backend/food-backend/Backend/`. It mounts all routes under `/api` in `src/app.js`, then versions them under `/v1` in `src/routes/index.js`. Confirmed, real route groups as of this writing:

- **Auth** (`src/core/auth/auth.routes.js`, mounted at `/api/v1/food/auth`, legacy alias `/api/v1/auth`):
  `POST /user/request-otp`, `POST /user/verify-otp` (also `restaurant/…` and `delivery/…` variants for other roles), `POST /refresh-token`, `POST /logout`, `GET /me` (Bearer). OTP verify returns the JWT access/refresh tokens — store them via `LocalStorage` and attach `Authorization: Bearer <token>` on every subsequent call.
- **User profile & account** (`/api/v1/food/user`, Bearer + role `USER`): `/profile` (get/patch/delete), `/profile/profile-image`, `/wallet`, `/wallet/topup/order`, `/wallet/topup/verify`, `/cashback`, `/refunds`, `/referrals/stats`, `/referrals/details`, `/addresses` (get/post), `/addresses/:addressId` (patch/delete), `/addresses/:addressId/default`, `/safety-emergency-reports`, `/support/ticket`, `/support/my-tickets`, favourites endpoints for restaurants and foods.
- **Orders** (`/api/v1/food/orders`, Bearer + role `USER`, `src/modules/food/orders/routes/order.routes.user.js`): `POST /calculate` (server-computed bill — see below), `POST /` (create), `POST /verify-payment`, `DELETE /:orderId/pending-payment`, `GET /` (list), `GET /:orderId`, `GET /:orderId/payments`, `GET /:orderId/drop-otp`, `GET /:orderId/route` (live tracking polyline/origin/destination), `PATCH /:orderId/cancel`, `PATCH /:orderId/ratings`, `PATCH /:orderId/instructions`.
- **Catalog / browsing** (`/api/v1/food/restaurant`, `src/modules/food/restaurant/routes/restaurant.routes.js`): approved-restaurant listing/detail, public offers, restaurant categories, `getPublicRestaurantMenuController` (a restaurant's menu = its food items), `listPublicFoodsController` (cross-restaurant food listing — this is your closest equivalent to a flat "product" feed), `getPublicRestaurantAddonsController`. There is no separate grocery-style Product/Category/Brand model — map Suvio Quick's "Product" concept onto a food item, and "Category" onto a restaurant/food category from this module or from Search below.
- **Search** (`/api/v1/food/search`): `GET /unified` (cross-entity search), `GET /categories/admin` (admin-curated categories, recommended for the Categories screen over restaurant-owned ones).
- **Landing / banners** (`/api/v1/food`, `src/modules/food/landing/routes/landing.routes.js`): hero banners, top banners, "under ₹250" banners, dining banners, home-promotion banners — use these for the Home screen's banner carousel and promotional sections instead of a generic `/banners` endpoint.
- **Admin-exposed public settings** (`/api/v1/food/admin/*/public`, no auth): `business-settings/public`, `fee-settings/public` (delivery-fee logic — see `order-pricing.service.js` and `feeSettings.model.js` for how it's computed), `feature-settings/public`, `cashback-settings/public`, `power-scanning/public`.
- **Notifications** (`/api/v1/food/notifications`, Bearer), **Chat** (`/api/v1/food/chat`, Bearer), **Payments** (`/api/v1/food/payments`, Bearer, plus a public `/api/v1/payments/webhook`), **Uploads** (`/api/v1/uploads`).

**Pricing is server-owned and already implemented**: `POST /api/v1/food/orders/calculate` is the only source of truth for subtotal, delivery fee, platform fee, GST, discount, and total (see `src/modules/food/orders/services/order-pricing.service.js`). The Flutter app must never compute or adjust these numbers client-side — it displays exactly what this endpoint returns and echoes the same `pricing` object back on `POST /api/v1/food/orders`.

This map is not guaranteed exhaustive or unchanged — before implementing any `Api*Repository` method, open the relevant `*.routes.js` file and its controller in the actual backend source to confirm the exact path, method, request body, and response shape, and mirror them precisely.

State the exact package versions you choose (latest stable at time of writing) in the `pubspec.yaml` you generate for the Flutter app. Do not generate or modify a `package.json` — the backend's dependencies are already installed and must not be touched.

---

## 2. Architecture — Clean Architecture, Feature-First, Strict Layering

Follow **Clean Layered Architecture** with strict one-directional dependency flow:

```
UI  →  Domain  →  Data  →  Platform / External APIs
```

Rules (non-negotiable):
- UI may depend on Domain. UI must NEVER depend on Data directly, only via DI-injected abstractions exposed through Domain-facing providers.
- Data implements Domain repository interfaces. Data must NEVER depend on UI or import Flutter widgets.
- Domain contains all business logic (pricing math, discount calculation, cart merging, coupon eligibility, stock rules, sorting/filtering). Domain must NEVER import Flutter, Riverpod, Dio, or `BuildContext`. Pure Dart only.
- Platform contains platform-specific concerns (permissions, location, notifications placeholders) and is called only from Data/DI, never directly from UI.
- Always depend on abstractions (interfaces), never concrete implementations, across layer boundaries.

### 2.1 Top-Level Folder Structure

```
lib/
├── main.dart
├── app.dart                          # MaterialApp.router + theme + providers scope
│
├── core/
│   ├── constants/
│   │   ├── app_strings.dart
│   │   ├── app_dimens.dart
│   │   ├── app_durations.dart
│   │   └── app_assets.dart
│   ├── config/
│   │   └── app_config.dart           # env flags, API base URL, feature flags
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_theme.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radii.dart
│   │   └── app_theme_provider.dart   # multi-primary-color theme switching
│   ├── network/
│   │   ├── api_client.dart           # abstract interface
│   │   ├── dio_api_client.dart       # real impl, unused today, ready for later
│   │   └── api_result.dart           # Result<T>/Either-style wrapper
│   ├── errors/
│   │   ├── app_exception.dart
│   │   ├── failure.dart
│   │   └── error_mapper.dart
│   ├── extensions/
│   │   ├── context_extensions.dart
│   │   ├── num_extensions.dart
│   │   └── string_extensions.dart
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── debouncer.dart
│   │   ├── validators.dart
│   │   └── logger.dart
│   └── local_storage/
│       ├── local_storage.dart        # abstract
│       └── shared_prefs_storage.dart # impl
│
├── domain/
│   ├── model/
│   │   ├── product.dart
│   │   ├── product_variant.dart
│   │   ├── addon.dart
│   │   ├── category.dart
│   │   ├── sub_category.dart
│   │   ├── brand.dart
│   │   ├── banner.dart
│   │   ├── cart.dart
│   │   ├── cart_item.dart
│   │   ├── coupon.dart
│   │   ├── address.dart
│   │   ├── order.dart
│   │   ├── order_status.dart
│   │   ├── payment_method.dart
│   │   ├── review.dart
│   │   ├── user.dart
│   │   ├── notification_item.dart
│   │   └── delivery_slot.dart
│   ├── repository/                   # abstract interfaces only
│   │   ├── product_repository.dart
│   │   ├── category_repository.dart
│   │   ├── cart_repository.dart
│   │   ├── order_repository.dart
│   │   ├── address_repository.dart
│   │   ├── auth_repository.dart
│   │   ├── coupon_repository.dart
│   │   ├── wishlist_repository.dart
│   │   ├── review_repository.dart
│   │   └── notification_repository.dart
│   ├── service/                      # business logic orchestration
│   │   ├── cart_pricing_service.dart
│   │   ├── coupon_eligibility_service.dart
│   │   ├── stock_service.dart
│   │   ├── search_ranking_service.dart
│   │   └── checkout_validation_service.dart
│   ├── usecase/
│   │   ├── add_to_cart_usecase.dart
│   │   ├── apply_coupon_usecase.dart
│   │   ├── place_order_usecase.dart
│   │   └── ... (one per meaningful business action)
│   └── validator/
│       └── address_validator.dart
│
├── data/
│   ├── dto/
│   │   ├── product_dto.dart
│   │   ├── category_dto.dart
│   │   └── ... (one per model, with fromJson/toJson matching the backend's JSON shape)
│   ├── mapper/
│   │   ├── product_mapper.dart       # DTO ↔ Domain model
│   │   └── ...
│   └── repository_impl/
│       ├── api_product_repository.dart      # implements ProductRepository, calls the backend
│       ├── api_category_repository.dart
│       ├── api_cart_repository.dart
│       ├── api_order_repository.dart
│       ├── api_address_repository.dart
│       ├── api_auth_repository.dart
│       ├── api_coupon_repository.dart
│       ├── api_wishlist_repository.dart
│       ├── api_review_repository.dart
│       └── api_notification_repository.dart
│
├── platform/
│   ├── location/
│   │   └── location_service.dart     # placeholder permission + fake coordinates
│   ├── notification/
│   │   └── notification_service.dart # placeholder local notification scaffolding
│   └── permission/
│       └── permission_service.dart
│
├── di/
│   ├── repository_providers.dart     # binds interfaces → Api*RepositoryImpl, built from one DioApiClient
│   ├── service_providers.dart
│   └── usecase_providers.dart
│
├── navigation/
│   ├── app_router.dart               # go_router config, all routes + typed params
│   └── route_paths.dart
│
└── ui/
    ├── common/
    │   ├── widgets/
    │   │   ├── buttons/
    │   │   │   ├── primary_button.dart
    │   │   │   ├── secondary_button.dart
    │   │   │   ├── icon_button_circle.dart
    │   │   │   └── animated_add_button.dart      # the +ADD → stepper morph button
    │   │   ├── cards/
    │   │   │   ├── product_card.dart
    │   │   │   ├── category_card.dart
    │   │   │   └── brand_card.dart
    │   │   ├── inputs/
    │   │   │   ├── app_text_field.dart
    │   │   │   ├── search_bar_widget.dart
    │   │   │   └── otp_input.dart
    │   │   ├── loaders/
    │   │   │   ├── shimmer_box.dart
    │   │   │   ├── product_card_skeleton.dart
    │   │   │   ├── list_skeleton.dart
    │   │   │   └── full_page_loader.dart
    │   │   ├── states/
    │   │   │   ├── empty_state_widget.dart
    │   │   │   ├── error_state_widget.dart
    │   │   │   └── offline_banner.dart
    │   │   ├── feedback/
    │   │   │   ├── app_snackbar.dart
    │   │   │   ├── app_dialog.dart
    │   │   │   └── app_bottom_sheet.dart
    │   │   ├── badges/
    │   │   │   ├── discount_badge.dart
    │   │   │   └── delivery_time_badge.dart
    │   │   └── misc/
    │   │       ├── rating_stars.dart
    │   │       ├── section_header.dart
    │   │       └── quantity_stepper.dart
    │   └── mixins/
    │       └── connectivity_aware_mixin.dart
    │
    └── screens/
        ├── splash/
        ├── onboarding/
        ├── auth/
        │   ├── login/
        │   └── otp/
        ├── location/
        │   ├── location_permission/
        │   └── address_selection/
        ├── home/
        ├── search/
        ├── category/
        │   ├── categories/
        │   └── sub_category/
        ├── brand/
        ├── product/
        │   ├── product_listing/
        │   └── product_details/
        ├── wishlist/
        ├── cart/
        ├── checkout/
        ├── coupons/
        ├── payment/
        ├── address/
        ├── notifications/
        ├── order/
        │   ├── order_success/
        │   ├── order_tracking/
        │   ├── orders_list/
        │   └── order_details/
        └── profile/
            ├── profile_home/
            ├── edit_profile/
            ├── help/
            ├── settings/
            ├── privacy_policy/
            ├── terms/
            └── about/
```

Each screen folder follows this internal convention (mirrors this project's existing convention — keep it identical):

```
home/
├── home_screen.dart        # renders UI only, watches provider
├── home_provider.dart      # AsyncNotifier, calls domain services/usecases
├── home_state.dart         # immutable state class (freezed-style or manual copyWith)
└── widgets/                # screen-local widgets not reusable elsewhere
```

### 2.2 Layer Rules Recap (enforce strictly in generated code)

| Layer | May depend on | Must NOT contain |
|---|---|---|
| UI | Domain (models, providers exposing usecases/services) | API calls, JSON parsing, business logic, direct DB access |
| Domain | Nothing (pure Dart) | Flutter imports, `BuildContext`, Riverpod, Dio, JSON |
| Data | Domain (implements its interfaces), Platform | Business logic, UI, Flutter widgets |
| DI | Data, Domain, Platform | Business logic |
| Platform | Nothing above it | Business logic |

State management providers (`*_provider.dart`) sit in the UI layer conceptually (they are presentation state), call into Domain usecases/services, and expose immutable `*_state.dart` classes. Providers must never contain business/pricing logic directly — that always lives in Domain services/usecases.

### 2.3 API Base URL & Environments

`core/config/app_config.dart` exposes the existing backend's base URL per build environment (e.g. via `--dart-define=API_BASE_URL=...`, pointed at wherever `backend/food-backend/Backend` is actually running — e.g. `http://10.0.2.2:<port>/api/v1` for the Android emulator or `http://localhost:<port>/api/v1` for the iOS simulator; read the backend's `.env`/`config` for the real port instead of assuming one). `di/repository_providers.dart` constructs one `DioApiClient` from that config, attaches the stored JWT as `Authorization: Bearer <token>` (see §1.1 Auth), and injects it into every `Api*Repository`. Every repository interface's `page`/`pageSize`, `query`, `filters`, `sort` parameters must match what the corresponding real endpoint actually accepts — confirm against its controller/validator, don't assume a generic contract.

---

## 3. Design System

### 3.1 Brand Identity
- App name: **Suvio Quick**
- Design a **unique premium visual identity**: not the yellow-of-Blinkit, not the purple-of-Zepto. Choose a distinctive primary palette (e.g., a deep emerald/teal-and-citrus combo, or an indigo-and-coral combo) that feels premium, energetic, and trustworthy, appropriate for fast grocery delivery. State the exact hex values you choose.
- The app must **support multiple primary color themes** (e.g. "Suvio Green", "Suvio Indigo", "Suvio Sunset") switchable from Settings, persisted via `LocalStorage`, driving `ColorScheme.fromSeed` or a custom `ThemeExtension`. Implement this as a real, working feature, not a stub.
- Full **light and dark mode** support, both fully designed (not just inverted defaults) — verify contrast and card elevation legibility in dark mode explicitly.

### 3.2 Typography Scale
Define and use a full named type scale (not ad-hoc `fontSize:` literals scattered through the app):
`displayLarge/Medium/Small`, `headlineLarge/Medium/Small`, `titleLarge/Medium/Small`, `bodyLarge/Medium/Small`, `labelLarge/Medium/Small` — mapped through `app_text_styles.dart` and applied via `Theme.of(context).textTheme`. Define specific use-cases: price text style (bold, tabular figures), strikethrough MRP style, badge label style, section header style.

### 3.3 Spacing System
Define an 8pt-based spacing scale in `app_spacing.dart`: `xxs=2, xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48`. All paddings/margins in the app must reference these constants — no raw magic numbers for spacing in widget code.

### 3.4 Radii & Elevation
Define a consistent corner-radius scale (`sm/md/lg/xl/pill`) and elevation/shadow tokens (card shadow, bottom sheet shadow, floating button shadow) in `app_radii.dart` / theme extensions, applied consistently — product cards, category chips, and bottom sheets should each use one deliberate radius from the scale, not one-off values.

### 3.5 Component Design Requirements

**Buttons:** primary (filled, brand color, used for main CTA like "Add to Cart" / "Proceed to Pay"), secondary (outlined/tonal), text button, circular icon button, and the special **AnimatedAddButton** (see §5). All buttons have defined states: default, pressed (scale/opacity micro-interaction), disabled, loading (inline spinner replacing label).

**Cards:** Product card, category card, brand card, order summary card, address card, coupon card — each with a defined elevation, radius, and internal padding from the spacing scale. Cards must have a pressed-state micro-interaction (subtle scale-down + shadow reduction on tap-down).

**Bottom Sheets:** Used for: variant/add-on selection, delivery slot selection, sort & filter, payment method selection, address selection, cancel-order confirmation. All bottom sheets share a common `AppBottomSheet` wrapper: drag handle, rounded top corners, consistent padding, safe-area aware, dismissible by swipe-down.

**Dialogs:** Used for destructive/blocking confirmations (remove item, cancel order, logout). Shared `AppDialog` wrapper with consistent button layout (primary/destructive right, cancel left or as text button).

**Snackbars:** Shared `AppSnackbar` with success/error/info variants, consistent icon + color + duration, used for "Added to cart", "Coupon applied", "Address saved", network error, etc. Must not stack/overlap — queue or replace.

**Empty States:** Shared `EmptyStateWidget` (illustration/icon + heading + supporting text + optional CTA) — used for empty cart, empty wishlist, empty orders, empty search results, empty notifications. Each with tailored copy, not generic "No data".

**Error States:** Shared `ErrorStateWidget` (icon + message + Retry button) used whenever a backend call fails (network error, 4xx/5xx response). Retry must actually re-trigger the provider's fetch.

**Loading States:** Shimmer skeletons matching the exact shape of the content they replace — `ProductCardSkeleton` mirrors the real product card's layout (image block, two text lines, price line), not a generic gray box. Use skeletons on: home sections, product listing, product details, cart, orders list, search results. Use a `FullPageLoader` only where no skeleton shape is meaningful (e.g. splash).

### 3.6 Motion & Interaction Language
- **Page transitions:** custom transition via `go_router`'s `pageBuilder` — e.g. shared-axis or fade-through between top-level tabs, slide-up for modals/bottom-sheet-style routes (like checkout), standard platform transition for stack pushes (like product details).
- **Hero animations:** product image must Hero-animate from product card (in listing/home) to the product details screen's image carousel.
– **Micro-interactions:** button press scale (0.96 on tap-down), add-to-cart button morphing into a quantity stepper with a spring/elastic curve, wishlist heart icon "pop" animation on toggle, cart badge count bump animation on item add, banner carousel auto-scroll with smooth easing and pagination dots that animate width on active index.
- **Smooth add-to-cart animation:** when a user taps "Add" on a product card, animate a small ghost image/icon flying from the card toward the cart icon/tab (or a lightweight scale+fade at the cart badge) to give tactile confirmation — implement this for real via `Overlay`/`AnimatedPositioned`, not just described.
- **List entrance animations:** staggered fade+slide-in for grid/list items as they first render (subtle, fast — under 300ms per item, staggered by ~30–50ms), used tastefully (not on every rebuild/scroll, only initial population).
- **Gesture support:** swipe-to-delete on cart items and addresses, pull-to-refresh on home/orders/search, long-press on product card for quick preview (optional but specify behavior if included), swipe between product images in the carousel.

---

## 4. State Management Conventions

- Each screen: `XxxState` (immutable, `copyWith`, holds `data`, `isLoading`, `isLoadingMore` for pagination, `error`, and any UI-only flags like `selectedTabIndex`), `XxxProvider` (`AsyncNotifier<XxxState>` or `Notifier<XxxState>`), `XxxScreen` (`ConsumerWidget`/`ConsumerStatefulWidget`).
- Global providers (in `di/`) expose repositories and cross-cutting state: `cartProvider` (global, since cart badge appears in bottom nav across screens), `authProvider`, `themeProvider`, `wishlistProvider`, `connectivityProvider`.
- Loading/Error/Empty/Content must be explicit, exhaustive states — prefer a sealed/union-style state (e.g. a sealed class `HomeViewState` with `Loading`, `Error`, `Empty`, `Loaded` variants, or explicit boolean+nullable fields switched over exhaustively in the widget) so the UI can never render "loaded" content on top of stale error data.
- Debounce search input (300ms) via the `Debouncer` util before triggering the search provider.
- Pagination: every listing provider (`ProductListing`, `Search`, `Orders`) must support `loadMore()` triggered by scroll-position threshold (e.g. 80% scrolled), track `isLoadingMore` separately from initial `isLoading`, and append rather than replace.

---

## 5. Screen-by-Screen Requirements

Build **every** screen below. Do not omit any.

1. **Splash** — brand mark animation, checks auth/onboarding-seen state from `LocalStorage`, routes accordingly.
2. **Onboarding** — 3 swipeable illustrated slides communicating speed/freshness/convenience, animated page indicator, skip + next/get-started CTA.
3. **Login** — phone number entry (country code fixed, e.g. +91), validation, "Continue" calls the existing backend's `POST /api/v1/food/auth/user/request-otp`.
4. **OTP** — 6-digit segmented `OtpInput`, auto-focus/auto-advance, resend timer countdown, verifies against `POST /api/v1/food/auth/user/verify-otp` (wrong/expired code shows an inline error from the backend's response), success stores the returned JWT access/refresh tokens and routes to location permission or home if address already set.
5. **Location Permission** — rationale illustration + copy, "Allow Location Access" (mock-grants and fetches a fake current location) and "Enter Manually" fallback.
6. **Address Selection** — map placeholder (static styled container standing in for a map, with a centered pin), draggable-pin illustration, address form (house/flat, landmark, tag: Home/Work/Other), saved addresses list, "Use Current Location" mock action.
7. **Home** — see §6 below, the most detailed screen.
8. **Search** — search bar auto-focused on entry, recent searches (persisted locally, clearable), trending searches (mock chips), live-as-you-type debounced results grouped by product/category/brand, empty-results state with suggestions.
9. **Categories** — full category grid/list (all top-level categories with icon + name), tapping opens Sub Categories.
10. **Sub Categories** — two-pane or list layout (sub-category rail on left, matching product grid on right — quick-commerce-standard pattern), or top horizontal chip filter + grid, your call, but must let users jump between sub-categories without leaving the screen.
11. **Brand Listing** — grid of brand logos/cards, tapping opens Product Listing filtered by brand.
12. **Product Listing** — used for category/sub-category/brand contexts; grid of Product Cards, sort & filter bottom sheet (sort: relevance/price/rating; filters: price range, brand, veg/non-veg where relevant, discount %), pagination-ready infinite scroll, skeleton loading, empty state when filters yield nothing.
13. **Product Details** — see §6 below.
14. **Variants** — presented as a bottom sheet from the product card or product details ("Add" tap when the product has variants opens this instead of adding directly): list of variants (e.g. different sizes/weights) each with its own price/MRP/stock, single-select, confirm adds the selected variant to cart.
15. **Add-ons** — bottom sheet presented after/alongside variant selection for products that support add-ons (e.g. "Add cutlery", "Add a dip"), multi-select with individual prices, running subtotal shown live in the sheet, confirm adds base item + selected add-ons as one cart line.
16. **Wishlist** — grid of wishlisted Product Cards, remove-from-wishlist with animation, empty state, "Add all to cart" bulk action.
17. **Cart** — see §6 below.
18. **Checkout** — see §6 below.
19. **Coupons** — full list of available coupons (code, description, min-order-value, discount, expiry), applied-state indicator, "Apply" per coupon, ineligible coupons shown grayed-out with the reason ("Add ₹150 more to unlock"), a coupon-code manual entry field at top.
20. **Payment** — payment method selection (UPI, Cards, Wallet/Suvio Wallet, Cash on Delivery placeholders), selecting a method and confirming simulates a short "processing" animation then routes to Order Success (or a simulated failure state occasionally, with retry).
21. **Addresses** — full saved-address management list (add/edit/delete/set-default), swipe-to-delete, opens the Address Selection flow for add/edit.
22. **Notifications** — list of order updates/offers/system notices, unread indicator, mark-all-read, empty state, grouped by "Today"/"Earlier".
23. **Order Success** — celebratory animation (confetti or checkmark morph), order ID, estimated delivery time, CTA to Track Order and Continue Shopping.
24. **Order Tracking** — see §6 below.
25. **Orders** — list of past/active orders (status chip, item thumbnails, total, date), tap opens Order Details, active order pinned/highlighted at top with live-tracking CTA.
26. **Order Details** — itemized list, bill breakup, delivery address used, payment method, status timeline (collapsed version of tracking), "Reorder" and "Get Help" actions, "Rate your order" if delivered.
27. **Profile** — user avatar/name/phone, menu list (Orders, Addresses, Wishlist, Coupons, Notifications, Help, Settings, About, Logout), Suvio Wallet balance card if applicable.
28. **Edit Profile** — name, email, phone (read-only or OTP-reverify to change), avatar picker (mock), save with inline validation.
29. **Help** — FAQ accordion list + "Contact Support" (mock chat/call CTA), search-within-FAQ field.
30. **Settings** — theme mode (light/dark/system), primary color theme picker, notification toggles, language placeholder, app version.
31. **Privacy Policy** — static long-form scrollable content, properly typeset with the app's typography scale.
32. **Terms** — same treatment as Privacy Policy.
33. **About** — app logo, version, short mission blurb, social links (non-functional placeholders acceptable).

---

## 6. Deep-Dive Screen Specifications

### 6.1 Home Screen
Must include, top to bottom, each as its own componentized, independently-loading section (skeleton per section, not one page-level spinner):
- **Delivery address bar** (pinned at top): current short address + "Delivery in 8 mins" style dynamic ETA + chevron to open Address Selection; profile/notification icon(s) alongside.
- **Search bar** (tappable, routes to Search screen; not an inline editable field on Home).
- **Promotional banners** — auto-scrolling carousel, animated pagination dots, tap routes to a listing/offer.
- **Categories** — horizontal icon-grid (2 rows scroll) or horizontal scroll strip.
- **Featured brands** — horizontal scroll of brand cards.
- **Flash Sale** — horizontal scroll with a live-feeling countdown timer per section header.
- **Trending** — horizontal product scroll.
- **Recently Bought** — horizontal product scroll, only shown if mock order history is non-empty.
- **Recommended** — horizontal product scroll (mock "personalized" ranking).
- **Best Sellers** — horizontal product scroll with rank badges (#1, #2…).
- **Category-specific rows**, each horizontal-scrolling Product Cards: Fresh Vegetables, Fresh Fruits, Dairy, Bakery, Snacks, Cold Drinks, Frozen Food, Instant Food, Beauty, Personal Care, Baby Care, Medicines, Pet Care, Cleaning, Kitchen.
- Each horizontal section has a `SectionHeader` (title + "See all" → routes to Product Listing pre-filtered) and each vertical/grid context must be infinite-scroll/pagination-ready even though mock data is finite (design the provider to support it).
- Pull-to-refresh re-fetches all sections.

### 6.2 Product Card (used everywhere: home, listing, search, wishlist, recommendations)
Must display: large product image (with shimmer while loading, cached), discount badge (top-left, e.g. "20% OFF", only if discounted), wishlist heart icon (top-right, animated toggle, filled when wishlisted), product name (max 2 lines, ellipsis), unit/weight (e.g. "500 g", "1 L", "6 pcs"), MRP with strikethrough (only if discounted) + selling price (bold, prominent), delivery time badge (e.g. "8 MINS"), rating (stars + count, if available), variant indicator (e.g. "3 options" chip if the product has variants), stock state: normal / "Only 3 left" (limited stock, distinct visual treatment e.g. amber text) / "Out of Stock" (image desaturated, card interaction for add disabled, card still tappable to view details), and the **AnimatedAddButton**: shows "ADD" in default state; tapping a plain (no-variant) product adds directly to cart and the button **morphs** into a quantity stepper (− qty +) with a spring animation; tapping a variant product opens the Variants bottom sheet instead. Quantity changes animate the number (scale/fade transition) and update the cart badge with a bump animation.

### 6.3 Product Details
- **Image carousel**: large, swipeable, auto-scroll with a pause-on-manual-interaction, dot indicators, Hero-animated from the originating card.
- **Variants**: horizontal selectable chips/cards if the product has variants (size/weight/pack), selecting updates price/MRP/stock shown on the page.
- **Add-ons**: inline expandable section if applicable, mirrors the Add-ons bottom sheet content but embedded in-page as well as offered as a sheet from the sticky Add-to-Cart bar.
- **Description, Ingredients, Nutrition**: tabbed or accordion sections, populated with plausible mock content, "Nutrition" rendered as a small table (per 100g/serving).
- **Reviews & Ratings**: aggregate rating + histogram (5★...1★ bar breakdown), list of individual mock reviews (name, avatar initial, star rating, date, comment, optional "helpful" count), "Write a review" CTA (opens a rating+comment form, submits to `POST /api/reviews`, and appends the backend's response to the list).
- **Delivery estimate**: "Delivered in ~10 mins to [current address]".
- **Offers**: applicable coupon teasers relevant to this product ("Use SUVIO50 to save ₹50").
- **Share**: share-sheet trigger (can use `share_plus` or a stub showing the native share sheet).
- **Quantity selector + sticky bottom Add-to-Cart bar**: always visible while scrolling, shows live price for selected quantity/variant, animated add confirmation identical in spirit to the card's.
- Related/"You may also like" horizontal product row at the bottom.

### 6.4 Cart
- **Bill/store grouping**: if items from a single virtual "dark store"/restaurant concept exist, group visually (quick-commerce is typically single-store per cart — if you model multiple, group clearly with per-group subtotal and a note that a second store means a second delivery).
- Line items: image, name, variant/add-on summary, per-unit price, quantity stepper (with the same animated stepper component), swipe-to-remove, "saved for later"/move-to-wishlist optional affordance.
- **Coupons**: applied coupon banner (code + savings, with a "Remove" action) or "Apply Coupon" CTA opening the Coupons screen/sheet.
- **Bill details** breakdown, fully itemized: Item Total (MRP sum), Total Savings (MRP − selling price sum, shown as a positive "You saved ₹X" callout), Delivery Charge (or "FREE" badge if above threshold — implement a real free-delivery threshold rule in `CartPricingService`), Platform Fee, Taxes/GST, Coupon Discount (if applied, negative), **Grand Total** (bold, largest).
- Suggested add-ons/cross-sell horizontal row ("Add these to your order") above the bill details.
- **Animated checkout button**: sticky bottom bar showing item count + grand total on the left, "Proceed to Checkout" button on the right, subtle pulse/attention animation when items are first added, disabled/hidden state when cart is empty (replaced by empty-cart state with "Browse Products" CTA).
- All pricing math must come from `CartPricingService` in Domain — the Cart screen must not compute totals itself.

### 6.5 Checkout
- Delivery **address** card (selected address + "Change" → Address Selection/list), with a prompt if none is selected.
- **Delivery slot**: for quick-commerce this is typically "as soon as possible" — but also offer a schedule-for-later toggle with mock time-slot chips.
- **Payment methods** summary card (selected method + "Change" → Payment screen/sheet).
- **Order summary**: collapsed itemized list (expandable), matching Cart's bill breakup exactly (single source of truth via the same `CartPricingService`).
- **Offers/coupon** application entry point (same as Cart, kept in sync).
- **Bill breakup**: identical structure to Cart's, final Grand Total large and sticky at the bottom alongside "Proceed to Pay" (routes into Payment flow, then Order Success on mock success).
- Validate: no proceeding without a selected address (inline error + shake animation on the address card if attempted).

### 6.6 Order Tracking
- **Timeline**: vertical stepper — Order Placed → Order Confirmed → Preparing/Packing → Out for Delivery → Delivered — each step with a timestamp once reached, animated check-in when a new step activates. Poll `GET /api/orders/:id/track` on an interval (e.g. every few seconds) to advance the timeline as the backend's order status changes.
- **Live status UI**: prominent current-status banner with an animated icon (e.g. a pulsing scooter/bag icon) and live-feeling ETA countdown, both driven by the polled backend response.
- **Delivery partner**: name, mock avatar, rating, "Call" and "Message" icon buttons (non-functional placeholders acceptable, but must be present and styled).
- **Map placeholder**: a static, well-styled container standing in for a live map (branded, not a broken gray box — e.g. a stylized route illustration or a muted map-tile image with a route line and two pins), clearly reads as "map goes here" without looking broken.
- **OTP placeholder**: delivery-verification OTP shown prominently near the "Out for Delivery" step (mock 4-digit code) since quick-commerce apps show this for the delivery partner to confirm.
- **Support**: "Need help with this order?" CTA → Help screen or a mock support sheet.

---

## 7. Coding Standards & Principles

- **SOLID** throughout: single-responsibility widgets/classes, interfaces (`abstract class`) for every repository/service that has more than one theoretical implementation, no god-classes.
- **Composition over inheritance** for widgets — small, focused, reusable widgets composed together, not deep widget subclassing.
- **Immutability**: all models and state classes are immutable with `copyWith`; no mutable public fields on domain models.
- **Naming conventions** (match this exact style, consistent with the rest of this codebase): `ProductRepository` / `MockProductRepository`, `CartPricingService`, `HomeProvider`/`HomeState`, `ProductDto`, `ProductMapper`, `ProductModel` (or `Product` if unambiguous within Domain). Avoid vague names like `Helper`, `Manager`, `Common`, `Base`, `Temp`, `Data` unless the class is genuinely generic (e.g. a truly generic `Debouncer` util is fine).
- **Error handling**: typed exceptions/failures (`NetworkFailure`, `NotFoundFailure`, `ValidationFailure`, `UnknownFailure`) mapped in Data, surfaced as `Failure` objects through Domain, converted to user-facing copy only in UI (never leak raw exception text to users).
- **Widget optimization**: prefer `const` constructors everywhere possible, extract stateless sub-widgets instead of large `build()` methods, use `ListView.builder`/`GridView.builder` (never build unbounded lists eagerly), use `RepaintBoundary` around expensive repeatedly-animating widgets (e.g. shimmer, carousel), avoid rebuilding whole screens on unrelated state changes (scope Riverpod `select` where it matters — e.g. cart badge should not force home page sections to rebuild).
- **Image performance**: always specify `cacheWidth`/`cacheHeight` or let `cached_network_image` handle resizing appropriately for the rendered size; never load full-resolution images into small thumbnails.
- **Offline-ready architecture**: a `connectivityProvider` (via `connectivity_plus`) exposes online/offline state; screens show an `OfflineBanner` and disable network-dependent actions gracefully rather than crashing when the backend is unreachable.
- **Search-ready architecture**: `ProductRepository.search({query, filters, sort, page})` is backed by the existing backend's real `GET /api/v1/food/search/unified` endpoint (§1.1) — match its actual query params, don't invent new ones.
- **Pagination-ready architecture**: every listing-returning repository method accepts whatever pagination params the corresponding real endpoint supports and returns a `PagedResult<T>` (items + `hasMore` + total count) built from that endpoint's actual response envelope.
- Keep functions short and focused; keep files reasonably sized (split large screens into `widgets/` subfiles rather than one 1000-line `build()`).
- Zero business logic inside `build()` methods — compute via Domain services/usecases, expose ready-to-render state.

---

## 8. Deliverable Format

When you (the AI executing this prompt) generate the application, output:
1. A complete Flutter `pubspec.yaml` with every dependency used, pinned to a reasonable version. Do not touch the backend's `package.json` or any backend source file.
2. The full Flutter folder/file tree as specified in §2.1, with every file actually created (no empty stubs — every file must contain real, working code that calls the existing backend per §1.1).
3. All 33 screens listed in §5, fully implemented against the real, existing backend, navigable end-to-end via `go_router` from Splash through to every leaf screen.
4. A `README.md` with a clearly marked section titled **"Connecting to the Existing Backend"** covering: how to start the backend that already exists in `backend/food-backend/Backend` (its own existing run instructions — do not write new ones for it), and how to point the Flutter app at it via `--dart-define=API_BASE_URL=...` (§2.3).
5. If any screen or feature in this prompt has no real equivalent in the existing backend after you've read its source, list it explicitly under a **"Backend Gaps"** section in the README rather than silently mocking it.
6. Confirm before finishing that: the Flutter app builds with zero analyzer errors/warnings, every network call in the app corresponds to a real endpoint you verified in the backend source, every screen has loading/empty/error/content states where applicable, dark mode has been verified, and navigation from Splash to every listed screen is reachable through real UI interaction (no orphaned screens).

Build the "Suvio Quick" frontend now, fully integrated with the existing backend, following every requirement above exactly, with taste, restraint, and production discipline — premium, fast, beautiful, and unmistakably its own design.
