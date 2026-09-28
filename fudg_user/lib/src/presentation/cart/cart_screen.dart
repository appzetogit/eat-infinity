import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/restaurant_model.dart';
import '../branding/app_colors.dart';
import '../common_widgets/smart_image.dart';
import '../home/viewmodels/home_viewmodel.dart';
import '../navigation/route_names.dart';
import '../../data/models/order_pricing.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';
import 'viewmodels/cart_viewmodel.dart';
import 'widgets/cart_recommendations_section.dart';
import 'widgets/coupon_sheet.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// Line-item subtotal from cart state.
  double get _itemTotal => ref.read(cartViewModelProvider).subtotal;

  /// Server-calculated bill, shared with checkout.
  ///
  /// These were invented client-side (₹35 delivery, ₹20 packaging, free over
  /// ₹500) — none of which exist on this backend, whose fees come from distance
  /// bands plus tax and platform fee. The cart therefore quoted a total that
  /// disagreed with checkout. Reading CheckoutViewModel's pricing means both
  /// screens show the same `POST /food/orders/calculate` result by construction.
  OrderPricing? get _pricing => ref.watch(checkoutViewModelProvider).pricing;

  /// True while the server bill is still in flight and nothing is cached.
  bool get _pricingPending =>
      _pricing == null && ref.watch(checkoutViewModelProvider).isCalculating;

  /// Formats a server-owned amount, or an em dash before the bill arrives —
  /// never a guess.
  String _amount(double? v) => v == null ? '—' : '₹${v.toStringAsFixed(0)}';

  double? get _deliveryFee => _pricing?.deliveryFee;
  double? get _packagingFee => _pricing?.packagingFee;
  double? get _toPayTotal => _pricing?.total;

  /// Resolves restaurant name from home list.
  /// The cart's restaurant from the already-loaded home list, or null.
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

  String? _restaurantNameFor(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return null;
    final nearby =
        ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ??
            const <RestaurantModel>[];
    for (final r in nearby) {
      if (r.id == restaurantId) return r.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cart = ref.watch(cartViewModelProvider);
    final freeDeliveryAbove = _restaurantFor(cart.restaurantId)?.freeDeliveryAbove;

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
            // 1. Top Header Row: Back button, Title, Subtitle, Edit button
            _buildTopHeader(context),

            if (cart.items.isEmpty)
              Expanded(child: _buildEmptyCart(context))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // 2. Free Delivery Progress Banner Card
                      if (freeDeliveryAbove != null && freeDeliveryAbove > 0) ...[
                        _buildFreeDeliveryCard(_itemTotal, freeDeliveryAbove),
                        const SizedBox(height: 14),
                      ],

                      // 3. Cart Items List
                      _buildCartItemsList(cart.items),

                      const SizedBox(height: 18),

                      // 4. "✨ You might also like" Recommendations Section
                      _buildRecommendationsSection(),

                      const SizedBox(height: 18),

                      // 5. Promo Code Banner Box
                      _buildPromoCodeBox(context),

                      const SizedBox(height: 18),

                      // 6. Billing & Address Summary Card
                      _buildBillingSummaryCard(cart.totalQuantity),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

            // 7. Bottom Checkout Action Bar
            if (cart.items.isNotEmpty)
              _buildBottomCheckoutBar(context),
          ],
        ),
      ),
    ),
  );
  }

  /// 1. Top Navigation Header Row
  Widget _buildTopHeader(BuildContext context) {
    final cart = ref.watch(cartViewModelProvider);
    final count = cart.totalQuantity;
    final name = _restaurantNameFor(cart.restaurantId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Cart',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(
                          text: '$count item${count == 1 ? '' : 's'}'
                              '${name == null ? '' : ' from '}'),
                      if (name != null)
                        TextSpan(
                          text: name,
                          style: const TextStyle(color: Color(0xFFF41222), fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Free Delivery Progress Banner Card
  ///
  /// The goal is the restaurant's own `freeDeliveryAbove`, the same figure the
  /// home card advertises. It used to be a hardcoded ₹500 that existed nowhere
  /// on the backend, so the cart counted towards a target the restaurant card
  /// contradicted and the bill never honoured. No threshold configured means no
  /// banner — there is no number to invent.
  Widget _buildFreeDeliveryCard(double subtotal, double threshold) {
    final double needed = (threshold - subtotal).clamp(0.0, threshold);
    final double progress = (subtotal / threshold).clamp(0.0, 1.0);
    final bool unlocked = needed <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF41222).withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF41222).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFF41222), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unlocked
                          ? 'You unlocked'
                          : 'Add items worth ₹${needed.toStringAsFixed(0)} more to get',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'FREE DELIVERY',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                    ),
                  ],
                ),
              ),
              Text(
                unlocked ? 'Unlocked 🎉' : '₹${needed.toStringAsFixed(0)} to go',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress Line Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFCBD5E1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF41222)),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty Cart View
  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF41222).withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 32, color: Color(0xFFF41222)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add dishes from a restaurant to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF41222),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Browse restaurants', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Cart Items List
  Widget _buildCartItemsList(List<CartItemModel> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildCartItemCard(items[i]),
        ],
      ],
    );
  }

  Widget _buildCartItemCard(CartItemModel item) {
    final food = item.food;
    final subtitleParts = <String>[
      if ((item.selectedVariant ?? '').isNotEmpty) item.selectedVariant!,
      ...item.selectedAddonDetails.map((a) => a.name),
    ];
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' • ')
        : (food.description.isNotEmpty ? food.description : '(Add-on)');

    final title = food.name;
    final price = '₹${item.totalPrice.toStringAsFixed(0)}';
    final isVeg = food.isVeg;
    final isBestseller = food.isPopular;
    final count = item.quantity;
    final notifier = ref.read(cartViewModelProvider.notifier);

    void onIncrement() => notifier.updateQuantity(item.id, count + 1);
    void onDecrement() => notifier.updateQuantity(item.id, count - 1);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          // Dish Image (72x72)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: SmartImage(
                url: food.imageUrl,
                category: ImageCategory.food,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Veg / Non-Veg Indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: isVeg
                            ? Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A34A)))
                            : CustomPaint(size: const Size(6, 6), painter: _TrianglePainter(color: const Color(0xFFEF4444))),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    if (isBestseller) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Bestseller',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),

                    // Quantity Counter Box (- 1 +)
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF41222), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onDecrement,
                            child: const Icon(Icons.remove, size: 14, color: Color(0xFFF41222)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                            ),
                          ),
                          GestureDetector(
                            onTap: onIncrement,
                            child: const Icon(Icons.add, size: 14, color: Color(0xFFF41222)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. "✨ You might also like" Recommendations Section
  Widget _buildRecommendationsSection() {
    final restaurantId = ref.watch(cartViewModelProvider).restaurantId;
    return CartRecommendationsSection(restaurantId: restaurantId ?? '');
  }

  /// 5. Promo Code Banner Box
  ///
  /// Reflects the attached code rather than always inviting one: an applied
  /// code shows its saving, a refused one shows the server's reason and stays
  /// attached, so it re-applies by itself once the cart qualifies again.
  Widget _buildPromoCodeBox(BuildContext context) {
    final checkout = ref.watch(checkoutViewModelProvider);
    final code = checkout.couponCode;
    final pricing = checkout.pricing;
    final applied = pricing?.hasCouponApplied ?? false;
    final error = checkout.couponError;
    final hasCode = code != null && code.isNotEmpty;

    final String title;
    final String subtitle;
    if (!hasCode) {
      title = 'Have a promo code?';
      subtitle = 'Apply code & save more';
    } else if (applied) {
      title = '$code applied';
      subtitle = 'You saved ₹${(pricing?.discount ?? 0).toStringAsFixed(0)}';
    } else {
      title = '$code not applied';
      subtitle = error ?? 'This code is not valid for this order';
    }

    return GestureDetector(
      onTap: () {
        Haptics.light();
        CouponSheet.show(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasCode && !applied
                ? const Color(0xFFEA580C).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF41222).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.percent_rounded, color: Color(0xFFF41222), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasCode && !applied
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasCode) ...[
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  ref.read(checkoutViewModelProvider.notifier).removeCoupon();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'REMOVE',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                  ),
                ),
              ),
            ] else
            GestureDetector(
              onTap: () {
                Haptics.light();
                CouponSheet.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF41222), width: 1.2),
                ),
                child: Row(
                  children: const [
                    Text(
                      'View Promocodes',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF41222)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFF41222), size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 6. Billing & Address Summary Card
  Widget _buildBillingSummaryCard(int itemCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Item Total, Delivery Fee, Packaging Fee, To Pay
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shopping Bag Icon Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF41222).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFF41222), size: 18),
                        ),
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF41222),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                '$itemCount',
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Item Total', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                              Text('₹${_itemTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Text('Delivery Fee ', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                  Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF94A3B8)),
                                ],
                              ),
                              Text(
                                _deliveryFee == 0 ? 'FREE' : _amount(_deliveryFee),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _deliveryFee == 0 ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Packaging Fee', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                              Text(_amount(_packagingFee), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFCBD5E1), height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('To Pay', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFF41222))),
                    Text(_pricingPending ? '…' : _amount(_toPayTotal), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFF41222))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),
          Container(width: 1, height: 95, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 10),

          // Right Side: Deliver to Home & Distance/Time Box
          SizedBox(
            width: 125,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFFF41222)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deliver to', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            Row(
                              children: const [
                                Text('Home', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF0F172A)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 3),
                    // Real ETA/distance for this cart's restaurant. Both were
                    // hardcoded, so every cart claimed 25–35 mins and 2.6 km.
                    Text(
                      () {
                        final r = _restaurantFor(
                            ref.watch(cartViewModelProvider).restaurantId);
                        return (r?.deliveryTime ?? '').isNotEmpty
                            ? r!.deliveryTime
                            : '—';
                      }(),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const Spacer(),
                    const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 2),
                    Text(
                      () {
                        final r = _restaurantFor(
                            ref.watch(cartViewModelProvider).restaurantId);
                        return r?.distanceKm != null
                            ? '${r!.distanceKm!.toStringAsFixed(1)} km'
                            : '—';
                      }(),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Bottom Checkout Action Bar
  Widget _buildBottomCheckoutBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Haptics.medium();
          context.push(RouteNames.checkout);
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF41222),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Proceed to Checkout',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 12),
              Text(
                _pricingPending ? '…' : _amount(_toPayTotal),
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Non-Veg Red Triangle Painter
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
