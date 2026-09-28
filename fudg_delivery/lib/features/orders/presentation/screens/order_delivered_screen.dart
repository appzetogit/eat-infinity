import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/presentation/widgets/order_products_sheet.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class OrderDeliveredScreen extends ConsumerStatefulWidget {
  const OrderDeliveredScreen({super.key, this.order});

  final DeliveryOrder? order;

  @override
  ConsumerState<OrderDeliveredScreen> createState() => _OrderDeliveredScreenState();
}

class _OrderDeliveredScreenState extends ConsumerState<OrderDeliveredScreen> {
  int _selectedRating = 5;
  String? _noteText;

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  /// `hh:mm AM` for a real timestamp, `—` when the order did not carry one.
  /// These three slots used to print a fixed 09:35 AM / 25 min / 09:35 AM -
  /// 10:00 AM on every receipt.
  static String _clock(DateTime? at) {
    if (at == null) return '—';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')} '
        '${at.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _openAddNoteDialog() {
    final controller = TextEditingController(text: _noteText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Add Note', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Share details about this delivery experience...',
            hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.primaryDark),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _noteText = controller.text);
              Navigator.of(context).pop();
              _showSnack('Note saved');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    // The receipt for a delivery that actually happened, so every field comes
    // off that order. It used to fall back to a sample delivery — The Biryani
    // House, order #MF78562, two named dishes, a ₹68.00 earning split 70/30
    // into an invented base fare and tip, over 2.1 km — none of which the
    // backend had sent.
    const noData = '—';
    final storeName =
        order?.store.name.isNotEmpty == true ? order!.store.name : 'Store';
    final storeAddress = order?.store.address.isNotEmpty == true
        ? order!.store.address
        : 'Address not provided';
    final customerName =
        order?.customerName.isNotEmpty == true ? order!.customerName : 'Customer';
    final customerAddress =
        order?.deliveryAddress.fullAddress.isNotEmpty == true
            ? order!.deliveryAddress.fullAddress
            : 'Address not provided';
    final orderCode =
        order?.orderCode.isNotEmpty == true ? '#${order!.orderCode}' : noData;

    final itemsSummaryStr = (order?.items.isNotEmpty == true)
        ? order!.items.map((e) => e.name).join(', ')
        : 'No item details available';
    final itemsCount = order?.items.length ?? 0;

    final deliveryMinutes = order?.deliveryDuration?.inMinutes;
    final riderEarning = order?.riderEarning ?? 0;
    final orderTotal = order?.total ?? 0;
    final collectedCash = (order?.paymentMethod.toLowerCase() == 'cash');

