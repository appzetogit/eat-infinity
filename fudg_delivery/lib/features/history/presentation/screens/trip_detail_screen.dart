import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/result.dart';
import '../../../orders/data/models/delivery_order.dart';
import '../../../orders/data/orders_repository.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

/// A dedicated, receipt-styled detail view for a single Trip History entry
/// (Completed / Pending / Cancelled). Deliberately distinct from
/// [OrderDetailScreen], which models the *live* delivery progress of the
/// one active order — this screen has no timeline, since a historical trip
/// has nothing left to progress through.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  /// The raw trip-summary map handed over from the Trip History list, used
  /// for an instant paint while the full order is fetched in the background.
  final Map<String, dynamic> trip;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  DeliveryOrder? _order;
  bool _loading = true;

  num _f(String key1, [String? key2, String? key3]) {
    final t = widget.trip;
    final v =
        t[key1] ??
        (key2 != null ? t[key2] : null) ??
        (key3 != null ? t[key3] : null);
    return (v is num) ? v : 0;
  }

  String _s(String key1, [String? key2, String? key3, String? key4]) {
    final t = widget.trip;
    final v =
        t[key1] ??
        (key2 != null ? t[key2] : null) ??
        (key3 != null ? t[key3] : null) ??
        (key4 != null ? t[key4] : null);
    return v?.toString() ?? '';
  }

  String get _status => _s('status');
  String get _restaurantName => _s('restaurantName', 'restaurant');

  /// Contact details are hidden once a trip is over.
  ///
  /// A finished delivery is no reason to still hold the customer's or the
  /// restaurant's number: the rider has no call to make, and the receipt is a
  /// record that outlives the job.
  bool get _contactsVisible {
    final status = _status.toLowerCase();
    return status != 'completed' && status != 'cancelled';
  }

  num get _earning => _f('deliveryEarning', 'earningAmount', 'amount');
  num get _total => _f('totalAmount', 'orderTotal');
  String get _displayOrderId => _s('orderId', 'id', '_id');
  String get _time => _s('time');
  String get _date => _s('date');

  /// The Mongo `_id` (not the human-readable order code) is what
  /// `GET /orders/:id` expects — prefer it over `orderId` for the fetch.
  String get _fetchId => _s('_id', 'id', 'orderId');

  String get _formattedDateTime {
    final rawDate = _s('date', 'deliveredAt', 'completedAt', 'createdAt');
    DateTime? dt;
    if (rawDate.isNotEmpty) {
      dt = DateTime.tryParse(rawDate)?.toLocal();
    }
    if (dt == null && _order?.deliveredAt != null) {
      dt = _order!.deliveredAt!.toLocal();
    }
    if (dt == null && _order?.placedAt != null) {
      dt = _order!.placedAt!.toLocal();
    }

    if (dt != null) {
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
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour12:$minute $period';
    }

    if (_date.isNotEmpty && _time.isNotEmpty) {
      if (_date.contains('T')) {
        final parsed = DateTime.tryParse(_date)?.toLocal();
        if (parsed != null) {
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
          return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year} • $_time';
        }
      }
      return '$_date • $_time';
    }
    return _date.isNotEmpty ? _date : _time;
  }

  @override
  void initState() {
    super.initState();
    _loadFullOrder();
  }

  Future<void> _loadFullOrder() async {
    if (_fetchId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final result = await ref
        .read(ordersRepositoryProvider)
        .getOrderDetails(_fetchId);
    if (!mounted) return;
    result.when(
      success: (order) => setState(() {
        _order = order;
        _loading = false;
      }),
      // Historical trip couldn't be re-fetched (e.g. endpoint scoped to
      // active orders only) — fall back to whatever the summary map has.
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text('$label copied to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  _StatusTheme get _statusTheme => switch (_status.toLowerCase()) {
    'completed' => const _StatusTheme(
      color: AppColors.online,
      darkColor: Color(0xFF0E8A40),
      icon: Icons.check_circle_rounded,
      label: 'Delivered',
    ),
    'cancelled' => const _StatusTheme(
      color: Color(0xFFE5484D),
      darkColor: Color(0xFFAD1F24),
      icon: Icons.cancel_rounded,
      label: 'Cancelled',
    ),
    _ => const _StatusTheme(
      color: AppColors.warning,
      darkColor: AppColors.pendingText,
      icon: Icons.schedule_rounded,
      label: 'Pending',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppColors.of(context);
    final textColor = palette.textPrimary;
    final subTextColor = palette.textSecondary;
    final scaffoldColor = palette.background;
    final st = _statusTheme;
    final order = _order;

    return Scaffold(
      backgroundColor: scaffoldColor,
      // SafeArea so the receipt cannot scroll up behind the clock and battery:
      // the list had no top inset, so content passed under the status bar.
      // The header's own manual status-bar padding drops accordingly.
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(top: 6.h, bottom: 54.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [st.color, st.darkColor],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => context.pop(),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'TRIP RECEIPT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.sp,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      width: 72.w,
                      height: 72.w,
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(st.icon, color: st.color, size: 40.sp),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      st.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22.sp,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    if (_formattedDateTime.isNotEmpty)
                      Text(
                        _formattedDateTime,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    SizedBox(height: 12.h),
                    if (_displayOrderId.isNotEmpty)
                      InkWell(
                        onTap: () =>
                            _copyToClipboard(_displayOrderId, 'Order ID'),
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$_displayOrderId',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.sp,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.copy_rounded,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 13.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: Offset(0, -28.h),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      _ReceiptTicket(
                        scaffoldColor: scaffoldColor,
                        surfaceColor: palette.surface,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        accentColor: st.color,
                        restaurantName: order?.store.name.isNotEmpty == true
                            ? order!.store.name
                            : _restaurantName,
                        restaurantAddress: order?.store.address ?? '',
                        storePhone: _contactsVisible
                            ? order?.store.phone
                            : null,
                        onCallStore:
                            _contactsVisible &&
                                order?.store.phone != null &&
                                order!.store.phone!.isNotEmpty
                            ? () => _dial(order.store.phone!)
                            : null,
                        items: order?.items ?? const [],
                        total: order?.total ?? _total.toDouble(),
                        earning: order?.riderEarning ?? _earning.toDouble(),
                        isCashOnDelivery: order?.isCashOnDelivery ?? false,
                        isPaid: order?.isPaid ?? true,
                        paymentLabel: order != null
                            ? (order.isCashOnDelivery
                                  ? (order.isPaid
                                        ? 'Cash Collected'
                                        : 'Cash Pending')
                                  : (order.isPaid
                                        ? 'Paid Online'
                                        : 'Payment Pending'))
                            : null,
                      ),
                      // The customer's score for this delivery, once given.
                      // The rider's lifetime average lives on the profile; this
                      // is the only place a single trip's rating is visible.
                      if (order?.customerRating != null) ...[
                        SizedBox(height: 16.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18.r),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 18.sp,
                                    color: AppColors.rating,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Customer rating',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.sp,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    final filled =
                                        i < order!.customerRating!.round();
                                    return Icon(
                                      filled
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 20.sp,
                                      color: filled
                                          ? AppColors.rating
                                          : subTextColor,
                                    );
                                  }),
                                  SizedBox(width: 8.w),
                                  Text(
                                    order!.customerRating!.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.customerRatingComment.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  '"${order.customerRatingComment}"',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontStyle: FontStyle.italic,
                                    color: subTextColor,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (_loading) ...[
                        SizedBox(height: 16.h),
                        _LoadingMoreCard(
                          theme: theme,
                          subTextColor: subTextColor,
                        ),
                      ],
                      if (order != null &&
                          (order.customerName.isNotEmpty ||
                              order
                                  .deliveryAddress
                                  .fullAddress
                                  .isNotEmpty)) ...[
                        SizedBox(height: 16.h),
                        _CustomerDetailsCard(
                          order: order,
                          showPhone: _contactsVisible,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          surfaceColor: palette.surface,
                          surfaceVariant: palette.surfaceVariant,
                          borderColor: palette.border,
                          primaryColor: theme.primaryColor,
                          onCall: () => _dial(order.customerPhone),
                          onCopyAddress: () => _copyToClipboard(
                            order.deliveryAddress.fullAddress,
                            'Address',
                          ),
                        ),
                      ],
                      if (order != null &&
                          (order.tripDistanceKm != null ||
                              order.tripDurationMins != null ||
                              order.pickupDistanceKm != null)) ...[
                        SizedBox(height: 16.h),
                        _TripStatsCard(
                          order: order,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          surfaceColor: palette.surface,
                          surfaceVariant: palette.surfaceVariant,
                          borderColor: palette.border,
                          accentColor: st.color,
                        ),
                      ],
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTheme {
  const _StatusTheme({
    required this.color,
    required this.darkColor,
    required this.icon,
    required this.label,
  });
  final Color color;
  final Color darkColor;
  final IconData icon;
  final String label;
}

/// The receipt-look card: a rounded ticket with punch-hole notches cut into
/// its sides at the divider between the item list and the price summary.
class _ReceiptTicket extends StatelessWidget {
  const _ReceiptTicket({
    required this.scaffoldColor,
    required this.surfaceColor,
    required this.textColor,
    required this.subTextColor,
    required this.accentColor,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.storePhone,
    required this.onCallStore,
    required this.items,
    required this.total,
    required this.earning,
    required this.isCashOnDelivery,
    required this.isPaid,
    required this.paymentLabel,
  });

  final Color scaffoldColor;
  final Color surfaceColor;
  final Color textColor;
  final Color subTextColor;
  final Color accentColor;
  final String restaurantName;
  final String restaurantAddress;
  final String? storePhone;
  final VoidCallback? onCallStore;
  final List<OrderItem> items;
  final double total;
  final double earning;
  final bool isCashOnDelivery;
  final bool isPaid;
  final String? paymentLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Extra room on top: this card is pulled up over the green header, so
      // the restaurant name needs more clearance there than on the other
      // three sides or it reads as stuck to the header.
      padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: accentColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.sp,
                        color: textColor,
                      ),
                    ),
                    if (restaurantAddress.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        restaurantAddress,
                        style: TextStyle(fontSize: 11.sp, color: subTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onCallStore != null)
                Material(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    onPressed: onCallStore,
                    icon: Icon(
                      Icons.call_rounded,
                      color: accentColor,
                      size: 18.sp,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          _Notched(scaffoldColor: scaffoldColor),
          SizedBox(height: 16.h),
          if (items.isNotEmpty)
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    _VegNonVegBadge(isVeg: item.isVeg),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        '${item.quantity} × ${item.name}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Text(
                'Itemized bill unavailable for this trip',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: subTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          SizedBox(height: 14.h),
          _DashedLine(color: subTextColor.withValues(alpha: 0.3)),
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Total',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (paymentLabel != null) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Status',
                  style: TextStyle(fontSize: 12.sp, color: subTextColor),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isPaid
                          ? const Color(0xFF34A853).withValues(alpha: 0.3)
                          : const Color(0xFFFF9800).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCashOnDelivery
                            ? Icons.payments_outlined
                            : Icons.credit_card_rounded,
                        size: 12.sp,
                        color: isPaid
                            ? const Color(0xFF1E8E3E)
                            : const Color(0xFFE65100),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        paymentLabel!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? const Color(0xFF1E8E3E)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 18.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(9.r),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accentColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'YOUR EARNING',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  // No "+" on a zero payout — a cancelled trip earned nothing,
                  // and "+₹0" reads like a credit that never happened.
                  earning > 0
                      ? '+₹${earning.toStringAsFixed(0)}'
                      : '₹${earning.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VegNonVegBadge extends StatelessWidget {
  const _VegNonVegBadge({required this.isVeg});
  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? const Color(0xFF2EA154) : const Color(0xFFE53935);
    return Container(
      width: 14.w,
      height: 14.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: Container(
        width: 6.w,
        height: 6.w,
        decoration: BoxDecoration(
          color: color,
          shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isVeg ? null : BorderRadius.circular(1.r),
        ),
      ),
    );
  }
}

class _Notched extends StatelessWidget {
  const _Notched({required this.scaffoldColor});
  final Color scaffoldColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16.h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: _DashedLine(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          Positioned(
            left: -28.w,
            child: _Circle(size: 18.r, color: scaffoldColor),
          ),
          Positioned(
            right: -28.w,
            child: _Circle(size: 18.r, color: scaffoldColor),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashGap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: dashGap / 2),
              child: Container(width: dashWidth, height: 1.5, color: color),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerDetailsCard extends StatelessWidget {
  const _CustomerDetailsCard({
    required this.order,
    required this.textColor,
    required this.subTextColor,
    required this.surfaceColor,
    required this.surfaceVariant,
    required this.borderColor,
    required this.primaryColor,
    required this.onCall,
    required this.onCopyAddress,
    this.showPhone = true,
  });

  final DeliveryOrder order;
  final Color textColor;
  final Color subTextColor;
  final Color surfaceColor;
  final Color surfaceVariant;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onCall;
  final VoidCallback onCopyAddress;

  /// False once the trip is finished — see `_contactsVisible`.
  final bool showPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.person_pin_circle_rounded,
                  size: 18.sp,
                  color: primaryColor,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Customer Details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (order.customerName.isNotEmpty) ...[
            Row(
              children: [
                _iconBox(
                  Icons.person_outline_rounded,
                  surfaceVariant,
                  subTextColor,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Name',
                        style: TextStyle(fontSize: 10.sp, color: subTextColor),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          if (order.deliveryAddress.fullAddress.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBox(
                  Icons.location_on_outlined,
                  surfaceVariant,
                  subTextColor,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Address',
                        style: TextStyle(fontSize: 10.sp, color: subTextColor),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        order.deliveryAddress.fullAddress,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCopyAddress,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 16.sp,
                    color: subTextColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          if (showPhone && order.customerPhone.isNotEmpty) ...[
            Row(
              children: [
                _iconBox(
                  Icons.phone_outlined,
                  primaryColor.withValues(alpha: 0.12),
                  primaryColor,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Number',
                        style: TextStyle(fontSize: 10.sp, color: subTextColor),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        order.customerPhone,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onCall,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call, color: Colors.white, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (order.deliveryInstructions != null &&
              order.deliveryInstructions!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFFD580)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 16.sp,
                    color: const Color(0xFFD97706),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Note',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          order.deliveryInstructions!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(icon, size: 16.sp, color: iconColor),
    );
  }
}

class _TripStatsCard extends StatelessWidget {
  const _TripStatsCard({
    required this.order,
    required this.textColor,
    required this.subTextColor,
    required this.surfaceColor,
    required this.surfaceVariant,
    required this.borderColor,
    required this.accentColor,
  });

  final DeliveryOrder order;
  final Color textColor;
  final Color subTextColor;
  final Color surfaceColor;
  final Color surfaceVariant;
  final Color borderColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.route_rounded,
                  size: 18.sp,
                  color: accentColor,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Trip Statistics',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              if (order.pickupDistanceKm != null && order.pickupDistanceKm! > 0)
                Expanded(
                  child: _statTile(
                    icon: Icons.near_me_rounded,
                    value: '${order.pickupDistanceKm!.toStringAsFixed(1)} km',
                    label: 'Pickup',
                    bg: surfaceVariant,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    accentColor: accentColor,
                  ),
                ),
              if (order.pickupDistanceKm != null && order.pickupDistanceKm! > 0)
                SizedBox(width: 10.w),
              if (order.tripDistanceKm != null && order.tripDistanceKm! > 0)
                Expanded(
                  child: _statTile(
                    icon: Icons.navigation_rounded,
                    value: '${order.tripDistanceKm!.toStringAsFixed(1)} km',
                    label: 'Delivery',
                    bg: surfaceVariant,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    accentColor: accentColor,
                  ),
                ),
              if (order.tripDistanceKm != null && order.tripDistanceKm! > 0)
                SizedBox(width: 10.w),
              if (order.tripDurationMins != null && order.tripDurationMins! > 0)
                Expanded(
                  child: _statTile(
                    icon: Icons.timer_outlined,
                    value: '${order.tripDurationMins!.toStringAsFixed(0)} min',
                    label: 'Duration',
                    bg: surfaceVariant,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    accentColor: accentColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color bg,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18.sp, color: accentColor),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMoreCard extends StatelessWidget {
  const _LoadingMoreCard({required this.theme, required this.subTextColor});
  final ThemeData theme;
  final Color subTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            'Loading full trip details…',
            style: TextStyle(fontSize: 12.sp, color: subTextColor),
          ),
        ],
      ),
    );
  }
}
