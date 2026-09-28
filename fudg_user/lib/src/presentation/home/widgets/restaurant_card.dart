import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/viewmodels/restaurant_detail_viewmodel.dart';

class RestaurantCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final int index;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.index = 0,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  late final ValueNotifier<int> _activePageNotifier;

  @override
  void initState() {
    super.initState();
    _activePageNotifier = ValueNotifier<int>(0);
  }

  @override
  void dispose() {
    _activePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuAsync = ref.watch(restaurantMenuProvider(restaurant.id));
    final menu = menuAsync.asData?.value ?? const <FoodModel>[];

    final featuredDish = menu.isEmpty
        ? null
        : menu.firstWhere((f) => f.isPopular, orElse: () => menu.first);

    final foodMenuUrls = menu
        .map((f) => f.imageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    final modelMenuUrls = restaurant.menuImages
        .where((url) => url.isNotEmpty)
        .toList();
    final modelCoverUrls = restaurant.coverImages
        .where((url) => url.isNotEmpty)
        .toList();

    final List<String> imageSlides;
    if (foodMenuUrls.isNotEmpty) {
      imageSlides = foodMenuUrls;
    } else if (modelMenuUrls.isNotEmpty) {
      imageSlides = modelMenuUrls;
    } else if (modelCoverUrls.isNotEmpty) {
      imageSlides = modelCoverUrls;
    } else if (restaurant.imageUrl.isNotEmpty) {
      imageSlides = [restaurant.imageUrl];
    } else {
      imageSlides = const [];
    }

    final startingPrice = restaurant.priceForOne > 0
        ? restaurant.priceForOne
        : (featuredDish != null ? featuredDish.price : 0.0);

    final List<double> slidePrices;
    final List<String> slideDishLabels;
    if (foodMenuUrls.isNotEmpty) {
      final menuWithImages = menu.where((f) => f.imageUrl.isNotEmpty).toList();
      slidePrices = menuWithImages.map((f) => f.price).toList();
      slideDishLabels = menuWithImages.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else if (menu.isNotEmpty) {
      slidePrices = menu.map((f) => f.price).toList();
      slideDishLabels = menu.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else {
      slidePrices = const [];
      slideDishLabels = const [];
    }

    final top3MenuItems = menu.take(3).map((f) {
      return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
    }).toList();

    final List<String> displayTopItems;
    if (top3MenuItems.isNotEmpty) {
      displayTopItems = top3MenuItems;
    } else if (restaurant.featuredDishName != null) {
      displayTopItems = [
        '${restaurant.featuredDishName}${startingPrice > 0 ? ' • ₹${startingPrice.toStringAsFixed(0)}' : ''}',
        if (restaurant.tags.isNotEmpty) restaurant.tags.first,
      ];
    } else if (restaurant.tags.isNotEmpty) {
      displayTopItems = restaurant.tags.take(3).toList();
    } else {
      displayTopItems = const [];
    }

    final bool isOpen = restaurant.isOpen;

    Widget cardWidget = Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        // The soft shadow alone left the card edge almost invisible against
        // the near-white feed background, so it carries a real border too.
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MediaCarousel(
            restaurant: restaurant,
            restaurantId: restaurant.id,
            imageSlides: imageSlides,
            isOpen: isOpen,
            featuredPriceBadge: startingPrice > 0 ? '₹${startingPrice.toStringAsFixed(0)} for one' : null,
            featuredDishName: restaurant.featuredDishName ?? featuredDish?.name,
            topMenuItemNames: slideDishLabels.isNotEmpty ? slideDishLabels : displayTopItems,
            onPageChanged: (page) {
              _activePageNotifier.value = page;
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 6.h),
            child: _RestaurantInfo(
              restaurant: restaurant,
              isDark: isDark,
              startingPrice: startingPrice,
              slidePrices: slidePrices,
              activePageNotifier: _activePageNotifier,
              topMenuItemNames: displayTopItems,
            ),
          ),
        ],
      ),
    );

    if (!isOpen) {
      cardWidget = IgnorePointer(
        ignoring: true,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: cardWidget,
        ),
      );
    }

    return _EntranceAnimationWrapper(
      index: widget.index,
      child: GestureDetector(
        onTap: isOpen
            ? () {
                Haptics.light();
                context.push(RouteNames.restaurantDetail, extra: restaurant);
              }
            : null,
        child: cardWidget,
      ),
    );
  }
}

