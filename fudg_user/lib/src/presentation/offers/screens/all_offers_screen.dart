import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/offers_viewmodel.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/coupon_sheet.dart';
import '../../checkout/viewmodels/checkout_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/free_delivery_progress_card.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';

class AllOffersScreen extends ConsumerStatefulWidget {
  const AllOffersScreen({super.key});

  @override
  ConsumerState<AllOffersScreen> createState() => _AllOffersScreenState();
}

class _AllOffersScreenState extends ConsumerState<AllOffersScreen> {
  int _selectedCategoryIndex = 0; // 0: All Offers

  RestaurantModel? _restaurantFor(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return null;
    final nearby =
        ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ??
        const <RestaurantModel>[];
    for (final r in nearby) {
      if (r.id == restaurantId) return r;
    }
    return null;
  }

  /// Applies a code against the real order and reports only what the server
  /// actually granted — tapping a card here must behave exactly like applying
  /// it from the coupon sheet, since both go through the same bill.
  Future<void> _applyOfferCode(String code) async {
    if (code.isEmpty) return;
    Haptics.light();
    if (ref.read(cartViewModelProvider).items.isEmpty) {
      AppSnackbar.error(
        context,
        'Add items to your cart before applying $code',
      );
      return;
    }
    await ref.read(checkoutViewModelProvider.notifier).applyCoupon(code);
    if (!mounted) return;
    final pricing = ref.read(checkoutViewModelProvider).pricing;
    if (pricing?.hasCouponApplied ?? false) {
      AppSnackbar.success(
        context,
        'Code $code applied — saved ₹${pricing!.discount.toStringAsFixed(0)}!',
      );
    } else {
      AppSnackbar.error(context, _rejectionMessage(code));
    }
  }

  /// The server's refusal wording for the code just applied. It writes these
  /// for customers, so it is shown exactly rather than reworded here.
  String _rejectionMessage(String code) {
    return ref.read(checkoutViewModelProvider).couponError ??
        'Code $code is not valid for this order';
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
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFFAFDFF),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Header Row: Back Button, Title, My Coupons Button
              _buildTopHeader(context, isDark),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // 2. Free Delivery Progress Card
                      _buildFreeDeliveryCard(isDark),

                      const SizedBox(height: 20),

                      // 3. "Best Offers for You 🎉" Carousel
                      _buildBestOffersSection(context, isDark),

                      const SizedBox(height: 24),

                      // 4. "Top Coupon Categories" Grid
                      _buildTopCategoriesSection(isDark),

                      const SizedBox(height: 24),

                      // 5. "More Savings for You" List Cards
                      _buildMoreSavingsSection(context, isDark),

                      const SizedBox(height: 20),

                      // 6. Notifications / Exclusive Offers Banner
                      _buildNotificationsBanner(isDark),

                      const SizedBox(height: 20),

                      // 7. Trust / Value Badges Row
                      _buildTrustBadgesRow(isDark),

                      const SizedBox(height: 28),
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

