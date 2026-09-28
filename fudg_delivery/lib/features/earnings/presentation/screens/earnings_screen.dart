import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/notifications/application/unread_notifications_controller.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  String _selectedTab = 'Daily'; // 'Daily', 'Weekly', 'Monthly', 'Yearly'
  final String _selectedTrendFilter = 'This Week';

  final PageController _performancePageController = PageController();

  /// Nothing on this screen used to touch the network — every figure
  /// (₹1,248.00, 28 orders, 98.5 km, the seven trend bars, two transactions)
  /// was written into the widget tree. These four fields are now the only
  /// source of what is rendered.
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  /// `summary` from `GET /food/delivery/earnings`.
  Map<String, dynamic> _summary = const {};

  /// `trips` from `GET /food/delivery/trip-history` for the same period —
  /// the transaction list and the trend chart are both derived from it,
  /// because no per-day earnings breakdown endpoint exists.
  List<Map<String, dynamic>> _trips = const [];

  /// `GET /food/delivery/earning-addons/active` — the live incentives.
  List<Map<String, dynamic>> _addons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _performancePageController.dispose();
    super.dispose();
  }

  /// Maps the segmented control onto the two different period vocabularies the
  /// backend uses: `/earnings` takes today|week|month|all, `/trip-history`
  /// takes daily|weekly|monthly.
  ({String earnings, String trips}) get _periods => switch (_selectedTab) {
        'Weekly' => (earnings: 'week', trips: 'weekly'),
        'Monthly' => (earnings: 'month', trips: 'monthly'),
        'Yearly' => (earnings: 'all', trips: 'monthly'),
        _ => (earnings: 'today', trips: 'daily'),
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(walletRepositoryProvider);
    final periods = _periods;
    final iso = _selectedDate.toIso8601String();

    final earningsResult = await repo.getEarnings(period: periods.earnings);
    final tripsResult =
        await repo.getTripHistory(period: periods.trips, date: iso);
    final addonsResult = await repo.getActiveEarningAddons();

    if (!mounted) return;

    Map<String, dynamic> summary = const {};
    List<Map<String, dynamic>> trips = const [];
    List<Map<String, dynamic>> addons = const [];
    String? error;

    earningsResult.when(
      success: (data) =>
          summary = data['summary'] as Map<String, dynamic>? ?? data,
      failure: (e) => error = e.message,
    );
    tripsResult.when(
      success: (data) => trips = (data['trips'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      failure: (e) => error ??= e.message,
    );
    // Incentives are a nice-to-have; a failure here must not blank the screen.
    addonsResult.when(success: (data) => addons = data, failure: (_) {});

    setState(() {
      _summary = summary;
      _trips = trips;
      _addons = addons;
      _error = error;
      _loading = false;
    });
  }

  double get _totalEarnings =>
      (_summary['totalEarnings'] as num?)?.toDouble() ?? 0;
  int get _totalOrders => (_summary['totalOrders'] as num?)?.toInt() ?? 0;

  /// The backend's own split (delivery.service.js `getDeliveryPartnerEarnings`),
  /// not a client-side percentage of the total.
  double get _orderEarning =>
      (_summary['orderEarning'] as num?)?.toDouble() ?? _totalEarnings;
  double get _incentive => (_summary['incentive'] as num?)?.toDouble() ?? 0;
  double get _otherEarnings =>
      (_summary['otherEarnings'] as num?)?.toDouble() ?? 0;

  /// What customers tipped. Absent on an older server build — that's simply
  /// "no tips", not an error.
  double get _tips => (_summary['tips'] as num?)?.toDouble() ?? 0;

  /// Shown wherever the backend has no figure at all — never a stand-in number.
  static const String _noData = '—';

  static String _axisLabel(double v) =>
      v >= 1000 ? '₹${(v / 1000).toStringAsFixed(1)}K' : '₹${v.round()}';

  String get _onlineHoursLabel {
    final h = (_summary['totalHours'] as num?)?.toInt() ?? 0;
    final m = (_summary['totalMinutes'] as num?)?.toInt() ?? 0;
    if (h == 0 && m == 0) return _noData;
    return '${h}h ${m}m';
  }

  String get _ratingLabel {
    final authState = ref.watch(authControllerProvider);
    final rating = authState is AuthAuthenticated ? authState.user.rating : null;
    return (rating == null || rating <= 0)
        ? _noData
        : rating.toStringAsFixed(1);
  }

  /// Earnings per day across the selected trip window, for the trend chart.
  /// Derived from the trips the backend returned — there is no per-day
  /// earnings endpoint, so this is a real aggregation rather than a guess.
  List<({DateTime day, double amount})> get _dailyTotals {
    final byDay = <DateTime, double>{};
    for (final t in _trips) {
      final at = _tripDate(t);
      if (at == null) continue;
      final key = DateTime(at.year, at.month, at.day);
      byDay[key] = (byDay[key] ?? 0) + _tripEarning(t);
    }
    // Always render a full week ending on the selected date, so an empty
    // period shows seven zero bars instead of collapsing the chart.
    final end = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    return List.generate(7, (i) {
      final day = end.subtract(Duration(days: 6 - i));
      return (day: day, amount: byDay[day] ?? 0);
    });
  }

  static double _n(Map<String, dynamic> t, List<String> keys) {
    for (final k in keys) {
      final v = t[k];
      if (v is num) return v.toDouble();
    }
    return 0;
  }

  static String _s(Map<String, dynamic> t, List<String> keys) {
    for (final k in keys) {
      final v = t[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static double _tripEarning(Map<String, dynamic> t) =>
      _n(t, ['deliveryEarning', 'earningAmount', 'amount']);

  /// The stored tip portion of a trip's earning, not derived by subtracting
  /// from the total — the stored value is authoritative.
  static double _tripTip(Map<String, dynamic> t) => _n(t, ['tipAmount', 'tip']);

  static DateTime? _tripDate(Map<String, dynamic> t) => DateTime.tryParse(
        _s(t, ['date', 'deliveredAt', 'completedAt', 'createdAt']),
      )?.toLocal();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _dateLabel {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final d = '${_selectedDate.day.toString().padLeft(2, '0')} '
        '${_months[_selectedDate.month - 1]} ${_selectedDate.year}';
    return isToday ? 'Today, $d' : d;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDateFilterPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2028),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    // Was a snackbar and nothing else. The date now anchors the query.
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Column(
        children: [
          // 1. Dark Teal Top Header & Filter Bar
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                child: Column(
                  children: [
                    // Top Bar: Title & Notification Bell
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Earnings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22.sp,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Track your earnings and performance',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFFF6A2A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticService.light();
                            context.push('/notifications');
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 38.r,
                                height: 38.r,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22.sp),
                              ),
                              // Unread notifications — this was wired to the
                              // order count, so it sat at "0" on a bell.
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: EdgeInsets.all(4.r),
                                    constraints: BoxConstraints(
                                      minWidth: 16.r,
                                      minHeight: 16.r,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
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

                    // Segmented Control Filter Tabs (Daily, Weekly, Monthly, Yearly)
                    Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((tab) {
                          final isSelected = _selectedTab == tab;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticService.light();
                                setState(() => _selectedTab = tab);
                                _load();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Center(
                                  child: Text(
                                    tab,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      fontSize: 13.sp,
                                      color: isSelected ? const Color(0xFF004D40) : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                              // Date Selector Dropdown Button
                    GestureDetector(
                      onTap: _openDateFilterPicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14.sp),
                            SizedBox(width: 6.w),
                            Text(
                              _dateLabel,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5.sp,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18.sp),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Scrollable Body Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom value clears MainScreen's navigation bar.
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 96.h),
              child: Column(
                children: [
                  // Hero Card: Today's Earnings Card
                  _buildEarningsHeroCard(),

                  SizedBox(height: 14.h),

                  // Performance Overview Card
                  _buildPerformanceOverviewCard(),

                  SizedBox(height: 14.h),

                  // Earnings Trend Bar Chart Card
                  _buildEarningsTrendCard(),

                  SizedBox(height: 14.h),

                  // Recent Transactions Card
                  _buildRecentTransactionsCard(),

                  SizedBox(height: 14.h),

                  // Weekly Goal / Incentive Banner Card
                  _buildIncentiveBannerCard(),

                  SizedBox(height: 16.h),
                ],
              ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              // A server error can run to hundreds of lines; unbounded it
              // pushes the retry button off the screen.
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // 1. Today's Earnings Card Widget
  Widget _buildEarningsHeroCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTab == 'Daily'
                          ? "Today's Earnings"
                          : '$_selectedTab Earnings',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '₹${_totalEarnings.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 28.sp,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        GestureDetector(
                          onTap: () => _showSnack(
                              'Paid on delivered orders in the selected period'),
                          child: Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 18.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '@ $_totalOrders ${_totalOrders == 1 ? 'Order' : 'Orders'} Completed',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 3D Wallet Graphic Illustration Widget
              SizedBox(
                width: 90.r,
                height: 75.r,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 8.h,
                      child: Container(
                        width: 20.r,
                        height: 20.r,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 12.sp),
                      ),
                    ),
                    Positioned(
                      left: 12.w,
                      bottom: 0,
                      child: Container(
                        width: 22.r,
                        height: 22.r,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB300),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.star_rounded, color: Colors.white, size: 13.sp),
                      ),
                    ),
                    Container(
                      width: 65.r,
                      height: 55.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DB6AC),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 6.h,
                            left: 10.w,
                            right: 10.w,
                            child: Container(
                              height: 18.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF5D67),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Icon(Icons.attach_money_rounded, color: Colors.white, size: 14.sp),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 14.r,
                              height: 14.r,
                              margin: EdgeInsets.only(right: 8.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
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
          SizedBox(height: 16.h),

          // Bottom Financial Breakdown Row (Base Fare, Tips, View Breakdown Button)
          Row(
            children: [
              // Amounts carry no break opportunity ("₹1234.56"), so in a
              // squeezed column they overflow rather than wrap — every one of
              // these is capped to a single ellipsised line.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // orderEarning is delivery pay only; tips are reported apart.
                    Text(
                      'Delivery pay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '₹${_orderEarning.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              Container(width: 1.w, height: 30.h, color: Colors.grey[200]),
              // Incentives always hold this slot. Tips get their own row below
              // rather than swapping in here, where the longer label had to fit
              // a column barely wide enough for the number.
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incentives',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '₹${_incentive.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  HapticService.light();
                  // The parts the server reported, without the empty ones. Their
                  // sum is totalEarnings, shown above -- never re-added here.
                  _showSnack(
                    [
                      'Delivery pay ₹${_orderEarning.toStringAsFixed(2)}',
                      if (_tips > 0) 'tips ₹${_tips.toStringAsFixed(2)}',
                      if (_incentive > 0) 'incentives ₹${_incentive.toStringAsFixed(2)}',
                      if (_otherEarnings > 0) 'other ₹${_otherEarnings.toStringAsFixed(2)}',
                    ].join(' + '),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                ),
                // Shortened: "View Breakdown" took ~130px of a ~296px row,
                // starving the two figures beside it.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 11.5.sp),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 16.sp),
                  ],
                ),
              ),
            ],
          ),
          // A tip is the one figure in this card that a customer chose to
          // give, not a scheduled rate — worth calling out, and worth hiding
          // outright rather than showing a permanent "Tips ₹0" row.
          if (_tips > 0) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.volunteer_activism_rounded, size: 14.sp, color: Colors.green[700]),
                SizedBox(width: 6.w),
                Text(
                  'Tips from customers',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
                const Spacer(),
                Text(
                  '+₹${_tips.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.green[700]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 2. Performance Overview Card Widget
  Widget _buildPerformanceOverviewCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Overview',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
          ),
          SizedBox(height: 14.h),

          // 4-Stat Metric Horizontal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                icon: Icons.two_wheeler_rounded,
                bgColor: AppColors.primaryLight,
                iconColor: AppColors.primaryDark,
                value: '$_totalOrders',
                label: 'Orders',
              ),
              _buildMetricItem(
                icon: Icons.currency_rupee_rounded,
                bgColor: AppColors.primaryLight,
                iconColor: AppColors.primaryDark,
                value: _totalOrders > 0
                    ? '₹${(_totalEarnings / _totalOrders).toStringAsFixed(0)}'
                    : _noData,
                label: 'Avg / Order',
              ),
              // The earnings endpoint returns totalHours/totalMinutes but
              // hardcodes them to 0 server-side, so this reads '—' rather
              // than the '8h 45m' that used to be painted here regardless.
              _buildMetricItem(
                icon: Icons.access_time_rounded,
                bgColor: AppColors.successBg,
                iconColor: AppColors.successText,
                value: _onlineHoursLabel,
                label: 'Online Hours',
              ),
              _buildMetricItem(
                icon: Icons.star_rounded,
                bgColor: AppColors.pendingBg,
                iconColor: AppColors.rating,
                value: _ratingLabel,
                label: 'Rating',
              ),
            ],
          ),
          SizedBox(height: 12.h),

        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5.sp, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 3. Earnings Trend Bar Chart Card Widget
  Widget _buildEarningsTrendCard() {
    // Real per-day totals, aggregated from the trips the backend returned.
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final days = _dailyTotals.map((e) {
      return {
        'day': weekdays[e.day.weekday - 1],
        'date': '${e.day.day.toString().padLeft(2, '0')} '
            '${_months[e.day.month - 1]}',
        'amount': e.amount,
        'active': e.day.year == today.year &&
            e.day.month == today.month &&
            e.day.day == today.day,
      };
    }).toList();

    // Axis scales to the data instead of a fixed ₹1.5K ceiling.
    final peak = days.fold<double>(
        0, (m, d) => (d['amount'] as double) > m ? d['amount'] as double : m);
    final hasEarnings = peak > 0;
    final maxVal = hasEarnings ? peak : 1.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Earnings Trend',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
              ),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showSnack('Showing trend for This Week');
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedTrendFilter,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600], size: 16.sp),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (!hasEarnings)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 34.h),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 40.sp, color: AppColors.lightBorder),
                  SizedBox(height: 10.h),
                  Text(
                    'No earnings in this period',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Completed deliveries will chart here.',
                    style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.lightTextSecondary),
                  ),
                ],
              ),
            )
          else
          // Bar Chart Grid Area
          SizedBox(
            height: 160.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Hidden when there is nothing to scale to — three
                    // rounded labels all read "₹1" on an empty week.
                    if (hasEarnings) ...[
                      Text(_axisLabel(maxVal), style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
                      Text(_axisLabel(maxVal * 2 / 3), style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
                      Text(_axisLabel(maxVal / 3), style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
                      Text('₹0', style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
                    ],
                  ],
                ),
                SizedBox(width: 8.w),

                // Chart Bars Area
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal Guide Lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (_) => Container(height: 1.h, color: Colors.grey[100])),
                      ),

                      // Bars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: days.map((data) {
                          final amount = data['amount'] as double;
                          final isToday = data['active'] as bool;
                          final barRatio = (amount / maxVal).clamp(0.0, 1.0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Amount Tooltip
                              if (amount > 0)
                                Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8.5.sp,
                                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                                    color: isToday ? const Color(0xFF004D40) : AppColors.primaryDark,
                                  ),
                                )
                              else
                                Text('₹0', style: TextStyle(fontSize: 8.5.sp, color: Colors.grey[400])),
                              SizedBox(height: 4.h),

                              // Bar Graphic. Height comes from whatever the
                              // column has left after the labels, not a fixed
                              // 120.h — that plus the labels came to more than
                              // the 160.h chart area, so the tallest bar
                              // overflowed.
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, barBox) {
                                    final full = barBox.maxHeight;
                                    return Align(
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 22.w,
                                        height: (full * barRatio).clamp(2.0, full),
                                        decoration: BoxDecoration(
                                          color: isToday
                                              ? const Color(0xFF004D40)
                                              : (amount > 0
                                                    ? const Color(0xFF26A69A)
                                                    : Colors.grey[200]),
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(6.r),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 6.h),

                              // X-Axis Labels
                              Text(
                                data['day'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                  color: isToday ? Colors.black87 : Colors.grey[600],
                                ),
                              ),
                              Text(
                                data['date'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 8.5.sp, color: Colors.grey[400]),
                              ),
                            ],
                          );
                        }).toList(),
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

  // 4. Recent Transactions Card Widget
  Widget _buildRecentTransactionsCard() {
    // The five most recent real trips for the selected period.
    final transactions = _trips.take(5).map((t) {
      final at = _tripDate(t);
      final hour12 = at == null
          ? ''
          : (at.hour % 12 == 0 ? 12 : at.hour % 12).toString().padLeft(2, '0');
      final method = _s(t, ['paymentMethod']).toLowerCase();
      return {
        'id': 'Order #${_s(t, ['orderId', 'id', '_id'])}',
        'time': at == null
            ? ''
            : '$hour12:${at.minute.toString().padLeft(2, '0')} '
                '${at.hour < 12 ? 'AM' : 'PM'}',
        'payment': method == 'cash' ? 'Cash on Delivery' : 'Prepaid',
        'amount': '+₹${_tripEarning(t).toStringAsFixed(2)}',
        'tip': _tripTip(t) > 0 ? 'incl. ₹${_tripTip(t).toStringAsFixed(0)} tip' : '',
        'date': at == null
            ? ''
            : '${at.day.toString().padLeft(2, '0')} '
                '${_months[at.month - 1]} ${at.year}',
      };
    }).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
              ),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showSnack('Opening all transactions');
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.sp),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 16.sp),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Text(
                'No deliveries in this period',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            )
          else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, _) => Divider(height: 18.h, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryDark, size: 18.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx['id']!,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5.sp, color: Colors.black87),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${tx['time']} • ${tx['payment']}',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tx['amount']!,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: AppColors.primaryDark),
                      ),
                      if (tx['tip']!.isNotEmpty)
                        Text(
                          tx['tip']!,
                          style: TextStyle(fontSize: 9.5.sp, color: Colors.green[700], fontWeight: FontWeight.w700),
                        ),
                      SizedBox(height: 2.h),
                      Text(
                        tx['date']!,
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18.sp),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 5. Incentive / Weekly Goal Banner Card Widget
  //
  // Driven by GET /food/delivery/earning-addons/active. The banner used to
  // promise a flat "₹500 for 50 orders" with a 22/50 progress bar that no
  // admin had ever configured; it is now hidden entirely when no incentive
  // is running.
  Widget _buildIncentiveBannerCard() {
    if (_addons.isEmpty) return const SizedBox.shrink();

    final addon = _addons.first;
    final title = (addon['title'] ?? 'Incentive').toString();
    final description = (addon['description'] ?? '').toString();
    final required = (addon['requiredOrders'] as num?)?.toInt() ?? 0;
    final reward = (addon['earningAmount'] as num?)?.toDouble() ?? 0;
    final progress =
        required <= 0 ? 0.0 : (_totalOrders / required).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        HapticService.light();
        _showSnack(description.isNotEmpty
            ? description
            : 'Complete $required orders to earn '
                '₹${reward.toStringAsFixed(0)}');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: const BoxDecoration(
                color: Color(0xFFFFB300),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, color: Colors.white, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5.sp, color: Colors.black87),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description.isNotEmpty
                        ? description
                        : 'Complete $required orders to earn '
                            '₹${reward.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text(
                        '$_totalOrders / $required',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.sp, color: Colors.black87),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6.h,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // 3D Gift Box Graphic Icon Widget
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44.r,
                  height: 44.r,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 24.sp),
                ),
              ],
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[500], size: 18.sp),
          ],
        ),
      ),
    );
  }
}
