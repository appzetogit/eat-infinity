import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/main/presentation/screens/main_screen.dart';
import 'package:food_user_application/features/notifications/data/notifications_repository.dart';
import 'package:food_user_application/features/profile/application/availability_controller.dart';
import 'package:food_user_application/features/profile/presentation/screens/delivery_readiness_screen.dart';
import 'package:food_user_application/features/refer_earn/application/referral_controller.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  /// Starts at zero. It used to default to 3 — both here and as the fallback
  /// when the inbox call failed — so a partner with nothing unread saw a
  /// permanent badge.
  int _unreadNotificationCount = 0;

  /// Dashboard figures. Every card on this screen used to be a literal
  /// (₹1,245.60 today, ₹856.30 wallet, 12 orders, 98% acceptance, 4.9 stars,
  /// "Andheri East, Mumbai"), while `_loadEarnings` fetched the real numbers
  /// and dropped them on the floor with `success: (data) {}`.
  bool _loadingStats = true;
  Map<String, dynamic> _todaySummary = const {};
  Map<String, dynamic> _wallet = const {};
  List<Map<String, dynamic>> _addons = const [];

  StreamSubscription<Map<String, dynamic>>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUnreadCount();
    _listenForFcmNotifications();

    // Ask for location as soon as the rider lands in the app, rather than
    // leaving the first prompt until they tap Online. Guarded inside the
    // service so returning to this tab does not re-prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(locationServiceProvider).promptOnStartup();
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final result =
        await ref.read(notificationsRepositoryProvider).getInbox(limit: 1);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _unreadNotificationCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
      }),
      failure: (_) {},
    );
  }

  void _listenForFcmNotifications() {
    final fcmService = ref.read(fcmServiceProvider);
    // Was never cancelled — the subscription outlived the screen.
    _fcmSub = fcmService.onNotificationReceived.listen((data) {
      _loadUnreadCount();
      // A delivered order changes today's totals, so refresh on any
      // order-completion push too, not only on referral bonuses.
      final type = data['type']?.toString();
      if (type == 'referral_bonus') {
        ref.read(referralControllerProvider.notifier).refreshStats();
      }
      if (type == 'referral_bonus' ||
          type == 'order_delivered' ||
          type == 'order_completed') {
        _loadStats();
      }
    });
  }

  Future<void> _loadStats() async {
    final repo = ref.read(walletRepositoryProvider);
    final earnings = await repo.getEarnings(period: 'today');
    final wallet = await repo.getWallet();
    final addons = await repo.getActiveEarningAddons();
    if (!mounted) return;

    setState(() {
      earnings.when(
        success: (data) =>
            _todaySummary = data['summary'] as Map<String, dynamic>? ?? data,
        failure: (_) {},
      );
      wallet.when(
        success: (data) =>
            _wallet = data['wallet'] as Map<String, dynamic>? ?? data,
        failure: (_) {},
      );
      addons.when(success: (data) => _addons = data, failure: (_) {});
      _loadingStats = false;
    });
  }

  double _num(Map<String, dynamic> src, String key) =>
      (src[key] as num?)?.toDouble() ?? 0;

  /// Currency for a figure the backend has answered for, and an em dash while
  /// the first load is still in flight — never a stand-in amount.
  String _money(double value) =>
      _loadingStats ? '—' : '₹${value.toStringAsFixed(2)}';

  int get _todayOrders =>
      (_todaySummary['totalOrders'] as num?)?.toInt() ?? 0;

  /// The live incentive, if an admin has one running. Drives the target card,
  /// the progress dial and the banner — all three were fixed numbers before.
  Map<String, dynamic>? get _addon => _addons.isEmpty ? null : _addons.first;
  int get _targetOrders =>
      (_addon?['requiredOrders'] as num?)?.toInt() ?? 0;
  double get _targetReward =>
      (_addon?['earningAmount'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    final isOnline = ref.watch(availabilityControllerProvider);

    // Going online is the moment a missing permission starts costing orders,
    // so it is where the fixes get offered. A listener rather than a one-shot
    // check in initState: availability is loaded asynchronously, so at mount
    // it still reads false even for a rider who is already online.
    ref.listen<bool>(availabilityControllerProvider, (previous, next) {
      if (next) offerDeliveryReadiness(context);
    });
    if (isOnline) {
      // Already online before this screen's listener existed — the listener
      // only fires on a change, so this covers the first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) offerDeliveryReadiness(context);
      });
    }
    final authState = ref.watch(authControllerProvider);
    final partner = authState is AuthAuthenticated ? authState.user : null;
    // No invented name. 'Armaan' used to greet every partner whose profile
    // had not loaded yet.
    final partnerName = (partner?.name.isNotEmpty ?? false)
        ? partner!.name
        : 'Partner';
    final photoUrl = AppConstants.resolveMediaUrl(partner?.profilePhoto);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR HEADER
              Row(
                children: [
                  // Avatar with Online dot
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: CircleAvatar(
                        radius: 20.r,
                        backgroundColor: tealBgLight,
                        // The partner's own photo, not the stock illustration.
                        backgroundImage: photoUrl.isEmpty
                            ? null
                            : CachedNetworkImageProvider(photoUrl),
                        child: photoUrl.isEmpty
                            ? Icon(Icons.person_rounded,
                                size: 22.sp, color: tealPrimary)
                            : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.online
                                : AppColors.lightTextSecondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 10.w),

                  // Status badge & Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: (isOnline
                                    ? AppColors.online
                                    : AppColors.lightTextSecondary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5.w,
                                height: 5.w,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppColors.online
                                      : AppColors.lightTextSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isOnline
                                      ? AppColors.online
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              'Hi, $partnerName',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text('👋', style: TextStyle(fontSize: 15.sp)),
                          ],
                        ),
                        Text(
                          'Ready to deliver?',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Notification Bell with Badge
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 20.sp,
                            color: darkText,
                          ),
                        ),
                        if (_unreadNotificationCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16.w,
                                minHeight: 16.w,
                              ),
                              child: Text(
                                '$_unreadNotificationCount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // 2. ONLINE TOGGLE BANNER
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You are',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w900,
                              color: isOnline
                                  ? tealPrimary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            isOnline
                                ? 'Go offline to stop\nreceiving orders'
                                : 'Go online to start\nreceiving orders',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Image.asset(
                        'assets/image/delivery_hero.png',
                        height: 70.h,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: isOnline,
                              activeThumbColor: Colors.white,
                              activeTrackColor: tealPrimary,
                              onChanged: (val) async {
                                HapticService.light();
                                await ref
                                    .read(availabilityControllerProvider.notifier)
                                    .toggle();
                              },
                            ),
                          ),
                          Text(
                            isOnline ? 'Go Offline' : 'Go Online',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // 3. TODAY'S STATS SUMMARY ROW (4 Cards)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatSummaryCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Today's Earnings",
                      value: _money(_num(_todaySummary, 'totalEarnings')),
                      actionLabel: 'View Details >',
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).setIndex(1),
                    ),
                    SizedBox(width: 10.w),
                    _buildStatSummaryCard(
                      icon: Icons.monetization_on_outlined,
                      title: 'Wallet Balance',
                      value: _money(_num(_wallet, 'pocketBalance')),
                      actionLabel: 'View Wallet >',
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).setIndex(1),
                    ),
                    SizedBox(width: 10.w),
                    _buildStatSummaryCard(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Incentives',
                      value: _money(_num(_wallet, 'totalBonus')),
                      actionLabel: 'View All >',
                      onTap: () =>
                          ref.read(mainTabIndexProvider.notifier).setIndex(1),
                    ),
                    // Only shown when an admin has an incentive running —
                    // there is no such thing as a default daily target.
                    if (_targetOrders > 0) ...[
                      SizedBox(width: 10.w),
                      _buildTargetSummaryCard(
                        title: "Today's Target",
                        value: '₹${_targetReward.toStringAsFixed(0)}',
                        percentageText:
                            '${((_todayOrders / _targetOrders) * 100).clamp(0, 100).round()}% Completed',
                        progressValue:
                            (_todayOrders / _targetOrders).clamp(0.0, 1.0),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // 4. YOUR PERFORMANCE TODAY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Performance Today',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),
                  Text(
                    'View Details >',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: tealPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    _buildPerformanceMetric(
                      icon: Icons.shopping_bag_outlined,
                      value: _loadingStats ? '—' : '$_todayOrders',
                      label: 'Completed Orders',
                    ),
                    _buildPerformanceMetric(
                      icon: Icons.currency_rupee_rounded,
                      value: _todayOrders > 0
                          ? '₹${(_num(_todaySummary, 'totalEarnings') / _todayOrders).toStringAsFixed(0)}'
                          : '—',
                      label: 'Avg / Order',
                    ),
                    // The API exposes no acceptance or cancellation rate, so
                    // the 98% / 0% that used to sit here were invented. Cash
                    // in hand is a real number the rider needs to see.
                    _buildPerformanceMetric(
                      icon: Icons.payments_outlined,
                      value: _money(_num(_wallet, 'cashInHand')),
                      label: 'Cash in Hand',
                    ),
                    _buildPerformanceMetric(
                      icon: Icons.star_rounded,
                      value: (partner?.rating ?? 0) > 0
                          ? '${partner!.rating!.toStringAsFixed(1)}★'
                          : '—',
                      label: 'Customer Rating',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // 5. CURRENT LOCATION BANNER
              //
              // Was "Current Zone: Andheri East, Mumbai" next to a "Peak
              // Hours 6 PM - 10 PM / High demand expected" panel. The backend
              // models neither zones nor peak windows, so both were fiction.
              // What it does know is the partner's own city and last GPS fix.
              if ((partner?.city ?? '').isNotEmpty)
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: tealPrimary,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 18.sp,
                          color: tealPrimary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service City',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              [
                                partner?.city ?? '',
                                partner?.state ?? '',
                              ].where((e) => e.isNotEmpty).join(', '),
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isOnline ? 'Accepting orders' : 'Not accepting',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 18.h),

              // 6. QUICK ACTIONS
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              SizedBox(height: 10.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  spacing: 14.w,
                children: [
                  _buildQuickActionButton(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'My Earnings',
                    onTap: () =>
                        ref.read(mainTabIndexProvider.notifier).setIndex(1),
                  ),
                  _buildQuickActionButton(
                    icon: Icons.article_outlined,
                    label: 'Order History',
                    // Was setIndex(2). Index 2 is the raised "New Order" CTA
                    // slot, which MainScreen folds back onto Home — so this
                    // tile navigated to the screen you were already on and
                    // read as dead. History is its own route.
                    onTap: () => context.push('/history'),
                  ),
                  // Incentives and Heatmap lived here with empty onTaps —
                  // there is no endpoint behind either, so they were tiles
                  // that looked tappable and did nothing.
                  _buildQuickActionButton(
                    icon: Icons.headset_mic_outlined,
                    label: 'Help & Support',
                    onTap: () => context.push('/help'),
                  ),
                ],
                ),
              ),

              SizedBox(height: 18.h),

              // 7. TODAY'S PROGRESS
              //
              // Anchored to the running incentive's requiredOrders. Was a
              // fixed 12/20 dial with "8 more orders to reach your daily
              // target", shown even to a partner with no target at all.
              if (_targetOrders > 0) ...[
                Text(
                  "Today's Progress",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                SizedBox(height: 10.h),
                Builder(builder: (context) {
                  final progress =
                      (_todayOrders / _targetOrders).clamp(0.0, 1.0);
                  final remaining = _targetOrders - _todayOrders;
                  return Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 60.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 60.w,
                                height: 60.w,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  backgroundColor: tealBgLight,
                                  color: tealPrimary,
                                  strokeWidth: 6.w,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_todayOrders',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w900,
                                      color: darkText,
                                    ),
                                  ),
                                  Text(
                                    '/$_targetOrders',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w500,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Orders Completed',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: darkText,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: tealBgLight,
                                  color: tealPrimary,
                                  minHeight: 5.h,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                remaining > 0
                                    ? '$remaining more '
                                        '${remaining == 1 ? 'order' : 'orders'} '
                                        'to reach your target'
                                    : 'Target reached — nice work!',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 40.sp,
                          color: const Color(0xFFFFB800),
                        ),
                      ],
                    ),
                  );
                }),

                SizedBox(height: 16.h),

                // 8. INCENTIVE BANNER — the live addon, or nothing.
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: tealBgLight,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded,
                          size: 28.sp, color: tealPrimary),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_addon?['title'] ?? 'Incentive').toString(),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              (_addon?['description'] ?? '')
                                      .toString()
                                      .isNotEmpty
                                  ? _addon!['description'].toString()
                                  : 'Complete $_targetOrders orders and get '
                                      '₹${_targetReward.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 80.h), // Clearance for bottom navigation bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const borderColor = AppColors.lightBorder;

    return Container(
      width: 140.w,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: tealBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20.sp, color: tealPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: tealPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSummaryCard({
    required String title,
    required String value,
    required String percentageText,
    required double progressValue,
  }) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const borderColor = AppColors.lightBorder;

    return Container(
      width: 140.w,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: tealBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.track_changes_rounded,
              size: 20.sp,
              color: tealPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            percentageText,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: tealPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: tealBgLight,
              color: tealPrimary,
              minHeight: 4.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: const BoxDecoration(
              color: tealBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16.sp, color: tealPrimary),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: darkText,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const borderColor = AppColors.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: tealBgLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20.sp, color: tealPrimary),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }
}
