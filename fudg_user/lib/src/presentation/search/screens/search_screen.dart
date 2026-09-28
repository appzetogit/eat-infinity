import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/food_model.dart';
import '../../../domain/model/search_result.dart';
import '../../../data/models/promo_banner_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../../common_widgets/search_bar_widget.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/banners_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../home/widgets/promo_banner_carousel.dart';
import '../viewmodels/search_state.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/voice_search_dialog.dart';
import '../../restaurant/screens/restaurant_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final dynamic initialMode;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialMode,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  int _selectedSegmentIndex = 0; // 0: Search Restaurants, 1: Search Items

  List<String> get _recentSearches =>
      ref.watch(searchViewModelProvider).recentSearches;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFoodDetail(FoodModel food) {
    Haptics.light();
    context.push(RouteNames.foodDetail, extra: food);
  }

  void _openRestaurantDetail([RestaurantModel? restaurant]) {
    Haptics.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestaurantScreen(restaurant: restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final systemUiStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Search Header Row using exact same Home Screen SearchBarWidget
            _buildSearchHeader(context, isDark),

            const SizedBox(height: 10),

            // Suggestions dropdown directly under search bar (after 3 letters typed)
            _buildSuggestions(context, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Search Segmented Toggle Tabs (Restaurants vs Items)
                    _buildSegmentedTabs(),

                    const SizedBox(height: 14),

                    // 3. Real Recent Searches Section (hidden if empty)
                    _buildRecentSearchesSection(),

                    const SizedBox(height: 14),

                    // 4. Results, directly under Recent Searches. They used to
                    // sit below the popular-search grid and the promo banner,
                    // which pushed them off-screen behind the keyboard — you had
                    // to scroll past two full sections to see what you searched
                    // for.
                    if (_selectedSegmentIndex == 0)
                      _buildTopRestaurantResultsSection(context, isDark)
                    else
                      _buildItemResultsSection(context, isDark),

                    const SizedBox(height: 14),

                    // 5. Real Popular Searches Categories Grid (backend data only)
                    _buildPopularSearchesSection(),

                    const SizedBox(height: 14),

                    // 6. Backend Hero Promo Banners (hidden if empty)
                    _buildPromoBanner(),

                    const SizedBox(height: 20),

                    // 7. Bottom AI Search Banner

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  /// 1. Top Search Header Row with exact Home Screen SearchBarWidget
  Widget _buildSearchHeader(BuildContext context, bool isDark) {
    final categories =
        ref.watch(homeViewModelProvider).categories.asData?.value ??
            const <CategoryModel>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          // Circular Teal Back Button
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
                color: const Color(0xFFF41222).withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFFF41222),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Exact same SearchBarWidget as Home Screen (full width)
          Expanded(
            child: SearchBarWidget(
              controller: _searchController,
              autofocus: true,
              categories: categories.map((c) => c.name).toList(),
              showScanner: false,
              onChanged: (query) {
                ref.read(searchViewModelProvider.notifier).onQueryChanged(query);
              },
              onSubmitted: (query) {
                ref.read(searchViewModelProvider.notifier).submitQuery(query);
              },
              onMicTap: () async {
                final spoken = await VoiceSearchDialog.show(context);
                if (spoken == null || spoken.trim().isEmpty || !mounted) return;
                _searchController.text = spoken.trim();
                ref
                    .read(searchViewModelProvider.notifier)
                    .submitQuery(spoken.trim());
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Search Segmented Toggle Tabs (Restaurants vs Items)

  /// Dish-name suggestions once the query is specific enough to be useful.
  ///
  /// Built from the food results the search already fetched, so it costs no
  /// extra request. Restaurant names are deliberately excluded — the point is
  /// to surface the dish you are actually looking for.
  /// Dynamic suggestions (Restaurants or Items based on active tab) after 3+ letters.
  Widget _buildSuggestions(BuildContext context, bool isDark) {
    final searchState = ref.watch(searchViewModelProvider);
    final homeState = ref.watch(homeViewModelProvider);
    final query = searchState.query.trim();

    // Requires at least 3 letters typed before displaying suggestions
    if (query.length < 3) return const SizedBox.shrink();

    final lower = query.toLowerCase();
    final names = <String>{};

    if (_selectedSegmentIndex == 0) {
      // 1. Search Restaurants Tab: Suggest matching restaurant names
      for (final r in searchState.results) {
        if (r.type == SearchResultType.restaurant &&
            r.title.toLowerCase().contains(lower)) {
          names.add(r.title.trim());
        }
        if (names.length >= 6) break;
      }
      if (names.length < 6) {
        final nearby = homeState.nearbyRestaurants.asData?.value ?? const [];
        for (final r in nearby) {
          if (r.name.toLowerCase().contains(lower)) {
            names.add(r.name.trim());
          }
          if (names.length >= 6) break;
        }
      }
    } else {
      // 2. Search Items Tab: Suggest matching food item names (e.g. Pizza, Burger, Biryani)
      for (final r in searchState.results) {
        if ((r.type == SearchResultType.food || r.type == SearchResultType.store99) &&
            r.title.toLowerCase().contains(lower)) {
          names.add(r.title.trim());
        }
        if (names.length >= 6) break;
      }
      if (names.length < 6) {
        final foods = homeState.popularFoods.asData?.value ?? const [];
        for (final f in foods) {
          if (f.name.toLowerCase().contains(lower)) {
            names.add(f.name.trim());
          }
          if (names.length >= 6) break;
        }
      }
      if (names.length < 6) {
        final categories = homeState.categories.asData?.value ?? const [];
        for (final c in categories) {
          if (c.name.toLowerCase().contains(lower)) {
            names.add(c.name.trim());
          }
          if (names.length >= 6) break;
        }
      }
    }

    names.removeWhere((n) => n.toLowerCase() == lower);
    if (names.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in names)
            InkWell(
              onTap: () {
                Haptics.light();
                FocusScope.of(context).unfocus();
                _searchController.text = name;
                ref.read(searchViewModelProvider.notifier).submitQuery(name);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      _selectedSegmentIndex == 0
                          ? Icons.storefront_rounded
                          : Icons.soup_kitchen_outlined,
                      size: 16,
                      color: const Color(0xFFF41222),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Icon(Icons.north_west_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Tab 1: Search Restaurants
          Expanded(
            child: GestureDetector(
              onTap: () {
                Haptics.light();
                setState(() => _selectedSegmentIndex = 0);
                ref.read(searchViewModelProvider.notifier).setMode(SearchMode.home);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSegmentIndex == 0 ? const Color(0xFFF41222) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: _selectedSegmentIndex == 0 ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                          'Search Restaurants',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _selectedSegmentIndex == 0 ? Colors.white : const Color(0xFF0F172A),
                          ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find your favorite restaurant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _selectedSegmentIndex == 0 ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 2: Search Items
          Expanded(
            child: GestureDetector(
              onTap: () {
                Haptics.light();
                setState(() => _selectedSegmentIndex = 1);
                ref.read(searchViewModelProvider.notifier).setMode(SearchMode.home);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSegmentIndex == 1 ? const Color(0xFFF41222) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.soup_kitchen_outlined,
                          size: 18,
                          color: _selectedSegmentIndex == 1 ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                          'Search Items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _selectedSegmentIndex == 1 ? Colors.white : const Color(0xFF0F172A),
                          ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find your favorite food',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _selectedSegmentIndex == 1 ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Recent Searches Section (Real SharedPreferences backend data only)
  Widget _buildRecentSearchesSection() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            GestureDetector(
              onTap: () {
                Haptics.light();
                ref.read(searchViewModelProvider.notifier).clearRecentSearches();
              },
              child: const Text(
                'Clear All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF41222)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _recentSearches.map((s) {
              return GestureDetector(
                onTap: () {
                  Haptics.light();
                  _searchController.text = s;
                  ref.read(searchViewModelProvider.notifier).submitQuery(s);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        s,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 4. Popular Searches Categories Section (Real backend category models only)
  Widget _buildPopularSearchesSection() {
    final async = ref.watch(homeViewModelProvider).categories;
    final categories = async.asData?.value ?? const <CategoryModel>[];

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Searches',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((c) {
              return GestureDetector(
                onTap: () {
                  Haptics.light();
                  _searchController.text = c.name;
                  ref.read(searchViewModelProvider.notifier).submitQuery(c.name);
                },
                child: Container(
                  width: 64,
                  height: 74,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: SmartImage(
                          url: c.imageUrl,
                          category: ImageCategory.category,
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 5. Hero Promo Banners (Real backend promo banners only)
  Widget _buildPromoBanner() {
    final banners = ref.watch(promoBannersProvider).asData?.value ?? const <PromoBannerModel>[];
    if (banners.isEmpty) return const SizedBox.shrink();

    return PromoBannerCarousel(banners: banners);
  }

  /// 6. Top Restaurant Results Section (Pure real backend data)

  /// Dish results for the "Search Items" tab.
  ///
  /// The search datasource has always returned these (`SearchResultType.food`,
  /// carrying the parsed FoodModel), but nothing rendered them — both tabs drew
  /// the restaurant list, so searching "pizza" showed restaurants and never the
  /// pizza itself.
  Widget _buildItemResultsSection(BuildContext context, bool isDark) {
    final searchState = ref.watch(searchViewModelProvider);
    final query = searchState.query.trim();

    final items = searchState.results
        .where((r) => r.type == SearchResultType.food)
        .map((r) => r.rawItem)
        .whereType<FoodModel>()
        .toList();

    if (query.isEmpty) return const SizedBox.shrink();

    if (searchState.isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No items match "$query"',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            children: [
              const TextSpan(text: 'Item Results '),
              TextSpan(
                text: '(${items.length} results)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((f) => GestureDetector(
              onTap: () => _openFoodDetail(f),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SmartImage(
                        url: f.imageUrl,
                        category: ImageCategory.food,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                f.isVeg
                                    ? Icons.circle_outlined
                                    : Icons.change_history_rounded,
                                size: 12,
                                color: f.isVeg
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (f.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              f.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '₹${f.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              if (f.originalPrice != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹${f.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildTopRestaurantResultsSection(BuildContext context, bool isDark) {
    final searchState = ref.watch(searchViewModelProvider);
    final homeState = ref.watch(homeViewModelProvider);

    List<RestaurantModel> restaurants = [];

    if (searchState.query.trim().isNotEmpty && searchState.results.isNotEmpty) {
      restaurants = searchState.results
          .where((res) => res.type == SearchResultType.restaurant)
          .map((res) => res.rawItem)
          .whereType<RestaurantModel>()
          .toList();
    } else if (searchState.query.trim().isEmpty) {
      restaurants = homeState.nearbyRestaurants.asData?.value ?? const [];
    }
    // else: a query with no matches leaves the list empty so the "no results"
    // state below can speak, rather than showing every restaurant as a match.

    if (restaurants.isEmpty && searchState.query.trim().isNotEmpty && !searchState.isSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No results for "${searchState.query}"',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    if (restaurants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Count & Sort Dropdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  children: [
                    const TextSpan(text: 'Top Restaurant Results '),
                    TextSpan(
                      text: '(${restaurants.length} results)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Row(
              children: const [
                Text('Sort by ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                Text('Relevance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF41222))),
                Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFF41222), size: 16),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (searchState.isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ...restaurants.map((r) {
            final hasOffer = r.offerBadges.isNotEmpty;
            final offerText = hasOffer ? r.offerBadges.first : '';
            final cuisineStr = r.tags.join(' • ');

            return GestureDetector(
              onTap: () => _openRestaurantDetail(r),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Cover Image Stack (110x110)
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SmartImage(
                              url: r.imageUrl,
                              category: ImageCategory.restaurant,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Top-Left Discount Badge (if backend offer exists)
                          if (hasOffer)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF41222),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  offerText,
                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          // Top-Right Favorite Heart Icon
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(Icons.favorite_border_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Right Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Name + Verified Icon + Veg/Non-Veg Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (r.isFeatured) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded, color: Color(0xFFF41222), size: 14),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Pure Veg or Non-Veg Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.isPureVeg ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: r.isPureVeg ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      r.isPureVeg ? 'Pure Veg' : 'Non-Veg',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: r.isPureVeg ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (r.area.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              r.area,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],

                          if (cuisineStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              cuisineStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Row 3: Rating + Delivery Time + Price per person
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                if (r.rating > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.white, size: 10),
                                        const SizedBox(width: 2),
                                        Text(
                                          r.rating.toStringAsFixed(1),
                                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (r.reviewCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${r.reviewCount})',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  const SizedBox(width: 6),
                                ],
                                if (r.deliveryTime.isNotEmpty) ...[
                                  Text(
                                    r.deliveryTime,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (r.priceForOne > 0)
                                  Text(
                                    '₹${r.priceForOne.toStringAsFixed(0)} for one',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),

                          if (hasOffer || r.isFeatured) ...[
                            const SizedBox(height: 6),

                            // Row 4: Real Offer Tag & Bestseller Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (hasOffer)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F7F5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      offerText,
                                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFF41222)),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                if (r.isFeatured)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Bestseller',
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

}
