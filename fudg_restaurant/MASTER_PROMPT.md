# MASTER_PROMPT.md — Quick Commerce Seller App

**Document type:** Technical implementation specification + AI execution contract
**Target executor:** An AI coding agent with full repository access
**Reference implementation:** The existing Flutter *Food Restaurant Partner* app in this repository (Dart package `food_user_application`)
**Backend:** The already-built Quick Commerce backend located inside this project under `backend/`

---

## 0. HOW TO USE THIS DOCUMENT

You are the AI agent building the Quick Commerce Seller App. This document is your contract.

Read it end to end **before** touching any file. Then execute **Phase 0 (Analysis)** in Section 6 and produce the required analysis report. Only after that report is delivered may you write a single line of production code.

Rules of precedence, highest first:

1. Explicit instructions from the human operator in the live conversation.
2. This document.
3. Patterns actually present in the existing codebase (`lib/`) and the existing backend (`backend/`).
4. `GUIDELINES.md` in the repository root.
5. General Flutter/Dart community convention.

Where rule 3 and rule 4 conflict, **rule 3 wins** — see Section 2.4. Where anything conflicts with this document, this document wins unless the human says otherwise.

If a rule in this document turns out to be impossible or wrong given what you find in the repository, **stop and report it**. Do not silently deviate.

---

## 1. PROJECT GOALS

### 1.1 What is being built

A production-grade **Quick Commerce Seller App** in Flutter — the merchant-side application for a quick-commerce (10–30 minute grocery/essentials delivery) platform. The seller uses it to run their store: manage the catalogue, keep stock accurate, accept and fulfil orders, track money, and configure their storefront.

### 1.2 Primary objectives

| # | Goal | Definition of success |
|---|------|----------------------|
| G1 | Full seller lifecycle coverage | Every module in Section 7 is implemented, wired to live APIs, and usable end to end. |
| G2 | Zero new backend | Not one new endpoint, route, controller, model, migration, or server file is created. The existing backend is consumed as-is. |
| G3 | Architectural continuity | The app is indistinguishable in structure, style, and idiom from the existing partner app. A developer moving between the two feels no seam. |
| G4 | No fake data, ever | No mock repositories, no stub JSON, no `Future.delayed` fakes, no hardcoded lists, no placeholder screens shipped as "done". |
| G5 | Always shippable | At the end of every module, the app compiles, analyzes clean, and runs on both Android and iOS. |
| G6 | Analyzer-clean | `flutter analyze` reports **0 errors, 0 warnings, 0 infos** at every module boundary. |
| G7 | Dual-platform | Android and iOS are both fully supported and both verified. Neither is deferred. |

### 1.3 Explicit non-goals

- Do **not** build a customer app, a delivery-partner app, or an admin panel.
- Do **not** build, extend, patch, migrate, or "improve" the backend.
- Do **not** redesign the architecture, swap the state management library, or replace the networking layer.
- Do **not** add web or desktop targets beyond what already exists.
- Do **not** introduce code generation (`build_runner`, `freezed`, `json_serializable`) — the existing codebase writes models by hand.

---

## 2. THE EXISTING SYSTEM — WHAT YOU MUST REUSE

This section is a verified inventory of the reference app. It is the ground truth you build on. **Confirm every item yourself in Phase 0** — this document was written at a point in time and the code may have moved on.

### 2.1 Package and tooling facts

| Fact | Value |
|------|-------|
| Dart package name | `food_user_application` |
| Import prefix in use | `package:food_user_application/...` (absolute, not relative) |
| Dart SDK constraint | `^3.11.4` |
| App version | `4.1.1+1` |
| Lints | `flutter_lints: ^6.0.0` via `analysis_options.yaml` (`include: package:flutter_lints/flutter.yaml`), no custom rules enabled |
| Android `applicationId` | `com.appzetofood.restaurant` |
| Android `compileSdk` | `36`, `minSdk` floor `21` |
| iOS | Present and configured under `ios/` |
| Test directory | **Does not exist yet** |
| Code generation | **None.** No `build_runner`, no `freezed`, no `json_serializable` |
| Localization | `l10n.yaml` + `lib/l10n/app_en.arb` + `lib/generated/l10n/` exist but are **effectively unused**; screens use hardcoded English strings |

### 2.2 Key dependencies already in `pubspec.yaml`

`flutter_riverpod ^3.3.2` · `go_router ^17.3.0` · `dio ^5.10.0` · `flutter_secure_storage ^10.3.1` · `cached_network_image ^3.4.1` · `firebase_core ^4.12.1` · `firebase_messaging ^16.4.3` · `socket_io_client ^3.1.6` · `image_picker ^1.2.0` · `geolocator ^14.0.2` · `geocoding ^4.0.0` · `google_maps_flutter ^2.13.1` · `intl ^0.20.2` · `flutter_local_notifications ^18.0.1` · `shared_preferences ^2.5.5` · `audioplayers ^6.7.1` · `connectivity_plus ^6.1.1` · `permission_handler ^13.0.0` (pinned via `dependency_overrides: permission_handler_android: 13.0.1`) · `android_intent_plus ^6.1.0` · `in_app_update ^4.2.0` · `in_app_review ^2.0.12`

**Rule:** If a capability you need is covered by a package already in this list, use it. Adding a new dependency requires an explicit written justification in your progress report and human approval before you add it.

### 2.3 Actual folder structure (`lib/`)

```
lib/
├── main.dart                         # runZonedGuarded + Firebase init + ProviderScope
├── app.dart                          # MaterialApp.router, theme wiring, lifecycle hooks, network overlay
│
├── config/
│   ├── constants/app_constants.dart  # baseUrl, socketUrl, Firebase + Maps keys
│   ├── router/app_router.dart        # goRouterProvider, auth redirect, StatefulShellRoute
│   └── theme/
│       ├── app_colors.dart           # AppColors
│       ├── app_text_styles.dart      # AppTextStyles
│       ├── app_theme.dart            # lightTheme, darkTheme
│       └── theme_mode_provider.dart  # ThemeModeNotifier (StateNotifier, persisted)
│
├── core/
│   ├── network/
│   │   ├── dio_client.dart           # dioProvider, AuthSessionNotifier, refresh-token queue
│   │   └── api_exception.dart        # ApiException
│   ├── providers/
│   │   ├── core_providers.dart       # secureStorageProvider, tokenStorageProvider
│   │   └── session_reset.dart        # resetSessionScopedProviders(ref)
│   ├── services/                     # fcm, socket, audio, local notifications,
│   │                                 # network_controller, update, review,
│   │                                 # battery_optimization, order_notification_action_handler
│   ├── storage/token_storage.dart    # TokenStorage over FlutterSecureStorage
│   ├── utils/multipart_utils.dart    # xFileToMultipart(XFile) -> MultipartFile
│   └── widgets/                      # app_toast, app_refresh_indicator, app_drawer,
│                                     # no_network_overlay, exit_app_dialog,
│                                     # battery_optimization_dialog
│
├── features/<feature>/
│   ├── data/          <feature>_repository.dart   (or *_api.dart for auth)
│   ├── domain/        <thing>_model.dart
│   └── presentation/
│       ├── controllers/  <feature>_controller.dart, <feature>_state.dart
│       ├── views/        <screen>_screen.dart
│       └── widgets/      <component>.dart
│
├── l10n/              app_en.arb
└── generated/l10n/    app_localizations*.dart
```

Existing features, for pattern reference: `addons`, `auth`, `complaints`, `explore`, `feedback`, `finance`, `inventory`, `main_layout`, `menu_categories`, `menu_items`, `notifications`, `offers`, `onboarding`, `orders`, `payouts`, `profile`, `registration`, `restaurant_profile`, `splash`, `support`, `zones`.

### 2.4 IMPORTANT — `GUIDELINES.md` diverges from the real code

`GUIDELINES.md` describes a **top-level layered** structure:

```
lib/data/  lib/domain/  lib/ui/  lib/di/  lib/platform/  lib/core/
```

**That structure does not exist in this repository.** The real code is **feature-first with per-feature layers**: `lib/features/<feature>/{data,domain,presentation}`.

Your obligations:

- **Follow the real code** (`lib/features/...`). Do not create `lib/data/`, `lib/domain/`, `lib/ui/`, `lib/di/`, or `lib/platform/`.
- **Follow the *principles* in `GUIDELINES.md`** where they are architecture-neutral and genuinely observed: one-way dependency flow, framework-free domain models, no API calls from widgets, no business logic in widgets, immutable models, DI via Riverpod providers, typed errors, small focused classes, no duplicate code, descriptive names over `Helper`/`Manager`/`Utils`.
- Note the divergence once in your Phase 0 report and move on. Do not "fix" `GUIDELINES.md` and do not restructure existing code to match it.

### 2.5 Networking layer — study `lib/core/network/dio_client.dart` closely

The single `dioProvider` is the **only** HTTP entry point in the app. It already implements:

- `BaseOptions` from `AppConstants.baseUrl`; connect/receive timeouts 20 s, send timeout 30 s; JSON content type.
- **Request interceptor:** reads the access token from `TokenStorage` and sets `Authorization: Bearer <token>`.
- **Response interceptor / envelope unwrapping:** the backend replies with `{ "success": bool, "message": String, "data": {...} }`. On `success == true` the interceptor **replaces `response.data` with the inner `data` payload**. On `success == false` it rejects with a `DioException` carrying an `ApiException` built from `message`.
  → **Consequence: repositories parse the *unwrapped* payload. Never re-unwrap `['data']` yourself.**
- **Error interceptor:** on `401` for non-auth endpoints it refreshes tokens via a dedicated interceptor-free `refreshDio` calling `POST /food/auth/refresh-token`, **de-duplicating concurrent refreshes through a `Completer` queue**, then replays the original request. If refresh fails it clears storage and fires `AuthSessionNotifier.notifySessionExpired()`.
- Every error that leaves the interceptor is a `DioException` whose `.error` is an `ApiException` with a human-readable `message`, `statusCode`, and raw `data`. Timeout and connectivity cases already have friendly copy.
- `authSessionProvider` (a plain `Provider<AuthSessionNotifier>` — Riverpod 3 dropped `ChangeNotifierProvider`) is listened to by the auth controller, which resets to logged-out; the router redirect then sends the user to `/login`.

**Rules:** Reuse `dioProvider` unchanged. Never construct a `Dio` instance in a feature. Never add an interceptor from a feature. If the Quick Commerce backend uses a different auth path prefix than `/food/auth/...`, the `isAuthEndpoint` check in `onError` is the one place that may need widening — flag it and get approval before editing.

### 2.6 Repository pattern (canonical example: `lib/features/finance/data/finance_repository.dart`)

```
class XRepository {
  XRepository(this._dio);
  final Dio _dio;

  Future<Model> getThing() async {
    final response = await _dio.get('/path');
    return Model.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}

final xRepositoryProvider = Provider<XRepository>((ref) => XRepository(ref.watch(dioProvider)));
```

Observed conventions:
- Constructor takes `Dio`; the provider lives at the bottom of the same file.
- Returns **domain models**, never raw maps (exception: `auth_api.dart` returns unwrapped maps because the auth payload is polymorphic — treat that as the documented exception, not the rule).
- Defensive casting: `Map<String, dynamic>.from(x as Map)`, `(x as List? ?? [])`.
- Optional request fields use collection-if: `if (v != null) 'key': v`.
- `PATCH` for partial updates, `POST` for creates, `DELETE` for deletes.
- Repositories contain **no** business rules, no UI, no navigation, no toasts.

### 2.7 Domain model pattern (canonical example: `lib/features/menu_items/domain/food_item_model.dart`)

- Plain Dart class. **No Flutter imports. No Riverpod imports. No Dio imports.**
- All fields `final`; class is effectively immutable.
- Named-required constructor first, then `factory X.fromJson(Map<String, dynamic> json)`, then fields, then computed getters.
- **Totally defensive parsing** — every field has a fallback so a malformed payload can never throw:
  - IDs: `(json['id'] ?? json['_id'] ?? '').toString()`
  - Strings: `(json['x'] ?? '').toString()`
  - Numbers: a local `num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());` then `?.toDouble() ?? 0`
  - Booleans: `json['x'] == true` (default false) or `json['x'] != false` (default true) — choose deliberately per field
- Derived state as getters: `bool get isVeg => foodType == 'Veg';`
- Enum-like values are kept as `String` with getters, matching the existing style. Do not introduce Dart `enum`s for backend status strings unless a module spec here calls for it.

### 2.8 State management (Riverpod 3)

| Pattern | When used | Example |
|---------|-----------|---------|
| `AsyncNotifier<T>` + `AsyncNotifierProvider` | Async screen/feature state — **the default** (14+ in use) | `MenuController` |
| `Notifier<T>` + `NotifierProvider` | Sync state machines | `AuthController` over sealed `AuthState` |
| `Provider<T>` | DI: repositories, services, Dio, storage | `menuRepositoryProvider` |
| `StateNotifier` + `import 'package:flutter_riverpod/legacy.dart'` | Legacy only, e.g. `ThemeModeNotifier` | avoid in new code |

Observed controller conventions:
- `build()` delegates straight to a repository call.
- `refresh()` sets `AsyncValue.loading()` then `state = await AsyncValue.guard(() => repo.call())`.
- Mutations call the repository, then `await refresh()`.
- **Optimistic updates** where the UI must feel instant (see `MenuController.toggleAvailability`): mutate `state` locally, call the API, and on failure `await refresh(); rethrow;`.
- Sealed classes for finite state machines (`AuthState`: `AuthInitial`, `AuthLoggedOut`, `AuthOtpSent`, `AuthNeedsRegistration`, `AuthPendingApproval`, `AuthRejected`, `AuthAuthenticated`).
- Controllers do **not** touch `BuildContext`, show dialogs, or navigate.

### 2.9 Session-scoped provider reset — `lib/core/providers/session_reset.dart`

None of the data controllers are `autoDispose`, so they survive logout. `resetSessionScopedProviders(Ref ref)` explicitly `ref.invalidate(...)`s every session-scoped controller, and is called on login, on logout, and on forced session expiry.

**Hard rule:** every new session-scoped controller you create **must** be added to `resetSessionScopedProviders`. This is a mandatory checklist item in every module's progress report.

### 2.10 Routing (`lib/config/router/app_router.dart`)

- `goRouterProvider` returns a `GoRouter` with `initialLocation: '/'`.
- `_GoRouterRefreshNotifier` listens to `authControllerProvider` and calls `notifyListeners()` so the redirect re-runs **without** rebuilding the router (rebuilding would reset the whole nav stack).
- `_publicRoutes` is a `const Set<String>` of routes reachable while logged out. Authenticated users hitting `/`, `/login`, or `/onboarding` are redirected to the main shell; unauthenticated users hitting anything not in `_publicRoutes` are redirected to `/login`.
- `rootNavigatorKey` is **public** so non-widget code (FCM tap handling) can navigate without a `BuildContext`.
- The main shell is a `StatefulShellRoute.indexedStack` with one `StatefulShellBranch` per bottom-nav tab, each with its own `GlobalKey<NavigatorState>`.
- Detail routes take path params (`/order-details/:id`) and simple `state.extra` payloads.

### 2.11 Theme (`lib/config/theme/`)