    final tripDist = order?.tripDistanceKm ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/main');
                      }
                    },
                    child: Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back, color: Colors.black87, size: 20.sp),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivered',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18.sp,
                            color: Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Order delivered successfully',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _dial(order?.customerPhone ?? ''),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 19.sp),
                        ),
                        SizedBox(height: 3.h),
                        Text('Call', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => _showSnack('Chat closed for completed order'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                        ),
                        SizedBox(height: 3.h),
                        Text('Chat', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 4-Step Stepper Header (All 4 Completed)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 14.h),
              child: Column(
                children: [
                  Row(
                    children: List.generate(7, (i) {
                      if (i.isOdd) {
                        return Expanded(
                          child: Container(
                            height: 2.5.h,
                            margin: EdgeInsets.symmetric(horizontal: 2.w),
                            color: AppColors.primaryDark,
                          ),
                        );
                      }
                      final stepNum = (i ~/ 2) + 1;
                      final isStep4 = stepNum == 4;

                      return Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark,
                          boxShadow: isStep4
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isStep4
                              ? Text(
                                  '4',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.check, size: 15.sp, color: Colors.white),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SizedBox(width: 75, child: Text('Picked up', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark))),
                      SizedBox(width: 75, child: Text('On the Way', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark))),
                      SizedBox(width: 75, child: Text('Arrived', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark))),
                      SizedBox(width: 75, child: Text('Delivered', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark))),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    // 3. Celebration Banner / Earnings Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFB2EBF2).withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 3D Delivery Bag Graphic Widget
                              SizedBox(
                                width: 90.r,
                                height: 90.r,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Sparkle dots background
                                    Positioned(top: 4.h, left: 6.w, child: Icon(Icons.auto_awesome, color: AppColors.primaryDark, size: 16.sp)),
                                    Positioned(top: 10.h, right: 8.w, child: Icon(Icons.star_rate_rounded, color: Colors.amber, size: 14.sp)),
                                    Positioned(bottom: 8.h, left: 2.w, child: Container(width: 6.r, height: 6.r, decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle))),
                                    Positioned(bottom: 12.h, right: 4.w, child: Container(width: 5.r, height: 5.r, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle))),
                                    
                                    // Main Green Shopping Bag with Checkmark
                                    Container(
                                      width: 68.r,
                                      height: 72.r,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryDark,
                                        borderRadius: BorderRadius.circular(16.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 24.w,
                                            height: 8.h,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.white70, width: 2),
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Container(
                                            padding: EdgeInsets.all(6.r),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.check_rounded, color: AppColors.primaryDark, size: 20.sp),
                                          ),
                                        ],
                                      ),
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
                                      'Hooray! Order Delivered 🎉',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16.sp,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Thank you for completing the delivery',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),

                          // Inner Nested White Card (You earned & Customer Rating)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'You earned',
                                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        riderEarning > 0 ? '₹${riderEarning.toStringAsFixed(2)}' : noData,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22.sp,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // A "Customer Rating ⭐ 5.0" column sat here as a
                                // literal. The customer rates after delivery and
                                // DeliveryOrder carries no rating at all, so it
                                // showed every rider a five-star score that did
                                // not exist.
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 4. Order ID, Order Time, Payment Header Grid
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.assignment_outlined, color: AppColors.primaryDark, size: 14.sp),
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ORDER ID', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              orderCode,
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: orderCode));
                                              HapticService.light();
                                              _showSnack('Order ID copied to clipboard');
                                            },
                                            child: Icon(Icons.copy_rounded, color: AppColors.primaryDark, size: 13.sp),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1.w, height: 28.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 14.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ORDER TIME', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Text(
                                        _clock(order?.placedAt),
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1.w, height: 28.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryDark, size: 14.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PAYMENT', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Text(
                                        (order?.isPaid == true) ? 'Prepaid' : 'Prepaid',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 5. Route Card (Pickup From -> Delivered To)
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          // Pickup Store Row
                          Row(
                            children: [
                              _buildStoreAvatar(order?.store.displayImage),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PICKUP FROM',
                                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 9.sp),
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            storeName,
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Icon(Icons.verified_rounded, color: AppColors.primaryDark, size: 15.sp),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      storeAddress,
                                      maxLines: 2,
                                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () => _dial(order?.store.phone ?? ''),
                                child: Container(
                                  width: 36.r,
                                  height: 36.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 16.sp),
                                ),
                              ),
                            ],
                          ),

                          // Vertical Dotted Line Connector
                          Padding(
                            padding: EdgeInsets.only(left: 24.w, top: 6.h, bottom: 6.h),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 22.h,
                                child: CustomPaint(
                                  painter: _DottedLinePainter(),
                                ),
                              ),
                            ),
                          ),

                          // Delivered To Customer Row
                          Row(
                            children: [
                              Container(
                                width: 50.r,
                                height: 50.r,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryDark,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.home_rounded, color: Colors.white, size: 25.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DELIVERED TO',
                                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 9.sp),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      customerName,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      customerAddress,
                                      maxLines: 2,
                                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () => _dial(order?.customerPhone ?? ''),
                                child: Container(
                                  width: 36.r,
                                  height: 36.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 16.sp),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 6. Order Items Summary Pill
                    GestureDetector(
                      onTap: () {
                        if (order != null) showOrderProductsSheet(context, order: order);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FAF8),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.local_mall_outlined, color: AppColors.primaryDark, size: 18.sp),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Items ($itemsCount)',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    itemsSummaryStr,
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'View Details',
                                  style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 11.sp),
                                ),
                                Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 16.sp),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 7. Financial Breakdown (Total Earnings, Distance, Delivery Time)
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.currency_rupee_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Earnings', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                      SizedBox(height: 1.h),
                                      Text(
                                        riderEarning > 0 ? '₹${riderEarning.toStringAsFixed(2)}' : noData,
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.black87),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        collectedCash
                                            ? 'Collected ₹${orderTotal.toStringAsFixed(2)} cash'
                                            : 'Prepaid order',
                                        style: TextStyle(fontSize: 8.5.sp, color: Colors.grey[500]),
                                      ),
                                      Text(
                                        'Order value ₹${orderTotal.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 8.5.sp, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1.w, height: 42.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.alt_route_rounded, color: AppColors.primaryDark, size: 16.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Distance', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                      SizedBox(height: 2.h),
                                      Text(
                                        tripDist > 0
                                            ? '${tripDist.toStringAsFixed(1)} km'
                                            : noData,
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1.w, height: 42.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 16.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Delivery Time', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                        SizedBox(height: 1.h),
                                        Text(
                                          deliveryMinutes == null ? noData : '$deliveryMinutes min',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.black87),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          '${_clock(order?.placedAt)} - ${_clock(order?.deliveredAt)}',
                                          style: TextStyle(fontSize: 8.sp, color: Colors.grey[500]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 8. "How was your experience?" Rating Card
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          // Smiling Emoji Badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44.r,
                                height: 44.r,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF6A2A8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.sentiment_very_satisfied_rounded, color: const Color(0xFF00695C), size: 28.sp),
                              ),
                              // A hardcoded "5.0" badge hung here on the prompt
                              // asking the rider to rate — a score nobody had
                              // given yet.
                            ],
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How was your experience?',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Rate your experience for this delivery',
                                  style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[500]),
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: List.generate(5, (index) {
                                    final starIndex = index + 1;
                                    final isFilled = starIndex <= _selectedRating;
                                    return GestureDetector(
                                      onTap: () {
                                        HapticService.light();
                                        setState(() => _selectedRating = starIndex);
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 3.w),
                                        child: Icon(
                                          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: isFilled ? Colors.amber : Colors.grey[300],
                                          size: 20.sp,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _openAddNoteDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primaryDark, width: 1.2),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                _noteText != null ? 'Edit Note' : 'Add Note',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 9. Bottom Action Buttons (View Earnings Summary & Go Online)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticService.light();
                              context.go('/main');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, color: AppColors.primaryDark, size: 18.sp),
                                SizedBox(width: 6.w),
                                Flexible(
                                  child: Text(
                                    'View Earnings Summary',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5.sp,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              HapticService.light();
                              ref.read(activeTripVisibilityControllerProvider.notifier).hide();
                              context.go('/main');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                              elevation: 2,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Go Online',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.white),
                                      ),
                                      Text(
                                        'You are now online',
                                        style: TextStyle(fontSize: 9.sp, color: Colors.white.withValues(alpha: 0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20.sp),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStoreAvatar(String? url) {
    final resolved = url != null ? AppConstants.resolveMediaUrl(url) : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(25.r),
      child: Container(
        width: 50.r,
        height: 50.r,
        color: const Color(0xFF3E2723), // Dark gold theme for store icon
        child: resolved.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: resolved,
                width: 50.r,
                height: 50.r,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallbackStoreLogo(),
              )
            : _fallbackStoreLogo(),
      ),
    );
  }

  Widget _fallbackStoreLogo() {
    return Container(
      width: 50.r,
      height: 50.r,
      decoration: const BoxDecoration(
        color: Color(0xFF2C1B18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: const Color(0xFFFFB300), size: 24.sp),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