  /// 1. Top Navigation Header Row
  Widget _buildTopHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE6F7F5),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Offers & Coupons',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),

          // My Coupons Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              CouponSheet.show(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'My Coupons',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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

  /// 2. Free Delivery Progress Card — only shown when the cart's restaurant
  /// actually has a `freeDeliveryAbove` threshold. There is no number to
  /// invent otherwise.
  Widget _buildFreeDeliveryCard(bool isDark) {
    final cart = ref.watch(cartViewModelProvider);
    final threshold = _restaurantFor(cart.restaurantId)?.freeDeliveryAbove;
    if (threshold == null || threshold <= 0) return const SizedBox.shrink();
    return FreeDeliveryProgressCard(
      subtotal: cart.subtotal,
      threshold: threshold,
    );
  }

  /// 3. "Best Offers for You 🎉" Section
  Widget _buildBestOffersSection(BuildContext context, bool isDark) {
    final async = ref.watch(offersProvider);
    final raw = async.asData?.value ?? const <Map<String, dynamic>>[];

    final checkout = ref.watch(checkoutViewModelProvider);
    final List<Map<String, dynamic>> offerCards = raw.map((o) {
      final code = (o['couponCode'] ?? o['code'] ?? '').toString();
      return {
        'tag': code.contains('BANK') ? 'BANK OFFER' : 'SPECIAL',
        'tagColor': code.contains('BANK')
            ? const Color(0xFFEA580C)
            : const Color(0xFF16A34A),
        'tagBg': code.contains('BANK')
            ? const Color(0xFFFFEDD5)
            : const Color(0xFFDCFCE7),
        'title': offerHeadline(o),
        'subtitle1': '',
        'subtitle2': offerConditions(o),
        'code': code,
        'bgColor': code.contains('BANK')
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF0FDF4),
        'validity': _validityLabel(o),
        'raw': o,
        'reason': checkout.couponCode == code ? checkout.couponError : null,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Best Offers for You ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Text('🎉', style: TextStyle(fontSize: 16)),
              ],
            ),
            Row(
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (offerCards.isEmpty)
          Text(
            'No offers available right now',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          )
        else
          // Horizontal Offer Cards
          SizedBox(
            height: 195,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: offerCards.length,
              itemBuilder: (context, index) {
                final card = offerCards[index];
                final tagColor = card['tagColor'] as Color;
                final tagBg = card['tagBg'] as Color;
                final bgColor = card['bgColor'] as Color;
                final code = card['code'] as String;

                return GestureDetector(
                  onTap: () => _applyOfferCode(code),
                  child: Container(
                    width: 138,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            card['tag'] as String,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: tagColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card['title'] as String,
                          // The server headline carries the cap ("50% OFF up
                          // to ₹60") and is far longer than the old title, so
                          // it is bounded on this fixed-height card.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tagColor,
                            height: 1.1,
                          ),
                        ),
                        if ((card['subtitle1'] as String).isNotEmpty) ...[
                          Text(
                            card['subtitle1'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                        Text(
                          card['subtitle2'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        // Dotted Coupon Box with COPY
                        GestureDetector(
                          onTap: () {
                            Haptics.light();
                            AppSnackbar.success(
                              context,
                              'Code ${card["code"]} copied!',
                            );
                          },
                          child: CustomPaint(
                            painter: _DashedRectPainter(
                              color: tagColor.withValues(alpha: 0.4),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    card['code'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'COPY',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: tagColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              card['validity'] as String,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => showOfferDetailsSheet(
                                context,
                                card['raw'] as Map<String, dynamic>,
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: card['reason'] != null
                                    ? const Color(0xFFEA580C)
                                    : (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ],
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

  /// 4. "Top Coupon Categories" Section
  Widget _buildTopCategoriesSection(bool isDark) {
    final categories = [
      {'name': 'All Offers', 'icon': Icons.local_offer_outlined},
      {'name': 'Bank Offers', 'icon': Icons.credit_card_rounded},
      {'name': 'Free Delivery', 'icon': Icons.directions_bike_rounded},
      {'name': 'New User', 'icon': Icons.person_outline_rounded},
      {'name': 'Top Brands', 'icon': Icons.star_border_rounded},
      {'name': 'Combo Offers', 'icon': Icons.card_giftcard_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Coupon Categories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(categories.length, (index) {
            final cat = categories[index];
            final isSelected = _selectedCategoryIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(() => _selectedCategoryIndex = index);
                },
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : const Color(0xFFE6F7F5))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569)),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          cat['name'] as String,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 5. "More Savings for You" List Cards
  Widget _buildMoreSavingsSection(BuildContext context, bool isDark) {
    final async = ref.watch(offersProvider);
    final raw = async.asData?.value ?? const <Map<String, dynamic>>[];

    const themes = [
      (
        Color(0xFF16A34A),
        Color(0xFFDCFCE7),
        Color(0xFFF0FDF4),
        Color(0xFF064E3B),
      ),
      (
        Color(0xFFEA580C),
        Color(0xFFFFEDD5),
        Color(0xFFFFF7ED),
        Color(0xFF7C2D12),
      ),
      (
        Color(0xFF7C3AED),
        Color(0xFFEDE9FE),
        Color(0xFFF5F3FF),
        Color(0xFF4C1D95),
      ),
    ];

    final checkout = ref.watch(checkoutViewModelProvider);
    final List<Map<String, dynamic>> listCoupons = raw.asMap().entries.map((
      entry,
    ) {
      final o = entry.value;
      final theme = themes[entry.key % themes.length];
      final leftColor = theme.$1;
      final tagBg = theme.$2;
      final lightBg = theme.$3;
      final darkBg = theme.$4;
      final discountValue =
          (o['discountValue'] as num?)?.toStringAsFixed(0) ?? '';
      final leftTitle = o['discountType'] == 'percentage'
          ? '$discountValue%\nOFF'
          : '₹$discountValue\nOFF';
      return {
        'leftTitle': leftTitle,
        'leftBg': isDark ? darkBg.withValues(alpha: 0.3) : lightBg,
        'leftColor': leftColor,
        'tag': (o['isFirstOrderOnly'] == true) ? 'FIRST ORDER' : 'ALL USERS',
        'tagBg': tagBg,
        'tagColor': leftColor,
        'title': offerHeadline(o),
        'subtitle': offerConditions(o),
        'minSpend': '',
        'code': (o['couponCode'] ?? '').toString(),
        'validity': _validityLabel(o),
        'raw': o,
        'reason': checkout.couponCode == (o['couponCode'] ?? '').toString()
            ? checkout.couponError
            : null,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Savings for You',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        if (listCoupons.isEmpty)
          Text(
            'No offers available right now',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ...listCoupons.map((c) {
          final leftColor = c['leftColor'] as Color;
          final leftBg = c['leftBg'] as Color;
          final tagColor = c['tagColor'] as Color;
          final tagBg = c['tagBg'] as Color;
          final code = c['code'] as String;
          const double notchPosition = 75.0;
          const double cardHeight = 92.0;

          return GestureDetector(
            onTap: () => _applyOfferCode(code),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: cardHeight,
              child: Stack(
                children: [
                  // Clipped Ticket Shape Background & Border
                  ClipPath(
                    clipper: _TicketClipper(notchPosition: notchPosition),
                    child: Container(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(double.infinity, cardHeight),
                    painter: _TicketBorderPainter(
                      notchPosition: notchPosition,
                      borderColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),

                  // Card Content Row
                  Row(
                    children: [
                      // Left Ticket Code Box
                      Container(
                        width: notchPosition,
                        height: cardHeight,
                        decoration: BoxDecoration(color: leftBg),
                        child: Center(
                          child: Text(
                            c['leftTitle'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: leftColor,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),

                      // Dashed Line Separator
                      CustomPaint(
                        size: const Size(1, cardHeight),
                        painter: _DashedLinePainter(
                          color: leftColor.withValues(alpha: 0.3),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Middle Details Column
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: tagBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c['tag'] as String,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: tagColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                c['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                c['subtitle'] as String,
                                // Conditions run long ("on orders above ₹199 ·
                                // Mon-Fri · 12:00-15:00"); the ticket is a
                                // fixed 92px. Full text is in the details sheet.
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // The reason replaces the max-discount line
                              // rather than stacking under it: this ticket is
                              // a fixed 92px and only fits one of the two.
                              if (c['reason'] != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  c['reason'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ] else if ((c['minSpend'] as String).isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  c['minSpend'] as String,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Right Code Box & Validity Column
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 12.0,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Haptics.light();
                                AppSnackbar.success(
                                  context,
                                  'Code ${c["code"]} copied!',
                                );
                              },
                              child: CustomPaint(
                                painter: _DashedRectPainter(
                                  color: leftColor.withValues(alpha: 0.4),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        c['code'] as String,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'COPY',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: leftColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => showOfferDetailsSheet(
                                context,
                                c['raw'] as Map<String, dynamic>,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    c['validity'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 1),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 13,
                                    color: c['reason'] != null
                                        ? const Color(0xFFEA580C)
                                        : (isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 6. Notifications / Exclusive Offers Banner Box
  Widget _buildNotificationsBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : const Color(0xFFDCFCE7),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.percent_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want more exclusive offers?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Enable notifications and never miss a deal!',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Haptics.light();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                'Enable Now',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Trust / Savings Value Badges Row
  Widget _buildTrustBadgesRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTrustBadge(
          icon: Icons.percent_rounded,
          title: 'Extra Savings',
          subtitle: 'Best deals & offers',
          isDark: isDark,
        ),
        _buildTrustBadge(
          icon: Icons.shield_outlined,
          title: 'Secure Payments',
          subtitle: '100% safe & secure',
          isDark: isDark,
        ),
        _buildTrustBadge(
          icon: Icons.savings_outlined,
          title: 'Save More',
          subtitle: 'On every order',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 8.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Dashed Border Painter for Coupon Code Boxes
class _DashedRectPainter extends CustomPainter {
  final Color color;

  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3, dashSpace = 2;

    // Top
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
    // Bottom
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + dashWidth, size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
    // Left
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
    // Right
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(size.width, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Clipper for Coupon Ticket with top and bottom notches
class _TicketClipper extends CustomClipper<Path> {
  final double notchPosition;

  _TicketClipper({required this.notchPosition});

  @override
  Path getClip(Size size) {
    const double notchRadius = 6.0;
    final path = Path();
    path.moveTo(0, 0);

    path.lineTo(notchPosition - notchRadius, 0);
    path.arcToPoint(
      Offset(notchPosition + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);

    path.lineTo(size.width, size.height);

    path.lineTo(notchPosition + notchRadius, size.height);
    path.arcToPoint(
      Offset(notchPosition - notchRadius, size.height),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, size.height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => true;
}

/// Custom Border Painter along the ticket notch path
class _TicketBorderPainter extends CustomPainter {
  final double notchPosition;
  final Color borderColor;

  _TicketBorderPainter({
    required this.notchPosition,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double notchRadius = 6.0;
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(notchPosition - notchRadius, 0);
    path.arcToPoint(
      Offset(notchPosition + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(notchPosition + notchRadius, size.height);
    path.arcToPoint(
      Offset(notchPosition - notchRadius, size.height),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Vertical Dashed Line Painter for Coupon Tickets
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    double dashHeight = 4, dashSpace = 3, startY = 4;
    while (startY < size.height - 4) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper labels derived from backend offer records


String _validityLabel(Map<String, dynamic> o) {
  final raw = o['endDate']?.toString();
  if (raw == null || raw.isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final l = d.toLocal();
  return 'Valid till ${l.day} ${months[l.month - 1]}';
}