- `AppColors` — brand (`primary #FF7622`, `primaryLight`, `primaryDark`), dark palette (`backgroundDark`, `surfaceDark`, `surfaceVariantDark`, `textPrimaryDark`, `textSecondaryDark`), light palette (`backgroundLight`, `surfaceLight`, `surfaceVariantLight`, `textPrimaryLight`, `textSecondaryLight`), status (`success`, `rating`, `error`).
- `AppTextStyles` — `h1`–`h4`, `bodyLarge/Medium/Small`, `button`, `caption`.
- `app_theme.dart` — full `lightTheme` and `darkTheme` (`useMaterial3: true`), font family `ManropeVariable`, card/input radius `16`, button radius `30`, button height `56`, `AppBarTheme` with `elevation: 0` and `centerTitle: true`.
- `themeModeProvider` persists the choice in `SharedPreferences` under `app_theme_mode`; default `ThemeMode.light`.

### 2.12 Shared widgets (`lib/core/widgets/`) — reuse, do not re-create

| Widget | Use |
|--------|-----|
| `AppToast.show / showError / showSuccess` | **All** user feedback. Floating snackbar, radius 16, icon + message. Never call `ScaffoldMessenger` directly. |
| `AppRefreshIndicator` | **All** pull-to-refresh. Plays the refresh sound via `audioServiceProvider`, then awaits `onRefresh`. Never use bare `RefreshIndicator`. |
| `NoNetworkOverlay` | Global offline overlay, already stacked in `app.dart`. Do not re-implement per screen. |
| `ExitAppDialog` | Back-press-to-exit confirmation on the root tab. |
| `BatteryOptimizationDialog` | One-time battery-optimization prompt, gated on `TokenStorage.hasSeenBatteryPrompt`. |
| `AppDrawer` | Existing side navigation. |

### 2.13 Core services (`lib/core/services/`) — reuse, do not re-create

| Service | Responsibility |
|---------|---------------|
| `fcm_service.dart` | Firebase Messaging: permission, token registration (re-registered on **every app resume** — idempotent server-side), foreground/background handlers, data-only push body composition, tap-payload encode/decode, navigation via `rootNavigatorKey`. |
| `socket_service.dart` | Socket.IO wrapper. Connects with the JWT in `auth`, websocket transport, auto-reconnect. Server auto-joins the role/id room. `on(event, handler)` / `off(event)` / `disconnect()`. |
| `local_notification_service.dart` | `flutter_local_notifications` channels, full-screen intents, action buttons. |
| `order_notification_action_handler.dart` | Accept/reject actions fired from a notification. |
| `audio_service.dart` | Alert and refresh sounds. |
| `network_controller.dart` | `connectivity_plus`-backed online/offline boolean driving `NoNetworkOverlay`. |
| `update_service.dart` | In-app update (`in_app_update`). |
| `review_service.dart` | In-app review (`in_app_review`). |
| `battery_optimization_service.dart` | Battery-optimization exemption via `permission_handler` / `android_intent_plus`. |

### 2.14 App bootstrap (`main.dart` / `app.dart`)

- `main()` wraps everything in `runZonedGuarded`; sets `FlutterError.onError` and `PlatformDispatcher.instance.onError` so no uncaught error kills the app.
- Firebase init is wrapped in `try/catch` — a device with broken Play Services must still launch the app.
- `runApp(const ProviderScope(child: <RootWidget>()))`.
- Root widget is a `ConsumerStatefulWidget` with `WidgetsBindingObserver`; on `AppLifecycleState.resumed` it refreshes live orders and re-registers the FCM token.
- `MaterialApp.router` with `debugShowCheckedModeBanner: false`, `theme`/`darkTheme`/`themeMode`, `routerConfig`, and a `builder` that stacks `NoNetworkOverlay` above the router child.

### 2.15 UI conventions observed in screens

- Screens are `ConsumerWidget` (or `ConsumerStatefulWidget` when local state/controllers/lifecycle is needed) — 37 files use these.
- `final isDarkMode = Theme.of(context).brightness == Brightness.dark;` at the top of `build`, then ternaries against `AppColors`.
- `Scaffold` → `backgroundColor: Theme.of(context).scaffoldBackgroundColor`; `AppBar` → `elevation: 0`, `centerTitle: true`, explicit `leading` `IconButton` calling `context.pop()`.
- `asyncValue.when(loading:, error:, data:)` in the body — this is the standard tri-state render (20 call sites).
- `loading:` → `const Center(child: CircularProgressIndicator())`.
- `error:` → centred, padded `Text` using `error is ApiException ? error.message : '<friendly fallback>'`.
- `data:` → `AppRefreshIndicator` wrapping a scrollable with `physics: const AlwaysScrollableScrollPhysics()`.
- Destructive actions go through a confirmation dialog.
- `const` constructors everywhere they are legal.

---

## 3. NON-NEGOTIABLE RULES

These are absolute. Violating any one of them means the module is rejected and must be redone.

### 3.1 Analysis before code
**R1.** You do not write production code until Phase 0 analysis is complete and its report is delivered.

### 3.2 Architecture
**R2.** Reuse the existing architecture exactly. Do not invent a new one.
**R3.** Do not change the architecture without a written, specific, technical reason approved by the human first. "Cleaner", "more modern", "best practice" are not reasons.
**R4.** Do not create `lib/data/`, `lib/domain/`, `lib/ui/`, `lib/di/`, or `lib/platform/`. Feature-first only.
**R5.** Do not swap, wrap, or supplement Riverpod, go_router, or Dio with another library.
**R6.** Dependency flow is one-way: `presentation → domain ← data`. Domain imports nothing from Flutter, Riverpod, or Dio.

### 3.3 Backend
**R7.** **Never generate a backend.** No server code, no routes, no controllers, no schemas, no migrations, no seed scripts, no serverless functions, no local mock server.
**R8.** **Never create a duplicate API.** If an endpoint exists, call it. If you believe one is missing, **stop and report** — do not work around it.
**R9.** **Never duplicate business logic that the backend already performs.** Totals, commissions, payout amounts, discount math, stock decrements, order-state transitions, and eligibility rules are computed server-side. The app displays them. Client-side recomputation of a server-owned number is a defect.
**R10.** Use **only** the backend inside this project's `backend/` folder. No external APIs, no third-party services not already wired in `pubspec.yaml`.

### 3.4 Data authenticity
**R11.** **No mock data.** Not in screens, not in providers, not "temporarily".
**R12.** **No fake APIs, no stubbed repositories, no `Future.delayed` simulations, no in-memory fixture lists.**
**R13.** **No hardcoded values** for anything the backend owns: prices, commissions, tax rates, statuses, category lists, currency codes, limits, IDs, store data. Design constants (padding, radii, durations, asset paths) are fine.
**R14.** **Every screen renders live backend data.** A screen with no backing endpoint is not built until Section 5's mapping resolves it.
**R15.** If an endpoint genuinely does not exist for a required screen, **stop the module and report it**. Do not stub it. Do not fake it. Do not build the UI "ready for later wiring".

### 3.5 Quality gates
**R16.** `flutter analyze` → **0 errors, 0 warnings, 0 infos** at every module boundary.
**R17.** `dart format .` applied; no formatting-only diffs left behind.
**R18.** The app builds and runs on **both** Android and iOS after every module.
**R19.** No `print()` in production paths — use `debugPrint` guarded by `kDebugMode`, matching `main.dart`. (Note: `socket_service.dart` currently has a bare `print` — do not copy that; do not fix it either unless asked.)
**R20.** No `// TODO`, no commented-out code, no dead code, no unused imports, no unreachable branches in delivered work.
**R21.** No secrets, tokens, or credentials committed. Keys live in `AppConstants` exactly as the existing app does.

### 3.6 Process
**R22.** **One module at a time.** Do not start module N+1 before module N is verified and reported.
**R23.** **Verify backend integration after every module** against the real running backend.
**R24.** **Deliver a progress report after every module**, in the Section 12 template.
**R25.** Never claim something works that you have not run. If a check was skipped, say so explicitly.

---

## 4. BACKEND INTEGRATION RULES

### 4.1 GATE 0 — locate and read the backend (blocking)

⚠️ **Known issue at the time of writing: `backend/` in this repository contains only an empty `backend/food-backend/` directory and `backend/build/.last_build_id`. `.gitignore` also excludes `backend/`. The Quick Commerce backend source was not present.**

