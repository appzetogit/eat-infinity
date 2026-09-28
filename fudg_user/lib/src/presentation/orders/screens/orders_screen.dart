import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../utils/reorder.dart';
import '../viewmodels/orders_viewmodel.dart';
import '../widgets/rate_order_sheet.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  int _selectedFilterIndex = 0; // 0: All Orders, 1: Ongoing, 2: Delivered, 3: Cancelled, 4: Returned
  String? _reorderingOrderId;

  Future<void> _handleReorder(BuildContext context, OrderModel order) async {
    if (_reorderingOrderId != null) return;
    final allowed = await ensureCartRestaurant(
      context,
      ref,
      order.restaurantId,
    );
    if (!allowed || !context.mounted) return;

    Haptics.medium();
    setState(() => _reorderingOrderId = order.id);
    try {
      final items = await resolveReorderItems(ref, order);
      if (!context.mounted) return;
      final cartNotifier = ref.read(cartViewModelProvider.notifier);
      for (final item in items) {
        cartNotifier.addItem(
          item.food,
          quantity: item.quantity,
          selectedVariant: item.selectedVariant,
          selectedVariantPrice: item.selectedVariantPrice,
          selectedAddons: item.selectedAddons,
          selectedAddonsPrice: item.selectedAddonsPrice,
        );
      }
      context.push(RouteNames.cart);
    } finally {
      if (mounted) {
        setState(() => _reorderingOrderId = null);
      }
    }
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
              // 1. Top Header Row: Back button, Title, Search & Filter icons
              _buildTopHeader(context),

              const SizedBox(height: 8),

              // 2. Horizontal Filter Status Tabs (Pills)
              _buildFilterTabs(),

              const SizedBox(height: 12),

              Expanded(child: _buildOrdersBody(context, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  /// Orders Body: strictly NO loading indicator / spinner per user requirement.
  /// Shows real backend orders grouped by date or a clean simple text state if empty.
  Widget _buildOrdersBody(BuildContext context, bool isDark) {
    final state = ref.watch(ordersViewModelProvider);

    final filteredOrders = _applyFilter(state.orders);

    // An empty list has three very different causes, and saying "No orders yet"
    // for all of them tells signed-out users and users hitting a failed request
    // something untrue about their own history.
    if (filteredOrders.isEmpty) {
      if (ref.watch(authViewModelProvider).value == null) {
        return _buildSimpleEmptyState(
          context,
          title: 'Sign in to see your orders',
          message: 'Your order history is tied to your account.',
          actionLabel: 'Sign In',
          onAction: () => context.push(RouteNames.login),
        );
      }
      if (state.error != null) {
        return _buildSimpleEmptyState(
          context,
          title: "Couldn't load your orders",
          message: state.error!,
          actionLabel: 'Retry',
          onAction: () =>
              ref.read(ordersViewModelProvider.notifier).refresh(),
        );
      }
      return _buildSimpleEmptyState(context);
    }

    // Compute total savings from coupons & rewards across all orders
    final double totalSavings = state.orders.fold(
      0.0,
      (sum, o) => sum + o.couponDiscount + o.rewardDiscount,
    );

    // Group orders by day label (Today, Yesterday, 26 May 2025, etc.)
    final groups = <String, List<OrderModel>>{};
    for (final o in filteredOrders) {
      groups.putIfAbsent(_dayLabel(o.createdAt), () => []).add(o);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3. Savings Summary Card (Only shown if user has real savings > 0)
            if (totalSavings > 0) ...[
              _buildSavingsSummaryCard(context, totalSavings),
              const SizedBox(height: 16),
            ],

            // Date Group Headers & Order Cards
            for (final entry in groups.entries) ...[
              _buildSectionHeader(entry.key, isDark),
              const SizedBox(height: 10),
              for (final o in entry.value) ...[
                _buildOrderCardFor(context, o, isDark),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 6),
            ],

            const SizedBox(height: 8),

            // 5. End of Orders History Footer Card
            if (!state.hasMore)
              _buildEndOfHistoryCard(),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  /// 1. Top Header Row (Centered Title in Expanded, Back button, Search & Filter icons)
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // Circular Back Button
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

          // Title Centered in Expanded
          const Expanded(
            child: Center(
              child: Text(
                'Order History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // Search & Filter Action Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.search);
                },
                child: const Icon(Icons.search_rounded, color: Color(0xFFF41222), size: 22),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                },
                child: const Icon(Icons.tune_rounded, color: Color(0xFFF41222), size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Horizontal Filter Status Tabs
  Widget _buildFilterTabs() {
    final filters = ['All Orders', 'Ongoing', 'Delivered', 'Cancelled', 'Returned'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _selectedFilterIndex = index);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF41222) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFF41222) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Text(
                filters[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 3. Total Savings Summary Banner Card
  Widget _buildSavingsSummaryCard(BuildContext context, double totalSavings) {
    if (totalSavings <= 0) return const SizedBox.shrink();

    final savingsStr = '₹${totalSavings.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF41222).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF41222).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFF41222), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You've saved $savingsStr so far!",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Thanks for choosing Eatinfinity 💚',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Haptics.light();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF41222), width: 1.2),
              ),
              child: const Text(
                'View Savings',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
    );
  }

  /// Order Card Builder from OrderModel data
  Widget _buildOrderCardFor(BuildContext context, OrderModel o, bool isDark) {
    final itemCount = o.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final cuisineText = o.items.isNotEmpty
        ? o.items.map((i) => i.name).join(', ')
        : 'Food Items';

    // Only the customer's own rating of this order. It used to fall back to
    // the restaurant's public average, which the card then labelled "You
    // rated" — a rating the customer never gave.
    final ratingVal = o.foodRating > 0 ? o.foodRating : null;

    return _buildOrderCard(
      context,
      order: o,
      isDark: isDark,
      restaurantName: o.restaurantName,
      cuisine: cuisineText,
      orderId: o.orderNumber.isNotEmpty ? o.orderNumber : o.id,
      timeMeta: '${_time(o.createdAt)}  •  $itemCount Item${itemCount == 1 ? '' : 's'}  •  ₹${o.total.toStringAsFixed(0)}',
      rating: ratingVal?.toStringAsFixed(1),
      orderStatus: o.orderStatus,
      statusLabel: o.statusLabel,
      deliveredTime: _time(o.deliveredAt ?? o.createdAt),
      imageUrl: o.restaurantImage,
    );
  }

  /// Single Order Card Matching Screenshot Design
  Widget _buildOrderCard(
    BuildContext context, {
    required OrderModel order,
    required bool isDark,
    required String restaurantName,
    required String cuisine,
    required String orderId,
    required String timeMeta,
    required String? rating,
    required String orderStatus,
    required String statusLabel,
    required String deliveredTime,
    required String imageUrl,
  }) {
    final isDelivered = orderStatus == 'delivered';
    final isCancelled = orderStatus.startsWith('cancelled');

    Color badgeBgColor;
    Color badgeTextColor;
    IconData badgeIcon;

    if (isDelivered) {
      badgeBgColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF15803D);
      badgeIcon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      badgeBgColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFB91C1C);
      badgeIcon = Icons.cancel_rounded;
    } else {
      badgeBgColor = const Color(0xFFE6F7F5);
      badgeTextColor = const Color(0xFFF41222);
      badgeIcon = Icons.two_wheeler_rounded;
    }

    final isReordering = _reorderingOrderId == order.id;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        context.push('/orders/details/$orderId');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Restaurant Image (72x72)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: SmartImage(
                      url: imageUrl,
                      category: ImageCategory.restaurant,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Middle Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        cuisine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderId,
                        // Unconstrained, this wrapped "FOD-4155844579" across
                        // two lines inside a narrow 72px space, pushing down
                        // the card's height and eating up padding.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Right Status Badge Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeTextColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: badgeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDelivered
                              ? 'Delivered on\n$deliveredTime'
                              : (isCancelled ? 'Cancelled on\n$deliveredTime' : deliveredTime),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500, height: 1.1),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Full-width prompt to rate, on delivered orders not yet rated.
            // Ratings are only accepted on delivered orders, and only once, so
            // this disappears for good once it has been used.
            if (isDelivered && rating == null) ...[
              GestureDetector(
                onTap: () async {
                  Haptics.light();
                  final rated = await RateOrderSheet.show(context, order);
                  if (rated == true && context.mounted) {
                    ref
                        .read(ordersViewModelProvider.notifier)
                        .refresh(isRefresh: true);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFCF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.star_rounded, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rate your food & delivery experience',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF16A34A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Bottom Actions Row: Rating Pill & Reorder Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (rating != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_border_rounded, size: 13, color: Color(0xFFF41222)),
                        const SizedBox(width: 3),
                        const Flexible(
                          child: Text(
                            'You rated',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF41222)),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                        ),
                      ],
                    ),
                  )
                // No "Rate Order" link here — the full-width prompt above
                // already offers it, and two entry points on one card read as
                // two different actions.
                else
                  const SizedBox.shrink(),

                GestureDetector(
                  onTap: isReordering ? null : () => _handleReorder(context, order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF41222), width: 1.2),
                    ),
                    child: isReordering
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF41222),
                            ),
                          )
                        : Row(
                            children: const [
                              Icon(Icons.autorenew_rounded, size: 13, color: Color(0xFFF41222)),
                              SizedBox(width: 4),
                              Text(
                                'Reorder',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 5. End of Orders History Footer Card
  Widget _buildEndOfHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF41222).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text(
                  "That's all your orders!",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  "You've reached the end of your order history.",
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF41222).withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFF41222), size: 18),
          ),
        ],
      ),
    );
  }

  /// Simple Text Empty State when no orders exist (NO loader/spinner shown)
  Widget _buildSimpleEmptyState(
    BuildContext context, {
    String? title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF41222).withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 28, color: Color(0xFFF41222)),
            ),
            const SizedBox(height: 14),
            Text(
              title ??
                  (_selectedFilterIndex == 0
                      ? 'No orders yet'
                      : 'No orders in this status'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message ??
                  (_selectedFilterIndex == 0
                      ? 'Your order history will show up here once you place an order.'
                      : 'Try selecting a different order status filter.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            if (actionLabel != null || _selectedFilterIndex == 0) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onAction ?? () => context.go(RouteNames.home),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF41222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel ?? 'Browse Restaurants',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<OrderModel> _applyFilter(List<OrderModel> all) {
    switch (_selectedFilterIndex) {
      case 1: // Ongoing
        return all.where((o) => o.isActive).toList();
      case 2: // Delivered
        return all.where((o) => o.orderStatus == 'delivered').toList();
      case 3: // Cancelled
        return all.where((o) => o.orderStatus.startsWith('cancelled')).toList();
      case 4: // Returned
        return all.where((o) => o.orderStatus == 'returned').toList();
      default:
        return all;
    }
  }

  String _dayLabel(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  String _time(DateTime? at) {
    if (at == null) return '';
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour >= 12 ? 'PM' : 'AM'}';
  }
}
