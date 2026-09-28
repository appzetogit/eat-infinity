import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/haptics.dart';
import '../../../core/error/failures.dart';
import '../widgets/rate_order_sheet.dart';
import '../../../data/models/order_model.dart';
import '../../../di/order_providers.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../checkout/viewmodels/checkout_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../viewmodels/orders_viewmodel.dart';
import '../widgets/previous_conversations_card.dart';

class OrderDeliveredScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDeliveredScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDeliveredScreen> createState() => _OrderDeliveredScreenState();
}

class _OrderDeliveredScreenState extends ConsumerState<OrderDeliveredScreen> {
  int _deliveryRating = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
    });
  }

  /// Opens the full rating sheet with the tapped star pre-selected.
  ///
  /// This used to submit straight away with `restaurantRating: 5` hardcoded —
  /// so rating a delivery partner silently filed a five-star review for a
  /// restaurant the customer never rated, and the server's one-shot guard then
  /// stopped them from ever rating it for real.
  Future<void> _openRatingSheet(int rating, OrderModel order) async {
    if (rating == 0) return;
    setState(() => _deliveryRating = rating);
    Haptics.medium();
    await RateOrderSheet.show(context, order, initialDeliveryRating: rating);
    if (mounted) {
      await ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
    }
  }

  Future<void> _dialPhone(String phone) async {
    if (phone.isEmpty) return;
    Haptics.light();
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    final scaffoldBg = isDark ? AppColors.backgroundDark : const Color(0xFFF6F8FA);

    // Delivered/rating is a dead end, not a step back into a now-stale
    // tracking screen — back (button, gesture, or hardware key) always goes
    // straight to home.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.home);
      },
      child: Scaffold(
      backgroundColor: scaffoldBg,
      body: orderAsync.when(
        loading: () => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.go(RouteNames.home),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.go(RouteNames.home),
            ),
          ),
          body: Center(
            child: Text(
              'Could not load order details.',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
            ),
          ),
        ),
        data: (order) {
          final deliveredTime = order.deliveredAt ?? order.createdAt;
          final timeStr = deliveredTime != null ? DateFormat('hh:mm a').format(deliveredTime.toLocal()) : '';
          final totalItems = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
          final itemsCountText = totalItems == 1 ? '1 Item' : '$totalItems Items';

          final partnerName = order.deliveryPartner?.name.isNotEmpty == true
              ? order.deliveryPartner!.name
              : 'DELIVERY BOY';

          return Column(
            children: [
              // FIXED STICKY TOP HEADER - DOES NOT MOVE ON PULL TO REFRESH
              _GreenDeliveredHeader(
                order: order,
                timeStr: timeStr,
                itemsCountText: itemsCountText,
              ),

              // SCROLLABLE BODY CONTENT BELOW HEADER (REFRESHES INDEPENDENTLY)
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: () async {
                    await ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
                  },
                  child: CustomScrollView(
                    key: PageStorageKey('order_delivered_${widget.orderId}'),
                    // Clamping (not bouncing) so the page doesn't drift on iOS;
                    // AlwaysScrollable keeps pull-to-refresh alive on short content.
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // FLOATING RATING CARD BELOW HEADER
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0, -18.h),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: _DeliveryRatingCard(
                              order: order,
                              partnerName: partnerName,
                              deliveryRating: _deliveryRating > 0 ? _deliveryRating : order.deliveryRating.toInt(),
                              onRate: (rating) => _openRatingSheet(rating, order),
                              onCall: () => _dialPhone(order.deliveryPartner?.phone ?? ''),
                            ),
                          ),
                        ),
                      ),

                      // BODY CONTENT SLIVERS
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 40.h),
                        sliver: SliverList.list(
                          children: [
                            // TIP YOUR DELIVERY PARTNER
                            _TipDeliveryPartnerCard(order: order),

                            SizedBox(height: 16.h),

                            // ORDER SUMMARY DOTTED HEADER
                            const _OrderSummaryDottedHeader(),

                            SizedBox(height: 16.h),

                            // ORDER SUMMARY LOCATIONS CARD
                            _OrderSummaryLocationsCard(order: order),

                            SizedBox(height: 16.h),

                            // DELIVERY SAFETY CARD
                            const _DeliverySafetyCard(),

                            SizedBox(height: 16.h),

                            // REFERRAL BANNER
                            const _ReferralBannerCard(),

                            SizedBox(height: 16.h),

                            // ALL CONVERSATION THREADS CARD
                            PreviousConversationsCard(orderId: order.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Green Header
class _GreenDeliveredHeader extends StatelessWidget {
  final OrderModel order;
  final String timeStr;
  final String itemsCountText;

  const _GreenDeliveredHeader({
    required this.order,
    required this.timeStr,
    required this.itemsCountText,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final titleText = order.restaurantName.isNotEmpty ? order.restaurantName : 'Eatinfinity';
    final subtitleText = [
      if (timeStr.isNotEmpty) timeStr,
      if (itemsCountText.isNotEmpty) itemsCountText,
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, topPadding + 12.h, 16.w, 36.h),
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      child: Row(
        children: [
          _CircleHeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.go(RouteNames.home),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitleText.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 36.w), // Keep title nicely centered
        ],
      ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleHeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 36.w,
        height: 36.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Rating Card
class _DeliveryRatingCard extends StatelessWidget {
  final OrderModel order;
  final String partnerName;
  final int deliveryRating;
  final ValueChanged<int> onRate;
  final VoidCallback onCall;

  const _DeliveryRatingCard({
    required this.order,
    required this.partnerName,
    required this.deliveryRating,
    required this.onRate,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF1E1E1E);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partner Name & Verified Checkmark Badge
          Row(
            children: [
              Text(
                'Delivered by ',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                partnerName.toUpperCase(),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 5.w),
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 17.sp,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'How was your delivery experience?',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20.h),

          // 5-Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isSelected = starIndex <= deliveryRating;
              return InkWell(
                onTap: () => onRate(starIndex),
                borderRadius: BorderRadius.circular(20.r),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected
                        ? const Color(0xFFFFB01D)
                        : (isDark ? Colors.white30 : const Color(0xFFC4C4C4)),
                    size: 34.sp,
                  ),
                ),
              );
            }),
          ),

          SizedBox(height: 20.h),
          Divider(
            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            height: 1,
          ),
          SizedBox(height: 14.h),

          // Contact Partner Sub-Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order not delivered?',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  GestureDetector(
                    onTap: onCall,
                    child: Text(
                      'Contact Delivery Partner',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.call_rounded,
                    color: AppColors.primary,
                    size: 22.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Section Header
class _OrderSummaryDottedHeader extends StatelessWidget {
  const _OrderSummaryDottedHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.white30 : const Color(0xFFE2E8F0);

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = (constraints.maxWidth / 6).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(count, (_) => Container(width: 3.w, height: 1.5.h, color: dotColor)),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Text(
            'ORDER SUMMARY',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = (constraints.maxWidth / 6).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(count, (_) => Container(width: 3.w, height: 1.5.h, color: dotColor)),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── Locations Summary
class _OrderSummaryLocationsCard extends StatelessWidget {
  final OrderModel order;

  const _OrderSummaryLocationsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF1E1E1E);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B);
    final dividerColor = isDark ? AppColors.borderDark : const Color(0xFFF1F5F9);

    final restaurantName = order.restaurantName.isNotEmpty ? order.restaurantName : 'Eatinfinity';
    final customerName = order.customerName.isNotEmpty ? order.customerName : 'Home';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Restaurant Pickup Location Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      order.restaurantAddress,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),
          Divider(color: dividerColor, height: 1),
          SizedBox(height: 14.h),

          // Drop-off Location Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.h,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.home_rounded,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivered to $customerName',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      order.deliveryAddress.isNotEmpty
                          ? order.deliveryAddress
                          : 'Delivery address details',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Safety Card
class _DeliverySafetyCard extends StatelessWidget {
  const _DeliverySafetyCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF1E1E1E);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: 'Your order is protected with\n',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 12.5.sp,
                  height: 1.3,
                ),
                children: [
                  TextSpan(
                    text: 'Eatinfinity delivery safety.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            ),
            onPressed: () {
              Haptics.light();
            },
            child: Text(
              'Know more',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Referral Banner
class _ReferralBannerCard extends StatelessWidget {
  const _ReferralBannerCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Haptics.medium();
        context.push(RouteNames.referral);
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refer Friends &',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Earn Up to ₹200',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                children: [
                  Text(
                    'Refer Now',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFF007A3D),
                    size: 18.sp,
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


// ─────────────────────────────────────────────────────── Tip Delivery Partner
/// Post-delivery tipping, paid from the wallet (the order is already
/// settled, so a second card payment for ₹20 isn't worth it). Hidden entirely
/// when `GET /food/tips/config` says tipping is off — same rule as checkout.
class _TipDeliveryPartnerCard extends ConsumerStatefulWidget {
  final OrderModel order;

  const _TipDeliveryPartnerCard({required this.order});

  @override
  ConsumerState<_TipDeliveryPartnerCard> createState() => _TipDeliveryPartnerCardState();
}

class _TipDeliveryPartnerCardState extends ConsumerState<_TipDeliveryPartnerCard> {
  bool _isSubmitting = false;

  Future<void> _tip(double amount) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    Haptics.medium();

    try {
      await ref.read(orderRemoteDataSourceProvider).tipOrder(widget.order.id, amount);
      if (!mounted) return;
      AppSnackbar.success(context, 'Thanks — your tip has been added');
      ref.invalidate(orderDetailProvider(widget.order.id));
      unawaited(ref.read(walletViewModelProvider.notifier).loadWallet(isRefresh: true));
    } on Failure catch (f) {
      if (!mounted) return;
      // Server-refusal messages (order not delivered, past 7 days, tipping
      // off, already maxed out) are shown verbatim — they're worded for the
      // customer already.
      if (f.message.toLowerCase().contains('insufficient wallet balance')) {
        AppSnackbar.error(context, f.message);
        context.push(RouteNames.wallet);
      } else {
        AppSnackbar.error(context, f.message);
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not add your tip. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configAsync = ref.watch(tipConfigProvider);
    final config = configAsync.asData?.value;
    if (config == null || !config.enabled || config.presets.isEmpty) {
      return const SizedBox.shrink();
    }

    final balance = ref.watch(walletViewModelProvider).wallet.balance;
    final alreadyTipped = widget.order.driverTip;
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip your delivery partner',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alreadyTipped > 0
                ? "You've tipped ₹${alreadyTipped.toStringAsFixed(0)} on this order · Wallet balance ₹${balance.toStringAsFixed(0)}"
                : 'Goes to them in full · Wallet balance ₹${balance.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in config.presets)
                ActionChip(
                  label: Text('₹$amount'),
                  onPressed: _isSubmitting ? null : () => _tip(amount.toDouble()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