Before anything else:

1. Inspect `backend/` and every subdirectory.
2. If backend source is present — read it fully and proceed to 4.2.
3. If it is **absent, empty, or clearly incomplete** — **STOP**. Report exactly what you found, and ask the human for: the backend source location, or a repository URL, or a machine-readable API contract (OpenAPI/Swagger/Postman collection), plus the base URL of a running instance.
4. **Under no circumstances** may you respond to a missing backend by generating one, scaffolding one, mocking one, or inferring endpoints from the Food app and hoping they exist. R7/R8/R11 apply with full force.

### 4.2 Read the backend the way its authors did

Once located, produce a complete picture before writing client code:

- **Entry point & server config** — framework, port, middleware stack, CORS, body limits.
- **Route registry** — every router file; the exact mounted path prefix for each (the Food app mounts everything under `/api/v1` with a `/food/...` sub-prefix; the Quick Commerce prefix may differ — **verify, never assume**).
- **Controllers/handlers** — for each endpoint: HTTP method, full path, path params, query params, request body shape and required fields, success response shape, status codes, and every error branch with its message.
- **Response envelope** — confirm whether it is the same `{ success, message, data }` shape the Dio interceptor unwraps. **If it differs, stop and report** — the interceptor is shared infrastructure and changing it needs approval.
- **Auth** — token type, header format, expiry, refresh endpoint and payload, role/claims, which routes are public.
- **Data models/schemas** — every field, type, default, enum, required flag, and relation. Field names in JSON responses (`_id` vs `id`, camelCase vs snake_case) drive your `fromJson`.
- **Validation** — server-side rules per field (min/max, regex, allowed values). Client validation must **mirror** these, never contradict them.
- **File uploads** — endpoint(s), field names, `multipart/form-data` vs base64 vs pre-signed URL, size and MIME limits, and the shape of the returned URL.
- **Realtime** — Socket.IO namespace/path, handshake auth, room-joining logic, and the exact event names and payloads emitted to sellers.
- **Push** — which server events trigger FCM, and the `data` payload keys the client must read.
- **Pagination** — page/limit vs cursor, and the exact response metadata keys.

### 4.3 Deliverable: `API_MAP.md`

Produce and maintain `API_MAP.md` at the repository root. It is the single source of truth linking backend to app. One row per endpoint:

| Column | Content |
|--------|---------|
| Module | Which app module consumes it |
| Method | GET / POST / PATCH / PUT / DELETE |
| Path | Full path including prefix, e.g. `/api/v1/seller/products/:id` |
| Backend file:line | Where the handler lives |
| Auth | Public / Bearer / role required |
| Request | Path params, query params, body fields with types and required flags |
| Response | Unwrapped payload shape (post-envelope) |
| Errors | Status codes and server messages |
| Flutter repository | `lib/features/<f>/data/<f>_repository.dart` |
| Flutter method | The Dart method name calling it |
| Model | The domain model it maps to |
| Status | `Not started` / `Wired` / `Verified against live backend` |

Rules:
- Fill in the backend columns for a module's endpoints **before** writing that module's repository.
- Update the `Status` column as you go. `Verified` means you saw a real response from a running backend.
- **Any endpoint the app needs but the backend lacks goes into a "GAPS" section at the bottom and is escalated — never silently implemented.**
- **Any endpoint that already has a Flutter method must not get a second one.** Search `API_MAP.md` before adding a repository method.

### 4.4 Integration rules

**B1.** Every endpoint is called through `dioProvider`. No other HTTP client.
**B2.** Every endpoint is called from exactly one repository method. Two methods hitting the same endpoint is a duplication defect.
**B3.** Repositories parse the **unwrapped** payload (see 2.5).
**B4.** Paths are written as string literals in repository methods, exactly as the existing code does. Do not build an endpoint-constants file unless the human asks — the existing app does not have one.
**B5.** Request bodies use collection-if for optional fields.
**B6.** Frontend and backend integration are done **together**, in the same module. Never "build the UI now, wire it later".
**B7.** If the backend returns a field the model does not need, ignore it. If it omits a field the model expects, the defensive `fromJson` fallback covers it — but **report the mismatch**.
**B8.** Never mutate, patch, or "fix" backend files. If a backend bug blocks you, report it and stop the module.

---

## 5. API MAPPING STRATEGY

For each module, in this order:

1. **Enumerate the screens** the module needs (from Section 7).
2. **Enumerate the data each screen shows** and each action it offers.
3. **Find the backend endpoint** for every one of those, in the backend source. Record it in `API_MAP.md`.
4. **Classify each screen requirement:**
   - **Covered** — an endpoint exists and returns what is needed → build it.
   - **Partially covered** — an endpoint exists but is missing a field or a filter → build what is covered; log the gap; **do not compute the missing part client-side if it is server-owned** (R9).
   - **Not covered** — no endpoint → **GAP. Escalate. Do not build the screen.**
5. **Never invent a path.** If you cannot point to the handler in the backend source, the endpoint does not exist.
6. **Never assume symmetry with the Food app.** `/food/restaurant/menu` existing says nothing about the Quick Commerce backend.
7. **Reconcile terminology** in the mapping table — the backend's vocabulary (product/SKU/variant/store/outlet/seller/merchant) is authoritative for model and field names; UI copy may differ where the module spec says so.
8. **Escalate contract oddities** rather than absorbing them: inconsistent envelopes, snake_case in one route and camelCase in another, an `id` that is sometimes a string and sometimes an object. Report, then handle defensively in `fromJson`.

---

## 6. DEVELOPMENT WORKFLOW

### PHASE 0 — ANALYSIS (blocking; no production code)

Do all of this before writing any feature code:

1. Read every file in `lib/` — all of `config/`, all of `core/`, and at least three complete features end to end (`menu_items`, `orders`, `finance` are recommended).
2. Read `pubspec.yaml`, `analysis_options.yaml`, `GUIDELINES.md`, `optimization_flow.md`, `l10n.yaml`.
3. Read the Android (`android/app/build.gradle.kts`, `AndroidManifest.xml`) and iOS (`ios/Runner/Info.plist`, capabilities) configuration.
4. Execute **Gate 0** (4.1) and, if the backend is present, the full read in 4.2.
5. Run `flutter analyze` and record the **baseline** — you must not add to it, and you should aim to reach zero.
6. Produce the **Phase 0 Analysis Report**:
   - Architecture summary in your own words (layers, DI graph, navigation, auth flow, error flow).
   - Inventory of reusable assets: every widget, service, util, provider, and theme token you will reuse, by file path.
   - Backend inventory: modules, route groups, auth scheme, envelope, upload mechanism, realtime events.
   - Draft `API_MAP.md` (backend columns filled for at least the first two modules).
   - Module build order with dependencies.
   - Every gap, ambiguity, contradiction, and risk found — with the specific question you need answered.
   - The analyzer baseline.
7. **Deliver the report and wait for approval before Phase 1.**

### PHASE 1..N — ONE MODULE AT A TIME

For each module, in the approved order:

1. **Scope** — restate the screens, data, and actions in one short paragraph.
2. **Map** — fill `API_MAP.md` for this module's endpoints. If there is a GAP, escalate now.
3. **Domain** — write immutable models with defensive `fromJson` (2.7).
4. **Data** — write the repository + provider (2.6). One method per endpoint.
5. **Presentation** — controller (`AsyncNotifier` by default) + state, then screens and widgets.
6. **Register** — add routes to `app_router.dart`; add session-scoped controllers to `resetSessionScopedProviders` (2.9).
7. **Reuse audit** — before shipping, confirm you did not re-create anything from 2.12/2.13 and did not duplicate an existing repository method.
8. **Verify** — run the Section 10 verification for this module against the **live backend**.
9. **Gates** — `dart format .`, `flutter analyze` (must be 0/0/0), Android build+run, iOS build+run.
10. **Report** — deliver the Section 12 progress report.
11. **Stop.** Wait for go-ahead before the next module.

