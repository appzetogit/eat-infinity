import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../cart/widgets/coupon_sheet.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../../data/models/tip_config.dart';
import '../../../data/models/address_model.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../../data/models/restaurant_model.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/checkout_viewmodel.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _selectedPaymentMethodIndex =
      0; // 0: UPI, 1: Card, 2: NetBanking, 3: Wallets, 4: COD
  bool _isPlacingOrder = false;

  /// Collapsed by default: the card lists only the method that is actually
  /// selected until "See All" is tapped, rather than every option at once.
  bool _showAllPaymentMethods = false;

  /// Collapsed by default too — the header's chevron opens the bill breakdown.
  bool _showBillBreakdown = false;

  /// Maps UI payment selection to backend enum (razorpay | wallet | cash)
  String get _paymentMethod => switch (_selectedPaymentMethodIndex) {
    3 => 'wallet',
    4 => 'cash',
    _ => 'razorpay',
  };

  AddressModel? _defaultAddress() {
    final addresses = ref.watch(addressViewModelProvider);
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.isNotEmpty ? addresses.last : null;
  }

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

  Future<void> _placeOrder(BuildContext context) async {
    Haptics.medium();

    final cart = ref.read(cartViewModelProvider);
    if (cart.items.isEmpty) {
      _toast('Your cart is empty.');
      return;
    }

    final address = _defaultAddress();
    if (address == null) {
      _toast('Add a delivery address to continue.');
      if (mounted) context.push(RouteNames.addAddress);
      return;
    }

    final user = ref.read(authViewModelProvider).value;
    final router = GoRouter.of(context);

    setState(() => _isPlacingOrder = true);
    try {
      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .payAndPlaceOrder(
            address: address.toOrderPayload(customerName: user?.displayName),
            restaurantName: '',
            paymentMethod: _paymentMethod,
          );

      if (!mounted) return;
      _toast(result.message);

      if (result.isPlaced && (result.orderId ?? '').isNotEmpty) {
        router.push('/orders/details/${result.orderId}');
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
            _buildTopHeader(context, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // 2. Delivery Address Card
                    _buildDeliveryAddressCard(context, isDark),

                    const SizedBox(height: 16),

                    // 3. Order Summary Card
                    _buildOrderSummaryCard(context, isDark),

                    const SizedBox(height: 16),

                    // 3b. Tip Your Delivery Partner Card
                    _buildTipCard(context, isDark),

                    const SizedBox(height: 16),

                    // 4. Payment Methods Card
                    _buildPaymentMethodsCard(context, isDark),

                    const SizedBox(height: 16),

                    // 5. 100% Secure Payments Banner
                    _buildSecurePaymentsCard(isDark),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 6. Bottom Sticky Checkout Footer Bar
            _buildBottomCheckoutBar(context, isDark),
          ],
        ),
      ),
    );
  }

  /// 1. Top Header Row
  Widget _buildTopHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Circular Cyan Back Button
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review your order and place it',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Delivery Address Card
  Widget _buildDeliveryAddressCard(BuildContext context, bool isDark) {
    final address = _defaultAddress();
    final distanceKm = ref
        .watch(checkoutViewModelProvider)
        .pricing
        ?.roadDistanceKm;
    final eta =
        _restaurantFor(
          ref.watch(cartViewModelProvider).restaurantId,
        )?.deliveryTime ??
        '';

    final String addressLabel = (address?.type.isNotEmpty == true)
        ? (address!.type[0].toUpperCase() +
              address.type.substring(1).toLowerCase())
        : 'Home';

    final String fullAddressStr = (address?.fullAddress.isNotEmpty == true)
        ? address!.fullAddress
        : '302, Noor Apartment, Kausa Mumbra, Thane - 400612, Maharashtra';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.addAddress);
                },
                child: Row(
                  children: [
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Address Details
          Padding(
            padding: const EdgeInsets.only(left: 46.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addressLabel,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0C4A6E)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fullAddressStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Delivery Instructions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Inner Sub-Banner: Delivering to Home • 2.6 km away
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4FAF9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bike_rounded,
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
                        'Delivering to $addressLabel • ${distanceKm != null ? distanceKm.toStringAsFixed(1) : "2.6"} km away',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        eta.isNotEmpty
                            ? 'Estimated delivery in $eta'
                            : 'Estimated delivery in 25–35 mins',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
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

  /// 3. Order Summary Card
  Widget _buildOrderSummaryCard(BuildContext context, bool isDark) {
    final cartCount = ref.watch(cartViewModelProvider).totalQuantity;
    // Real count only — this used to fall back to a literal "4 Items".
    final String itemsText = '$cartCount ${cartCount == 1 ? 'Item' : 'Items'}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(() => _showBillBreakdown = !_showBillBreakdown);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      itemsText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showBillBreakdown
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bill Details List
          Builder(
            builder: (context) {
              final checkout = ref.watch(checkoutViewModelProvider);
              final p = checkout.pricing;

              // No server bill: say so. This used to fall back to hardcoded
              // numbers, so a rejected cart (restaurant closed, out of range)
              // showed a complete bill and only failed at "Place Order".
              if (p == null) {
                return _billUnavailable(context, ref, checkout, isDark);
              }

              final double itemTotal = p.subtotal;
              final double deliveryFee = p.deliveryFee;
              final double packagingFee = p.packagingFee;
              final double total = p.total;

              return Column(
                children: [
                  // Collapsed, the card shows only what's payable; the
                  // per-charge breakdown opens from the header chevron.
                  if (_showBillBreakdown) ...[
                    _billRow('Item Total', itemTotal, isDark),
                    const SizedBox(height: 6),
                    _billRow('Delivery Fee', deliveryFee, isDark, info: true),
                    const SizedBox(height: 6),
                    _billRow('Packaging Fee', packagingFee, isDark, info: true),
                    // These were missing entirely, so the rows summed to less
                    // than "To Pay" — a ₹15 gap on a ₹255 bill with no
                    // explanation. Every charge the server applies gets a line.
                    if (p.quickDeliveryFee > 0) ...[
                      const SizedBox(height: 6),
                      _billRow(
                        'Express Delivery',
                        p.quickDeliveryFee,
                        isDark,
                        info: true,
                      ),
                    ],
                    if (p.deliveryFeeGst > 0) ...[
                      const SizedBox(height: 6),
                      _billRow(
                        'Delivery GST',
                        p.deliveryFeeGst,
                        isDark,
                        info: true,
                      ),
                    ],
                    if (p.platformFee > 0) ...[
                      const SizedBox(height: 6),
                      _billRow(
                        'Platform Fee',
                        p.platformFee,
                        isDark,
                        info: true,
                      ),
                    ],
                    if (p.tax > 0) ...[
                      const SizedBox(height: 6),
                      _billRow(
                        p.gstRate > 0
                            ? 'GST (${p.gstRate.toStringAsFixed(p.gstRate % 1 == 0 ? 0 : 1)}%)'
                            : 'GST',
                        p.tax,
                        isDark,
                        info: true,
                      ),
                    ],
                    if (p.tip > 0) ...[
                      const SizedBox(height: 6),
                      _billRow('Tip for delivery partner', p.tip, isDark),
                    ],
                    if (p.discount > 0) ...[
                      const SizedBox(height: 6),
                      _billRow(
                        'Discount',
                        -p.discount,
                        isDark,
                        highlight: true,
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Dashed horizontal line separator
                    CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DashedHorizontalLinePainter(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'To Pay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Why the attached coupon isn't coming off, beside the total
                  // it would have changed — "Add ₹149 more" is only useful
                  // where the customer can see what they'd be adding to.
                  if (p.hasCouponError) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(
                            0xFFEA580C,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 14,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.couponErrorMessage!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C2D12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Inner Promocodes Box
          GestureDetector(
            onTap: () {
              Haptics.light();
              CouponSheet.show(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFE6F7F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.3 : 0.2,
                  ),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.percent_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Promocodes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Apply code & save more',
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tip presets from the admin, straight from `GET /food/tips/config`. No
  /// section at all when the config failed to load or tipping is off — see
  /// [tipConfigProvider].
  Widget _buildTipCard(BuildContext context, bool isDark) {
    final configAsync = ref.watch(tipConfigProvider);
    final config = configAsync.asData?.value;
    if (config == null || !config.enabled || config.presets.isEmpty) {
      return const SizedBox.shrink();
    }

    final tipAmount = ref.watch(checkoutViewModelProvider).tipAmount;
    final isCustom =
        tipAmount > 0 && !config.presets.contains(tipAmount.toInt());
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tip your delivery partner',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Goes to them in full, on top of their delivery earning',
            style: TextStyle(
              fontSize: 11.5,
              color: muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in config.presets)
                ChoiceChip(
                  label: Text('₹$amount'),
                  selected: tipAmount == amount.toDouble(),
                  onSelected: (_) {
                    Haptics.light();
                    ref
                        .read(checkoutViewModelProvider.notifier)
                        .setTip(
                          tipAmount == amount.toDouble()
                              ? 0
                              : amount.toDouble(),
                        );
                  },
                ),
              ActionChip(
                label: Text(
                  isCustom ? '₹${tipAmount.toStringAsFixed(0)}' : 'Custom',
                ),
                onPressed: () => _showCustomTipDialog(context, config),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomTipDialog(
    BuildContext context,
    TipConfig config,
  ) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a custom tip'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: InputDecoration(
            prefixText: '₹ ',
            helperText: config.maxAmount != null
                ? 'Up to ₹${config.maxAmount!.toStringAsFixed(0)}'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? 0;
              if (value <= 0) return;
              if (config.maxAmount != null && value > config.maxAmount!) {
                AppSnackbar.error(
                  dialogContext,
                  'The most you can add is ₹${config.maxAmount!.toStringAsFixed(0)}',
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount != null && mounted) {
      ref.read(checkoutViewModelProvider.notifier).setTip(amount);
    }
  }

  /// Stands in for the bill rows when the server has not priced this cart.
  ///
  /// Occupies the same slot as the rows so the card keeps its shape, and shows
  /// the server's own reason — "Restaurant is currently closed", "…only
  /// delivers within 4 km" — because that is the part the user can act on.
  Widget _billUnavailable(
    BuildContext context,
    WidgetRef ref,
    CheckoutState checkout,
    bool isDark,
  ) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (checkout.isCalculating) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: muted),
          ),
          const SizedBox(width: 8),
          Text(
            'Calculating your bill...',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          checkout.error ?? 'Bill unavailable right now.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Haptics.light();
            ref.read(checkoutViewModelProvider.notifier).recalculate();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _billRow(
    String label,
    double amount,
    bool isDark, {
    bool info = false,
    bool highlight = false,
  }) {
    final negative = amount < 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (info) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ],
        ),
        Text(
          '${negative ? '-' : ''}₹${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: highlight
                ? const Color(0xFF16A34A)
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  /// 4. Payment Methods Card
  Widget _buildPaymentMethodsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : const Color(0xFFE6F7F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Payment Methods',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(
                    () => _showAllPaymentMethods = !_showAllPaymentMethods,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      _showAllPaymentMethods ? 'Show Less' : 'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showAllPaymentMethods
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Collapsed, only the chosen method is listed — which is UPI until
          // the customer picks another, so they are not made to scan five
          // options to pay the usual way.
          for (final index
              in _showAllPaymentMethods
                  ? const [0, 1, 2, 3, 4]
                  : [_selectedPaymentMethodIndex]) ...[
            _paymentOption(index, isDark),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// One payment method by its selection index, so the card can render either
  /// just the selected one or the full list from the same definitions.
  Widget _paymentOption(int index, bool isDark) {
    return switch (index) {
      1 => _buildPaymentOptionRow(
        index: 1,
        icon: Icons.credit_card_rounded,
        title: 'Credit / Debit Card',
        subtitle: 'Visa, Mastercard, Rupay & more',
        recommendedTag: null,
        logos: const ['VISA', 'Mastercard', 'RuPay'],
        handlingFeeTag: null,
        isDark: isDark,
      ),
      2 => _buildPaymentOptionRow(
        index: 2,
        icon: Icons.account_balance_rounded,
        title: 'Net Banking',
        subtitle: 'Pay using your preferred bank',
        recommendedTag: null,
        logos: null,
        handlingFeeTag: null,
        isDark: isDark,
      ),
      3 => _buildPaymentOptionRow(
        index: 3,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Wallets',
        subtitle: 'PhonePe, Paytm, Amazon Pay & more',
        recommendedTag: null,
        logos: const ['Paytm', 'PhonePe', 'Amazon Pay'],
        handlingFeeTag: null,
        isDark: isDark,
      ),
      4 => _buildPaymentOptionRow(
        index: 4,
        icon: Icons.payments_outlined,
        title: 'Cash on Delivery',
        subtitle: 'Pay in cash when your order arrives',
        recommendedTag: null,
        logos: null,
        handlingFeeTag: '₹20 Handling Fee',
        isDark: isDark,
      ),
      _ => _buildPaymentOptionRow(
        index: 0,
        icon: Icons.account_balance_rounded,
        title: 'UPI',
        subtitle: 'Pay easily using any UPI app',
        recommendedTag: 'Recommended',
        logos: null,
        handlingFeeTag: null,
        isDark: isDark,
      ),
    };
  }

  Widget _buildPaymentOptionRow({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    String? recommendedTag,
    List<String>? logos,
    String? handlingFeeTag,
    required bool isDark,
  }) {
    final isSelected = _selectedPaymentMethodIndex == index;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        setState(() => _selectedPaymentMethodIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFE6F7F5))
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1)),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 10),

            // Icon Box
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              size: 20,
            ),

            const SizedBox(width: 10),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
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
                ],
              ),
            ),

            // Right Tag or Brand Badges
            if (recommendedTag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C4A6E)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  recommendedTag,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                  ),
                ),
              )
            else if (handlingFeeTag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C4A6E)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  handlingFeeTag,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                  ),
                ),
              )
            else if (logos != null)
              Row(
                children: logos.map((l) {
                  return Container(
                    margin: const EdgeInsets.only(left: 4.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(width: 6),
            Icon(
              isSelected
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.chevron_right_rounded,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8)),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// 5. 100% Secure Payments Banner Card
  Widget _buildSecurePaymentsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.verified_user_rounded,
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
                  '100% Secure Payments',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Your payment details are safe with us',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Powered by Razorpay',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'PCI DSS COMPLIANT',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 6. Bottom Sticky Checkout Footer Bar
  Widget _buildBottomCheckoutBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To Pay',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final total = ref
                          .watch(checkoutViewModelProvider)
                          .pricing
                          ?.total;
                      return Text(
                        total == null ? '--' : '₹${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 1),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),

              // Place Order Button
              GestureDetector(
                onTap: _isPlacingOrder ? null : () => _placeOrder(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  decoration: BoxDecoration(
                    color: _isPlacingOrder
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isPlacingOrder
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Place Order',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final discount =
                  ref.watch(checkoutViewModelProvider).pricing?.discount ?? 0;
              if (discount <= 0) return const SizedBox.shrink();
              return Text(
                'You will save ₹${discount.toStringAsFixed(0)} on this order',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom Dashed Horizontal Line Painter for Order Summary
class _DashedHorizontalLinePainter extends CustomPainter {
  final Color color;

  _DashedHorizontalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double dashWidth = 4, dashSpace = 3, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
