import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/address_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/promo_banner_model.dart';
import '../../data/models/restaurant_model.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/search_bar_widget.dart';
import '../common_widgets/smart_image.dart';
import '../common_widgets/exit_confirmation_dialog.dart';
import '../navigation/route_names.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import '../restaurant/screens/restaurant_screen.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../search/widgets/voice_search_dialog.dart';
import 'viewmodels/banners_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'viewmodels/zone_viewmodel.dart';
import 'screens/home_filter_screen.dart';
import 'widgets/promo_banner_carousel.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/top_restaurant_card.dart';
import 'widgets/home_coupons_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// [restaurant] is the tapped [RestaurantModel] when we have one, so the
  /// detail screen can open on real data instead of re-fetching blind.
  void _openRestaurantDetail([RestaurantModel? restaurant]) {
    Haptics.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestaurantScreen(restaurant: restaurant),
      ),
    );
  }

  void _open(String route) {
    Haptics.light();
    context.push(route);
  }

  /// Height of a category label, grown by the reader's system font scale.
  ///
  /// `.sp` text scales with that setting but a fixed box does not, so a phone
  /// set to a large font overflowed this two-line label.
  double _categoryLabelHeight(BuildContext context) =>
      24.h * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  /// One category tile: circle, label and the selected-underline beneath it.
  ///
  /// Shared with the loading placeholder so the row keeps the same height
  /// before and after the categories arrive — the placeholder used to be a
  /// flat `92.h`, taller than a real tile, which overflowed the header on a
  /// fresh install where nothing is cached yet.
  double _categoryTileHeight(BuildContext context) =>
      48.w + 3.h + _categoryLabelHeight(context) + 3.h + 3.h;

  /// How far the search row hangs below the banner it sits on.
  ///
  /// Half the row's own height — it measures 49.9pt — so exactly half of the
  /// search bar and the Veg Mode control sit on the artwork and half below it.
  /// This only lands where it should now that the carousel's page dots are
  /// drawn on the banner in full-bleed mode: while they were stacked
  /// underneath, the carousel was taller than the image and this offset was
  /// measured from the bottom of the dots, leaving the bar barely touching the
  /// artwork at all.
  static const double _searchOverhang = 25.0;

  /// Where we're delivering to: the user's default saved address if there is
  /// one, otherwise the detected serviceable zone.
  AddressModel? get _deliveryAddress {
    final addresses = ref.watch(addressViewModelProvider);
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.isNotEmpty ? addresses.last : null;
  }

  String _locationTitle() {
    final a = _deliveryAddress;
    if (a != null && a.title.isNotEmpty) return a.title;
    if (a != null && a.city.isNotEmpty) return a.city;
    final zone = ref.watch(zoneViewModelProvider).asData?.value;
    return zone?.name ?? 'Select location';
  }

  String _locationSubtitle() {
    final a = _deliveryAddress;
    if (a != null && a.fullAddress.isNotEmpty) return a.fullAddress;
    final zone = ref.watch(zoneViewModelProvider).asData?.value;
    if (zone != null && zone.isInService) {
      return 'Delivering to ${zone.name ?? 'your area'}';
    }
    return 'Tap to set your delivery address';
  }

  /// Search and Offers are tabs, so they switch branch rather than pushing a
  /// second copy of the shell on top of the current one.
  void _goTab(String route) {
    Haptics.light();
    context.go(route);
  }

  /// True when the home feed failed outright and there is nothing cached to
  /// show. Without this every section quietly collapses to `SizedBox.shrink()`
  /// and the user is left staring at a blank screen with no idea why.
  bool get _homeFailed {
    final state = ref.watch(homeViewModelProvider);
    final restaurants = state.nearbyRestaurants;
    return restaurants.hasError &&
        (restaurants.asData?.value ?? const []).isEmpty;
  }

  Widget _buildLoadFailure(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 64.h),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 56.sp,
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          SizedBox(height: 16.h),
          Text(
            "Couldn't load Eatinfinity",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () => ref
                .read(homeViewModelProvider.notifier)
                .loadHomeData(isRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // What the brand header band fades into at its bottom edge.
    final headerFade = isDark
        ? AppColors.backgroundDark
        : const Color(0xFFFAFDFF);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : const Color(0xFFFAFDFF),
          body: SafeArea(
            top: false,
            child: AppRefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(homeViewModelProvider.notifier)
                    .loadHomeData(isRefresh: true);
                await ref
                    .read(activeOrderViewModelProvider.notifier)
                    .fetchActiveOrder(isRefresh: true);
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Top Hero Header (Extends all the way up behind the status bar)
                  SliverToBoxAdapter(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: headerFade),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The banner is the top of the screen, not something
                          // sitting under a header bar: it starts at y=0 and
                          // runs up behind the status bar, with the location
                          // and notification controls floating on top of it.
                          // They used to be stacked above it in a Column, which
                          // is what pushed the artwork down and left a band of
                          // flat colour across the top of the app.
                          Stack(
                            children: [
                              // Reserves the overhang inside the stack instead
                              // of letting the search row hang out past the
                              // bottom on a negative offset.
                              //
                              // Clip.none only stops the overflow being painted
                              // out; hit testing still stops at the parent's
                              // bounds, so the part of the row below the banner
                              // — which is where the Veg Mode switch sits — was
                              // drawn but could not be tapped. Growing the
                              // stack keeps the same layout with the whole row
                              // inside it.
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: _searchOverhang,
                                ),
                                child: _buildHeroPromoCarousel(),
                              ),
                              Positioned(
                                top: MediaQuery.of(context).padding.top + 4.h,
                                left: 10.w,
                                right: 10.w,
                                child: _buildHeaderLocationRow(context, isDark),
                              ),
                              // In the banner's own stack, not in the sliver
                              // below it. Slivers paint in reverse order, so
                              // the banner — being the earlier sliver — painted
                              // straight over a search bar that was pulled up
                              // underneath it. Sitting inside the same stack is
                              // what actually puts it on top of the artwork.
                              Positioned(
                                left: 8.w,
                                right: 8.w,
                                bottom: 0,
                                child: _buildSearchBar(context, isDark),
                              ),
                            ],
                          ),
                          // The overhang is inside the stack above now, so
                          // only the gap under the search bar is left.
                          SizedBox(height: 10.h),
                          if (_homeFailed) _buildLoadFailure(context),
                        ],
                      ),
                    ),
                  ),

                  // 2. Category row.
                  //
                  // A plain sliver rather than a pinned one. Pinning reserved a
                  // fixed height and then drew its contents higher up, and the
                  // difference was dead space — the gap that used to sit
                  // between the categories and Top Restaurants. It also carried
                  // a status-bar-sized spacer so the row would clear the notch
                  // once stuck to the top, which at rest was simply a hole.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFoodCategoryGrid(context),
                          const HomeCouponsSection(),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),

                        // 4. Offer Banners (FOOD DEALS / Secondary Promotional Banners)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildOfferBannersSection(context),
                        ),

                        const SizedBox(height: 20),

                        // 5. Top Restaurants Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildTopRestaurantsSection(context, isDark),
                        ),

                        const SizedBox(height: 24),

                        // 6. What's on your mind? Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildWhatsOnYourMindSection(context, isDark),
                        ),

                        const SizedBox(height: 24),

                        // 7. All Restaurants Section (Full vertical list)
                        _buildAllRestaurantsSection(context, isDark),

                        SizedBox(
                          height:
                              ref.watch(cartViewModelProvider).items.isNotEmpty
                              ? 90.h
                              : 24.h,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Top Header Row: Location Pin + Location Name + Subtitle & Bell Badge Icon
  /// Halo behind the controls floating on the banner.
  ///
  /// White, not black: these glyphs are dark, so the job is to separate them
  /// from the darker parts of the artwork rather than from the pale ones. Wide
  /// and soft so it reads as a lift rather than an outline.
  static const List<Shadow> _onBannerShadow = [
    Shadow(color: Color(0xCCFFFFFF), blurRadius: 10),
    Shadow(color: Color(0x66FFFFFF), blurRadius: 3),
  ];

  /// Ink for anything sitting on the banner.
  static const Color _onBannerInk = Color(0xFF0B1220);

  Widget _buildHeaderLocationRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _open(RouteNames.addAddress),
            // Transparent: the banner shows straight through. Legibility now
            // rests on the label colours below being white with a soft drop
            // shadow rather than on a plate behind them.
            child: Container(
              padding: EdgeInsets.fromLTRB(0, 5.h, 12.w, 5.h),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // White plate, brand glyph. A red disc read well on the
                      // white pill this used to sit on, but disappears into a
                      // red banner now that the pill is gone.
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _locationTitle(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _onBannerInk,
                                letterSpacing: -0.3,
                                shadows: _onBannerShadow,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _onBannerInk,
                              size: 20,
                              shadows: _onBannerShadow,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _locationSubtitle(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w700,
                                  shadows: _onBannerShadow,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF1E293B),
                              size: 16,
                              shadows: _onBannerShadow,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Notification Bell Icon with Red Badge Dot
        GestureDetector(
          onTap: () {
            Haptics.light();
            context.push(RouteNames.notifications);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  // A hairline keeps the tap target findable once the plate
                  // behind it is gone.
                  border: Border.all(
                    color: _onBannerInk.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: _onBannerInk,
                  size: 22,
                  shadows: _onBannerShadow,
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF4444),
                    border: Border.all(color: Colors.white, width: 1.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. Search Bar + Voice Search Mic Icon
  Widget _buildSearchBar(BuildContext context, bool isDark) {
    // Read-only on Home: tapping opens the search tab. The rotating hint is fed
    // the real global categories so it never names one we don't stock.
    final categories =
        ref.watch(homeViewModelProvider).categories.asData?.value ??
        const <CategoryModel>[];

    return Row(
      children: [
        Expanded(
          child: SearchBarWidget(
            readOnly: true,
            categories: categories.map((c) => c.name).toList(),
            showScanner: false,
            onTap: () => _goTab(RouteNames.search),
            onMicTap: () async {
              final spoken = await VoiceSearchDialog.show(context);
              if (spoken == null || spoken.trim().isEmpty || !mounted) return;
              _goTab(
                '${RouteNames.search}?q=${Uri.encodeComponent(spoken.trim())}',
              );
            },
          ),
        ),
        SizedBox(width: 8.w),
        _buildVegFilterButton(isDark),
      ],
    );
  }

  /// Veg-only toggle, sitting beside the search bar.
  ///
  /// [vegFilterProvider] was already read by the restaurant menu, favourites,
  /// nearby list and cart suggestions — and its own doc names a "Home search bar
  /// pill" as one of the two places it is set. That pill did not exist, so the
  /// filter could only be reached through Profile → Veg Mode. This is it.
  ///
  /// A stacked "VEG MODE" caption over a switch, per the reference. The caption
  /// matters: a lone switch says nothing about what it switches, and this one
  /// changes what the whole page lists.
  Widget _buildVegFilterButton(bool isDark) {
    final isVegOnly = ref.watch(vegFilterProvider);
    const vegGreen = Color(0xFF0F8A3D);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        ref.read(vegFilterProvider.notifier).toggle();
      },
      // The control overlaps the banner, so it is opaque-free but shadowed,
      // like the location row above it.
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'VEG',
            style: TextStyle(
              fontSize: 9,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: _onBannerInk,
              shadows: _onBannerShadow,
            ),
          ),
          const Text(
            'MODE',
            style: TextStyle(
              fontSize: 9,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              color: _onBannerInk,
              shadows: _onBannerShadow,
            ),
          ),
          SizedBox(height: 4.h),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 34,
            height: 18,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isVegOnly ? vegGreen : const Color(0xFFBFC7D2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: isVegOnly
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Hero Promo Banner Carousel — "Home Promotion Banners" in the admin
  /// panel, from `GET /food/hero-banners/home-promotion/public`. Each banner
  /// can be linked to a restaurant there, so taps must honour its own
  /// `ctaLink` (see [_openOfferBanner]) instead of always opening All Offers.
  ///
  /// Hidden entirely when the server has no banners.
  Widget _buildHeroPromoCarousel() {
    final promoBanners =
        ref.watch(promoBannersProvider).asData?.value ??
        const <PromoBannerModel>[];
    return PromoBannerCarousel(
      banners: promoBanners,
      onBannerTap: _openOfferBanner,
      fullBleed: true,
    );
  }

  /// 3b. Offer Banners — "Promotions Management → Offer Banners" in the admin
  /// panel, from `GET /food/offer-banners/public`. A separate CMS from the
  /// hero carousel above: each banner opens its own `ctaLink` (see
  /// [_openOfferBanner]) rather than always going to All Offers.
  ///
  /// Hidden entirely when the server has no live banners.
  Widget _buildOfferBannersSection(BuildContext context) {
    final offerBanners =
        ref.watch(offerBannersProvider).asData?.value ??
        const <PromoBannerModel>[];
    if (offerBanners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(height: 8.h),
        PromoBannerCarousel(
          banners: offerBanners,
          onBannerTap: _openOfferBanner,
          compact: true,
          autoScroll: false,
        ),
      ],
    );
  }

  /// A banner with no `ctaLink` is decorative and does nothing on tap.
  /// External links open in the browser; in-app links are pushed only when
  /// they match [PromoBannerModel.destination]'s route whitelist, so an
  /// admin-typed path this build doesn't have can't crash the screen.
  void _openOfferBanner(BuildContext context, PromoBannerModel banner) {
    final dest = banner.destination;
    if (dest == null) return;
    if (dest.startsWith('http://') || dest.startsWith('https://')) {
      launchUrl(Uri.parse(dest), mode: LaunchMode.externalApplication);
      return;
    }
    context.push(dest);
  }

  /// 4. Food Categories Horizontal Bar matching reference design
  Widget _buildFoodCategoryGrid(BuildContext context) {
    final async = ref.watch(homeViewModelProvider).categories;
    final backendCategories = async.asData?.value ?? const <CategoryModel>[];

    final displayCategories = <_CategoryUiItem>[
      const _CategoryUiItem(id: 'all', name: 'All', imageUrl: ''),
    ];

    // Backend categories only. There is no placeholder list: an "All" chip on
    // its own is a truthful empty state, invented categories are not.
    for (final c in backendCategories) {
      displayCategories.add(
        _CategoryUiItem(id: c.id, name: c.name, imageUrl: c.imageUrl),
      );
    }
    if (backendCategories.isEmpty) {
      return async.isLoading
          ? SizedBox(
              height: _categoryTileHeight(context),
              child: const Center(child: CircularProgressIndicator()),
            )
          : const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(displayCategories.length, (index) {
          final cat = displayCategories[index];
          final isSelected = _selectedCategoryIndex == index;
          final isAll = index == 0;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _selectedCategoryIndex = index);
              if (!isAll) {
                context.push(
                  RouteNames.homeFilter,
                  extra: HomeFilterArgs(
                    title: cat.name,
                    emptyMessage:
                        'No restaurants serving ${cat.name} near you right now.',
                    matches: (r) =>
                        r.name.toLowerCase().contains(cat.name.toLowerCase()) ||
                        r.tags.any(
                          (t) =>
                              t.toLowerCase().contains(cat.name.toLowerCase()),
                        ) ||
                        r.restaurantTags.any(
                          (t) =>
                              t.toLowerCase().contains(cat.name.toLowerCase()),
                        ),
                  ),
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.only(right: 2.w),
              child: SizedBox(
                width: 60.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon / Circular Image Container
                    if (isAll)
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48.w,
                        height: 48.w,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFF1F5F9),
                            width: isSelected ? 2.0 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: SmartImage(
                            url: cat.imageUrl,
                            category: ImageCategory.category,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),

                    SizedBox(height: 3.h),

                    // Label Text
                    SizedBox(
                      height: _categoryLabelHeight(context),
                      child: Text(
                        cat.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF334155),
                          height: 1.15,
                        ),
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // Active Indicator Underline Bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 16.w : 0,
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 6. Top Restaurants Section with Overlay Badges
  /// Nearby restaurants with Veg Mode applied.
  ///
  /// Both restaurant sections on Home go through this. They used to read
  /// `nearbyRestaurants` straight off the view model, so Veg Mode changed
  /// nothing on the very page its switch lives on — the filter only reached
  /// the restaurant menu, favourites and cart suggestions. Matches the
  /// `isPureVeg` test [NearbyRestaurantsList] already uses, so the two cannot
  /// disagree about what "veg" means.
  List<RestaurantModel> _vegFiltered(List<RestaurantModel> all) {
    if (!ref.watch(vegFilterProvider)) return all;
    return all.where((r) => r.isPureVeg).toList(growable: false);
  }

  Widget _buildTopRestaurantsSection(BuildContext context, bool isDark) {
    final async = ref.watch(homeViewModelProvider).nearbyRestaurants;
    final restaurants = _vegFiltered(
      async.asData?.value ?? const <RestaurantModel>[],
    );

    // Nothing to show and nothing coming — drop the whole section rather than
    // render an empty carousel under a "Top Restaurants" heading. Veg Mode
    // filtering everything out is explained by the All Restaurants section
    // below, so this one stays quiet rather than repeating it.
    if (restaurants.isEmpty && !async.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Section Title & View All Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Restaurants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                Haptics.light();
                context.push(
                  RouteNames.homeFilter,
                  extra: HomeFilterArgs(
                    title: 'Top Restaurants',
                    emptyMessage:
                        'No top restaurants available near you right now.',
                    matches: (r) => true,
                  ),
                );
              },
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF64748B),
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 2-Row Horizontal Top Restaurants Grid
        //
        // Card width is solved for rather than fixed: two whole cards and half
        // of the third should be on screen, which is what tells people the row
        // scrolls. The old 114pt card fitted about 3.1 columns, so the third
        // card was nearly whole and the fourth a sliver — busier, and every
        // card smaller than it needed to be.
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            // 2 whole cards + 2 gaps + half a card == the viewport.
            final cardWidth = (constraints.maxWidth - 2 * spacing) / 2.5;
            // A measured height, not a ratio of the width. The card's content
            // comes to 128pt — a fixed image plus fixed-size text — so scaling
            // the cell with the width just left white space inside the card
            // below the content, which is what the grid stretches it to fill.
            // 4pt of slack absorbs a little text scaling before it clips.
            const cardHeight = 132.0;
            final gridHeight = cardHeight * 2 + spacing;

            return SizedBox(
              height: gridHeight,
              child: async.isLoading && restaurants.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        // Cross axis is vertical here, so this is height / width.
                        childAspectRatio: cardHeight / cardWidth,
                      ),
                      itemCount: restaurants.length,
                      itemBuilder: (context, index) {
                        final r = restaurants[index];
                        return TopRestaurantCard(
                          restaurant: r,
                          index: index,
                          onTap: () => _openRestaurantDetail(r),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }

  /// 6. "What's on your mind?" category cards section (using real backend categories)
  Widget _buildWhatsOnYourMindSection(BuildContext context, bool isDark) {
    final async = ref.watch(homeViewModelProvider).categories;
    final categories = async.asData?.value ?? const <CategoryModel>[];

    if (categories.isEmpty && !async.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "What's on your mind?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 115.h,
          child: async.isLoading && categories.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => SizedBox(width: 10.w),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return GestureDetector(
                      onTap: () {
                        Haptics.light();
                        context.push(
                          RouteNames.homeFilter,
                          extra: HomeFilterArgs(
                            title: cat.name,
                            emptyMessage:
                                'No items available in ${cat.name} right now.',
                            matches: (r) =>
                                r.name.toLowerCase().contains(
                                  cat.name.toLowerCase(),
                                ) ||
                                r.tags.any(
                                  (t) => t.toLowerCase().contains(
                                    cat.name.toLowerCase(),
                                  ),
                                ) ||
                                r.restaurantTags.any(
                                  (t) => t.toLowerCase().contains(
                                    cat.name.toLowerCase(),
                                  ),
                                ),
                          ),
                        );
                      },
                      child: Container(
                        width: 145.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Category Image from Backend
                            SmartImage(
                              url: cat.imageUrl,
                              category: ImageCategory.category,
                              fit: BoxFit.cover,
                            ),

                            // Dark Gradient Overlay for Text Visibility
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.72),
                                  ],
                                ),
                              ),
                            ),

                            // Category Name & Arrow CTA Button
                            Padding(
                              padding: EdgeInsets.all(10.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cat.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Container(
                                      width: 26.w,
                                      height: 26.w,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: AppColors.primary,
                                        size: 15.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 7. All Restaurants Section (Full vertical list matching reference screenshot)
  Widget _buildAllRestaurantsSection(BuildContext context, bool isDark) {
    final async = ref.watch(homeViewModelProvider).nearbyRestaurants;
    final all = async.asData?.value ?? const <RestaurantModel>[];
    final restaurants = _vegFiltered(all);

    // Say so when Veg Mode is what emptied the list. Hiding the section
    // silently makes the toggle look broken: the page simply goes blank and
    // nothing on screen connects that to the switch that caused it.
    if (restaurants.isEmpty && all.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Column(
          children: [
            Icon(
              Icons.eco_outlined,
              size: 32,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            SizedBox(height: 10.h),
            Text(
              'No pure veg restaurants near you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Turn off Veg Mode to see all ${all.length} restaurants',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (restaurants.isEmpty && !async.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Count & Sort Dropdown. Padded to 16 to sit flush with the
        // card margins below it.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '${restaurants.length} Restaurants near you',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ),

        const SizedBox(height: 4),

        if (async.isLoading && restaurants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: restaurants.length,
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            itemBuilder: (context, index) =>
                RestaurantCard(restaurant: restaurants[index], index: index),
          ),
      ],
    );
  }
}

class _CategoryUiItem {
  const _CategoryUiItem({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}

/// Pins the search bar + categories row to the top of the home screen while
/// scrolling (request: "scroll krne pe search bar or categories stick hona
/// chahiye"). `minExtent == maxExtent`: this header doesn't shrink, it just
/// stays put once it reaches the top.