### Rules of engagement during a module

- Do not refactor unrelated existing code. If you spot a real bug in the Food app, report it; do not fix it uninvited.
- Do not start a second module because the first is "basically done".
- If blocked, complete every part of the module that is not blocked, then report precisely what is blocked and why. Do not fake past a blocker.
- Keep diffs minimal and focused. No drive-by renames, no import reshuffling, no formatting churn in files you did not otherwise change.

---

## 7. MODULE SPECIFICATIONS

> For **every** module below, these apply and are not repeated each time:
> live backend APIs only (R11–R15) · existing architecture (R2–R6) · `AsyncNotifier` + `AsyncValue.when` tri-state UI · `AppRefreshIndicator` for refresh · `AppToast` for feedback · `ApiException.message` for error copy · light + dark themed · Android + iOS verified · added to `resetSessionScopedProviders` if session-scoped · `flutter analyze` 0/0/0.
>
> Every field, status value, filter, and action listed below is **conditional on the backend supporting it**. Map first (Section 5); build only what is covered; escalate the rest.

### M0 — Foundation

Establish the shell before any feature.

- Confirm/adjust `AppConstants.baseUrl` and `socketUrl` for the Quick Commerce backend.
- Verify the response envelope matches what `dio_client.dart` unwraps; escalate if not.
- Verify `TokenStorage` key set covers the seller session (tokens, seller/store id, status, onboarding + prompt flags); extend it if the backend requires more, following the existing style.
- Set up `main.dart` / `app.dart` equivalents: `runZonedGuarded`, guarded Firebase init, global error handlers, `ProviderScope`, `MaterialApp.router`, theme wiring, `NoNetworkOverlay` in the builder, resume-lifecycle hooks.
- Splash screen that resolves the stored session and routes accordingly.
- Router skeleton: public route set, auth redirect, `StatefulShellRoute.indexedStack` for the bottom tabs, `rootNavigatorKey`.
- Onboarding screens gated on `TokenStorage.hasSeenOnboarding`.

**Verify:** cold start on a clean install lands on onboarding/login; cold start with a valid stored session lands on the dashboard; killing the network shows `NoNetworkOverlay`; theme toggle persists across restart.

### M1 — Authentication

- Login exactly as the backend defines it (OTP, password, or both — read the backend, do not assume OTP because the Food app uses OTP).
- OTP entry with resend cooldown if OTP is used.
- Seller registration/onboarding flow if the backend exposes one, following the existing multi-step registration pattern (`features/registration/`: step widgets, a form-data domain object, a controller owning step state).
- Application/approval status screen for pending and rejected sellers.
- Token persistence via `TokenStorage`; refresh handled by the existing interceptor.
- Session expiry → `AuthSessionNotifier` → logged-out state → router redirect.
- A sealed `AuthState` covering every state the backend can put a seller in.
- FCM permission request and token registration on successful login.

**Verify:** wrong OTP/password shows the server's message; expired access token silently refreshes and replays the request; invalidated refresh token bounces to login exactly once (no loop, no duplicate refresh calls under concurrency); pending and rejected sellers see their status screen and cannot reach the dashboard.

### M2 — Store Management

- Store profile: name, description, logo, banner, contact, address, geolocation.
- Open/closed toggle and operating hours per day.
- Serviceable area / delivery zone configuration, if the backend supports it (`features/zones/` is the reference).
- Delivery settings: radius, minimum order, delivery fee, prep time — **all read from and written to the backend**, never hardcoded.
- Store status (active / suspended / under review) surfaced clearly.
- Bank / payout account details, if store-scoped.

**Verify:** every field round-trips (edit → save → reload from server → value persists); toggling store open/closed reflects on the server; invalid input is rejected with the server's message.

### M3 — Categories

- List categories with their real hierarchy (parent/child) if the backend models one.
- Create, edit, delete (with confirmation), reorder if supported.
- Category image upload via the shared upload path (M16).
- Active/inactive toggle with an optimistic switch (2.8 pattern).
- Distinguish platform-global categories from seller-owned ones if the backend does — never let a seller edit what they do not own.

**Verify:** CRUD persists server-side; deleting a category with products behaves exactly as the backend dictates (blocked or cascading — do not guess); the product form's category picker reads this same list with no duplicate fetch logic.

### M4 — Product Management

The core catalogue module.

- Product list: search (debounced 300–500 ms), filter (category, status, availability), sort, and **pagination driven by the backend's real paging contract**.
- Product detail view.
- Create and edit product: name, description, images, category, brand, unit/pack size, MRP, selling price, tax, SKU/barcode, attributes — **exactly the fields the backend schema defines**.
- Variants (size/weight/pack) if the backend models them.
- Availability toggle — optimistic, reverting on failure.
- Delete/archive per the backend's semantics.
- Approval status (pending/approved/rejected) and rejection reason surfaced, following `FoodItemModel`'s pattern.
- Bulk actions only if the backend has a bulk endpoint.

**Verify:** create → appears in list after refresh and on the server; edit → `PATCH` sends only changed fields; availability toggle survives a full refresh; pagination fetches page 2 correctly and does not duplicate or drop rows; search hits the server (or filters client-side) exactly as the backend contract allows.

### M5 — Inventory Management

- Stock levels per product/variant, live from the backend.
- Stock adjustment (set / increment / decrement) using **the backend's endpoint and semantics** — never compute the new quantity client-side and PUT it if the server offers an atomic adjust.
- Low-stock and out-of-stock views driven by **server-defined thresholds**.
- Stock history / audit trail if the backend exposes it.
- Bulk update only if a bulk endpoint exists.

**Verify:** an adjustment is reflected on the server and after refresh; concurrent adjustments do not produce a wrong number (rely on the server); out-of-stock products behave as the backend specifies in the storefront (report, do not enforce client-side).

### M6 — Orders

The highest-stakes module. Money and SLAs depend on it.

- Live/incoming orders with a full-screen or dialog alert on arrival (`incoming_order_dialog.dart` is the reference), alert sound via `audio_service`, and accept/reject actions.
- Order lifecycle actions exactly as the backend's state machine allows: accept, reject (with reason), mark packed/ready, hand to rider, mark delivered, cancel. **Never allow a transition the backend forbids.**
- Order detail: items, quantities, prices, customer info as exposed, delivery address, payment mode/status, timestamps, rider info.
- Order history with date/status filters and pagination.
- **Socket.IO** subscription for live order events via `socket_service` — subscribe on entering the relevant scope, `off()` on dispose, and always reconcile against a REST refetch.
- **FCM** handling for order pushes, including notification action buttons (`order_notification_action_handler.dart` is the reference).
- Refresh on `AppLifecycleState.resumed` so a push missed while backgrounded cannot lose an order.

**Verify:** a real order placed against the live backend triggers the socket event **and** the push; accept/reject reaches the server and the status changes; killing the app and reopening still shows the correct current state (server is the source of truth, not local state); a forbidden transition is rejected with the server's message and the UI does not desync.

### M7 — Dashboard

- Today's key metrics: orders, revenue, pending orders, cancellations, average value — **all from the backend's dashboard/summary endpoint**. If a metric has no endpoint, it is a GAP; do not compute it by summing a list.
- Store open/closed status with a quick toggle.
- Alerts: low stock, pending approvals, action-needed orders.
- Quick links into other modules.
- Date-range switch only if the backend accepts a range parameter.

**Verify:** every number matches what the backend returns for the same range; the dashboard refreshes on pull and on resume; empty/zero states render correctly for a brand-new seller.

### M8 — Earnings

- Earnings summary: gross, commission, deductions, net — **server-computed**.
- Per-order earnings breakdown.
- Period filters (day/week/month/custom) using the backend's parameters.
- Settlement/payout cycle status.
- Invoice/statement download if the backend serves files (`features/finance/` and `features/payouts/` are the reference).