class _EntranceAnimationWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceAnimationWrapper({
    required this.index,
    required this.child,
  });

  @override
  State<_EntranceAnimationWrapper> createState() => _EntranceAnimationWrapperState();
}

class _EntranceAnimationWrapperState extends State<_EntranceAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final delayMs = (widget.index % 6) * 60;
    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}



class _RestaurantInfo extends ConsumerWidget {
  final RestaurantModel restaurant;
  final bool isDark;
  final double startingPrice;
  final List<double> slidePrices;
  final ValueNotifier<int>? activePageNotifier;
  final List<String> topMenuItemNames;

  const _RestaurantInfo({
    required this.restaurant,
    required this.isDark,
    required this.startingPrice,
    this.slidePrices = const [],
    this.activePageNotifier,
    this.topMenuItemNames = const [],
  });

  Widget _buildInlineItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12.sp, color: color),
        SizedBox(width: 3.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final locationLabel = restaurant.area;

    // Info Line Spans: Clock 30 mins • ₹134 for one
    final infoSpans = <InlineSpan>[];

    if (restaurant.deliveryTime.isNotEmpty) {
      infoSpans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(
          Icons.access_time_rounded,
          size: 13.sp,
          color: AppColors.primaryDeep,
        ),
      ));
      infoSpans.add(TextSpan(
        text: ' ${restaurant.deliveryTime}',
        style: TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
      ));
    }

    if (restaurant.distanceKm != null) {
      if (infoSpans.isNotEmpty) {
        infoSpans.add(TextSpan(
          text: '   •   ',
          style: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
        ));
      }
      infoSpans.add(TextSpan(
        text: '${restaurant.distanceKm!.toStringAsFixed(1)} km',
        style: TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
      ));
    }

    final priceWidget = (slidePrices.isNotEmpty || startingPrice > 0)
        ? ValueListenableBuilder<int>(
            valueListenable: activePageNotifier ?? ValueNotifier<int>(0),
            builder: (context, currentPage, _) {
              final activePrice = (slidePrices.isNotEmpty &&
                      currentPage < slidePrices.length &&
                      slidePrices[currentPage] > 0)
                  ? slidePrices[currentPage]
                  : (slidePrices.isNotEmpty &&
                          (currentPage % slidePrices.length) < slidePrices.length &&
                          slidePrices[currentPage % slidePrices.length] > 0
                      ? slidePrices[currentPage % slidePrices.length]
                      : startingPrice);
              if (activePrice <= 0) return const SizedBox.shrink();
              return Text(
                '₹${activePrice.toStringAsFixed(0)} for one',
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                ),
              );
            },
          )
        : null;

    if (priceWidget != null) {
      if (infoSpans.isNotEmpty) {
        infoSpans.add(TextSpan(
          text: '   •   ',
          style: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
        ));
      }
      infoSpans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: priceWidget,
      ));
    }

    final cuisinesText = restaurant.tags.isNotEmpty
        ? restaurant.tags.join('  •  ')
        : (restaurant.restaurantTags.isNotEmpty
            ? restaurant.restaurantTags.join('  •  ')
            : 'Desserts  •  North Indian  •  Snacks');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Restaurant Name Header Row with Green Rating Pill (Top-Right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (restaurant.rating > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 13.sp,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      restaurant.rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // 1b. Live offers ticker. Renders only when the restaurant actually
        // has promotions — `offerBadges` comes straight from the backend.
        if (restaurant.offerBadges.isNotEmpty) ...[
          SizedBox(height: 6.h),
          AutoScrollingOffers(
            offers: restaurant.offerBadges,
            prefix: Icon(
              Icons.local_offer_rounded,
              size: 12.sp,
              color: AppColors.primaryDeep,
            ),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
        ],

        SizedBox(height: 3.h),

        // 2. Delivery Time / Cost Line & Right-Side Inline Location / Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(children: infoSpans),
              ),
            ),
            if (locationLabel.isNotEmpty)
              Flexible(
                child: _buildInlineItem(
                  icon: Icons.location_on_rounded,
                  label: locationLabel,
                  color: AppColors.primaryDeep,
                ),
              )
            else if (!restaurant.isOpen)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3F1D24)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF881337)
                        : const Color(0xFFFECDD3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12.sp,
                      color: const Color(0xFFE11D48),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Unavailable Delivery',
                      style: TextStyle(
                        color: const Color(0xFFE11D48),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        SizedBox(height: 3.h),

        // 3. Cuisines Line & Right-Aligned Inline Pure Veg Badge directly below Location
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                cuisinesText,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (restaurant.isPureVeg) ...[
              SizedBox(width: 8.w),
              _buildInlineItem(
                icon: Icons.eco_rounded,
                label: 'Pure Veg',
                color: const Color(0xFF2E7D32),
              ),
            ],
          ],
        ),

        // 4. Temporary Closed Banner (Matching Screenshot)
        if (!restaurant.isOpen) ...[
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primarySoft,
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 15.sp,
                    color: AppColors.primaryDeep,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Delivery is currently unavailable.',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.primarySoft
                              : AppColors.primaryDeepText,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'It will accept orders once it reopens.',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.primarySoft
                              : AppColors.primaryDeepText.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // 5. Must Try / Popular Dish Banner Row
        if (topMenuItemNames.isNotEmpty || restaurant.featuredDishName != null) ...[
          SizedBox(height: 5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryTintDark
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark
                    ? AppColors.primaryTintDarkStrong
                    : AppColors.primarySoft,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14.sp,
                  color: AppColors.primaryDeep,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: PageUpTextTicker(
                    items: topMenuItemNames.isNotEmpty
                        ? topMenuItemNames
                        : [
                            if (restaurant.featuredDishName != null)
                              '${restaurant.featuredDishName}${startingPrice > 0 ? ' • ₹${startingPrice.toStringAsFixed(0)}' : ''}'
                          ],
                    prefix: Text(
                      'Must Try • ',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                if (!restaurant.isOpen)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Unavailable',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      Haptics.medium();
                      context.push(RouteNames.restaurantDetail,
                          extra: restaurant);
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.primarySoft,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14.sp,
                            color: AppColors.primaryDeep,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaCarousel extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;
  final String restaurantId;
  final List<String> imageSlides;
  final bool isOpen;
  final String? featuredPriceBadge;
  final String? featuredDishName;
  final List<String> topMenuItemNames;
  final ValueChanged<int>? onPageChanged;

  const _MediaCarousel({
    this.restaurant,
    required this.restaurantId,
    required this.imageSlides,
    required this.isOpen,
    this.featuredPriceBadge,
    this.featuredDishName,
    this.topMenuItemNames = const [],
    this.onPageChanged,
  });

  @override
  ConsumerState<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends ConsumerState<_MediaCarousel> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  Timer? _timer;
  Timer? _inactivityTimer;
  int _currentPage = 0;
  bool _isUserInteracting = false;

  late final AnimationController _heartBumpController;
  late final Animation<double> _heartScaleAnimation;

  int get _slideCount => widget.imageSlides.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _heartBumpController, curve: Curves.easeOutCubic),
    );

    if (_slideCount > 1 && widget.isOpen) {
      _startAutoSlideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageSlides.length != widget.imageSlides.length ||
        oldWidget.isOpen != widget.isOpen) {
      if (_currentPage >= widget.imageSlides.length) {
        _currentPage = 0;
      }
      if (_slideCount > 1 && widget.isOpen) {
        _startAutoSlideTimer();
      } else {
        _timer?.cancel();
        _inactivityTimer?.cancel();
      }
    }
  }

  void _startAutoSlideTimer() {
    _timer?.cancel();
    if (_slideCount <= 1 || !mounted || _isUserInteracting || !widget.isOpen) return;

    _timer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (!mounted || _slideCount <= 1 || _isUserInteracting || !widget.isOpen) {
        timer.cancel();
        return;
      }
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slideCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserInteractionStart() {
    _isUserInteracting = true;
    _timer?.cancel();
    _inactivityTimer?.cancel();
  }

  void _onUserInteractionEnd() {
    if (!_isUserInteracting) return;
    _isUserInteracting = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isUserInteracting && _slideCount > 1) {
        _startAutoSlideTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inactivityTimer?.cancel();
    _pageController.dispose();
    _heartBumpController.dispose();
    super.dispose();
  }

  void _handleFavoriteTap() {
    Haptics.medium();
    _heartBumpController.forward(from: 0.0);
    ref.read(favoritesViewModelProvider.notifier).toggle(widget.restaurantId, widget.restaurant);
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(
      favoritesViewModelProvider.select((state) => state.value?.restaurantIds.contains(widget.restaurantId) ?? false),
    );

    final currentDishLabel = widget.topMenuItemNames.isNotEmpty
        ? widget.topMenuItemNames[_currentPage % widget.topMenuItemNames.length]
        : (widget.featuredDishName != null
            ? '${widget.featuredDishName}${widget.featuredPriceBadge != null ? " • ${widget.featuredPriceBadge}" : ""}'
            : widget.featuredPriceBadge);

    return SizedBox(
      height: 205.h,
      child: Stack(
        children: [
          // 1. Cover / Food Image Slides Carousel (Grayscale desaturation when closed)
          Positioned.fill(
            child: _slideCount == 0
                ? Container(color: const Color(0xFFF0F0F0))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _onUserInteractionStart();
                      } else if (notification is ScrollEndNotification) {
                        _onUserInteractionEnd();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slideCount,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        widget.onPageChanged?.call(page);
                      },
                      itemBuilder: (context, index) {
                        return SmartImage(
                          url: widget.imageSlides[index],
                          category: ImageCategory.restaurant,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    ),
                  ),
          ),

          // 2. Dark Gradient Overlay for text contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Temporarily Closed Badge Overlay (Matching Screenshot)
          if (!widget.isOpen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xDC18181B),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 26.sp,
                          color: const Color(0xFFF43F5E),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNAVAILABLE DELIVERY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'Will reopen soon',
                              style: TextStyle(
                                color: const Color(0xFFD4D4D8),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Synchronized Top-Left Black Tag (Dish Name & Price)
          if (currentDishLabel != null && currentDishLabel.isNotEmpty)
            Positioned(
              top: 12.h,
              left: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey<String>(currentDishLabel),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 13.sp,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          currentDishLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Bookmark / Favorite Button (Top-Right)
          Positioned(
            top: 12.h,
            right: 12.w,
            child: GestureDetector(
              onTap: _handleFavoriteTap,
              child: Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ScaleTransition(
                  scale: _heartScaleAnimation,
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 17.sp,
                    color: isFavorite ? const Color(0xFFFF4B72) : Colors.black54,
                  ),
                ),
              ),
            ),
          ),

          // 6. Carousel Dot Indicators (Matching Screenshot)
          if (_slideCount > 1)
            Positioned(
              bottom: 10.h,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_slideCount, (i) => _dot(i == _currentPage)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.only(left: 4.w),
      width: active ? 14.w : 5.w,
      height: 5.h,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}

/// Animated ticker cycling through items using vertical page-up transition
/// (old text slides UP and exits top, new text arrives UP from bottom).
class PageUpTextTicker extends StatefulWidget {
  final List<String> items;
  final TextStyle style;
  final Widget? prefix;
  final Duration interval;
  final Duration animationDuration;

  const PageUpTextTicker({
    super.key,
    required this.items,
    required this.style,
    this.prefix,
    this.interval = const Duration(milliseconds: 2800),
    this.animationDuration = const Duration(milliseconds: 400),
  });

  @override
  State<PageUpTextTicker> createState() => _PageUpTextTickerState();
}

class _PageUpTextTickerState extends State<PageUpTextTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PageUpTextTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted || widget.items.length <= 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final currentText = widget.items[_currentIndex % widget.items.length];

    return AnimatedSwitcher(
      duration: widget.animationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isIncoming =
            (child.key as ValueKey<int>?)?.value == _currentIndex;

        final inAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(animation);

        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, -1.0),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: isIncoming ? inAnimation : outAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey<int>(_currentIndex),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            SizedBox(width: 4.w),
          ],
          Flexible(
            child: Text(
              currentText,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live offers banner: an infinite right-to-left ticker over the restaurant's
/// real promotions.
///
/// Horizontal sibling of [PageUpTextTicker] — the incoming offer slides in from
/// the right while the outgoing one exits left, so the row reads as a marquee
/// without the cost of a continuously animating scroll.
///
/// Content is [RestaurantModel.offerBadges] verbatim. The widget renders
/// nothing when a restaurant has no live offer rather than inventing one; the
/// cards previously advertised discounts that did not exist on the backend.
///
/// Touching the row pauses the rotation so a half-read offer does not slide
/// away mid-glance; it resumes [resumeDelay] after the finger lifts.
class AutoScrollingOffers extends StatefulWidget {
  final List<String> offers;
  final TextStyle style;
  final Widget? prefix;
  final Duration interval;
  final Duration animationDuration;
  final Duration resumeDelay;

  const AutoScrollingOffers({
    super.key,
    required this.offers,
    required this.style,
    this.prefix,
    this.interval = const Duration(milliseconds: 3500),
    this.animationDuration = const Duration(milliseconds: 450),
    this.resumeDelay = const Duration(seconds: 5),
  });

  @override
  State<AutoScrollingOffers> createState() => _AutoScrollingOffersState();
}

class _AutoScrollingOffersState extends State<AutoScrollingOffers> {
  int _currentIndex = 0;
  Timer? _timer;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AutoScrollingOffers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.offers.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted || widget.offers.length <= 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.offers.length;
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    _resumeTimer?.cancel();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    if (widget.offers.length <= 1) return;
    _resumeTimer = Timer(widget.resumeDelay, () {
      if (mounted) _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    final currentText = widget.offers[_currentIndex % widget.offers.length];

    return Listener(
      // Listener rather than GestureDetector: the row sits inside a tappable
      // card, and a gesture recogniser here would compete with the card's own
      // tap for the win.
      onPointerDown: (_) => _pause(),
      onPointerUp: (_) => _scheduleResume(),
      onPointerCancel: (_) => _scheduleResume(),
      behavior: HitTestBehavior.translucent,
      child: AnimatedSwitcher(
        duration: widget.animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming =
              (child.key as ValueKey<int>?)?.value == _currentIndex;

          // Right-to-left: the new offer enters from the right edge, the old
          // one leaves past the left.
          final offset = Tween<Offset>(
            begin: Offset(isIncoming ? 1.0 : -1.0, 0.0),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Row(
          key: ValueKey<int>(_currentIndex),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.prefix != null) ...[
              widget.prefix!,
              SizedBox(width: 4.w),
            ],
            Flexible(
              child: Text(
                currentText,
                style: widget.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
