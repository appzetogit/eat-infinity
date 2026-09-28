import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/search_bar_widget.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../viewmodels/restaurant_detail_viewmodel.dart';
import '../widgets/food_detail_sheet.dart';
import '../widgets/offer_unlock_strip.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  final dynamic restaurant;

  const RestaurantScreen({super.key, this.restaurant});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  int _selectedCategoryIndex = 0;
  bool _isVegOnly = false;
  bool _isNonVegOnly = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Height of the pinned search + category-chips header. Scroll targets have
  /// to clear it, otherwise a section lands underneath and looks unscrolled.
  static const double _stickyHeaderHeight = 160;

  /// One key per rendered category section, so the menu index can scroll to it.
  final Map<String, GlobalKey> _sectionKeys = {};

  GlobalKey _sectionKey(String category) =>
      _sectionKeys.putIfAbsent(category, () => GlobalKey());

  /// The menu after the veg / non-veg / search filters, but before the
  /// category chip. The chip narrows the page to a single section; the menu
  /// index deliberately still lists every category so you can jump out of the
  /// one you're in.
  List<FoodModel> _filteredMenu(List<FoodModel> menu) {
    var items = menu;
    if (_isVegOnly) items = items.where((f) => f.isVeg).toList();
    if (_isNonVegOnly) items = items.where((f) => !f.isVeg).toList();
    if (_searchQuery.isNotEmpty) {
      items = items
          .where((f) => f.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return items;
  }

  /// Menu items bucketed by category, preserving the order the kitchen listed
  /// them in rather than sorting alphabetically.
  Map<String, List<FoodModel>> _groupByCategory(List<FoodModel> items) {
    final grouped = <String, List<FoodModel>>{};
    for (final f in items) {
      final c = f.categoryName.trim();
      grouped.putIfAbsent(c.isEmpty ? 'Other' : c, () => []).add(f);
    }
    return grouped;
  }

  static const Map<String, String> _categoryIcons = {
    'recommended': '⭐️',
    'bestsellers': '🔥',
    'combos': '🎁',
    'biryani': '🥣',
    'kebabs': '🍢',
    'rolls': '🌯',
    'curries': '🍲',
    'rice': '🍚',
    'breads': '🍞',
    'beverages': '🥤',
    'desserts': '🍰',
    'pizza': '🍕',
    'burgers': '🍔',
    'chicken': '🍗',
    'main course': '🍲',
  };

  String _iconForCategory(String name) =>
      _categoryIcons[name.trim().toLowerCase()] ?? '🍽️';

  RestaurantModel? get _restaurant {
    final r = widget.restaurant;
    return r is RestaurantModel ? r : null;
  }

  String? get _restaurantId {
    final r = widget.restaurant;
    if (r == null) return null;
    try {
      return (r as dynamic).id as String?;
    } catch (_) {
      return null;
    }
  }

  List<String> _menuCategories(List<FoodModel> menu) {
    if (menu.isEmpty) return const [];
    final seen = <String>{};
    final out = <String>['All'];
    for (final f in menu) {
      final c = f.categoryName.trim();
      if (c.isEmpty || !seen.add(c)) continue;
      out.add(c);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Scrolls the menu to [category]'s section.
  ///
  /// Sections for other categories only exist while the chip filter is on
  /// "All", so the filter is cleared first and the frame allowed to lay out —
  /// the section's key has no context until it has actually been built.
  Future<void> _scrollToCategory(String category) async {
    // Read before the await so no BuildContext crosses the async gap.
    final viewportHeight = MediaQuery.of(context).size.height;

    if (_selectedCategoryIndex != 0) {
      setState(() => _selectedCategoryIndex = 0);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;

    final sectionContext = _sectionKeys[category]?.currentContext;
    if (sectionContext == null || !sectionContext.mounted) return;

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      // Park the heading just below the pinned header instead of under it.
      alignment: (_stickyHeaderHeight / viewportHeight).clamp(0.0, 1.0),
    );
  }

  /// The Zomato-style menu index: every category with its dish count, tapping
  /// one jumps the page to that section.
  void _showMenuCategorySheet(List<FoodModel> menu) {
    Haptics.medium();
    final grouped = _groupByCategory(menu);
    if (grouped.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: grouped.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (_, i) {
                    final entry = grouped.entries.elementAt(i);
                    return InkWell(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _scrollToCategory(entry.key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value.length}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cart = ref.watch(cartViewModelProvider);

    final id = _restaurantId;
    final loadedMenu = (id == null || id.isEmpty)
        ? const <FoodModel>[]
        : ref.watch(restaurantMenuProvider(id)).asData?.value ??
            const <FoodModel>[];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The cover image sits below the status bar here (SafeArea top: true),
      // so the bar always shows the plain scaffold background, not the image
      // — icon color just needs to match that background, not the header.
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.home);
          }
        },
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : const Color(0xFFFAFDFF),
          body: Stack(
            children: [
              // Scrolling under the status bar only, not into it — so the
              // pinned search bar docks flush below the status bar instead of
              // reserving a permanent status-bar-height gap under the info
              // card in the resting (unscrolled) state.
              SafeArea(
                top: true,
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    // 1. Hero Cover Header Image & Overlaid Info Card (includes stats row)
                    SliverToBoxAdapter(
                      child: _buildHeaderAndInfoOverlay(context, isDark),
                    ),

                    // 2 & 4. Search/Veg Toggles + Category Chips — pinned to the
                    // top on scroll, matching the Home screen's sticky behaviour.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyRestaurantHeaderDelegate(
                        height: 160,
                        backgroundColor: isDark
                            ? AppColors.backgroundDark
                            : const Color(0xFFFAFDFF),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildSearchAndVegToggles(isDark),
                            const SizedBox(height: 8),
                            _buildCategoryFilterChips(isDark),
                          ],
                        ),
                      ),
                    ),

                    // 5. Main Split Body: Left Category Sidebar + Right Food Items List
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildMainBody(isDark),
                          // Clearance for the cart bar, offer strip and menu
                          // button that float over the bottom of this list.
                          SizedBox(height: cart.totalQuantity > 0 ? 190 : 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating View Cart Bar shown when cart has items
              if (cart.items.isNotEmpty)
                FloatingViewCartBar(
                  bottomOffset: 20.0 + MediaQuery.of(context).padding.bottom,
                  onTap: () {
                    Haptics.medium();
                    context.push(RouteNames.cart);
                  },
                ),

              // Menu index + offer strip, stacked in one column so they sit
              // above the cart bar without each needing its own hand-tuned
              // offset — and so the offers strip can appear or vanish (it is
              // loaded async) without shifting the button onto the cart bar.
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom +
                    (cart.items.isNotEmpty ? 86.0 : 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (loadedMenu.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () =>
                            _showMenuCategorySheet(_filteredMenu(loadedMenu)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Menu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (id != null && id.isNotEmpty)
                      OfferUnlockStrip(restaurantId: id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Hero Cover Image + Action Buttons + Overlaid White Info Card
  Widget _buildHeaderAndInfoOverlay(BuildContext context, bool isDark) {
    final r = _restaurant;
    final ratingStr = (r?.rating ?? 0) > 0 ? r!.rating.toStringAsFixed(1) : '—';
    final reviewsStr = (r?.reviewCount ?? 0) > 0
        ? '${r!.reviewCount} ratings'
        : 'No ratings yet';
    final timeStr = (r?.deliveryTime.isNotEmpty == true)
        ? r!.deliveryTime
        : '—';
    final distStr = r?.distanceKm != null
        ? '${r!.distanceKm!.toStringAsFixed(1)} km'
        : '—';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Top Cover Image Banner
        SizedBox(
          height: 175,
          width: double.infinity,
          child: SmartImage(
            url: r?.coverImages.isNotEmpty == true
                ? r!.coverImages.first
                : (r?.imageUrl ?? ''),
            category: ImageCategory.restaurant,
            fit: BoxFit.cover,
          ),
        ),

        // Floating Action Circle Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.home);
                    }
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final favState = ref
                        .watch(favoritesViewModelProvider)
                        .value;
                    final rId = _restaurantId ?? '';
                    final isFav =
                        favState?.restaurantIds.contains(rId) ?? false;
                    return GestureDetector(
                      onTap: () {
                        Haptics.light();
                        if (rId.isNotEmpty) {
                          ref
                              .read(favoritesViewModelProvider.notifier)
                              .toggle(rId, _restaurant);
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? const Color(0xFFEF4444) : Colors.white,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Overlaid Floating White Restaurant Info Card
        Padding(
          padding: const EdgeInsets.only(top: 115, left: 16, right: 16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Logo Badge Circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SmartImage(
                          url: r?.imageUrl ?? '',
                          category: ImageCategory.brand,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rating Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$ratingStr ★',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF41222),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    reviewsStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Restaurant Name. The veg mark used to trail it
                          // here; it now sits under the offer badge so the two
                          // share a right-hand column.
                          Text(
                            r?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Cuisines Text
                          Text(
                            (r?.tags.isNotEmpty == true)
                                ? r!.tags.join(', ')
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Meta details (Price • Time • Distance)
                          Text(
                            [
                              if ((r?.priceForOne ?? 0) > 0)
                                '₹${r!.priceForOne.toStringAsFixed(0)} for one',
                              if ((r?.deliveryTime ?? '').isNotEmpty)
                                r!.deliveryTime,
                              if (r?.distanceKm != null)
                                '${r!.distanceKm!.toStringAsFixed(1)} km',
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Scooter Free Delivery Label
                          if (r?.isFreeDelivery == true) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: const [
                                Icon(
                                  Icons.two_wheeler_rounded,
                                  size: 14,
                                  color: Color(0xFFF41222),
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'FREE DELIVERY',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFF41222),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Right column: offer badge with the veg mark centred
                    // beneath it, so the two line up on one axis instead of
                    // the mark floating at the end of the name.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 92),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7F5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFFF41222,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            // Real offer badge for this restaurant. Was a fixed
                            // "50% OFF / UPTO ₹100 / Use code: TBL50" — a coupon
                            // that does not exist and would be rejected at
                            // checkout.
                            child: Text(
                              (r?.offerBadges.isNotEmpty == true)
                                  ? r!.offerBadges.first
                                  : 'No offer',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF41222),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF16A34A),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Container(height: 1, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 4),

                // Delivery Time / Distance / Rating stats row (merged into this same card)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.timer_outlined,
                        timeStr,
                        'Delivery Time',
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 8),
                      _buildStatItem(
                        Icons.location_on_outlined,
                        distStr,
                        'Distance',
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 8),
                      _buildStatItem(
                        Icons.star_outline_rounded,
                        ratingStr,
                        (r?.reviewCount ?? 0) > 0
                            ? '${r!.reviewCount} ratings'
                            : 'Ratings',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Category image for a menu section — read straight off this restaurant's
  /// own menu items (which carry their section's image, restaurant-owned
  /// categories included), falling back to the global cuisine categories for
  /// the rare section whose own image is empty.
  String _categoryImageFor(String catName, List<FoodModel> menu) {
    final target = catName.trim().toLowerCase();
    for (final f in menu) {
      if (f.categoryName.trim().toLowerCase() == target &&
          f.categoryImage.isNotEmpty) {
        return f.categoryImage;
      }
    }
    final backendCategories =
        ref.watch(homeViewModelProvider).categories.asData?.value ??
        const <CategoryModel>[];
    for (final c in backendCategories) {
      if (c.name.trim().toLowerCase() == target) return c.imageUrl;
    }
    return '';
  }

  /// 3. Category Chips Horizontal Scroll Bar (real menu categories) — same
  /// circle-icon-with-border style and sizing as the Home screen's category
  /// row, just backed by this restaurant's menu sections instead.
  Widget _buildCategoryFilterChips(bool isDark) {
    final id = _restaurantId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final menu =
        ref.watch(restaurantMenuProvider(id)).asData?.value ??
        const <FoodModel>[];
    final cats = _menuCategories(menu);
    if (cats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: cats.length,
        itemBuilder: (context, index) {
          final catName = cats[index];
          final isAll = catName == 'All';
          final isActive = _selectedCategoryIndex == index;
          final imageUrl = isAll ? '' : _categoryImageFor(catName, menu);
          return GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _selectedCategoryIndex = index);
            },
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAll)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                          width: isActive ? 2.0 : 1.2,
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
                        child: imageUrl.isNotEmpty
                            ? SmartImage(
                                url: imageUrl,
                                category: ImageCategory.category,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Center(
                                child: Text(
                                  _iconForCategory(catName),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 24,
                    child: Text(
                      catName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: isActive
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155)),
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 16 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 4. Search Bar & Veg / Non-Veg Filter Toggle Row
  Widget _buildSearchAndVegToggles(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: SearchBarWidget(
              controller: _searchController,
              categories: const [
                'Search in menu...',
                'Biryani',
                'Pizza',
                'Shake',
              ],
              showScanner: false,
              showMic: true,
              onChanged: (q) {
                setState(() {
                  _searchQuery = q.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 8),

          // Veg Toggle Pill
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isVegOnly = !_isVegOnly;
                if (_isVegOnly) _isNonVegOnly = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isVegOnly ? const Color(0xFFE8F5E9) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isVegOnly
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF16A34A),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Veg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Non-Veg Toggle Pill
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                _isNonVegOnly = !_isNonVegOnly;
                if (_isNonVegOnly) _isVegOnly = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isNonVegOnly ? const Color(0xFFFFEBEE) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isNonVegOnly
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFEF4444),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(6, 6),
                        painter: _TrianglePainter(
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Non-Veg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Split View Main Body: Left Category Sidebar + Right Food Items List
  Widget _buildMainBody(bool isDark) {
    final id = _restaurantId;
    if (id == null || id.isEmpty) {
      return _buildEmptyMenuCard('No menu available for this restaurant');
    }

    final async = ref.watch(restaurantMenuProvider(id));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              const Text(
                "Couldn't load the menu",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => ref.invalidate(restaurantMenuProvider(id)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF41222),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (menu) {
        if (menu.isEmpty) {
          return _buildEmptyMenuCard('This restaurant has no dishes yet');
        }

        final cats = _menuCategories(menu);
        final selected = _selectedCategoryIndex < cats.length
            ? cats[_selectedCategoryIndex]
            : cats.first;

        final items = _filteredMenu(menu)
            .where((f) => selected == 'All' || f.categoryName.trim() == selected)
            .toList();

        final bestsellers = menu.where((f) => f.isPopular).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 36,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No dishes match "$_searchQuery"'
                              : 'No dishes match your active filter',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Rendered as one block per category, each carrying the key
                // the menu index scrolls to, instead of a single flat list.
                ..._groupByCategory(items).entries.expand(
                      (section) => [
                        Padding(
                          key: _sectionKey(section.key),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  section.key,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Text(
                                '${section.value.length}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._buildMenuDishesForItems(section.value),
                        const SizedBox(height: 14),
                      ],
                    ),

              if (bestsellers.isNotEmpty) ...[
                const SizedBox(height: 20),

                // Section 2 Header: Bestsellers Carousel Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text('✨ ', style: TextStyle(fontSize: 12)),
                        Text(
                          'Bestsellers',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(' ✨', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: const [
                        Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
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
                  ],
                ),

                const SizedBox(height: 10),

                // Horizontal Bestsellers Dishes Carousel
                _buildHorizontalBestsellersList(),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Clean, elegant Empty State Card when restaurant has 0 dishes
  Widget _buildEmptyMenuCard(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF41222).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                size: 32,
                color: Color(0xFFF41222),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No menu items are listed for this restaurant right now.\nPlease explore other top restaurants nearby!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Haptics.light();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.home);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF41222),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Explore Other Restaurants',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns real food items list for a pre-filtered list of items.
  List<Widget> _buildMenuDishesForItems(List<FoodModel> items) {
    final cart = ref.watch(cartViewModelProvider);
    final widgets = <Widget>[];
    for (final f in items) {
      var qty = 0;
      for (final line in cart.items) {
        if (line.food.id == f.id) qty += line.quantity;
      }
      widgets.add(
        _buildDishCard(
          food: f,
          name: f.name,
          description: f.description,
          price: '₹${f.price.toStringAsFixed(0)}',
          oldPrice: f.originalPrice != null
              ? '₹${f.originalPrice!.toStringAsFixed(0)}'
              : '',
          discount: (f.originalPrice != null && f.originalPrice! > f.price)
              ? '${(((f.originalPrice! - f.price) / f.originalPrice!) * 100).round()}% OFF'
              : '',
          isVeg: f.isVeg,
          isBestseller: f.isPopular,
          imageUrl: f.imageUrl,
          quantity: qty,
          onIncrement: () =>
              ref.read(cartViewModelProvider.notifier).addItem(f),
          onDecrement: () => _decrement(f),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  void _decrement(FoodModel food) {
    final cart = ref.read(cartViewModelProvider);
    for (final line in cart.items) {
      if (line.food.id == food.id) {
        ref
            .read(cartViewModelProvider.notifier)
            .updateQuantity(line.id, line.quantity - 1);
        return;
      }
    }
  }

  /// Single Dish Card (Matching reference design)
  Widget _buildDishCard({
    FoodModel? food,
    required String name,
    required String description,
    required String price,
    required String oldPrice,
    required String discount,
    required bool isVeg,
    required bool isBestseller,
    required String imageUrl,
    required int quantity,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(context, food);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          // The image is now taller than the text block, so the details
          // centre against it instead of hugging the top.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Dish Image — 40% of the row, details take the other 60%.
            // Flex rather than a fixed 84px so it scales with screen width.
            Expanded(
              flex: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SmartImage(
                    url: imageUrl,
                    category: ImageCategory.food,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Middle Column Details
            Expanded(
              flex: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Veg / Non-Veg Indicator Icon
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isVeg
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: isVeg
                              ? Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF16A34A),
                                  ),
                                )
                              : CustomPaint(
                                  size: const Size(6, 6),
                                  painter: _TrianglePainter(
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (isBestseller)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Bestseller',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF41222),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible + scaleDown: price + struck-through price +
                      // "11% OFF" together are wider than the space left by the
                      // ADD button, which overflowed this row by ~21px.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Text(
                                price,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (oldPrice.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  oldPrice,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                              if (discount.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  discount,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF41222),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Add Button / Counter Stepper
                      if (quantity > 0)
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF41222),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: onDecrement,
                                child: const Icon(
                                  Icons.remove,
                                  size: 14,
                                  color: Color(0xFFF41222),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF41222),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: onIncrement,
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Color(0xFFF41222),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: onIncrement,
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF41222),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                children: const [
                                  Text(
                                    'ADD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFF41222),
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.add,
                                    size: 12,
                                    color: Color(0xFFF41222),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal Bestsellers Carousel (at bottom of right area)
  Widget _buildHorizontalBestsellersList() {
    final id = _restaurantId;
    final menu = (id == null || id.isEmpty)
        ? const <FoodModel>[]
        : (ref.watch(restaurantMenuProvider(id)).asData?.value ??
              const <FoodModel>[]);
    final popular = menu.where((f) => f.isPopular).toList();
    if (popular.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: popular.length,
            itemBuilder: (context, index) {
              final f = popular[index];

              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: SizedBox(
                        height: 75,
                        width: double.infinity,
                        child: SmartImage(
                          url: f.imageUrl,
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Bestseller',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF41222),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${f.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (f.originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${f.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => ref
                                .read(cartViewModelProvider.notifier)
                                .addItem(f),
                            child: Container(
                              height: 26,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF41222),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'ADD',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF41222),
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.add,
                                      size: 12,
                                      color: Color(0xFFF41222),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(popular.length.clamp(1, 4), (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: i == 0 ? 6 : 5,
              height: i == 0 ? 6 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == 0
                    ? const Color(0xFFF41222)
                    : const Color(0xFFCBD5E1),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 6. Floating Bottom Cart Bar
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pins the category chips + search/veg toggle row to the top while
/// scrolling, matching the Home screen's sticky search bar + categories.
class _StickyRestaurantHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyRestaurantHeaderDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  final double height;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyRestaurantHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.child != child;
  }
}