**Verify:** totals equal the backend's totals exactly (no client-side rounding drift); period filters send the right parameters; a period with no data renders an empty state, not an error.

### M9 — Wallet

- Balance: available, pending, on-hold — as the backend defines them.
- Transaction ledger with pagination and type filters (credit, debit, payout, adjustment, refund).
- Withdrawal request against the backend's endpoint, honouring **server-side** minimum/maximum and eligibility. Client-side checks mirror the server's rules; the server's rejection message is always shown verbatim.
- Withdrawal history with status.
- Bank account details view/update if wallet-scoped.

**Verify:** balance matches the server; a withdrawal request creates a real record and the balance updates after refresh; a request below the minimum is rejected with the server's message; the ledger paginates without gaps or repeats.

### M10 — Coupons

- List seller coupons with status (active/scheduled/expired/disabled).
- Create/edit: code, type (flat/percentage), value, min order, max discount, usage limits (total and per-user), validity window, applicable products/categories — **exactly the backend's schema**.
- Enable/disable toggle.
- Usage/redemption stats if exposed.
- Delete with confirmation.

**Verify:** a created coupon exists server-side with the exact values submitted; validation errors surface the server's messages; date ranges are sent in the format the backend expects and render back correctly in the device's timezone.

### M11 — Discounts

- Product-level and category-level discounts as the backend models them.
- Scheduled/time-bound offers with start and end.
- Bulk discount application only if a bulk endpoint exists.
- Active-offer visibility on the product list.
- **The discounted price shown is the backend's computed price.** Do not recompute it in Dart (R9).

**Verify:** applying a discount changes the effective price on the server; a scheduled discount activates and expires per the server's clock, not the device's; overlapping-discount behaviour matches the backend's rule (report it; do not invent one).

### M12 — Notifications

- Notification list from the backend with read/unread state (`features/notifications/` is the reference).
- Mark read, mark all read, clear all — each against real endpoints.
- Unread badge on the dashboard/nav.
- FCM foreground handling via `local_notification_service`; background/terminated via the existing background handler.
- Tap-to-navigate through `rootNavigatorKey` using the existing payload encode/decode.
- FCM token registered at login **and on every app resume** (idempotent server-side).
- Android notification channels and iOS permissions configured for both platforms.

**Verify:** a real push arrives in foreground, background, **and terminated** state on both platforms; tapping navigates to the right screen; mark-read persists server-side; the badge count matches the server.

### M13 — Reports

- Sales, order, product-performance, and inventory reports — **only those the backend actually serves**.
- Date-range and grouping parameters per the backend contract.
- Tabular and/or chart rendering. Add a charting dependency **only** with prior approval (R and Section 2.2).
- Export/download only if the backend generates the file. **Never generate a report client-side from raw lists** (R9).

**Verify:** report figures match the backend's; large ranges do not freeze the UI; empty ranges render an empty state.

### M14 — Seller Profile

- Profile: name, phone, email, photo, KYC/document status.
- Edit supported fields; the existing `edit_field_sheet.dart` pattern is the reference.
- Document upload/re-upload where the backend allows, with status and rejection reasons.
- Change phone/email flows only if the backend has them.
- Read-only display of server-owned fields (seller ID, joined date, approval status).

**Verify:** edits persist; documents upload and their status reflects the server; server-owned fields are not editable.

### M15 — Settings, Logout & Account Deletion

- Theme mode (light/dark/system) via the existing `themeModeProvider`.
- Notification preferences if the backend stores them; local-only preferences via `SharedPreferences`, never `flutter_secure_storage`.
- Language selection **only if** localization is actually being adopted for this app — otherwise omit it rather than shipping a dead toggle.
- App version display; in-app update via `update_service`; rate-app via `review_service`.
- Support / help / contact, per the backend's support endpoints (`features/support/`, `features/complaints/`, `features/feedback/` are references).
- **Logout:** confirmation dialog → call the server's logout endpoint (send refresh token + FCM token so the server can de-register the device) → `TokenStorage.clear()` → `resetSessionScopedProviders(ref)` → disconnect the socket → set `AuthLoggedOut` → router redirects to `/login`. Onboarding and one-time prompt flags **survive** logout.
- **Delete account:** hard confirmation (typed or two-step), the backend's delete endpoint, then the same teardown as logout.

**Verify:** after logout no authenticated request succeeds; logging in as a *different* seller shows **zero** data from the previous session (this is exactly what `resetSessionScopedProviders` protects — test it explicitly); pushes stop after logout; deletion behaves per the backend.

### M16 — Image Uploads (cross-cutting; build with the first module that needs it)

- Pick from camera or gallery via `image_picker`, with `permission_handler` for permissions on both platforms.
- Convert with the **existing** `xFileToMultipart(XFile)` in `lib/core/utils/multipart_utils.dart` — bytes-based, so it works uniformly. Do not write a second converter.
- Upload through the backend's real upload contract (multipart field name, or pre-signed URL flow — read the backend).
- Client-side compression/resizing **only if** the backend enforces a size limit; adding a compression dependency needs approval.
- Validate MIME type and size against the **server's** limits before upload; show the server's message on rejection.
- Upload progress via Dio's `onSendProgress` where the UX warrants it.
- Display remote images with `cached_network_image`, always with a placeholder and an error widget.
- Handle replace and remove per the backend's semantics.
- `registration/presentation/widgets/image_picker_tile.dart` is the reference UI.

**Verify:** upload works from camera and gallery on **both** platforms; permission denial is handled gracefully with a path to Settings; the returned URL renders; oversized/wrong-type files are rejected with the server's message.

---

## 8. STANDARDS

### 8.1 Coding standards

- **Naming:** `PascalCase` types, `camelCase` members, `snake_case.dart` files. `XRepository`, `XController`, `XState`, `XModel`, `xRepositoryProvider`, `xControllerProvider`. Avoid `Helper`, `Manager`, `Util`, `Base`, `Common`, `Data` unless genuinely generic.
- **Imports:** absolute `package:<package_name>/...` throughout, matching the existing code. No relative imports across features.
- **Immutability:** all model fields `final`; `const` constructors wherever legal.
- **Nullability:** avoid `!` on nullable values in UI paths; prefer defaults in `fromJson` so downstream code deals in non-nullables.
- **Function size:** one job per function. Extract private `_buildX(...)` helpers for large widget trees, as existing screens do.
- **Comments:** the existing code comments the *why*, especially for non-obvious defensive decisions (see the FCM resume-registration and optimistic-toggle comments). Match that density — explain surprises, not syntax.
- **Formatting:** `dart format .` before every commit.
- **Lints:** `flutter_lints` as configured. Do not add `// ignore:` to silence a real problem; fix it. If an ignore is genuinely warranted, comment why on the line above.
- **No dead code, no TODOs, no commented-out blocks** in delivered work.

### 8.2 UI/UX standards

- Screens are `ConsumerWidget`; use `ConsumerStatefulWidget` only when local state, controllers, or lifecycle hooks are needed.
- Every async screen renders **all three** states via `AsyncValue.when` — plus a distinct **empty** state inside `data:` when a list is empty. Four visual states minimum: loading, error, empty, content.
- Loading: `const Center(child: CircularProgressIndicator())` for full-page; inline spinners in buttons during submission with the button disabled.
- Error: centred padded text using `error is ApiException ? error.message : '<friendly fallback>'`, plus a retry affordance where retry makes sense.
- Empty: an icon, one line of explanation, and a primary action where one exists.
- All feedback through `AppToast` (`showSuccess` / `showError`). Never raw `ScaffoldMessenger`.
- All pull-to-refresh through `AppRefreshIndicator` with `AlwaysScrollableScrollPhysics`.
- Destructive actions (delete, logout, cancel order, delete account) always confirm first.
- Forms: inline field-level validation, disabled submit while in flight, no double-submit.
- Long lists use `ListView.builder` / `GridView.builder` — never a `Column` of mapped children for unbounded data.
- Respect `SafeArea`, keyboard insets, and text scaling. Nothing may overflow at 1.3× text scale on a small device.
- Tap targets ≥ 48 dp. Meaningful semantic labels on icon-only buttons.
- Every screen is verified in **both** light and dark mode.

