import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';
import '../../chat/screens/chat_screen.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/order_tracking_viewmodel.dart';
import '../widgets/live_tracking_map.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _navigatedToDelivered = false;

  @override
  void initState() {
    super.initState();
    // Opens the socket tracking room, fetches the order + route, and starts
    // the rider position stream. Deferred so it runs after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderTrackingProvider.notifier).start(widget.orderId);
    });
  }

  /// Once the order flips to delivered, replace this screen with the rating
  /// screen — `go` (not `push`) so there is nothing stale left to pop back to.
  void _maybeGoToDelivered(OrderModel? order) {
    if (_navigatedToDelivered || order == null || !order.isDelivered) return;
    _navigatedToDelivered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/orders/delivered/${widget.orderId}');
    });
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $cleanPhone')),
        );
      }
    }
  }

  String _formatTime(DateTime? at) {
    if (at == null) return '—';
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final period = at.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _formatDate(DateTime? at) {
    if (at == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day.toString().padLeft(2, '0')} ${months[at.month - 1]} ${at.year}';
  }

  String _formatDeliveryWindow(OrderModel? order) {
    if (order == null) return '—';
    if (order.deliveredAt != null) {
      return 'Delivered at ${_formatTime(order.deliveredAt)}';
    }
    if (order.createdAt != null && order.eta.minutes != null && order.eta.minutes! > 0) {
      final start = order.createdAt!.add(Duration(minutes: (order.eta.minutes! - 5).clamp(1, 1000)));
      final end = order.createdAt!.add(Duration(minutes: order.eta.minutes! + 5));
      return '${_formatTime(start)} – ${_formatTime(end)}';
    }
    return '15 – 30 mins';
  }

  int _getStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'created':
      case 'placed':
      case 'pending':
      case 'confirmed':
        return 0;
      case 'preparing':
        return 1;
      case 'ready_for_pickup':
      case 'reached_pickup':
      case 'picked_up':
      case 'out_for_delivery':
      case 'en_route_to_delivery':
      case 'reached_drop':
      case 'at_drop':
        return 2;
      case 'delivered':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _maybeGoToDelivered(ref.watch(orderTrackingProvider).order);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Back button, Title, Support Headset Icon
            _buildTopHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // 2. Main Status Header ("Your order is on the way!" + ETA Box)
                    _buildMainStatusHeader(),

                    const SizedBox(height: 16),

                    // 2b. Handover OTP, once the rider has the order
                    _buildHandoverOtpCard(),

                    // 3. Dynamic Step Tracker Stepper Card
                    _buildStepTrackerCard(),

                    const SizedBox(height: 16),

                    // 4. Live Status Announcement Banner
                    _buildAnnouncementBanner(),

                    const SizedBox(height: 16),

                    // 5. Live GPS Tracking Map Card
                    _buildLiveTrackingMapCard(),

                    const SizedBox(height: 16),

                    // 6. Delivery Partner Card
                    _buildDeliveryPartnerCard(context),

                    const SizedBox(height: 16),

                    // 7. Restaurant Details & Order ID Card
                    _buildRestaurantDetailsCard(context),

                    const SizedBox(height: 16),

                    // 8. Estimated Delivery Time & Need Help Card
                    _buildEstimatedDeliveryCard(context),

                    const SizedBox(height: 16),

                    // 9. Savings Highlight Banner Card (rendered only when savings > 0)
                    _buildSavingsCard(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top Navigation Header Row
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            ),
          ),

          const Text(
            'Order Tracking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

          // Support Headset Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(
                RouteNames.chat,
                extra: ChatArgs(orderId: widget.orderId, peerName: 'Support', peerRole: 'ADMIN'),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Main Status Header
  Widget _buildMainStatusHeader() {
    final t = ref.watch(orderTrackingProvider);
    final order = t.order;
    final headline = order?.statusLabel ?? 'Tracking your order…';
    final etaMinutes = order?.eta.minutes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order == null
                    ? 'Fetching the latest update…'
                    : (order.isDelivered
                        ? 'Your order has been delivered successfully.'
                        : 'Sit tight, your delicious food is on the way.'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            children: [
              Icon(Icons.access_time_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order?.isDelivered == true ? 'Status' : 'Arriving in',
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    order?.isDelivered == true
                        ? 'Done'
                        : (etaMinutes != null ? '$etaMinutes mins' : '—'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 3. Dynamic Step Tracker Stepper Card
  Widget _buildStepTrackerCard() {
    final order = ref.watch(orderTrackingProvider).order;
    final status = order?.orderStatus ?? 'created';
    final activeStep = _getStepIndex(status);

    final historyMap = <String, DateTime>{};
    if (order != null) {
      for (final event in order.statusHistory) {
        if (event.at != null) {
          historyMap[event.to.toLowerCase()] = event.at!;
        }
      }
    }

    final step0Time = _formatTime(order?.createdAt);
    final step1Time = _formatTime(historyMap['preparing']);
    final step2Time = _formatTime(historyMap['picked_up'] ?? historyMap['out_for_delivery']);
    final step3Time = _formatTime(order?.deliveredAt ?? historyMap['delivered']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Step 1: Confirmed
          _buildTrackerStep(
            icon: Icons.check,
            isCompleted: activeStep > 0,
            isActive: activeStep == 0,
            title: 'Confirmed',
            time: step0Time,
          ),

          _buildDashedConnector(isCompleted: activeStep > 0),

          // Step 2: Preparing
          _buildTrackerStep(
            icon: Icons.restaurant_rounded,
            isCompleted: activeStep > 1,
            isActive: activeStep == 1,
            title: 'Preparing',
            time: step1Time != '—' ? step1Time : (activeStep >= 1 ? 'Active' : '—'),
          ),

          _buildDashedConnector(isCompleted: activeStep > 1),

          // Step 3: Out for Delivery
          _buildTrackerStep(
            icon: Icons.two_wheeler_rounded,
            isCompleted: activeStep > 2,
            isActive: activeStep == 2,
            title: 'On the Way',
            time: step2Time != '—' ? step2Time : (activeStep >= 2 ? 'Active' : '—'),
          ),

          _buildDashedConnector(isCompleted: activeStep > 2),

          // Step 4: Delivered
          _buildTrackerStep(
            icon: Icons.task_alt_rounded,
            isCompleted: activeStep == 3,
            isActive: false,
            title: 'Delivered',
            time: step3Time,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerStep({
    required IconData? icon,
    required bool isCompleted,
    required bool isActive,
    required String title,
    required String time,
  }) {
    // Flexible rather than a fixed 72: four steps at 72 plus their connectors
    // came to more than a narrow screen has, so the row overflowed outright on
    // small devices instead of simply drawing tighter.
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? const Color(0xFF16A34A)
                  : isActive
                      ? Colors.white
                      : const Color(0xFFE2E8F0),
              border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : isActive
                      ? Icon(icon ?? Icons.two_wheeler_rounded, color: AppColors.primary, size: 18)
                      : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive || isCompleted ? FontWeight.w900 : FontWeight.w500,
              color: isActive || isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedConnector({required bool isCompleted}) {
    // Fixed now that the steps themselves flex — two Expanded siblings
    // competing for the same row is what left no room for either.
    return SizedBox(
      width: 14,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 2,
        child: CustomPaint(
          painter: _HorizontalDashedLinePainter(
            color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  /// 4. Live Status Announcement Banner Box
  Widget _buildAnnouncementBanner() {
    final order = ref.watch(orderTrackingProvider).order;

    String bannerTitle = 'Order in progress';
    String bannerSubtitle = 'We are tracking your order status.';
    String emoji = '🛵';

    if (order != null) {
      if (order.isDelivered) {
        bannerTitle = 'Order Delivered! 🎉';
        bannerSubtitle = 'Enjoy your delicious meal from ${order.restaurantName}.';
        emoji = '🎉';
      } else if (order.isOutForDelivery) {
        bannerTitle = 'Yay! Your order is out for delivery';
        bannerSubtitle = 'Our delivery partner is on the way to you.';
        emoji = '🛵';
      } else if (order.orderStatus == 'preparing') {
        bannerTitle = 'Food is being prepared 🍳';
        bannerSubtitle = '${order.restaurantName} is preparing your items.';
        emoji = '🍳';
      } else if (order.orderStatus == 'confirmed' || order.orderStatus == 'created') {
        bannerTitle = 'Order Confirmed! 📝';
        bannerSubtitle = '${order.restaurantName} has received your order.';
        emoji = '📝';
      } else if (order.isCancelled) {
        bannerTitle = 'Order Cancelled';
        bannerSubtitle = order.cancellationReason.isNotEmpty
            ? order.cancellationReason
            : 'This order was cancelled.';
        emoji = '❌';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                Text(
                  bannerSubtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Handover OTP.
  ///
  /// The backend generates it at pickup, pushes it on `delivery_drop_otp` and
  /// serves it from `GET /food/orders/:orderId/drop-otp`; the tracking view
  /// model has been holding it in `dropOtp` all along. Nothing ever drew it,
  /// so the rider asked for a code the customer had no way to read.
  Widget _buildHandoverOtpCard() {
    final state = ref.watch(orderTrackingProvider);
    final order = state.order;
    if (order == null || !order.showDropOtp) return const SizedBox.shrink();

    final otp = state.dropOtp;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery OTP',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                Text(
                  otp == null
                      ? 'Fetching your code…'
                      : 'Share this code with your delivery partner',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (otp == null)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            // Tapping copies it — reading four digits aloud in a noisy doorway
            // is exactly where this goes wrong.
            GestureDetector(
              onTap: () {
                Haptics.light();
                Clipboard.setData(ClipboardData(text: otp));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Delivery OTP copied')),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final digit in otp.split(''))
                    Container(
                      margin: const EdgeInsets.only(left: 5),
                      width: 26,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          digit,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
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
  }

  /// 5. Live GPS Tracking Map Card
  Widget _buildLiveTrackingMapCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Builder(
              builder: (context) {
                final t = ref.watch(orderTrackingProvider);
                if (!t.hasRiderFix &&
                    t.restaurantLat == null &&
                    t.customerLat == null) {
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_searching_rounded,
                              size: 28,
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            t.isLocatingRider
                                ? 'Locating your rider…'
                                : 'Live tracking starts once your order is picked up.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return LiveTrackingMap(
                  riderLat: t.riderLat,
                  riderLng: t.riderLng,
                  heading: t.heading,
                  restaurantLat: t.restaurantLat,
                  restaurantLng: t.restaurantLng,
                  customerLat: t.customerLat,
                  customerLng: t.customerLng,
                  routePoints: t.routePoints,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 6. Delivery Partner Card
  Widget _buildDeliveryPartnerCard(BuildContext context) {
    final partner = ref.watch(orderTrackingProvider).order?.deliveryPartner;
    if (partner == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Driver Avatar Photo
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE2E8F0),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const ClipOval(
                  child: Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 30),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF16A34A),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Driver Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        partner.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFF16A34A), size: 11),
                          const SizedBox(width: 2),
                          Text(
                            // '4.8' used to stand in here, so every unrated
                            // partner arrived with a score they never earned.
                            partner.rating > 0
                                ? partner.rating.toStringAsFixed(1)
                                : '—',
                            style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Your Delivery Partner',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                if (partner.hasVehicleInfo) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        partner.vehicleNumber,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Call & Chat Action Buttons
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  if (partner.phone.isNotEmpty) {
                    _makeCall(partner.phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Driver phone number not available.')),
                    );
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6F7F5),
                  ),
                  child: Icon(Icons.call_rounded, color: AppColors.primary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  context.push(
                    RouteNames.chat,
                    extra: ChatArgs(
                      orderId: widget.orderId,
                      peerId: partner.id,
                      peerName: partner.name.isNotEmpty ? partner.name : 'Delivery Partner',
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6F7F5),
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 7. Restaurant Details & Order ID Card
  Widget _buildRestaurantDetailsCard(BuildContext context) {
    final order = ref.watch(orderTrackingProvider).order;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: SmartImage(
                url: order?.restaurantImage ?? '',
                category: ImageCategory.restaurant,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order?.restaurantName ?? '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                if ((order?.restaurantAddress ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    order!.restaurantAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    final num = order?.orderNumber ?? widget.orderId;
                    Clipboard.setData(ClipboardData(text: num));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Order ID copied: $num')),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Order ID: ${order?.orderNumber ?? widget.orderId}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // View Details Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push('/orders/details/${widget.orderId}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                'View Details',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 8. Estimated Delivery Time & Need Help Card
  Widget _buildEstimatedDeliveryCard(BuildContext context) {
    final order = ref.watch(orderTrackingProvider).order;
    final windowLabel = _formatDeliveryWindow(order);
    final dateLabel = _formatDate(order?.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDCFCE7),
            ),
            child: Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Delivery',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  windowLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                const SizedBox(height: 1),
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Need Help Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(
                RouteNames.chat,
                extra: ChatArgs(orderId: widget.orderId, peerName: 'Support', peerRole: 'ADMIN'),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                'Need Help?',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 9. Savings Highlight Banner Card
  Widget _buildSavingsCard() {
    final order = ref.watch(orderTrackingProvider).order;
    if (order == null) return const SizedBox.shrink();

    final savings = order.couponDiscount + order.walletUsed + order.rewardDiscount;
    if (savings <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You saved ₹${savings.toStringAsFixed(0)} on this order!',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Thanks for choosing Eatinfinity 💚',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Horizontal Dashed Line Painter for Step Tracker
class _HorizontalDashedLinePainter extends CustomPainter {
  final Color color;

  _HorizontalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double dashWidth = 3, dashSpace = 2, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
