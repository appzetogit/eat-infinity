import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedStatus = 'All'; // 'All', 'Delivered', 'Cancelled', 'In Progress'
  final String _selectedPeriod = 'Daily'; // backend range around _selectedDate
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  /// Raw trip DTOs from `GET /food/delivery/trip-history`, passed straight
  /// through to [TripDetailScreen] via `context.push('/trip-details')` —
  /// which reads exactly these keys.
  ///
  /// This list used to be five invented deliveries (The Biryani House / Ali
  /// Khan / ₹68.00 …) rendered while the real fetch below ran and had its
  /// result thrown away.
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.getTripHistory(
      period: _selectedPeriod.toLowerCase(),
      date: _selectedDate.toIso8601String(),
      // 'All' is sent as no filter; the backend maps the rest itself.
      status: _selectedStatus == 'All' ? null : _backendStatus(_selectedStatus),
    );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _trips = (data['trips'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      }),
      failure: (error) => setState(() {
        _error = error.message;
        _loading = false;
      }),
    );
  }

  /// The chips read Delivered/Cancelled; the backend filter expects
  /// Completed/Cancelled (see `normalizeStatusFilter` in delivery.service.js).
  static String _backendStatus(String chip) =>
      chip == 'Delivered' ? 'Completed' : chip;

  /// Trip DTO helpers — the backend sends several aliases per field
  /// (`restaurantName`/`restaurant`, `deliveryEarning`/`earningAmount`), so
  /// read them the same way [TripDetailScreen] does.
  static String _s(Map<String, dynamic> t, List<String> keys) {
    for (final k in keys) {
      final v = t[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static double _n(Map<String, dynamic> t, List<String> keys) {
    for (final k in keys) {
      final v = t[k];
      if (v is num) return v.toDouble();
    }
    return 0;
  }

  /// The displayed date+time, formatted in the device's own timezone rather
  /// than the pre-formatted `time` string the server also sends.
  static String _when(Map<String, dynamic> t) {
    final raw = _s(t, ['date', 'deliveredAt', 'completedAt', 'createdAt']);
    final at = DateTime.tryParse(raw)?.toLocal();
    if (at == null) return _s(t, ['time']);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${at.day.toString().padLeft(2, '0')} ${months[at.month - 1]} '
        '${at.year}, ${hour12.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')} '
        '${at.hour < 12 ? 'AM' : 'PM'}';
  }

  void _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
    // Previously this only raised a snackbar; the chosen day is now the
    // `date` the trip-history query is anchored on.
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The status chip is applied server-side by _loadTrips; the search box is
    // a local narrowing of whatever came back.
    final query = _searchQuery.toLowerCase();
    final filteredOrders = _trips.where((trip) {
      if (query.isEmpty) return true;
      return _s(trip, ['orderId', 'id', '_id']).toLowerCase().contains(query) ||
          _s(trip, ['restaurantName', 'restaurant'])
              .toLowerCase()
              .contains(query);
    }).toList();

    // Summary reflects the rows actually on screen, rather than a fixed
    // ₹1,248.00 / 98.5 km. Trip DTOs carry no distance, so that cell now
    // reports COD collected, which they do carry.
    final totalEarnings = filteredOrders.fold<double>(
        0, (sum, t) => sum + _n(t, ['deliveryEarning', 'earningAmount', 'amount']));
    final totalCollected = filteredOrders.fold<double>(
        0, (sum, t) => sum + _n(t, ['codCollectedAmount']));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order History',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22.sp,
                            color: Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'View all your past completed & cancelled orders',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date Picker Filter Icon Button
                  GestureDetector(
                    onTap: _openDatePicker,
                    child: Container(
                      padding: EdgeInsets.all(9.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.calendar_today_rounded, color: AppColors.primaryDark, size: 18.sp),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Search Field Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by Order ID, Store or Customer...',
                  hintStyle: TextStyle(fontSize: 12.5.sp, color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20.sp),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close_rounded, color: Colors.grey[600], size: 18.sp),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // 3. Status Filter Chips (All, Delivered, Cancelled)
            SizedBox(
              height: 38.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: ['All', 'Delivered', 'Cancelled'].map((status) {
                  final isSelected = _selectedStatus == status;
                  return GestureDetector(
                    onTap: () {
                      HapticService.light();
                      setState(() => _selectedStatus = status);
                      _loadTrips();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryDark : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryDark : Colors.grey[300]!,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 12.h),

            // 4. Summary Stats Header Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryStat(label: 'Total Orders', value: '${filteredOrders.length}'),
                    Container(width: 1.w, height: 26.h, color: Colors.grey[200]),
                    _buildSummaryStat(
                        label: 'Total Earnings',
                        value: '₹${totalEarnings.toStringAsFixed(2)}'),
                    Container(width: 1.w, height: 26.h, color: Colors.grey[200]),
                    _buildSummaryStat(
                        label: 'Cash Collected',
                        value: '₹${totalCollected.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // 5. Orders History List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : filteredOrders.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadTrips,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    16.w, 4.h, 16.w, 40.h),
                                itemCount: filteredOrders.length,
                                itemBuilder: (context, index) =>
                                    _buildOrderHistoryCard(
                                        filteredOrders[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: AppColors.primaryDark),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _loadTrips,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.25),
            Icon(Icons.history_rounded, size: 64.sp, color: Colors.grey[300]),
            SizedBox(height: 12.h),
            Text(
              'No trips for this period',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    // Scrollable and line-capped: a server error can be an enormous dump (a
    // rejected Prisma query runs to hundreds of lines), and rendering it whole
    // in a fixed Column overflowed the screen instead of showing the retry.
    return SingleChildScrollView(
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
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _loadTrips, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // Order History Card Item Widget
  Widget _buildOrderHistoryCard(Map<String, dynamic> order) {
    // Backend status vocabulary is Completed / Cancelled / Pending.
    final status = _s(order, ['status']);
    final isDelivered = status == 'Completed';
    final isCancelled = status == 'Cancelled';
    final statusLabel = isDelivered ? 'Delivered' : status;
    final statusColor = isDelivered
        ? AppColors.primaryDark
        : isCancelled
            ? const Color(0xFFD32F2F)
            : const Color(0xFFF57C00);
    final statusBg = isDelivered
        ? AppColors.primaryLight
        : isCancelled
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF3E0);

    final storeName = _s(order, ['restaurantName', 'restaurant']);
    final orderRef = _s(order, ['orderId', 'id', '_id']);
    final earnings = _n(order, ['deliveryEarning', 'earningAmount', 'amount']);
    final itemsCount = (order['items'] as List<dynamic>? ??
            order['orderItems'] as List<dynamic>? ??
            const [])
        .length;
    final paymentMethod = _s(order, ['paymentMethod']);
    final orderTotal = _n(order, ['totalAmount', 'orderTotal']);

    return GestureDetector(
      onTap: () {
        HapticService.light();
        context.push('/trip-details', extra: order);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Order ID, Status Badge & Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The reference falls back to the raw 24-character id when the
                // order has no short one, which overran this row with nothing
                // able to give. The id yields; the badge and time do not.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          orderRef.isEmpty ? 'Order' : '#$orderRef',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  _when(order),
                  maxLines: 1,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Route Summary: Pickup & Drop-off
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppColors.primaryDark, size: 18.sp),
                    Container(width: 1.5.w, height: 22.h, color: Colors.grey[300]),
                    Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18.sp),
                  ],
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName.isEmpty ? 'Store' : storeName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                      ),
                      Text(
                        'Pickup',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 10.h),
                      // Trip history carries no customer identity or drop
                      // address — it used to show invented ones. Order value
                      // is what the endpoint actually returns.
                      Text(
                        orderTotal > 0
                            ? 'Order value ₹${orderTotal.toStringAsFixed(2)}'
                            : 'Delivery',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                      ),
                      Text(
                        'Drop',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),
            Divider(color: Colors.grey[100], height: 1),
            SizedBox(height: 10.h),

            // Footer Row: Items, Payment & Earnings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    [
                      if (itemsCount > 0)
                        '$itemsCount ${itemsCount == 1 ? 'Item' : 'Items'}',
                      if (paymentMethod.isNotEmpty)
                        paymentMethod.toLowerCase() == 'cash'
                            ? 'Cash on Delivery'
                            : 'Prepaid',
                    ].join(' • '),
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isDelivered
                          ? '+ ₹${earnings.toStringAsFixed(2)}'
                          : '₹0.00',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.sp,
                        color: isDelivered ? AppColors.primaryDark : Colors.grey[500],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18.sp),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