### 8.3 Theme rules

- **Never hardcode a colour** outside `AppColors` / the `ThemeData`. If a new colour is genuinely needed, add it to `AppColors` with a descriptive name.
- **Never hardcode a `TextStyle` from scratch** — use `AppTextStyles` or `Theme.of(context).textTheme`, then `copyWith` for local tweaks.
- Use `Theme.of(context).scaffoldBackgroundColor`, `cardTheme`, `appBarTheme` rather than restating values.
- Dark mode via `final isDarkMode = Theme.of(context).brightness == Brightness.dark;` and `AppColors` ternaries, matching existing screens.
- Radii and sizes follow the theme constants: card/input `16`, button `30`, button height `56`.
- Font family is `ManropeVariable` via the theme — do not set `fontFamily` per widget.
- Do not add a second theme system, a design-token package, or a `ThemeExtension` unless approved.

### 8.4 State management rules

- `AsyncNotifier` + `AsyncNotifierProvider` is the default for anything that loads data.
- `Notifier` + `NotifierProvider` for sync state machines over a sealed state class.
- `Provider` for DI only.
- **No new `StateNotifier`** (legacy import). No `ChangeNotifier` in feature code — `AuthSessionNotifier` is a deliberate, documented exception.
- `build()` delegates to the repository; `refresh()` uses `AsyncValue.guard`; mutations call the repository then `refresh()`.
- Optimistic updates only where the UX demands instant feedback, and **always** with a revert-on-failure path.
- Controllers never import Flutter's `material.dart`, never take a `BuildContext`, never navigate, never toast.
- Widgets never call repositories directly.
- Every session-scoped controller goes into `resetSessionScopedProviders`. **No exceptions.**
- Prefer `ref.watch` in `build`, `ref.read` in callbacks.
- Do not use `autoDispose` for controllers registered in the session reset (that is the whole point of the reset).

### 8.5 Networking rules

- One `Dio`: `dioProvider`. No new instances, no new interceptors from features.
- Repositories are the only callers of `_dio`.
- Timeouts are already set globally; do not override per call without a written reason.
- Send only fields the backend accepts. Use collection-if for optionals.
- `GET` reads, `POST` creates, `PATCH` partial updates, `PUT` full replacement (only if the backend uses it), `DELETE` deletes.
- Cancel in-flight requests with a `CancelToken` where a screen can be popped mid-request.
- Debounce search input 300–500 ms before firing.
- Paginate every unbounded list, per the backend's paging contract.
- Never log tokens, request bodies containing credentials, or full responses in release builds.

### 8.6 Error handling

- The interceptor already converts everything to `ApiException`. **Do not swallow errors** with bare `catch (_) {}` in feature code unless the fallback is deliberate and commented.
- Repositories let exceptions propagate. Controllers capture them with `AsyncValue.guard` (or a try/catch that sets an error state). UI renders them.
- **Always prefer the server's message** (`ApiException.message`) over a generic string — the backend writes the copy the seller needs.
- Provide a friendly fallback only when the error is not an `ApiException`.
- 401 handling is the interceptor's job. Never handle 401 in a feature.
- Validation errors (422/400) map to the offending form field where the backend identifies it.
- Never show a raw exception, stack trace, or `DioException.toString()` to a user.
- Unexpected errors must not crash the app — the global handlers in `main.dart` are the last resort, not the plan.
- Anything user-triggered that fails must produce **visible** feedback. Silent failure is a defect.

### 8.7 Offline handling

Scope this to what the existing app actually does, plus only what the human approves:

- **Baseline (required):** `network_controller` + `NoNetworkOverlay` already give a global offline indicator — reuse it, do not re-implement per screen.
- Connectivity errors surface the interceptor's friendly copy ("No internet connection. Please try again.").
- Every failed load offers a retry.
- `cached_network_image` gives image caching for free.
- **Offline data caching is NOT part of the baseline.** The existing app does not have a local database, and `optimization_flow.md` mentions Isar only as an aspiration. **Do not add a local database, offline queue, or sync engine unless the human explicitly approves it as a scoped work item.** If approved, it becomes its own module with its own spec — never a side effect of another module.
- Never let stale local state contradict the server. On resume and on refresh, the server wins.

### 8.8 Validation rules

- **Mirror the backend.** Read the server's validators and reproduce them client-side for fast feedback. Client validation is a UX affordance, never the security boundary.
- Validate at the trust boundary in the app: every text field, every picker, every uploaded file.
- Standard rules: trim whitespace; required fields non-empty; phone/email against the backend's format; prices and quantities must be non-negative numbers within the backend's bounds; dates must produce a valid range (end after start); images validated for MIME and size against the server's limits.
- Show one clear message per field, inline, at the point of error.
- Disable submit while a request is in flight; guarantee no double-submit.
- **Never** trust client validation to protect data — always handle the server's rejection too.
- Never silently coerce user input into something different from what they typed.

### 8.9 Performance rules

Guided by `optimization_flow.md`, applied only where it matters:

- `const` constructors everywhere legal.
- `ListView.builder` / `GridView.builder` for all unbounded lists; `itemExtent` or `prototypeItem` where rows are uniform.
- Pagination on every list backed by a growing collection.
- Debounced search.
- `cached_network_image` for every remote image, with `memCacheWidth`/`memCacheHeight` sized to the display box.
- Keep `ref.watch` scopes narrow — watch the specific provider a widget needs, not a parent object graph. Use `select` where it prevents real rebuilds.
- Avoid rebuilding heavy subtrees; use `RepaintBoundary` only where profiling justifies it.
- No expensive work in `build()`. No synchronous I/O on the main isolate. Heavy parsing goes to `compute` **only** if profiling shows a jank problem.
- Do not preload data a screen does not display.
- Dispose controllers, focus nodes, animation controllers, stream subscriptions, and socket listeners.
- **Do not micro-optimize speculatively.** Measure first; the simplest correct implementation is the default.

---

## 9. TESTING REQUIREMENTS

There is currently **no `test/` directory**. Establish one as part of M0.

**Minimum bar per module** (not a full test pyramid — enough that a break is caught):

1. **Model tests** — for every model with non-trivial `fromJson`: a real backend payload parses correctly; a missing-fields payload does not throw and yields the documented defaults; type-coerced fields (string `"12.50"` → `double`) work.
2. **Controller tests** — happy path produces `AsyncData`; a thrown `ApiException` produces `AsyncError`; optimistic updates revert on failure. Repositories are overridden via `ProviderContainer` overrides — **this is test scaffolding, not production mock data**, and is the one place fakes are allowed.
3. **Widget tests** — for screens with meaningful branching: loading, error, empty, and content states each render.
4. **Business-rule tests** — any client-side rule (validation, formatting, derived getters) that could silently break.

Rules:
- Tests live in `test/` mirroring `lib/`'s structure: `test/features/<feature>/...`.
- `flutter_test` only. No new test dependency without approval.
- Tests must be deterministic — no real network, no real clock dependence, no sleeps.
- **Never** convert a test fake into production code, and never let a test double leak into `lib/`.
- `flutter test` must pass before a module is reported complete.

---

## 10. BUILD & INTEGRATION VERIFICATION

Run **all** of this at every module boundary. Report the actual output. Do not report a check you did not run.

### 10.1 Static gates

```
dart format --set-exit-if-changed .
flutter analyze          # MUST be 0 errors, 0 warnings, 0 infos
flutter test
```

### 10.2 Build gates

```
flutter build apk --debug
flutter build appbundle --release        # or apk --release
flutter build ios --debug --no-codesign
flutter build ipa --no-codesign          # if signing config permits
```

### 10.3 Runtime gates — Android **and** iOS

