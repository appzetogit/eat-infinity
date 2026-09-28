import 'package:flutter/material.dart';
import '../../data/models/delivery_order.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

/// The incoming-order alert card matching the design specification.
///
/// Deliberately free of Riverpod, ScreenUtil and plugins: rendered by both the
/// in-app [IncomingOrderScreen] and background overlay engine.
class IncomingOrderCard extends StatelessWidget {
  const IncomingOrderCard({
    super.key,
    required this.order,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    this.etaMins,
    this.busy = false,
  });

  final DeliveryOrder order;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final double? etaMins;
  final bool busy;

  static const Color _tealPrimary = AppColors.primary;
  static const Color _tealHeader = AppColors.primaryDark;
  static const Color _tealBgLight = AppColors.primaryLight;
  static const Color _darkText = AppColors.lightTextPrimary;
  static const Color _subtitleColor = AppColors.lightTextSecondary;
  static const Color _borderColor = AppColors.lightBorder;
  static const Color _yellowBg = Color(0xFFFFFBEB);

  /// Placeholder for a figure the offer payload did not carry. Never a
  /// plausible-looking number: a rider deciding in 20 seconds must be able to
  /// tell "no data" from "small trip".
  static const String _unknown = '—';

  String get _etaLabel {
    final mins = etaMins ?? order.tripDurationMins;
    if (mins == null || mins <= 0) return _unknown;
    return '${mins.round()} min';
  }

  static String _km(double? value) => (value == null || value <= 0)
      ? _unknown
      : '${value.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final fraction = totalSeconds <= 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

    // Everything below comes off the offer itself. It previously fell back to
    // a sample order — a named store, a named customer, an address and a
    // ₹68.00 earning — whenever a field was missing, which meant a rider could
    // accept on a figure the backend never sent.
    final restaurantName =
        order.store.name.isNotEmpty ? order.store.name : 'Pickup store';
    final restaurantAddr = order.store.address.isNotEmpty
        ? order.store.address
        : 'Address not provided';

    final customerName =
        order.customerName.isNotEmpty ? order.customerName : 'Customer';
    final customerAddr = order.deliveryAddress.fullAddress.isNotEmpty
        ? order.deliveryAddress.fullAddress
        : 'Address not provided';

    final totalEarning = order.riderEarning;
    final orderTotal = order.total;
    final collectCash = order.paymentMethod.toLowerCase() == 'cash';

    final itemsCount = order.items.length;
    final notes = order.deliveryInstructions?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. TOP CURVED TEAL HEADER WITH TIMER DIAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                color: _tealHeader,
              ),
              child: Column(
                children: [
                  // Top Speaker Icon + Title + Subtitle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: const [
                            Text(
                              'New Order!',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '1 Rider = 1 Order',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30), // Spacer balancing left icon
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Circular Progress Countdown Dial
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: fraction,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            color: Colors.white,
                            strokeWidth: 6,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$secondsLeft',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _tealHeader,
                              ),
                            ),
                            const Text(
                              'sec',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _tealHeader,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Please respond quickly',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 2. MAIN DETAILS BODY CONTAINER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // PICKUP FROM ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Black/Gold Chef Hat Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.soup_kitchen_rounded,
                          color: Color(0xFFFFB800),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PICKUP FROM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _tealPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    restaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: _tealPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              restaurantAddr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Phone Call Action Button
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _tealBgLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          size: 18,
                          color: _tealPrimary,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: _borderColor, height: 1),
                  ),

                  // DELIVER TO ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Teal Avatar with User Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: _tealBgLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: _tealPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELIVER TO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _tealPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customerAddr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Phone Call Action Button
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _tealBgLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          size: 18,
                          color: _tealPrimary,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: _borderColor, height: 1),
                  ),

                  // TRIP METRICS GRID (3 Columns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Distance
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: _tealBgLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.alt_route_rounded,
                                size: 16,
                                color: _tealPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _km(order.tripDistanceKm),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Distance',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Column 2: Estimated Time
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: _tealBgLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: _tealPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _etaLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Estimated Time',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Column 3: Total Earning
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: _tealBgLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.currency_rupee_rounded,
                                    size: 16,
                                    color: _tealPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Flexible: at 320px this column is ~95px
                                // wide and the label overflowed it by 90px.
                                const Flexible(
                                  child: Text(
                                    'Total Earning ⓘ',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: _subtitleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalEarning > 0
                                  ? '₹${totalEarning.toStringAsFixed(2)}'
                                  : _unknown,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: _tealPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Order value, and what has to be collected on
                            // delivery. Replaces a base-fare/tip split that
                            // was invented client-side as 70%/30% of the
                            // earning — the backend sends neither figure.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _tealBgLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    orderTotal > 0
                                        ? '₹${orderTotal.toStringAsFixed(2)}'
                                        : _unknown,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _tealPrimary,
                                    ),
                                  ),
                                  const Text(
                                    'Order Value',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w500,
                                      color: _subtitleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    collectCash && orderTotal > 0
                                        ? '₹${orderTotal.toStringAsFixed(2)}'
                                        : '₹0.00',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _tealPrimary,
                                    ),
                                  ),
                                  Text(
                                    collectCash ? 'Collect Cash' : 'Prepaid',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w500,
                                      color: _subtitleColor,
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

                  const SizedBox(height: 12),

                  // ORDER ITEMS ROW
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _tealBgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: _tealPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Items',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              Text(
                                itemsCount > 0
                                    ? '$itemsCount ${itemsCount == 1 ? 'Item' : 'Items'}'
                                    : _unknown,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'View Details >',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _tealPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // SPECIAL INSTRUCTIONS BOX — only when the customer left
                  // any. It used to render "Please ring the bell. Don't call."
                  // on every order that carried no instructions.
                  if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _yellowBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Special Instructions',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notes,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],

                  const SizedBox(height: 16),

                  // BOTTOM ACTION BUTTONS ROW (Decline & Accept)
                  Row(
                    children: [
                      // Decline Button
                      Expanded(
                        flex: 4,
                        child: InkWell(
                          onTap: onReject,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF04438),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEE4E2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFFF04438),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Decline',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFF04438),
                                        ),
                                      ),
                                      // Wrapped rather than fixed-height: the
                                      // pair overflowed the 54px button by
                                      // 31px once the text wrapped at 320px.
                                      Text(
                                        'Lose this order',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: _subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Accept Order Button (Swipe / Tap)
                      Expanded(
                        flex: 6,
                        child: InkWell(
                          onTap: onAccept,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _tealPrimary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _tealPrimary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: _tealPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Accept Order',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Slide to accept',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Footer Security Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: _tealPrimary,
                      ),
                      SizedBox(width: 4),
                      // Flexible: this single line is wider than a 320px
                      // screen and overflowed the card by 272px.
                      Flexible(
                        child: Text(
                          'Safe delivery. Happy customers. Better earnings.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _subtitleColor,
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
}

/// Shown for a beat after the countdown runs out.
class IncomingOrderExpiredCard extends StatelessWidget {
  const IncomingOrderExpiredCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_off_rounded, size: 40, color: Color(0xFFF04438)),
          SizedBox(height: 12),
          Text(
            'Order expired',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'This order has been offered to another partner.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