- App launches from cold start on both platforms.
- Every screen in the module renders in **light and dark** mode.
- Every API call in the module hits the **live backend** and returns real data.
- Every write action persists — verified by refetching, not by trusting local state.
- Every error path was actually triggered (invalid input, network off, forced 401) and shows the server's message.
- Pull-to-refresh works on every list.
- No overflow, no clipped text, no unbounded-height errors at small sizes and 1.3× text scale.
- No console errors or exceptions during the flow.

### 10.4 Backend integration verification (mandatory per module)

For **every** endpoint the module touches:

1. Call it against the running backend from the app.
2. Confirm the request (method, path, headers, body) matches the handler's expectations.
3. Confirm the response parses into the model with no field silently defaulting because of a name mismatch.
4. Trigger at least one server-side error branch and confirm the message surfaces.
5. Mark the row `Verified` in `API_MAP.md`.

If a check cannot be run (no test data, no device, backend down), **say so explicitly** in the report and mark the row unverified. Never mark verified on assumption.

---

## 11. FINAL VERIFICATION CHECKLIST

Run before declaring the project complete. Every line must be **YES** with evidence.

**Architecture**
- [ ] Feature-first structure matches the existing app exactly; no `lib/data/`, `lib/domain/`, `lib/ui/`, `lib/di/`, `lib/platform/`.
- [ ] Every feature has `data/` + `domain/` + `presentation/{controllers,views,widgets}` as applicable.
- [ ] Domain models import no Flutter, Riverpod, or Dio.
- [ ] No widget calls a repository directly; no controller touches `BuildContext`.
- [ ] Riverpod, go_router, and Dio are the only state/routing/network libraries.
- [ ] No architecture change was made without written approval.

**Backend**
- [ ] Zero backend files created, modified, or deleted.
- [ ] Every network call goes through `dioProvider`.
- [ ] `API_MAP.md` is complete; every row is `Verified`; the GAPS section is empty or every entry is escalated and acknowledged.
- [ ] No duplicate repository method for any endpoint.
- [ ] No server-owned computation reimplemented in Dart.
- [ ] Only the in-project backend is used.

**Data authenticity**
- [ ] Zero mock data, fake APIs, stub repositories, or `Future.delayed` simulations in `lib/`.
- [ ] Zero hardcoded backend-owned values.
- [ ] Every screen renders live backend data.
- [ ] Grep confirms: no `mock`, no `dummy`, no `fake`, no `placeholder`, no `sample_data`, no `lorem` in `lib/`.

**Reuse**
- [ ] `AppToast`, `AppRefreshIndicator`, `NoNetworkOverlay`, and the existing dialogs are used — no duplicates created.
- [ ] Existing core services are reused — no duplicate FCM/socket/audio/notification/network/update/review service.
- [ ] `xFileToMultipart` is the only XFile→MultipartFile converter.
- [ ] `TokenStorage` is the only secure-storage wrapper.
- [ ] `AppColors` / `AppTextStyles` / `ThemeData` are the only styling sources.

**Modules**
- [ ] M0–M16 complete, each verified and reported.
- [ ] Every session-scoped controller is in `resetSessionScopedProviders`.
- [ ] Logging in as a different seller shows zero data from the previous session.
- [ ] Logout and account deletion fully tear down session state, socket, and push registration.

**Quality**
- [ ] `flutter analyze` → 0 errors, 0 warnings, 0 infos.
- [ ] `dart format --set-exit-if-changed .` passes.
- [ ] `flutter test` passes; every module has the Section 9 minimum coverage.
- [ ] No `print()` in production paths; no TODOs; no commented-out code; no unused imports.
- [ ] No secrets committed.

**Platforms**
- [ ] Android debug and release builds succeed; app runs on a real device.
- [ ] iOS debug build succeeds; app runs on a real device or simulator.
- [ ] Permissions declared and handled on both (camera, photos, notifications, location if used).
- [ ] Push notifications verified on both, in foreground, background, and terminated states.
- [ ] Every screen verified in light and dark mode on both.

**UX**
- [ ] Every async screen has loading, error, empty, and content states.
- [ ] Every error shows the server's message where one exists.
- [ ] Every destructive action confirms first.
- [ ] Every list paginates and pull-to-refreshes.
- [ ] Nothing overflows at 1.3× text scale on a small device.

---

## 12. PROGRESS REPORT TEMPLATE

Deliver this after **every** module. No module is complete without it.

```markdown
## Module Report — M<n>: <Module Name>

### 1. Scope delivered
<What was built, in 3–6 bullets.>

### 2. Files created
- lib/features/<f>/domain/<m>_model.dart — <purpose>
- lib/features/<f>/data/<f>_repository.dart — <purpose>
- ...

### 3. Files modified
- lib/config/router/app_router.dart — added routes: <list>
- lib/core/providers/session_reset.dart — registered: <list>
- ...

### 4. Backend endpoints consumed
| Method | Path | Repository method | Verified against live backend |
|--------|------|-------------------|-------------------------------|
| GET | /... | XRepository.getY() | YES / NO — <reason> |

API_MAP.md updated: YES/NO

### 5. Reuse audit
- Reused: <widgets, services, utils, providers — by path>
- Created new shared code: <none, or what and why>
- Duplicate check: confirmed no existing repository method covers these endpoints.

### 6. Architecture conformance
- Layer boundaries respected: YES/NO
- New dependencies added: NONE / <name + justification + approval status>
- Deviations from MASTER_PROMPT.md: NONE / <what, why, approved by whom>

### 7. Verification results
| Check | Result |
|-------|--------|
| dart format | PASS / FAIL |
| flutter analyze | 0 errors, 0 warnings, 0 infos — PASS / FAIL (<paste output>) |
| flutter test | PASS (<n> tests) / FAIL |
| Android build | PASS / FAIL |
| Android runtime | PASS / FAIL / NOT RUN — <reason> |
| iOS build | PASS / FAIL |
| iOS runtime | PASS / FAIL / NOT RUN — <reason> |
| Light + dark mode | PASS / FAIL |
| Error paths triggered | <which ones> |

### 8. Tests added
- test/features/<f>/... — <what it covers>

### 9. Known gaps / blockers
- <Missing endpoint, ambiguous contract, unverifiable check — with the exact question needed to unblock.>
- <"NONE" if genuinely none.>

### 10. Next module
M<n+1>: <name> — awaiting go-ahead.
```

---

## 13. PROHIBITED — QUICK REFERENCE

Never, without explicit human approval:

❌ Write backend code of any kind
❌ Create a mock, fake, stub, or placeholder API/repository/data set in `lib/`
❌ Hardcode a value the backend owns
❌ Duplicate an existing endpoint call, widget, service, or utility
❌ Recompute server-owned business logic client-side
❌ Change the architecture, folder structure, or core libraries
❌ Add a dependency
❌ Introduce code generation (`build_runner`, `freezed`, `json_serializable`)
❌ Add a local database, offline queue, or sync engine
❌ Create a second `Dio`, theme system, storage wrapper, or toast helper
❌ Ship with analyzer errors, warnings, or infos
❌ Ship a screen not backed by a live endpoint
❌ Skip a module's verification or its progress report
❌ Start the next module before the current one is verified and reported
❌ Refactor unrelated existing code
❌ Report a check as passed without running it

---

## 14. START HERE

Your first action is **not** to write code. It is:

1. Read this document in full.
2. Execute **Phase 0** (Section 6): read `lib/`, read the config, run **Gate 0** on `backend/` (Section 4.1), read the backend, draft `API_MAP.md`, capture the `flutter analyze` baseline.
3. Deliver the **Phase 0 Analysis Report**, including every gap, ambiguity, and question.
4. **Wait for approval.**
5. Then build **M0 — Foundation**, verify it, report it, and stop.
6. Repeat, one module at a time, until Section 11's checklist is fully green.

If at any point you are about to violate a rule in Section 13 because it seems like the only way forward — **that is the moment to stop and ask.**
